module Errors

    using JSON3, HTTP

    export LongPortError, @lperror, ApiResponse

    struct ApiResponse{T}
        code::Int
        message::String
        data::T
        headers::Dict{String, String}

        function ApiResponse(resp::HTTP.Response)
            json = JSON3.read(resp.body)
            headers = Dict(resp.headers)
            data = get(json, :data, nothing)
            new{typeof(data)}(json.code, json.message, data, headers)
        end
    end

    struct LongPortError{T} <: Exception
        code::Int
        message::String
        request_id::Union{Nothing,String}
        payload::T
    end

    # Convenience constructor for nothing payload
    LongPortError(code::Int, message::String, request_id::Union{Nothing,String}=nothing) =
        LongPortError{Nothing}(code, message, request_id, nothing)

    Base.showerror(io::IO, e::LongPortError) = print(io,
        "LongPortError(code=$(e.code), message=$(e.message), request_id=$(e.request_id))")

    macro lperror(code, message, request_id=nothing, payload=nothing)
        :(throw(LongPortError($(esc(code)), $(esc(message)), $(esc(request_id)), $(esc(payload)))))
    end

end # module Errors
