module Utils

    using Logging, Dates, JSON3, DataFrames, EnumX
    import DecFP: Dec64

    export to_namedtuple, to_china_time, to_dataframe, safeparse, Arc,
           symbol_to_counter_id, index_symbol_to_counter_id, counter_id_to_symbol,
           json3_to_mutable,
           Dec64

    # A simple wrapper to mimic Rust's Arc for shared ownership semantics
    struct Arc{T}
        value::T
    end

    Base.getproperty(arc::Arc, sym::Symbol) = getproperty(getfield(arc, :value), sym)
    Base.setproperty!(arc::Arc, sym::Symbol, x) = setproperty!(getfield(arc, :value), sym, x)

    # Utility function to convert UTC timestamp to China time (UTC+8)
    function to_china_time(timestamp::Int64)
        return unix2datetime(timestamp) + Hour(8)
    end

    function to_china_time(timestamp::String)
        return unix2datetime(parse(Int64, timestamp)) + Hour(8)
    end

    """
        to_dataframe(data::Vector{T}) where T

    Converts a vector of structs to a DataFrame.
    """
    function to_dataframe(data::Vector{T}) where {T}
        if isempty(data)
            if isstructtype(T) && !isabstracttype(T)
                fnames = fieldnames(T)
                return DataFrame([name => [] for name in fnames])
            else
                return DataFrame()
            end
        end

        fnames = fieldnames(eltype(data))
        n = length(data)
        df = DataFrame()
        for fname in fnames
            col = Vector{Any}(undef, n)
            @inbounds for i in eachindex(data)
                v = getfield(data[i], fname)
                col[i] = v === nothing ? missing : v
            end
            df[!, fname] = col
        end

        return df
    end

    """
    通用结构体转NamedTuple函数
    """
    function to_namedtuple(obj)
        if obj === nothing
            return nothing
        elseif obj isa JSON3.Object
            # Convert JSON object to NamedTuple
            keys = Tuple(propertynames(obj))
            values = Tuple(to_namedtuple(obj[key]) for key in keys)
            return NamedTuple{keys}(values)
        elseif obj isa Union{JSON3.Array, Vector, SubArray}
            # Convert JSON array or Vector to Vector of converted items
            return [to_namedtuple(item) for item in obj]
        elseif isstructtype(typeof(obj))
            # Handle structs, but exclude types that are problematic or should be treated as values
            if obj isa Union{String, Date, DateTime, Tuple}
                return obj
            end
            field_names = fieldnames(typeof(obj))
            field_values = map(field_names) do name
                field_val = getfield(obj, name)
                if name === :timestamp && (field_val isa Number || field_val isa String)
                    # Convert protobuf timestamp (seconds) to DateTime
                    return to_china_time(field_val)
                # Recursively convert nested objects
                elseif isstructtype(typeof(field_val)) && !(field_val isa Union{String, Date, DateTime, Tuple}) ||
                    field_val isa JSON3.Object || field_val isa JSON3.Array
                    return to_namedtuple(field_val)
                else
                    return field_val
                end
            end
            return NamedTuple{field_names}(Tuple(field_values))
        else
            # Return primitives and other types as-is
            return obj
        end
    end

    function safeparse(::Type{T}, val) where {T}
        # 空值处理
        if val === "" || val === nothing
            return T <: EnumX.Enum ? T(0) : zero(T)
        end

        # 已经是目标类型
        if val isa T
            return val
        end

        # 枚举类型（EnumX）直接用构造器解析
        if T <: EnumX.Enum
            sval = String(val)
            for e in instances(T)  # 枚举所有成员
                ename = string(e)
                if ename == sval
                    return e
                end
            end
            num = parse(Int, val)
            return T(num)
        end

        # 数字类型
        if T <: Real
            return parse(T, val)
        end

        # 不支持的类型
        error("safeparse: unsupported type $T")
    end

    """
    解析可选的 Decimal 字段。空串、`nothing`、或非数字占位符（如 `"--"`）都返回 `nothing`。
    LongBridge HTTP API 把 `Option<Decimal>` 序列化为字符串：缺失值常见为 `""` 或 `"--"`。
    """
    _parse_optional_decimal(::Nothing) = nothing
    function _parse_optional_decimal(v::AbstractString)
        isempty(v) && return nothing
        # API 偶尔返回 "--" 等占位符表示"无数据"——容错处理
        try
            return parse(Dec64, String(v))
        catch
            return nothing
        end
    end
    _parse_optional_decimal(v::Number) = Dec64(v)

    # ── Symbol ↔ counter_id 转换 ────────────────────────────────────────

    const _US_ETF_SET = Ref{Union{Nothing, Set{String}}}(nothing)
    const _US_ETF_LOCK = ReentrantLock()

    function _us_etf_set()
        s = _US_ETF_SET[]
        isnothing(s) || return s
        lock(_US_ETF_LOCK) do
            s2 = _US_ETF_SET[]
            isnothing(s2) || return s2
            path = joinpath(@__DIR__, "us_etf_counter.csv")
            new_set = Set{String}()
            for line in eachline(path)
                t = strip(line)
                isempty(t) || push!(new_set, String(t))
            end
            _US_ETF_SET[] = new_set
            return new_set
        end
    end

    """
        symbol_to_counter_id(symbol) -> String

    把 LongBridge symbol（如 `"TSLA.US"`）转成内部 counter_id（如 `"ST/US/TSLA"`）。
    美股 ETF 通过内置 ETF 列表识别，输出 `"ETF/US/..."`。
    """
    function symbol_to_counter_id(symbol::AbstractString)
        s = String(symbol)
        idx = findlast('.', s)
        isnothing(idx) && return s
        code   = SubString(s, 1, prevind(s, idx))
        market = uppercase(SubString(s, nextind(s, idx)))
        etf_candidate = string("ETF/", market, "/", code)
        return etf_candidate ∈ _us_etf_set() ? etf_candidate : string("ST/", market, "/", code)
    end

    """
        index_symbol_to_counter_id(symbol) -> String

    把指数 symbol（如 `"HSI.HK"`）转成 counter_id（如 `"IX/HK/HSI"`）。
    """
    function index_symbol_to_counter_id(symbol::AbstractString)
        s = String(symbol)
        idx = findlast('.', s)
        isnothing(idx) && return s
        code   = SubString(s, 1, prevind(s, idx))
        market = uppercase(SubString(s, nextind(s, idx)))
        return string("IX/", market, "/", code)
    end

    """
        counter_id_to_symbol(counter_id) -> String

    把 counter_id（如 `"ST/US/TSLA"`）转回 symbol（如 `"TSLA.US"`）。
    """
    function counter_id_to_symbol(counter_id::AbstractString)
        s = String(counter_id)
        parts = split(s, '/'; limit=3)
        length(parts) == 3 ? string(parts[3], '.', parts[2]) : s
    end

    """
        json3_to_mutable(x) -> Any

    递归地把 `JSON3.Object` / `JSON3.Array` 转成 `Dict{String,Any}` / `Vector{Any}`，
    便于对原始响应做客户端后处理（如去 prefix、按字段重组）。其它类型原样返回。
    """
    function json3_to_mutable(x)
        if x isa JSON3.Object
            Dict{String,Any}(string(k) => json3_to_mutable(v) for (k, v) in pairs(x))
        elseif x isa JSON3.Array
            Any[json3_to_mutable(v) for v in x]
        else
            x
        end
    end

end
