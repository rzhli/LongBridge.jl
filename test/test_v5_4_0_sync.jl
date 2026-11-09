using Test, HTTP, JSON, SHA, Base64
using LongBridge

const _OAuth540 = LongBridge.OAuth

function _oauth540_error(f, code)
    err = try
        f()
        nothing
    catch e
        e
    end
    @test err isa OAuthError
    if err isa OAuthError
        @test err.code == code
        @test occursin("code=$code", sprint(showerror, err))
    end
    return err
end

function _oauth540_handle(; client_id = "client +/&", refresh = "refresh +/&=令牌", expiry = 0)
    token = OAuthToken(client_id, "access +/&=令牌", refresh, UInt64(expiry))
    OAuthHandle(client_id, UInt16(0), token)
end

function _oauth540_fetch(task)
    @test timedwait(() -> istaskdone(task), 5; pollint = 0.01) == :ok
    istaskdone(task) || error("OAuth test task did not finish")
    fetch(task)
end

@testset "v5.4.0 typed OAuth errors and local lifecycle" begin
    for (name, code) in [
        :Other => 0, :NoTokenAvailable => 1, :NoRefreshToken => 2,
        :RefreshTokenFailed => 3, :RevokeFailed => 4, :AuthorizationFailed => 5,
        :AuthorizationTimeout => 6, :ExchangeCodeFailed => 7, :CsrfTokenMismatch => 8,
        :BindCallbackFailed => 9, :LocalAddressFailed => 10, :CallbackChannelClosed => 11,
        :NoHomeDir => 12, :TokenFileRead => 13, :TokenFileParse => 14,
        :TokenFileWrite => 15, :TokenFileDelete => 16, :CreateDirFailed => 17,
        :SerializeToken => 18,
    ]
        @test OAuthError(getproperty(OAuthErrorCode, name), "fixture").code == code
    end
    @test LongBridge.revoke! === _OAuth540.revoke!
    @test LongBridge.clear! === _OAuth540.clear!
    @test LongBridge.HttpClient.OAUTH_REQUEST_KW.client === LongBridge.HttpClient.HTTP_CLIENT
    @test LongBridge.HttpClient.OAUTH_REQUEST_KW.connect_timeout == 10
    @test LongBridge.HttpClient.OAUTH_REQUEST_KW.request_timeout == 35
    @test LongBridge.HttpClient.OAUTH_TOKEN_TIMEOUT == 30

    mktempdir() do dir
        withenv("LONGBRIDGE_TOKEN_DIR" => dir) do
            handle = _oauth540_handle(client_id = "local", expiry = 4102444800)
            token = handle.token
            path = _OAuth540.save_to_path(token)
            @test clear!(handle) === nothing
            @test handle.token === nothing
            @test !ispath(path)
            @test clear!(handle) === nothing
            _oauth540_error(() -> _OAuth540.access_token(handle), 1)
            _oauth540_error(() -> revoke!(handle), 1)

            handle.token = token
            mkdir(path)
            _oauth540_error(() -> clear!(handle), 16)
            @test handle.token === token
            @test _OAuth540.access_token(handle) == token.access_token
            @test isdir(path)
            rm(path)

            # A client without an ID cannot revoke and has no cache to delete.
            external = _oauth540_handle(client_id = "", refresh = nothing)
            _oauth540_error(() -> revoke!(external), 4)
            @test clear!(external) === nothing
            @test isdir(dir)
            _oauth540_error(() -> _OAuth540.access_token(_oauth540_handle(refresh = nothing)), 2)

            # Cached valid tokens never start browser authorization.
            _OAuth540.save_to_path(token)
            cached = OAuthBuilder("local") |> build(_ -> error("unexpected browser"))
            @test _OAuth540.access_token(cached) == token.access_token
            # Corrupt cache is still ignored, preserving the existing load contract.
            write(path, "not JSON")
            @test_logs (:warn, "Failed to load cached OAuth token") _OAuth540.load_from_path("local")
            rm(path)

            blocked = joinpath(dir, "blocked")
            write(blocked, "not a directory")
            withenv("LONGBRIDGE_TOKEN_DIR" => joinpath(blocked, "tokens")) do
                _oauth540_error(() -> _OAuth540.save_to_path(token), 17)
            end
        end
    end
end

@testset "v5.4.0 OAuth HTTP contracts, errors and redirects" begin
    seen = NamedTuple[]
    response = Ref(HTTP.Response(200; body = ""))
    server = HTTP.serve!("127.0.0.1", 0) do req
        push!(seen, (method = req.method, path = HTTP.URI(req.target).path,
            fields = HTTP.queryparams(HTTP.URI("http://fixture/?" * String(req.body))),
            content_type = HTTP.header(req, "Content-Type")))
        response[]
    end
    url = "http://127.0.0.1:$(HTTP.port(server))"
    post_token = fields -> _OAuth540._post_token(fields; base_url = url)
    post_revoke = fields -> _OAuth540._post_revoke(fields; base_url = url)
    try
        mktempdir() do dir
            withenv("LONGBRIDGE_TOKEN_DIR" => dir) do
                handle = _oauth540_handle()
                original = handle.token
                path = _OAuth540.save_to_path(original)
                saved = read(path)
                @test _OAuth540._revoke!(handle, post_revoke) === nothing
                @test seen[end].path == "/oauth2/revoke"
                @test seen[end].method == "POST"
                @test startswith(seen[end].content_type, "application/x-www-form-urlencoded")
                @test seen[end].fields == Dict("client_id" => handle.client_id,
                    "token" => original.refresh_token, "token_type_hint" => "refresh_token")
                @test handle.token === original
                @test read(path) == saved

                handle.token = OAuthToken(handle.client_id, original.access_token, nothing, UInt64(0))
                _OAuth540._revoke!(handle, post_revoke)
                @test seen[end].fields["token"] == original.access_token
                @test seen[end].fields["token_type_hint"] == "access_token"
                handle.token = original

                # Server rejections retain the error and description, without retries.
                for (status, body, message) in [
                    (400, "{\"error\":\"invalid_grant\",\"error_description\":\"expired refresh token\"}",
                        "Server returned error response: invalid_grant: expired refresh token"),
                    (400, "{\"error\":\"unsupported_token_type\"}",
                        "Server returned error response: unsupported_token_type"),
                    (503, "upstream unavailable", "Server returned HTTP 503"),
                    (429, "{}", "Server returned HTTP 429"),
                ]
                    response[] = HTTP.Response(status; body)
                    for (operation, code) in [
                        (() -> _OAuth540._revoke!(handle, post_revoke), 4),
                        (() -> _OAuth540._access_token(handle, post_token), 3),
                        (() -> post_token((grant_type = "authorization_code", code = "fake")), 7),
                    ]
                        before = length(seen)
                        err = _oauth540_error(operation, code)
                        @test occursin(message, sprint(showerror, err))
                        @test length(seen) == before + 1
                        @test handle.token === original
                        @test read(path) == saved
                    end
                end

                # Preserve the existing fallback only while the access token is valid.
                soon = OAuthToken(handle.client_id, original.access_token, original.refresh_token,
                    UInt64(floor(time())) + 600)
                handle.token = soon
                @test _OAuth540._access_token(handle, post_token) == soon.access_token
                @test handle.token === soon
                @test read(path) == saved
                handle.token = original

                response[] = HTTP.Response(307, ["Location" => "$url/leak"]; body = "")
                _oauth540_error(() -> _OAuth540._revoke!(handle, post_revoke), 4)
                _oauth540_error(() -> _OAuth540._access_token(handle, post_token), 3)
                _oauth540_error(() -> post_token((grant_type = "authorization_code", code = "fake")), 7)
                @test all(r -> r.path != "/leak", seen)

                for bad_body in ["invalid JSON", "{}", "{\"access_token\":42}",
                    "{\"access_token\":\"a\",\"expires_in\":-1}"]
                    response[] = HTTP.Response(200; body = bad_body)
                    _oauth540_error(() -> _OAuth540._access_token(handle, post_token), 3)
                    @test handle.token === original
                    @test read(path) == saved
                end

                response[] = HTTP.Response(200; body = JSON.json((
                    access_token = "rotated access", refresh_token = "rotated refresh", expires_in = 7200)))
                @test _OAuth540._access_token(handle, post_token) == "rotated access"
                @test seen[end].fields["grant_type"] == "refresh_token"
                @test seen[end].fields["refresh_token"] == original.refresh_token
                @test handle.token.refresh_token == "rotated refresh"
                @test _OAuth540.load_from_path(handle.client_id).access_token == "rotated access"
                before = length(seen)
                @test _OAuth540.access_token(handle) == "rotated access"
                @test length(seen) == before

                for refresh_field in [NamedTuple(), (refresh_token = nothing,)]
                    response[] = HTTP.Response(200; body = JSON.json((access_token = "next", refresh_field...)))
                    _OAuth540._refresh_token!(handle, post_token)
                    @test handle.token.refresh_token == "rotated refresh"
                    @test 3590 <= Int(handle.token.expires_at) - floor(Int, time()) <= 3600
                end

                # Keep the current token if persisting a successful refresh fails.
                current = handle.token
                rm(path)
                mkdir(path)
                _oauth540_error(() -> _OAuth540._refresh_token!(handle, post_token), 15)
                @test handle.token === current
                rm(path)
                @test clear!(handle) === nothing
                before = length(seen)
                cfg = from_oauth(handle; http_url = url)
                _oauth540_error(() -> LongBridge.Client.http_get(cfg, "/v1/test"), 1)
                @test length(seen) == before
            end
        end
    finally
        close(server)
    end

    # A closed loopback port supplies a real transport error, with its cause retained.
    err = _oauth540_error(() -> post_token((grant_type = "refresh_token", refresh_token = "fake")), 3)
    @test err.cause isa Exception
    @test occursin(sprint(showerror, err.cause), sprint(showerror, err))
end

function _oauth540_callback(url; code = "auth code +/&", state = nothing, error = nothing)
    query = HTTP.queryparams(HTTP.URI(url))
    fields = isnothing(error) ? (code = code, state = something(state, query["state"])) :
        (error = error, error_description = "user declined")
    callback = replace(query["redirect_uri"], "localhost" => "127.0.0.1")
    HTTP.get(callback; query = Dict(string(k) => v for (k, v) in pairs(fields)),
        status_exception = false, retry = false, request_timeout = 5)
end

@testset "v5.4.0 browser PKCE, callbacks and builder" begin
    verifiers = String[]
    states = String[]
    seen = NamedTuple[]
    response = Ref(HTTP.Response(200; body = JSON.json((access_token = "authorized", expires_in = 7200))))
    server = HTTP.serve!("127.0.0.1", 0) do req
        push!(seen, (path = HTTP.URI(req.target).path,
            fields = HTTP.queryparams(HTTP.URI("http://fixture/?" * String(req.body)))))
        response[]
    end
    url = "http://127.0.0.1:$(HTTP.port(server))"
    post_token = fields -> _OAuth540._post_token(fields; base_url = url)
    try
        mktempdir() do dir
            withenv("LONGBRIDGE_TOKEN_DIR" => dir) do
                for i in 1:2
                    handle = OAuthHandle("public-client-$i", UInt16(0), nothing)
                    auth_query = Ref{Any}()
                    open_url = function (auth_url)
                        query = HTTP.queryparams(HTTP.URI(auth_url))
                        auth_query[] = query
                        @test query["client_id"] == handle.client_id
                        @test query["response_type"] == "code"
                        @test query["code_challenge_method"] == "S256"
                        @test !haskey(query, "code_verifier")
                        @test HTTP.URI(query["redirect_uri"]).port != "0"
                        push!(states, query["state"])
                        # Unrelated callback paths are ignored.
                        callback = replace(query["redirect_uri"], "localhost" => "127.0.0.1")
                        @test HTTP.get(callback * "-extra"; status_exception = false).status == 404
                        @test _oauth540_callback(auth_url).status == 200
                        # Duplicate callbacks must never block server shutdown.
                        @test _oauth540_callback(auth_url).status == 200
                    end
                    _OAuth540._authorize!(handle, open_url, post_token; auth_timeout = 5)
                    fields = seen[end].fields
                    @test seen[end].path == "/oauth2/token"
                    @test fields["grant_type"] == "authorization_code"
                    @test fields["code"] == "auth code +/&"
                    @test fields["redirect_uri"] == auth_query[]["redirect_uri"]
                    verifier = fields["code_verifier"]
                    push!(verifiers, verifier)
                    @test occursin(r"^[A-Za-z0-9_-]{43}$", verifier)
                    expected = replace(rstrip(base64encode(sha256(verifier)), '='), '+' => '-', '/' => '_')
                    @test auth_query[]["code_challenge"] == expected
                    @test handle.token.access_token == "authorized"
                    @test _OAuth540.load_from_path(handle.client_id).access_token == "authorized"
                end
                @test verifiers[1] != verifiers[2]
                @test states[1] != states[2]

                for (open_url, expected_code) in [
                    (url -> _oauth540_callback(url; state = "wrong"), 8),
                    (url -> _oauth540_callback(url; error = "access_denied"), 5),
                    (url -> _oauth540_callback(url; code = ""), 5),
                    (_ -> error("browser failed"), 0),
                ]
                    handle = OAuthHandle("callback-error", UInt16(0), nothing)
                    before = length(seen)
                    _oauth540_error(() -> _OAuth540._authorize!(handle, open_url, post_token), expected_code)
                    @test handle.token === nothing
                    @test !isfile(_OAuth540.token_path(handle.client_id))
                    @test length(seen) == before
                end

                handle = OAuthHandle("timeout", UInt16(0), nothing)
                _oauth540_error(() -> _OAuth540._authorize!(handle, _ -> nothing, post_token; auth_timeout = 0.05), 6)
                @test !islocked(handle.lock)
                # An occupied callback port fails with a typed error before opening a browser.
                occupied = OAuthHandle("occupied", UInt16(HTTP.port(server)), nothing)
                _oauth540_error(() -> _OAuth540.authorize!(occupied, _ -> error("unexpected browser")), 9)

                builder = OAuthBuilder("build-error")
                _OAuth540.callback_port!(builder, 0)
                response[] = HTTP.Response(400; body = "{\"error\":\"invalid_grant\"}")
                _oauth540_error(() -> _OAuth540._build(builder, _oauth540_callback, post_token), 7)
                @test !isfile(_OAuth540.token_path("build-error"))

                # A failed refresh falls back to authorization, which also carries PKCE.
                token = OAuthToken("build-recover", "expired", "bad-refresh", UInt64(0))
                _OAuth540.save_to_path(token)
                builder = OAuthBuilder(token.client_id)
                _OAuth540.callback_port!(builder, 0)
                open_url = function (auth_url)
                    response[] = HTTP.Response(200; body = "{\"access_token\":\"recovered\",\"expires_in\":7200}")
                    _oauth540_callback(auth_url)
                end
                handle = _OAuth540._build(builder, open_url, post_token)
                @test handle.token.access_token == "recovered"
                @test haskey(seen[end].fields, "code_verifier")
            end
        end
    finally
        close(server)
    end
end

@testset "v5.4.0 token lock serialization and timeout release" begin
    entered = Channel{Nothing}(1)
    release = Channel{Nothing}(1)
    seen = String[]
    revoked_tokens = String[]
    blocking_path = Ref("/oauth2/revoke")
    delay = Ref(false)
    server = HTTP.serve!("127.0.0.1", 0) do req
        path = HTTP.URI(req.target).path
        push!(seen, path)
        if path == "/oauth2/revoke"
            fields = HTTP.queryparams(HTTP.URI("http://fixture/?" * String(req.body)))
            push!(revoked_tokens, fields["token"])
        end
        if delay[]
            sleep(0.5)
        elseif path == blocking_path[]
            put!(entered, nothing)
            take!(release)
        end
        HTTP.Response(200; body = path == "/oauth2/revoke" ? "" :
            "{\"access_token\":\"rotated\",\"refresh_token\":\"new-refresh\",\"expires_in\":7200}")
    end
    url = "http://127.0.0.1:$(HTTP.port(server))"
    post_token = fields -> _OAuth540._post_token(fields; base_url = url)
    post_revoke = fields -> _OAuth540._post_revoke(fields; base_url = url)
    try
        mktempdir() do dir
            withenv("LONGBRIDGE_TOKEN_DIR" => dir) do
                for next_operation in [:refresh, :clear]
                    empty!(seen)
                    handle = _oauth540_handle(client_id = "serialized")
                    original = handle.token
                    _OAuth540.save_to_path(original)
                    revoking = @async _OAuth540._revoke!(handle, post_revoke)
                    @test timedwait(() -> isready(entered), 5; pollint = 0.01) == :ok
                    isready(entered) || error("revocation did not reach fixture")
                    take!(entered)
                    waiting = @async next_operation == :refresh ?
                        _OAuth540._access_token(handle, post_token) : clear!(handle)
                    yield()
                    @test !istaskdone(waiting)
                    @test handle.token === original
                    @test seen == ["/oauth2/revoke"]
                    put!(release, nothing)
                    @test _oauth540_fetch(revoking) === nothing
                    _oauth540_fetch(waiting)
                    if next_operation == :refresh
                        @test seen == ["/oauth2/revoke", "/oauth2/token"]
                        @test handle.token.refresh_token == "new-refresh"
                    else
                        @test handle.token === nothing
                        @test !isfile(_OAuth540.token_path(handle.client_id))
                    end
                end

                # A refresh that wins the lock must finish before revoke reads
                # the rotated token, or before clear deletes the newly saved file.
                blocking_path[] = "/oauth2/token"
                for next_operation in [:revoke, :clear]
                    empty!(seen)
                    handle = _oauth540_handle(client_id = "refresh-first")
                    _OAuth540.save_to_path(handle.token)
                    refreshing = @async _OAuth540._refresh_token!(handle, post_token)
                    @test timedwait(() -> isready(entered), 5; pollint = 0.01) == :ok
                    isready(entered) || error("refresh did not reach fixture")
                    take!(entered)
                    waiting = @async next_operation == :revoke ?
                        _OAuth540._revoke!(handle, post_revoke) : clear!(handle)
                    yield()
                    @test !istaskdone(waiting)
                    @test seen == ["/oauth2/token"]
                    put!(release, nothing)
                    @test _oauth540_fetch(refreshing) === nothing
                    @test _oauth540_fetch(waiting) === nothing
                    if next_operation == :revoke
                        @test revoked_tokens[end] == "new-refresh"
                        @test handle.token.refresh_token == "new-refresh"
                        @test _OAuth540.load_from_path(handle.client_id).refresh_token == "new-refresh"
                    else
                        @test handle.token === nothing
                        @test !isfile(_OAuth540.token_path(handle.client_id))
                    end
                end

                delay[] = true
                for (operation, code) in [
                    (h -> _OAuth540._revoke!(h, fields -> _OAuth540._post_revoke(fields;
                        base_url = url, request_timeout = 0.15)), 4),
                    (h -> _OAuth540._access_token(h, fields -> _OAuth540._post_token(fields;
                        base_url = url, request_timeout = 0.15)), 3),
                ]
                    handle = _oauth540_handle(client_id = "deadline")
                    original = handle.token
                    path = _OAuth540.save_to_path(original)
                    task = @async _oauth540_error(() -> operation(handle), code)
                    err = _oauth540_fetch(task)
                    @test err.cause isa Exception
                    @test handle.token === original
                    @test _OAuth540.load_from_path(handle.client_id).access_token == original.access_token
                    # Another task acquires the lock after timeout and removes the cache.
                    @test _oauth540_fetch(@async clear!(handle)) === nothing
                    @test !isfile(path)
                end
                _oauth540_error(() -> _OAuth540._post_token((grant_type = "authorization_code", code = "fake");
                    base_url = url, request_timeout = 0.15), 7)
            end
        end
    finally
        isready(release) || put!(release, nothing)
        close(server)
    end
end
