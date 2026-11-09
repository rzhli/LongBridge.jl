module OAuth

using HTTP, JSON, Random, SHA, Base64
using Base.Threads: ReentrantLock

using ..Errors: OAuthError, OAuthErrorCode
using ..HttpClient: HTTP_CLIENT, OAUTH_REQUEST_KW, OAUTH_TOKEN_TIMEOUT

export OAuthToken,
    OAuthHandle,
    OAuthBuilder,
    build,
    is_expired,
    expires_soon,
    access_token,
    load_from_path,
    save_to_path,
    callback_port!,
    OAuthError,
    OAuthErrorCode,
    revoke!,
    clear!

# ==================== Constants ====================

const OAUTH_BASE_URL = "https://openapi.longbridgeapp.com"
const OAUTH_AUTHORIZE_PATH = "/oauth2/authorize"
const OAUTH_TOKEN_PATH = "/oauth2/token"
const OAUTH_REVOKE_PATH = "/oauth2/revoke"
const DEFAULT_CALLBACK_PORT = UInt16(60355)
const DEFAULT_REDIRECT_URI = "http://localhost:60355/callback"
const AUTH_TIMEOUT = 300.0  # 5 minutes

# ==================== Token Endpoint ====================

function _oauth_try(f, code::OAuthErrorCode.T, message::String)
    try
        return f()
    catch e
        e isa InterruptException && rethrow()
        e isa OAuthError && rethrow()
        throw(OAuthError(code, message, e))
    end
end

# Private endpoint/timeout arguments let protocol tests use loopback servers.
# NamedTuple bodies use HTTP.jl's application/x-www-form-urlencoded encoder.
function _post_oauth(path, fields, code, message; base_url = OAUTH_BASE_URL,
    request_timeout = OAUTH_REQUEST_KW.request_timeout)
    return _oauth_try(code, message) do
        resp = HTTP.post(base_url * path; body = fields,
            OAUTH_REQUEST_KW..., request_timeout)
        if resp.status != 200
            data = try
                JSON.parse(resp.body)
            catch
                nothing
            end
            detail = "Server returned HTTP $(resp.status)"
            if data isa AbstractDict && get(data, :error, nothing) isa AbstractString
                detail = "Server returned error response: $(data.error)"
                description = get(data, :error_description, nothing)
                if description isa AbstractString && !isempty(description)
                    detail *= ": $description"
                end
            end
            throw(OAuthError(code, "$message: $detail"))
        end
        resp
    end
end

function _post_token(fields::NamedTuple; base_url = OAUTH_BASE_URL,
    request_timeout = fields.grant_type == "refresh_token" ?
        OAUTH_TOKEN_TIMEOUT : OAUTH_REQUEST_KW.request_timeout)
    refreshing = fields.grant_type == "refresh_token"
    code = refreshing ? OAuthErrorCode.RefreshTokenFailed : OAuthErrorCode.ExchangeCodeFailed
    message = refreshing ? "failed to refresh token" : "failed to exchange code for token"
    return _oauth_try(code, message) do
        resp = _post_oauth(OAUTH_TOKEN_PATH, fields, code, message; base_url, request_timeout)
        JSON.parse(resp.body)
    end
end

function _post_revoke(fields::NamedTuple; base_url = OAUTH_BASE_URL,
    request_timeout = OAUTH_TOKEN_TIMEOUT)
    _post_oauth(OAUTH_REVOKE_PATH, fields, OAuthErrorCode.RevokeFailed,
        "failed to revoke token"; base_url, request_timeout)
    # RFC 7009 success can have an empty body (including an already-invalid token).
    return nothing
end

function _token_dir()
    dir = get(ENV, "LONGBRIDGE_TOKEN_DIR", "")
    !isempty(dir) && return dir

    home = get(ENV, Sys.iswindows() ? "USERPROFILE" : "HOME", "")
    !isempty(home) && return joinpath(home, ".longbridge", "tokens")

    isempty(Base.DEPOT_PATH) && throw(OAuthError(OAuthErrorCode.NoHomeDir,
        "cannot determine home directory or Julia depot for token storage"))
    return joinpath(first(Base.DEPOT_PATH), "longbridge", "tokens")
end

# ==================== OAuthToken ====================

"""
    OAuthToken

Represents an OAuth 2.0 token with access and refresh tokens.
Persisted as JSON under `\$LONGBRIDGE_TOKEN_DIR` when set, otherwise under
the user-level LongBridge token directory.
"""
struct OAuthToken
    client_id::String
    access_token::String
    refresh_token::Union{String,Nothing}
    expires_at::UInt64  # unix timestamp
end

"""
    is_expired(token::OAuthToken) -> Bool

Returns true if the token has expired.
"""
is_expired(token::OAuthToken) = UInt64(floor(time())) >= token.expires_at

"""
    expires_soon(token::OAuthToken) -> Bool

Returns true if the token expires within 1 hour (or is already expired).
"""
function expires_soon(token::OAuthToken)
    now_ts = UInt64(floor(time()))
    token.expires_at <= 3600 || now_ts >= token.expires_at - 3600
end

"""
    token_path(client_id::String) -> String

Returns the filesystem path for persisting this client's token.
"""
token_path(client_id::AbstractString) = joinpath(_token_dir(), client_id)

"""
    save_to_path(token::OAuthToken)

Persist the token to `\$LONGBRIDGE_TOKEN_DIR/<client_id>` when set, otherwise
to the user-level LongBridge token directory.
"""
function save_to_path(token::OAuthToken)
    path = token_path(token.client_id)
    _oauth_try(OAuthErrorCode.CreateDirFailed, "failed to create directory $(dirname(path))") do
        mkpath(dirname(path))
    end
    data = _oauth_try(OAuthErrorCode.SerializeToken, "failed to serialize token") do
        JSON.json(token)
    end
    _oauth_try(OAuthErrorCode.TokenFileWrite, "failed to write token file $path") do
        write(path, data)
    end
    return path
end

"""
    load_from_path(client_id::String) -> Union{OAuthToken, Nothing}

Load a cached token from disk. Returns `nothing` if no cached token exists.
"""
function load_from_path(client_id::AbstractString)::Union{OAuthToken,Nothing}
    path = token_path(client_id)
    isfile(path) || return nothing
    try
        data = _oauth_try(OAuthErrorCode.TokenFileRead, "failed to read token file $path") do
            read(path, String)
        end
        return _oauth_try(OAuthErrorCode.TokenFileParse, "failed to parse token file $path") do
            JSON.parse(data, OAuthToken)
        end
    catch e
        e isa InterruptException && rethrow()
        @warn "Failed to load cached OAuth token" path exception=e
        return nothing
    end
end

# ==================== OAuthHandle ====================

"""
    OAuthHandle

Manages an active OAuth session with automatic token refresh.
Thread-safe via ReentrantLock on the token field.
"""
mutable struct OAuthHandle
    client_id::String
    callback_port::UInt16
    token::Union{OAuthToken,Nothing}
    lock::ReentrantLock

    function OAuthHandle(
        client_id::String,
        callback_port::UInt16,
        token::Union{OAuthToken,Nothing},
    )
        new(client_id, callback_port, token, ReentrantLock())
    end
end

"""
    access_token(handle::OAuthHandle) -> String

Returns a valid access token, refreshing automatically if expired or expiring soon.
"""
access_token(handle::OAuthHandle)::String = _access_token(handle, _post_token)

function _access_token(handle::OAuthHandle, post_token)::String
    lock(handle.lock) do
        token = handle.token
        if isnothing(token)
            throw(OAuthError(OAuthErrorCode.NoTokenAvailable, "no token available"))
        end

        if is_expired(token) || expires_soon(token)
            if !isnothing(token.refresh_token)
                try
                    _refresh_token!(handle, post_token)
                    return handle.token.access_token
                catch e
                    e isa InterruptException && rethrow()
                    # Storage failures must remain visible even while the old
                    # access token is still valid.
                    (e isa OAuthError && e.code == Int(OAuthErrorCode.RefreshTokenFailed)) || rethrow()
                    @warn "Token refresh failed" exception=e
                    if is_expired(token)
                        rethrow()
                    end
                end
            elseif is_expired(token)
                throw(OAuthError(OAuthErrorCode.NoRefreshToken, "no refresh token available"))
            end
        end

        return token.access_token
    end
end

"""
    refresh_token!(handle::OAuthHandle)

Exchange the refresh token for a new access token via the OAuth token endpoint.
Serialized with access, revoke and clear; the request is bounded to 30 seconds.
"""
refresh_token!(handle::OAuthHandle) = _refresh_token!(handle, _post_token)

function _refresh_token!(handle::OAuthHandle, post_token)
    lock(handle.lock) do
        token = handle.token
        if isnothing(token) || isnothing(token.refresh_token)
            throw(OAuthError(OAuthErrorCode.NoRefreshToken, "no refresh token available"))
        end

        data = post_token((
            grant_type = "refresh_token",
            refresh_token = token.refresh_token,
            client_id = handle.client_id,
            redirect_uri = "http://localhost:$(handle.callback_port)/callback",
        ))
        new_token = _token_from_response(data, handle.client_id,
            OAuthErrorCode.RefreshTokenFailed; refresh_token = token.refresh_token)

        save_to_path(new_token)
        handle.token = new_token
        @info "OAuth token refreshed" client_id=handle.client_id
        return nothing
    end
end

function _token_from_response(data, client_id, code; refresh_token = nothing)
    return _oauth_try(code, "invalid OAuth token response") do
        access = data.access_token
        access isa AbstractString || throw(ArgumentError("access_token must be a string"))
        refreshed = get(data, :refresh_token, nothing)
        isnothing(refreshed) && (refreshed = refresh_token)
        (isnothing(refreshed) || refreshed isa AbstractString) ||
            throw(ArgumentError("refresh_token must be a string"))
        expiry = get(data, :expires_in, 3600)
        (expiry isa Integer && !(expiry isa Bool) && expiry >= 0) ||
            throw(ArgumentError("expires_in must be a nonnegative integer"))
        OAuthToken(client_id, access, refreshed,
            Base.Checked.checked_add(UInt64(expiry), UInt64(floor(time()))))
    end
end

"""
    revoke!(handle::OAuthHandle)

Revoke the refresh token (or access token if no refresh token exists) on the
server via RFC 7009. Local memory and the cached file are left untouched.
Call `clear!(handle)` after this succeeds to disconnect completely.
The token lock is held for the whole request, bounded to 30 seconds.
"""
revoke!(handle::OAuthHandle) = _revoke!(handle, _post_revoke)

function _revoke!(handle::OAuthHandle, post_revoke)
    isempty(handle.client_id) && throw(OAuthError(OAuthErrorCode.RevokeFailed,
        "token was not issued through an OAuth client, nothing to revoke"))
    lock(handle.lock) do
        token = handle.token
        isnothing(token) && throw(OAuthError(OAuthErrorCode.NoTokenAvailable, "no token available"))
        has_refresh = !isnothing(token.refresh_token)
        post_revoke((
            client_id = handle.client_id,
            token = has_refresh ? token.refresh_token : token.access_token,
            token_type_hint = has_refresh ? "refresh_token" : "access_token",
        ))
        return nothing
    end
end

"""
    clear!(handle::OAuthHandle)

Delete the cached token file, then clear the in-memory token, without contacting
the server. A missing file is harmless. If deletion fails, throw `OAuthError`
(code 16) and keep the in-memory token. Call `revoke!` first to revoke remotely.
"""
function clear!(handle::OAuthHandle)
    lock(handle.lock) do
        if !isempty(handle.client_id)
            path = token_path(handle.client_id)
            _oauth_try(OAuthErrorCode.TokenFileDelete, "failed to delete token file $path") do
                # rm can remove empty directories too; only unlink token files.
                isdir(path) && !islink(path) && throw(ArgumentError("token path is a directory"))
                rm(path; force = true)
            end
        end
        handle.token = nothing
        return nothing
    end
end

# ==================== Authorization Flow ====================

"""
    authorize!(handle::OAuthHandle, open_url_fn)

Run the full browser-based OAuth authorization flow:
1. Start local HTTP callback server
2. Open authorization URL in browser
3. Wait for callback with authorization code
4. Exchange code and the matching PKCE verifier for tokens
"""
authorize!(handle::OAuthHandle, open_url_fn) = _authorize!(handle, open_url_fn, _post_token)

_base64url(bytes) = replace(rstrip(base64encode(bytes), '='), '+' => '-', '/' => '_')

function _authorize!(handle::OAuthHandle, open_url_fn, post_token; auth_timeout = AUTH_TIMEOUT)
    lock(handle.lock) do
        # RFC 7636: 32 cryptographically random bytes -> 43 unpadded URL-safe chars.
        verifier = _base64url(rand(RandomDevice(), UInt8, 32))
        challenge = _base64url(sha256(verifier))
        csrf_state = _base64url(rand(RandomDevice(), UInt8, 32))
        result_ch = Channel{Union{String,OAuthError}}(1)
        result_lock = ReentrantLock()
        delivered = Ref(false)
        function deliver(result)
            lock(result_lock) do
                # Only the first callback/timeout wins. Repeated callbacks must
                # not fill the channel and prevent the server from shutting down.
                if !delivered[] && isopen(result_ch)
                    delivered[] = true
                    put!(result_ch, result)
                end
            end
        end

        server = _oauth_try(OAuthErrorCode.BindCallbackFailed,
            "failed to bind callback server on port $(handle.callback_port)") do
            HTTP.serve!("127.0.0.1", Int(handle.callback_port)) do request::HTTP.Request
                uri = HTTP.URI(request.target)
                uri.path == "/callback" || return HTTP.Response(404; body = "Not Found")
                request.method == "GET" || return HTTP.Response(405; body = "Method Not Allowed")
                params = HTTP.queryparams(uri)
                state = get(params, "state", "")
                code = get(params, "code", "")
                err = get(params, "error", "")
                if !isempty(err)
                    description = get(params, "error_description", "")
                    message = "OAuth authorization failed: $err"
                    isempty(description) || (message *= ": $description")
                    deliver(OAuthError(OAuthErrorCode.AuthorizationFailed, message))
                    return HTTP.Response(400; body = "Authorization failed. You can close this window.")
                elseif state != csrf_state
                    deliver(OAuthError(OAuthErrorCode.CsrfTokenMismatch, "CSRF token mismatch"))
                    return HTTP.Response(400; body = "CSRF state mismatch. Please try again.")
                elseif isempty(code)
                    deliver(OAuthError(OAuthErrorCode.AuthorizationFailed, "No authorization code received"))
                    return HTTP.Response(400; body = "No authorization code received.")
                end
                deliver(code)
                return HTTP.Response(200; body = "Authorization successful! You can close this window.")
            end
        end

        timer = nothing
        try
            port = _oauth_try(OAuthErrorCode.LocalAddressFailed, "failed to get local address") do
                HTTP.port(server)
            end
            redirect_uri = "http://localhost:$port/callback"
            auth_url = OAUTH_BASE_URL * OAUTH_AUTHORIZE_PATH * "?" * HTTP.URIs.escapeuri((
                client_id = handle.client_id,
                redirect_uri = redirect_uri,
                response_type = "code",
                state = csrf_state,
                scope = "openapi",
                code_challenge = challenge,
                code_challenge_method = "S256",
            ))

            timer = Timer(auth_timeout) do _
                deliver(OAuthError(OAuthErrorCode.AuthorizationTimeout,
                    "authorization timed out after $auth_timeout seconds"))
            end
            _oauth_try(OAuthErrorCode.Other, "failed to open authorization URL") do
                open_url_fn(auth_url)
            end
            result = _oauth_try(OAuthErrorCode.CallbackChannelClosed,
                "callback channel closed unexpectedly") do
                take!(result_ch)
            end
            close(timer)
            result isa OAuthError && throw(result)

            data = post_token((
                grant_type = "authorization_code",
                code = result,
                client_id = handle.client_id,
                redirect_uri = redirect_uri,
                code_verifier = verifier,
            ))
            new_token = _token_from_response(data, handle.client_id, OAuthErrorCode.ExchangeCodeFailed)
            save_to_path(new_token)
            handle.token = new_token
            @info "OAuth authorization successful" client_id=handle.client_id
            return nothing
        finally
            isnothing(timer) || close(timer)
            lock(result_lock) do
                close(result_ch)
            end
            close(server)
        end
    end
end

# ==================== OAuthBuilder ====================

"""
    OAuthBuilder

Builder pattern for constructing an OAuthHandle with token lifecycle management.

# Usage
```julia
oauth = OAuthBuilder("your-client-id") |> build(url -> run(`xdg-open \$url`))
cfg = from_oauth(oauth)
```
"""
mutable struct OAuthBuilder
    client_id::String
    callback_port::UInt16

    OAuthBuilder(client_id::String) = new(client_id, DEFAULT_CALLBACK_PORT)
end

"""
    callback_port!(builder::OAuthBuilder, port::Integer) -> OAuthBuilder

Set the local callback port for the OAuth authorization flow.
"""
function callback_port!(builder::OAuthBuilder, port::Integer)
    builder.callback_port = UInt16(port)
    return builder
end

# Backwards-compatible alias for older code; prefer callback_port! for new code.
callback_port(builder::OAuthBuilder, port::Integer) = callback_port!(builder, port)

"""
    build(open_url_fn) -> Function

Returns a function that takes an OAuthBuilder and completes the OAuth flow:
1. Check for cached token on disk
2. If valid → use it
3. If expired → try refresh; if refresh fails → full auth flow
4. If no token → full auth flow
5. Persist token and return OAuthHandle
"""
function build(open_url_fn)
    return builder::OAuthBuilder -> _build(builder, open_url_fn, _post_token)
end

function _build(builder::OAuthBuilder, open_url_fn, post_token)
    handle = OAuthHandle(builder.client_id, builder.callback_port, nothing)

    # Try loading cached token
    cached = load_from_path(builder.client_id)

    if !isnothing(cached)
        handle.token = cached

        if !is_expired(cached) && !expires_soon(cached)
            @info "Using cached OAuth token" client_id=builder.client_id
            return handle
        end

        # Token expired or expiring soon — try refresh.
        if !isnothing(cached.refresh_token)
            try
                @info "Cached token expiring, attempting refresh..." client_id=builder.client_id
                _refresh_token!(handle, post_token)
                return handle
            catch e
                e isa InterruptException && rethrow()
                (e isa OAuthError && e.code == Int(OAuthErrorCode.RefreshTokenFailed)) || rethrow()
                @warn "Token refresh failed, falling back to full authorization" exception=e
            end
        end
    end

    # No valid token — run full authorization flow.
    @info "Starting OAuth authorization flow..." client_id=builder.client_id
    _authorize!(handle, open_url_fn, post_token)
    return handle
end

end # module OAuth
