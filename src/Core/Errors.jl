module Errors

using JSON, HTTP, EnumX

export LongBridgeError, UnexpectedHttpResponse, OAuthError, OAuthErrorCode, @lperror, ApiResponse

"""Stable OAuth error codes, matching upstream openapi v5.4.0. Codes are never reused."""
@enumx OAuthErrorCode begin
    Other = 0
    NoTokenAvailable = 1
    NoRefreshToken = 2
    RefreshTokenFailed = 3
    RevokeFailed = 4
    AuthorizationFailed = 5
    AuthorizationTimeout = 6
    ExchangeCodeFailed = 7
    CsrfTokenMismatch = 8
    BindCallbackFailed = 9
    LocalAddressFailed = 10
    CallbackChannelClosed = 11
    NoHomeDir = 12
    TokenFileRead = 13
    TokenFileParse = 14
    TokenFileWrite = 15
    TokenFileDelete = 16
    CreateDirFailed = 17
    SerializeToken = 18
end

"""
    OAuthError

An OAuth failure, including failures obtaining a token for an API request.
`code::Int` matches `OAuthErrorCode` and upstream's stable numeric codes;
`message` describes the operation and `cause` retains the underlying exception.
Catch this type separately from `LongBridgeError` (server OpenAPI errors).
"""
struct OAuthError <: Exception
    code::Int
    message::String
    cause::Union{Nothing,Exception}
end

OAuthError(code::OAuthErrorCode.T, message::AbstractString, cause = nothing) =
    OAuthError(Int(code), String(message), cause)

function Base.showerror(io::IO, e::OAuthError)
    print(io, "OAuthError(code=", e.code, ", message=", e.message)
    if !isnothing(e.cause)
        print(io, ": ")
        showerror(io, e.cause)
    end
    print(io, ")")
end

# `ApiResponse` 构造时已将 header 名归一化为小写，因此这里只需一次 O(1) 查询。
function _header_value(headers::Dict{String,String}, name::String)
    return get(headers, lowercase(name), "")
end

"""An HTTP response that is not a standard LongBridge API envelope.

`status`, `trace_id`, `headers`, and `body` retain the original response
context so intermediary and load-balancer failures remain diagnosable.
"""
struct UnexpectedHttpResponse <: Exception
    status::Int
    trace_id::String
    headers::Dict{String,String}
    body::String
end

Base.showerror(io::IO, e::UnexpectedHttpResponse) = print(
    io,
    "UnexpectedHttpResponse(status=",
    e.status,
    ", trace_id=",
    repr(e.trace_id),
    ", body=",
    repr(e.body),
    ")",
)

struct ApiResponse{T}
    code::Int
    message::String
    data::T
    headers::Dict{String,String}

    function ApiResponse(resp::HTTP.Response)
        status = Int(resp.status)
        body = String(resp.body)
        # HTTP field names are case-insensitive; normalize them so callers can
        # reliably access trace/request IDs with their conventional lowercase names.
        headers = Dict(lowercase(String(k)) => String(v) for (k, v) in resp.headers)
        try
            json = JSON.parse(body)
            # A non-OpenAPI error page may still be valid JSON, but without the
            # standard `code` and `message` envelope fields.
            if !(haskey(json, :code) && haskey(json, :message))
                status < 300 && throw(ArgumentError("response is missing code/message"))
                throw(UnexpectedHttpResponse(
                    status,
                    _header_value(headers, "x-trace-id"),
                    headers,
                    body,
                ))
            end
            data = get(json, :data, nothing)
            return new{typeof(data)}(Int(json.code), String(json.message), data, headers)
        catch err
            err isa UnexpectedHttpResponse && rethrow()
            status >= 300 && throw(UnexpectedHttpResponse(
                status,
                _header_value(headers, "x-trace-id"),
                headers,
                body,
            ))
            rethrow()
        end
    end
end

struct LongBridgeError{T} <: Exception
    code::Int
    message::String
    request_id::Union{Nothing,String}
    payload::T
end

# Convenience constructor for nothing payload
LongBridgeError(code::Int, message::String, request_id::Union{Nothing,String} = nothing) =
    LongBridgeError{Nothing}(code, message, request_id, nothing)

Base.showerror(io::IO, e::LongBridgeError) =
    print(
        io,
        "LongBridgeError(code=",
        e.code,
        ", message=",
        e.message,
        ", request_id=",
        e.request_id,
        ")",
    )

macro lperror(code, message, request_id = nothing, payload = nothing)
    :(throw(
        LongBridgeError($(esc(code)), $(esc(message)), $(esc(request_id)), $(esc(payload))),
    ))
end

end # module Errors
