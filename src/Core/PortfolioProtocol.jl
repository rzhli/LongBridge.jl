module PortfolioProtocol

using EnumX, JSON3, StructTypes
using ..Utils: Dec64, counter_id_to_symbol
import ..Utils: _parse_optional_decimal

export FlowDirection,
    AssetType,
    ExchangeRate,
    ExchangeRates,
    ProfitSummaryInfo,
    ProfitSummaryBreakdown,
    ProfitAnalysisSummary,
    ProfitAnalysisItem,
    ProfitAnalysisSublist,
    ProfitAnalysis,
    ProfitAnalysisByMarketItem,
    ProfitAnalysisByMarket,
    ProfitDetailEntry,
    ProfitDetails,
    ProfitAnalysisDetail,
    FlowItem,
    ProfitAnalysisFlows,
    _flow_direction_from_str,
    _asset_type_from_str

@enumx FlowDirection begin
    Unknown = 0
    Buy = 1
    Sell = 2
end

@enumx AssetType begin
    Unknown = 0
    Stock = 1
    Fund = 2
    Crypto = 3
end

function _flow_direction_from_str(s::AbstractString)
    s == "buy" ? FlowDirection.Buy :
    s == "sell" ? FlowDirection.Sell : FlowDirection.Unknown
end

function _asset_type_from_str(s::AbstractString)
    s == "stock" ? AssetType.Stock :
    s == "fund" ? AssetType.Fund : s == "crypto" ? AssetType.Crypto : AssetType.Unknown
end

const MaybeTimestamp = Union{Int64,String,Nothing}

_timestamp_value(::Nothing)::MaybeTimestamp = nothing
_timestamp_value(v::Integer)::MaybeTimestamp = Int64(v)
_timestamp_value(v::AbstractString)::MaybeTimestamp = String(v)
_timestamp_value(v)::MaybeTimestamp = string(v)

# ── ExchangeRate ────────────────────────────────────────────────────

struct ExchangeRate
    average_rate::Float64
    base_currency::String
    bid_rate::Float64
    offer_rate::Float64
    other_currency::String
end
StructTypes.StructType(::Type{ExchangeRate}) = StructTypes.Struct()

struct ExchangeRates
    exchanges::Vector{ExchangeRate}
end
StructTypes.StructType(::Type{ExchangeRates}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ExchangeRates}, obj::JSON3.Object)
    items = if haskey(obj, :exchanges) && !isnothing(obj.exchanges)
        [JSON3.read(JSON3.write(e), ExchangeRate) for e in obj.exchanges]
    else
        ExchangeRate[]
    end
    ExchangeRates(items)
end

# ── ProfitAnalysis (summary 部分) ───────────────────────────────────

struct ProfitSummaryInfo
    asset_type::AssetType.T
    profit_max::String
    profit_max_name::String
    loss_max::String
    loss_max_name::String
end
StructTypes.StructType(::Type{ProfitSummaryInfo}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ProfitSummaryInfo}, obj::JSON3.Object)
    ProfitSummaryInfo(
        _asset_type_from_str(String(get(obj, :asset_type, ""))),
        String(get(obj, :profit_max, "")),
        String(get(obj, :profit_max_name, "")),
        String(get(obj, :loss_max, "")),
        String(get(obj, :loss_max_name, "")),
    )
end

struct ProfitSummaryBreakdown
    stock::Union{Dec64,Nothing}
    fund::Union{Dec64,Nothing}
    crypto::Union{Dec64,Nothing}
    mmf::Union{Dec64,Nothing}
    other::Union{Dec64,Nothing}
    cumulative_transaction_amount::Union{Dec64,Nothing}
    trade_order_num::String
    trade_stock_num::String
    ipo::Union{Dec64,Nothing}
    ipo_hit::Int
    ipo_subscription::Int
    summary_info::Vector{ProfitSummaryInfo}
end
StructTypes.StructType(::Type{ProfitSummaryBreakdown}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ProfitSummaryBreakdown}, obj::JSON3.Object)
    si = if haskey(obj, :summary_info) && !isnothing(obj.summary_info)
        [StructTypes.construct(ProfitSummaryInfo, x) for x in obj.summary_info]
    else
        ProfitSummaryInfo[]
    end
    ProfitSummaryBreakdown(
        _parse_optional_decimal(get(obj, :stock, nothing)),
        _parse_optional_decimal(get(obj, :fund, nothing)),
        _parse_optional_decimal(get(obj, :crypto, nothing)),
        _parse_optional_decimal(get(obj, :mmf, nothing)),
        _parse_optional_decimal(get(obj, :other, nothing)),
        _parse_optional_decimal(get(obj, :cumulative_transaction_amount, nothing)),
        String(get(obj, :trade_order_num, "")),
        String(get(obj, :trade_stock_num, "")),
        _parse_optional_decimal(get(obj, :ipo, nothing)),
        Int(get(obj, :ipo_hit, 0)),
        Int(get(obj, :ipo_subscription, 0)),
        si,
    )
end

struct ProfitAnalysisSummary
    currency::String
    current_total_asset::Union{Dec64,Nothing}
    start_date::String
    end_date::String
    start_time::String
    end_time::String
    ending_asset_value::Union{Dec64,Nothing}
    initial_asset_value::Union{Dec64,Nothing}
    invest_amount::Union{Dec64,Nothing}
    is_traded::Bool
    sum_profit::Union{Dec64,Nothing}
    sum_profit_rate::Union{Dec64,Nothing}
    profits::ProfitSummaryBreakdown
end
StructTypes.StructType(::Type{ProfitAnalysisSummary}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ProfitAnalysisSummary}, obj::JSON3.Object)
    ProfitAnalysisSummary(
        String(get(obj, :currency, "")),
        _parse_optional_decimal(get(obj, :current_total_asset, nothing)),
        String(get(obj, :start_date, "")),
        String(get(obj, :end_date, "")),
        String(get(obj, :start_time, "")),
        String(get(obj, :end_time, "")),
        _parse_optional_decimal(get(obj, :ending_asset_value, nothing)),
        _parse_optional_decimal(get(obj, :initial_asset_value, nothing)),
        _parse_optional_decimal(get(obj, :invest_amount, nothing)),
        Bool(get(obj, :is_traded, false)),
        _parse_optional_decimal(get(obj, :sum_profit, nothing)),
        _parse_optional_decimal(get(obj, :sum_profit_rate, nothing)),
        StructTypes.construct(ProfitSummaryBreakdown, obj.profits),
    )
end

# ── ProfitAnalysis (sublist 部分) ───────────────────────────────────

struct ProfitAnalysisItem
    name::String
    market::String
    is_holding::Bool
    profit::Union{Dec64,Nothing}
    profit_rate::Union{Dec64,Nothing}
    clearance_times::Int64
    item_type::AssetType.T
    currency::String
    symbol::String                        # 由 counter_id 转换
    holding_period::String
    security_code::String
    isin::String
    underlying_profit::Union{Dec64,Nothing}
    derivatives_profit::Union{Dec64,Nothing}
    order_profit::Union{Dec64,Nothing}
end
StructTypes.StructType(::Type{ProfitAnalysisItem}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ProfitAnalysisItem}, obj::JSON3.Object)
    ProfitAnalysisItem(
        String(get(obj, :name, "")),
        String(get(obj, :market, "")),
        Bool(get(obj, :is_holding, false)),
        _parse_optional_decimal(get(obj, :profit, nothing)),
        _parse_optional_decimal(get(obj, :profit_rate, nothing)),
        Int64(get(obj, :clearance_times, 0)),
        _asset_type_from_str(String(get(obj, :type, ""))),
        String(get(obj, :currency, "")),
        counter_id_to_symbol(String(get(obj, :counter_id, ""))),
        String(get(obj, :holding_period, "")),
        String(get(obj, :security_code, "")),
        String(get(obj, :isin, "")),
        _parse_optional_decimal(get(obj, :underlying_profit, nothing)),
        _parse_optional_decimal(get(obj, :derivatives_profit, nothing)),
        _parse_optional_decimal(get(obj, :order_profit, nothing)),
    )
end

struct ProfitAnalysisSublist
    start::String
    end_::String                          # JSON 字段名 "end"
    start_date::String
    end_date::String
    updated_at::String
    updated_date::String
    items::Vector{ProfitAnalysisItem}
end
StructTypes.StructType(::Type{ProfitAnalysisSublist}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ProfitAnalysisSublist}, obj::JSON3.Object)
    items = if haskey(obj, :items) && !isnothing(obj.items)
        [StructTypes.construct(ProfitAnalysisItem, x) for x in obj.items]
    else
        ProfitAnalysisItem[]
    end
    ProfitAnalysisSublist(
        String(get(obj, :start, "")),
        String(get(obj, :end, "")),
        String(get(obj, :start_date, "")),
        String(get(obj, :end_date, "")),
        String(get(obj, :updated_at, "")),
        String(get(obj, :updated_date, "")),
        items,
    )
end

struct ProfitAnalysis
    summary::ProfitAnalysisSummary
    sublist::ProfitAnalysisSublist
end

# ── ProfitAnalysisByMarket ──────────────────────────────────────────

struct ProfitAnalysisByMarketItem
    code::String
    name::String
    market::String
    profit::Union{Dec64,Nothing}
end
StructTypes.StructType(::Type{ProfitAnalysisByMarketItem}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ProfitAnalysisByMarketItem}, obj::JSON3.Object)
    ProfitAnalysisByMarketItem(
        String(get(obj, :code, "")),
        String(get(obj, :name, "")),
        String(get(obj, :market, "")),
        _parse_optional_decimal(get(obj, :profit, nothing)),
    )
end

struct ProfitAnalysisByMarket
    profit::Union{Dec64,Nothing}
    has_more::Bool
    stock_items::Vector{ProfitAnalysisByMarketItem}
end
StructTypes.StructType(::Type{ProfitAnalysisByMarket}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ProfitAnalysisByMarket}, obj::JSON3.Object)
    items = if haskey(obj, :stock_items) && !isnothing(obj.stock_items)
        [StructTypes.construct(ProfitAnalysisByMarketItem, x) for x in obj.stock_items]
    else
        ProfitAnalysisByMarketItem[]
    end
    ProfitAnalysisByMarket(
        _parse_optional_decimal(get(obj, :profit, nothing)),
        Bool(get(obj, :has_more, false)),
        items,
    )
end

# ── ProfitAnalysisDetail ────────────────────────────────────────────

struct ProfitDetailEntry
    describe::String
    amount::Union{Dec64,Nothing}
end
StructTypes.StructType(::Type{ProfitDetailEntry}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ProfitDetailEntry}, obj::JSON3.Object)
    ProfitDetailEntry(
        String(get(obj, :describe, "")),
        _parse_optional_decimal(get(obj, :amount, nothing)),
    )
end

struct ProfitDetails
    holding_value::Union{Dec64,Nothing}
    profit::Union{Dec64,Nothing}
    cumulative_credited_amount::Union{Dec64,Nothing}
    credited_details::Vector{ProfitDetailEntry}
    cumulative_debited_amount::Union{Dec64,Nothing}
    debited_details::Vector{ProfitDetailEntry}
    cumulative_fee_amount::Union{Dec64,Nothing}
    fee_details::Vector{ProfitDetailEntry}
    short_holding_value::Union{Dec64,Nothing}
    long_holding_value::Union{Dec64,Nothing}
    holding_value_at_beginning::Union{Dec64,Nothing}
    holding_value_at_ending::Union{Dec64,Nothing}
end
StructTypes.StructType(::Type{ProfitDetails}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ProfitDetails}, obj::JSON3.Object)
    _entries(key) =
        if haskey(obj, key) && !isnothing(obj[key])
            [StructTypes.construct(ProfitDetailEntry, e) for e in obj[key]]
        else
            ProfitDetailEntry[]
        end
    ProfitDetails(
        _parse_optional_decimal(get(obj, :holding_value, nothing)),
        _parse_optional_decimal(get(obj, :profit, nothing)),
        _parse_optional_decimal(get(obj, :cumulative_credited_amount, nothing)),
        _entries(:credited_details),
        _parse_optional_decimal(get(obj, :cumulative_debited_amount, nothing)),
        _entries(:debited_details),
        _parse_optional_decimal(get(obj, :cumulative_fee_amount, nothing)),
        _entries(:fee_details),
        _parse_optional_decimal(get(obj, :short_holding_value, nothing)),
        _parse_optional_decimal(get(obj, :long_holding_value, nothing)),
        _parse_optional_decimal(get(obj, :holding_value_at_beginning, nothing)),
        _parse_optional_decimal(get(obj, :holding_value_at_ending, nothing)),
    )
end

struct ProfitAnalysisDetail
    profit::Union{Dec64,Nothing}
    underlying_details::ProfitDetails
    derivative_pnl_details::ProfitDetails
    name::String
    updated_at::String
    updated_date::String
    currency::String
    default_tag::Int
    start::String
    end_::String
    start_date::String
    end_date::String
end
StructTypes.StructType(::Type{ProfitAnalysisDetail}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ProfitAnalysisDetail}, obj::JSON3.Object)
    ProfitAnalysisDetail(
        _parse_optional_decimal(get(obj, :profit, nothing)),
        StructTypes.construct(ProfitDetails, obj.underlying_details),
        StructTypes.construct(ProfitDetails, obj.derivative_pnl_details),
        String(get(obj, :name, "")),
        String(get(obj, :updated_at, "")),
        String(get(obj, :updated_date, "")),
        String(get(obj, :currency, "")),
        Int(get(obj, :default_tag, 0)),
        String(get(obj, :start, "")),
        String(get(obj, :end, "")),
        String(get(obj, :start_date, "")),
        String(get(obj, :end_date, "")),
    )
end

# ── ProfitAnalysisFlows ─────────────────────────────────────────────

struct FlowItem
    executed_date::String
    executed_timestamp::MaybeTimestamp   # API 可能返回 int 或 string，保持原值
    code::String
    direction::FlowDirection.T
    executed_quantity::Union{Dec64,Nothing}
    executed_price::Union{Dec64,Nothing}
    executed_cost::Union{Dec64,Nothing}
    describe::String
end
StructTypes.StructType(::Type{FlowItem}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{FlowItem}, obj::JSON3.Object)
    FlowItem(
        String(get(obj, :executed_date, "")),
        _timestamp_value(get(obj, :executed_timestamp, nothing)),
        String(get(obj, :code, "")),
        _flow_direction_from_str(String(get(obj, :direction, ""))),
        _parse_optional_decimal(get(obj, :executed_quantity, nothing)),
        _parse_optional_decimal(get(obj, :executed_price, nothing)),
        _parse_optional_decimal(get(obj, :executed_cost, nothing)),
        String(get(obj, :describe, "")),
    )
end

struct ProfitAnalysisFlows
    flows_list::Vector{FlowItem}
    has_more::Bool
end
StructTypes.StructType(::Type{ProfitAnalysisFlows}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ProfitAnalysisFlows}, obj::JSON3.Object)
    items = if haskey(obj, :flows_list) && !isnothing(obj.flows_list)
        [StructTypes.construct(FlowItem, x) for x in obj.flows_list]
    else
        FlowItem[]
    end
    ProfitAnalysisFlows(items, Bool(get(obj, :has_more, false)))
end

end # module PortfolioProtocol
