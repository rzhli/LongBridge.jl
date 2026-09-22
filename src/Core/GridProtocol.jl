# 网格交易（GridContext）类型定义
# 对应上游 rust/src/grid/types.rs 与 requests/*.rs（#570）。全部走 HTTP，用 construct 解析。

module GridProtocol

using EnumX, Dates, JSON
using ..Utils: JSONObject
import ..Utils: construct

export TriggerPriceType,
    GridTimeInForce,
    GridLimitEvent,
    GridTradeRule,
    GridOrder,
    GridOrderSubOrder,
    GridOrderHistory,
    GridOrderDetail,
    TriggerOrder,
    GridBidSize,
    GridChannelInfo,
    GridSymbolInfo,
    SubmitGridOrderResponse,
    SubmitGridOrderOptions,
    ReplaceGridOrderOptions,
    GetGridOrdersOptions,
    GetGridOrdersByIdsOptions,
    GetGridOrderDetailOptions,
    GetGridTriggerHistoryOptions,
    grid_rule_dict

# ── 枚举（服务端用整数）─────────────────────────────────────────────

# 网格触发阈值的解释方式
@enumx TriggerPriceType begin
    Unknown = 0
    Spread = 1
    Percent = 2
end
_parse_trigger_price_type(v)::TriggerPriceType.T =
    (n = _as_int(v, 0); (n == 1 || n == 2) ? TriggerPriceType.T(n) : TriggerPriceType.Unknown)

# 网格订单有效期
@enumx GridTimeInForce begin
    Day = 0
    GoodTilCanceled = 1
    GoodTilDate = 6
end
function _parse_grid_tif(v)::GridTimeInForce.T
    n = _as_int(v, 0)
    n == 1 && return GridTimeInForce.GoodTilCanceled
    n == 6 && return GridTimeInForce.GoodTilDate
    return GridTimeInForce.Day
end

# 到达网格边界时的动作
@enumx GridLimitEvent begin
    Unknown = 0
    Ignore = 1
    CloseAtLast = 2
end
_parse_grid_limit_event(v)::GridLimitEvent.T =
    (n = _as_int(v, 0); (n == 1 || n == 2) ? GridLimitEvent.T(n) : GridLimitEvent.Unknown)

# ── 解析辅助 ────────────────────────────────────────────────────────

_as_int(v, dflt) =
    v isa Integer ? Int(v) :
    (v isa AbstractString ? something(tryparse(Int, v), dflt) : dflt)

_str(obj, k) = String(get(obj, k, ""))
_bool(obj, k) = (v = get(obj, k, false); v isa Bool ? v : (v == "true" || v == 1))
_i32(obj, k) = Int32(_as_int(get(obj, k, 0), 0))

# 字符串编码的十进制，空串 → nothing
function _optf64(obj, k)
    v = get(obj, k, nothing)
    (isnothing(v) || v == "") && return nothing
    v isa Number && return Float64(v)
    tryparse(Float64, string(v))
end

# 可选 unix 秒时间戳 → UTC DateTime（缺失/0/空 → nothing）
function _opt_secs_datetime(obj, k)
    v = get(obj, k, nothing)
    (isnothing(v) || v == "" || v == 0) && return nothing
    secs = v isa Integer ? Int64(v) : tryparse(Int64, string(v))
    (isnothing(secs) || secs == 0) && return nothing
    unix2datetime(secs)
end

_vec(obj, k, T) = (raw = get(obj, k, nothing);
                   isnothing(raw) ? T[] : T[construct(T, x) for x in raw])

# ── 请求：网格交易规则 ──────────────────────────────────────────────

"""
网格交易规则——submit / replace 的参数。价格、数量为十进制（作为字符串发送），
枚举类字段用整数码表。所有字段可选，网关仍会做业务校验。
"""
Base.@kwdef struct GridTradeRule
    submitted_base_price::Union{Float64,Nothing} = nothing
    upper_limit_price::Union{Float64,Nothing} = nothing
    lower_limit_price::Union{Float64,Nothing} = nothing
    trigger_price_type::Union{TriggerPriceType.T,Nothing} = nothing
    trigger_spread_up::Union{Float64,Nothing} = nothing
    trigger_spread_down::Union{Float64,Nothing} = nothing
    trigger_percent_up::Union{Float64,Nothing} = nothing
    trigger_percent_down::Union{Float64,Nothing} = nothing
    multiple_trigger::Union{Bool,Nothing} = nothing
    time_in_force::Union{GridTimeInForce.T,Nothing} = nothing
    upper_limit_quantity::Union{Float64,Nothing} = nothing
    lower_limit_quantity::Union{Float64,Nothing} = nothing
    expire_time::Union{Int64,Nothing} = nothing
    upper_limit_event::Union{GridLimitEvent.T,Nothing} = nothing
    lower_limit_event::Union{GridLimitEvent.T,Nothing} = nothing
    trigger_sell_depth::Union{Int,Nothing} = nothing
    trigger_buy_depth::Union{Int,Nothing} = nothing
    trigger_quantity::Union{Float64,Nothing} = nothing
    support_shortsell::Union{Bool,Nothing} = nothing
    rth::Union{Int,Nothing} = nothing
    grid_order_type_up::Union{String,Nothing} = nothing
    grid_order_type_down::Union{String,Nothing} = nothing
end

"""把 `GridTradeRule` 转成请求 body 的字典，跳过 `nothing`；十进制作为字符串、枚举作为整数发送。"""
function grid_rule_dict(rule::GridTradeRule)
    d = Dict{String,Any}()
    for name in fieldnames(GridTradeRule)
        val = getfield(rule, name)
        isnothing(val) && continue
        key = String(name)
        if val isa EnumX.Enum
            d[key] = Int(val)
        elseif val isa AbstractFloat
            d[key] = string(val)
        else
            d[key] = val
        end
    end
    d
end

# ── 响应：网格订单 ──────────────────────────────────────────────────

"""一个网格交易订单（list / by-ids 响应的元素）。"""
struct GridOrder
    order_id::String
    symbol::String
    stock_name::String
    market::String
    status::String
    grid_status::String
    submitted_base_price::Union{Float64,Nothing}
    current_base_price::Union{Float64,Nothing}
    pre_trigger_base_price::Union{Float64,Nothing}
    post_trigger_base_price::Union{Float64,Nothing}
    upper_limit_price::Union{Float64,Nothing}
    lower_limit_price::Union{Float64,Nothing}
    trigger_price_type::TriggerPriceType.T
    trigger_spread_up::Union{Float64,Nothing}
    trigger_spread_down::Union{Float64,Nothing}
    trigger_percent_up::Union{Float64,Nothing}
    trigger_percent_down::Union{Float64,Nothing}
    pullback_percent::Union{Float64,Nothing}
    pullback_spread::Union{Float64,Nothing}
    rebound_percent::Union{Float64,Nothing}
    rebound_spread::Union{Float64,Nothing}
    trigger_sell_order_type::String
    trigger_buy_order_type::String
    trigger_sell_depth::Int32
    trigger_buy_depth::Int32
    trigger_quantity::Union{Float64,Nothing}
    trigger_sell_quantity::Union{Float64,Nothing}
    trigger_buy_quantity::Union{Float64,Nothing}
    upper_limit_quantity::Union{Float64,Nothing}
    lower_limit_quantity::Union{Float64,Nothing}
    upper_limit_event::GridLimitEvent.T
    lower_limit_event::GridLimitEvent.T
    multiple_trigger::Bool
    trigger_times::Int32
    total_buy_quantity::Union{Float64,Nothing}
    total_sell_quantity::Union{Float64,Nothing}
    total_profit_balance::Union{Float64,Nothing}
    settlement_currency::String
    time_in_force::GridTimeInForce.T
    gtd::String
    created_at::Union{DateTime,Nothing}
    rth::Int32
    support_shortsell::Bool
    grid_order_type_up::String
    grid_order_type_down::String
end
function construct(::Type{GridOrder}, obj::JSONObject)
    GridOrder(
        _str(obj, :order_id),
        _str(obj, :symbol),
        _str(obj, :stock_name),
        _str(obj, :market),
        _str(obj, :status),
        _str(obj, :grid_status),
        _optf64(obj, :submitted_base_price),
        _optf64(obj, :current_base_price),
        _optf64(obj, :pre_trigger_base_price),
        _optf64(obj, :post_trigger_base_price),
        _optf64(obj, :upper_limit_price),
        _optf64(obj, :lower_limit_price),
        _parse_trigger_price_type(get(obj, :trigger_price_type, 0)),
        _optf64(obj, :trigger_spread_up),
        _optf64(obj, :trigger_spread_down),
        _optf64(obj, :trigger_percent_up),
        _optf64(obj, :trigger_percent_down),
        _optf64(obj, :pullback_percent),
        _optf64(obj, :pullback_spread),
        _optf64(obj, :rebound_percent),
        _optf64(obj, :rebound_spread),
        _str(obj, :trigger_sell_order_type),
        _str(obj, :trigger_buy_order_type),
        _i32(obj, :trigger_sell_depth),
        _i32(obj, :trigger_buy_depth),
        _optf64(obj, :trigger_quantity),
        _optf64(obj, :trigger_sell_quantity),
        _optf64(obj, :trigger_buy_quantity),
        _optf64(obj, :upper_limit_quantity),
        _optf64(obj, :lower_limit_quantity),
        _parse_grid_limit_event(get(obj, :upper_limit_event, 0)),
        _parse_grid_limit_event(get(obj, :lower_limit_event, 0)),
        _bool(obj, :multiple_trigger),
        _i32(obj, :trigger_times),
        _optf64(obj, :total_buy_quantity),
        _optf64(obj, :total_sell_quantity),
        _optf64(obj, :total_profit_balance),
        _str(obj, :settlement_currency),
        _parse_grid_tif(get(obj, :time_in_force, 0)),
        _str(obj, :gtd),
        _opt_secs_datetime(obj, :created_at),
        _i32(obj, :rth),
        _bool(obj, :support_shortsell),
        _str(obj, :grid_order_type_up),
        _str(obj, :grid_order_type_down),
    )
end

"""网格订单详情里的一条触发子订单。"""
struct GridOrderSubOrder
    id::String
    price::Union{Float64,Nothing}
    order_type::String
    quantity::Union{Float64,Nothing}
    executed_qty::Union{Float64,Nothing}
    action::Int32
    status::String
    submitted_at::Union{DateTime,Nothing}
    rth::Int32
end
function construct(::Type{GridOrderSubOrder}, obj::JSONObject)
    GridOrderSubOrder(
        _str(obj, :id),
        _optf64(obj, :price),
        _str(obj, :order_type),
        _optf64(obj, :quantity),
        _optf64(obj, :executed_qty),
        _i32(obj, :action),
        _str(obj, :status),
        _opt_secs_datetime(obj, :submitted_at),
        _i32(obj, :rth),
    )
end

"""网格订单详情里的一条生命周期历史记录。"""
struct GridOrderHistory
    history_id::String
    created_at::Union{DateTime,Nothing}
    status::String
    suspend_reason::String
    reason::String
end
function construct(::Type{GridOrderHistory}, obj::JSONObject)
    GridOrderHistory(
        _str(obj, :history_id),
        _opt_secs_datetime(obj, :created_at),
        _str(obj, :status),
        _str(obj, :suspend_reason),
        _str(obj, :reason),
    )
end

"""网格交易订单的详情。"""
struct GridOrderDetail
    order_id::String
    symbol::String
    stock_name::String
    status::String
    grid_status::String
    suspend_reason::String
    sleeping_reason::String
    submitted_base_price::Union{Float64,Nothing}
    current_base_price::Union{Float64,Nothing}
    upper_limit_price::Union{Float64,Nothing}
    lower_limit_price::Union{Float64,Nothing}
    trigger_price_type::TriggerPriceType.T
    trigger_spread_up::Union{Float64,Nothing}
    trigger_spread_down::Union{Float64,Nothing}
    trigger_percent_up::Union{Float64,Nothing}
    trigger_percent_down::Union{Float64,Nothing}
    pullback_percent::Union{Float64,Nothing}
    pullback_spread::Union{Float64,Nothing}
    rebound_percent::Union{Float64,Nothing}
    rebound_spread::Union{Float64,Nothing}
    multiple_trigger::Bool
    time_in_force::GridTimeInForce.T
    trigger_quantity::Union{Float64,Nothing}
    trigger_sell_quantity::Union{Float64,Nothing}
    trigger_buy_quantity::Union{Float64,Nothing}
    upper_limit_quantity::Union{Float64,Nothing}
    lower_limit_quantity::Union{Float64,Nothing}
    upper_limit_event::GridLimitEvent.T
    lower_limit_event::GridLimitEvent.T
    trigger_sell_depth::Int32
    trigger_buy_depth::Int32
    created_at::Union{DateTime,Nothing}
    updated_at::Union{DateTime,Nothing}
    settlement_currency::String
    expire_time::Union{DateTime,Nothing}
    gtd::String
    grid_sub_orders::Vector{GridOrderSubOrder}
    sub_has_more::Bool
    grid_order_history::Vector{GridOrderHistory}
    history_has_more::Bool
    support_shortsell::Bool
    rth::Int32
    grid_order_type_up::String
    grid_order_type_down::String
end
function construct(::Type{GridOrderDetail}, obj::JSONObject)
    GridOrderDetail(
        _str(obj, :order_id),
        _str(obj, :symbol),
        _str(obj, :stock_name),
        _str(obj, :status),
        _str(obj, :grid_status),
        _str(obj, :suspend_reason),
        _str(obj, :sleeping_reason),
        _optf64(obj, :submitted_base_price),
        _optf64(obj, :current_base_price),
        _optf64(obj, :upper_limit_price),
        _optf64(obj, :lower_limit_price),
        _parse_trigger_price_type(get(obj, :trigger_price_type, 0)),
        _optf64(obj, :trigger_spread_up),
        _optf64(obj, :trigger_spread_down),
        _optf64(obj, :trigger_percent_up),
        _optf64(obj, :trigger_percent_down),
        _optf64(obj, :pullback_percent),
        _optf64(obj, :pullback_spread),
        _optf64(obj, :rebound_percent),
        _optf64(obj, :rebound_spread),
        _bool(obj, :multiple_trigger),
        _parse_grid_tif(get(obj, :time_in_force, 0)),
        _optf64(obj, :trigger_quantity),
        _optf64(obj, :trigger_sell_quantity),
        _optf64(obj, :trigger_buy_quantity),
        _optf64(obj, :upper_limit_quantity),
        _optf64(obj, :lower_limit_quantity),
        _parse_grid_limit_event(get(obj, :upper_limit_event, 0)),
        _parse_grid_limit_event(get(obj, :lower_limit_event, 0)),
        _i32(obj, :trigger_sell_depth),
        _i32(obj, :trigger_buy_depth),
        _opt_secs_datetime(obj, :created_at),
        _opt_secs_datetime(obj, :updated_at),
        _str(obj, :settlement_currency),
        _opt_secs_datetime(obj, :expire_time),
        _str(obj, :gtd),
        _vec(obj, :grid_sub_orders, GridOrderSubOrder),
        _bool(obj, :sub_has_more),
        _vec(obj, :grid_order_history, GridOrderHistory),
        _bool(obj, :history_has_more),
        _bool(obj, :support_shortsell),
        _i32(obj, :rth),
        _str(obj, :grid_order_type_up),
        _str(obj, :grid_order_type_down),
    )
end

"""一条网格触发历史记录（一笔被触发的订单）。"""
struct TriggerOrder
    id::String
    status::String
    name::String
    symbol::String
    price::Union{Float64,Nothing}
    quantity::Union{Float64,Nothing}
    executed_price::Union{Float64,Nothing}
    executed_qty::Union{Float64,Nothing}
    submitted_at::Union{DateTime,Nothing}
    action::Int32
    order_type::String
    trigger_price::Union{Float64,Nothing}
    msg::String
    currency::String
    last_done::Union{Float64,Nothing}
    updated_at::Union{DateTime,Nothing}
    time_in_force::GridTimeInForce.T
    gtd::String
    trigger_at::Union{DateTime,Nothing}
    trigger_status::Int32
end
function construct(::Type{TriggerOrder}, obj::JSONObject)
    TriggerOrder(
        _str(obj, :id),
        _str(obj, :status),
        _str(obj, :name),
        _str(obj, :symbol),
        _optf64(obj, :price),
        _optf64(obj, :quantity),
        _optf64(obj, :executed_price),
        _optf64(obj, :executed_qty),
        _opt_secs_datetime(obj, :submitted_at),
        _i32(obj, :action),
        _str(obj, :order_type),
        _optf64(obj, :trigger_price),
        _str(obj, :msg),
        _str(obj, :currency),
        _optf64(obj, :last_done),
        _opt_secs_datetime(obj, :updated_at),
        _parse_grid_tif(get(obj, :time_in_force, 0)),
        _str(obj, :gtd),
        _opt_secs_datetime(obj, :trigger_at),
        _i32(obj, :trigger_status),
    )
end

# ── 响应：标的信息 ──────────────────────────────────────────────────

"""symbol-info 响应里的一条价格步长（bid-size）规则。"""
struct GridBidSize
    str_proceed::Union{Float64,Nothing}
    end_proceed::Union{Float64,Nothing}
    bid_size::Union{Float64,Nothing}
end
construct(::Type{GridBidSize}, obj::JSONObject) = GridBidSize(
    _optf64(obj, :str_proceed),
    _optf64(obj, :end_proceed),
    _optf64(obj, :bid_size),
)

"""symbol-info 响应里嵌套的通道 / 授权信息。"""
struct GridChannelInfo
    strategy_granted::Bool
    support_rth::Bool
    currency::String
    settlement_currency::Vector{String}
end
function construct(::Type{GridChannelInfo}, obj::JSONObject)
    sc = get(obj, :settlement_currency, nothing)
    GridChannelInfo(
        _bool(obj, :strategy_granted),
        _bool(obj, :support_rth),
        _str(obj, :currency),
        isnothing(sc) ? String[] : String[String(x) for x in sc],
    )
end

"""证券（标的）信息（`/v1/orders/info`），用于构建网格订单。"""
struct GridSymbolInfo
    name::String
    last_done::Union{Float64,Nothing}
    lot_size::Union{Float64,Nothing}
    buy_lot_size::Union{Float64,Nothing}
    sell_lot_size::Union{Float64,Nothing}
    bid_sizes::Vector{GridBidSize}
    channel_info::GridChannelInfo
end
function construct(::Type{GridSymbolInfo}, obj::JSONObject)
    # 反序列化接受服务端的 channel_infos 键
    ci = get(obj, :channel_info, nothing)
    isnothing(ci) && (ci = get(obj, :channel_infos, nothing))
    GridSymbolInfo(
        _str(obj, :name),
        _optf64(obj, :last_done),
        _optf64(obj, :lot_size),
        _optf64(obj, :buy_lot_size),
        _optf64(obj, :sell_lot_size),
        _vec(obj, :bid_sizes, GridBidSize),
        isnothing(ci) ? GridChannelInfo(false, false, "", String[]) :
        construct(GridChannelInfo, ci),
    )
end

"""提交网格订单的响应。"""
struct SubmitGridOrderResponse
    order_id::String
end
construct(::Type{SubmitGridOrderResponse}, obj::JSONObject) =
    SubmitGridOrderResponse(_str(obj, :order_id))

# ── 请求参数 ────────────────────────────────────────────────────────

"""提交网格订单的参数。"""
Base.@kwdef struct SubmitGridOrderOptions
    symbol::String
    settlement_currency::String
    grid_trading_rule::GridTradeRule
end

"""修改网格订单的参数。"""
Base.@kwdef struct ReplaceGridOrderOptions
    order_id::String
    grid_trading_rule::GridTradeRule
end

"""查询网格订单列表的参数。`status` 为逗号连接的状态过滤（如 `Performing,Suspended`）。"""
Base.@kwdef struct GetGridOrdersOptions
    page::Union{Int,Nothing} = nothing
    limit::Union{Int,Nothing} = nothing
    market::Union{String,Nothing} = nothing
    status::Union{String,Nothing} = nothing
    symbol::Union{String,Nothing} = nothing
    sort_by::Union{String,Nothing} = nothing
    sort_order::Union{String,Nothing} = nothing
end

"""按 ID 批量查询网格订单的参数。"""
Base.@kwdef struct GetGridOrdersByIdsOptions
    order_ids::Vector{String}
end

"""查询网格订单详情的参数。`history_id` 为翻页游标。"""
Base.@kwdef struct GetGridOrderDetailOptions
    order_id::String
    history_id::Union{String,Nothing} = nothing
    limit::Union{Int,Nothing} = nothing
end

"""查询网格触发历史的参数。"""
Base.@kwdef struct GetGridTriggerHistoryOptions
    grid_order_id::String
    page::Union{Int,Nothing} = nothing
    limit::Union{Int,Nothing} = nothing
end

end # module GridProtocol
