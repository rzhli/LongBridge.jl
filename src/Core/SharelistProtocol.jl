module SharelistProtocol

    using JSON3, StructTypes, Dates
    using ..Utils: Dec64, counter_id_to_symbol, to_china_time
    import ..Utils: _parse_optional_decimal

    export SharelistStock, SharelistInfo, SharelistList,
           SharelistScopes, SharelistDetail

    # ── SharelistStock ─────────────────────────────────────────────────

    struct SharelistStock
        symbol::String                      # 由 counter_id 转换
        name::String
        market::String
        code::String
        intro::String
        unread_change_log_category::String
        change::Union{Dec64,Nothing}
        last_done::Union{Dec64,Nothing}
        trade_status::Union{Int,Nothing}
        latency::Union{Bool,Nothing}
    end
    StructTypes.StructType(::Type{SharelistStock}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{SharelistStock}, obj::JSON3.Object)
        ts = get(obj, :trade_status, nothing)
        lat = get(obj, :latency, nothing)
        SharelistStock(
            counter_id_to_symbol(String(get(obj, :counter_id, ""))),
            String(get(obj, :name, "")),
            String(get(obj, :market, "")),
            String(get(obj, :code, "")),
            String(get(obj, :intro, "")),
            String(get(obj, :unread_change_log_category, "")),
            _parse_optional_decimal(get(obj, :change, nothing)),
            _parse_optional_decimal(get(obj, :last_done, nothing)),
            isnothing(ts) ? nothing : Int(ts),
            isnothing(lat) ? nothing : Bool(lat),
        )
    end

    # ── SharelistInfo ──────────────────────────────────────────────────

    # id 可能是字符串或整数
    _parse_id(v::Integer) = Int64(v)
    _parse_id(v::AbstractString) = parse(Int64, v)
    _parse_id(::Nothing) = Int64(0)

    struct SharelistInfo
        id::Int64
        name::String
        description::String
        cover::String
        subscribers_count::Int64
        created_at::DateTime
        edited_at::DateTime
        this_year_chg::Union{Dec64,Nothing}
        creator::Any                       # JSON 原值，结构复杂
        stocks::Vector{SharelistStock}
        subscribed::Bool
        chg::Union{Dec64,Nothing}
        sharelist_type::Int               # 0=普通, 3=官方, 4=行业
        industry_code::String
    end
    StructTypes.StructType(::Type{SharelistInfo}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{SharelistInfo}, obj::JSON3.Object)
        stocks = if haskey(obj, :stocks) && !isnothing(obj.stocks)
            [StructTypes.construct(SharelistStock, x) for x in obj.stocks]
        else
            SharelistStock[]
        end
        SharelistInfo(
            _parse_id(get(obj, :id, nothing)),
            String(get(obj, :name, "")),
            String(get(obj, :description, "")),
            String(get(obj, :cover, "")),
            Int64(get(obj, :subscribers_count, 0)),
            to_china_time(obj.created_at isa Number ? Int64(obj.created_at) : String(obj.created_at)),
            to_china_time(obj.edited_at  isa Number ? Int64(obj.edited_at)  : String(obj.edited_at)),
            _parse_optional_decimal(get(obj, :this_year_chg, nothing)),
            get(obj, :creator, nothing),
            stocks,
            Bool(get(obj, :subscribed, false)),
            _parse_optional_decimal(get(obj, :chg, nothing)),
            Int(get(obj, :sharelist_type, 0)),
            String(get(obj, :industry_code, "")),
        )
    end

    # ── SharelistList ──────────────────────────────────────────────────

    struct SharelistList
        sharelists::Vector{SharelistInfo}
        subscribed_sharelists::Vector{SharelistInfo}
        tail_mark::String
    end
    StructTypes.StructType(::Type{SharelistList}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{SharelistList}, obj::JSON3.Object)
        _list(key) = if haskey(obj, key) && !isnothing(obj[key])
            [StructTypes.construct(SharelistInfo, x) for x in obj[key]]
        else
            SharelistInfo[]
        end
        SharelistList(
            _list(:sharelists),
            _list(:subscribed_sharelists),
            String(get(obj, :tail_mark, "")),
        )
    end

    # ── SharelistDetail ────────────────────────────────────────────────

    struct SharelistScopes
        subscription::Bool
        is_self::Bool                     # JSON 字段名 "self"
    end
    StructTypes.StructType(::Type{SharelistScopes}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{SharelistScopes}, obj::JSON3.Object)
        SharelistScopes(
            Bool(get(obj, :subscription, false)),
            Bool(get(obj, :self, false)),
        )
    end

    struct SharelistDetail
        sharelist::SharelistInfo
        scopes::SharelistScopes
    end
    StructTypes.StructType(::Type{SharelistDetail}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{SharelistDetail}, obj::JSON3.Object)
        SharelistDetail(
            StructTypes.construct(SharelistInfo, obj.sharelist),
            StructTypes.construct(SharelistScopes, obj.scopes),
        )
    end

end # module SharelistProtocol
