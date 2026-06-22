module AssetProtocol

using EnumX, JSON3, StructTypes

export StatementType, StatementItem, GetStatementListResponse, GetStatementResponse

@enumx StatementType begin
    Daily = 1
    Monthly = 2
end

# ── StatementItem ───────────────────────────────────────────────────

struct StatementItem
    dt::Int32
    file_key::String
end
StructTypes.StructType(::Type{StatementItem}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{StatementItem}, obj::JSON3.Object)
    StatementItem(Int32(get(obj, :dt, 0)), String(get(obj, :file_key, "")))
end

# ── GetStatementListResponse ────────────────────────────────────────

struct GetStatementListResponse
    list::Vector{StatementItem}
end
StructTypes.StructType(::Type{GetStatementListResponse}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{GetStatementListResponse}, obj::JSON3.Object)
    items = if haskey(obj, :list) && !isnothing(obj.list)
        [StructTypes.construct(StatementItem, e) for e in obj.list]
    else
        StatementItem[]
    end
    GetStatementListResponse(items)
end

# ── GetStatementResponse (download url) ─────────────────────────────

struct GetStatementResponse
    url::String
end
StructTypes.StructType(::Type{GetStatementResponse}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{GetStatementResponse}, obj::JSON3.Object)
    GetStatementResponse(String(get(obj, :url, "")))
end

end # module AssetProtocol
