module GridCtx

using Dates

using ..Config
using ..Client
using ..Errors
using ..Errors: ApiResponse
using ..Utils: construct
using ..GridProtocol

export GridContext,
    grid_submit,
    grid_replace,
    grid_list,
    grid_list_by_ids,
    grid_detail,
    grid_trigger_history,
    grid_cancel,
    grid_suspend,
    grid_restart,
    grid_symbol_info

"""
    GridContext(config::Config.Settings)

网格交易管理上下文。HTTP-only。
"""
struct GridContext
    config::Config.Settings
end

_check(resp) =
    resp.code == 0 ||
    @lperror(resp.code, resp.message, get(resp.headers, "x-request-id", nothing))

function _put!(params, key, val)
    isnothing(val) && return
    params[key] = val
end

"""
    submit(ctx::GridContext, options::SubmitGridOrderOptions) -> SubmitGridOrderResponse

提交网格交易订单。端点：`POST /v1/gridtrading/submit`
"""
function grid_submit(ctx::GridContext, options::SubmitGridOrderOptions)
    body = Dict{String,Any}(
        "symbol" => options.symbol,
        "settlement_currency" => options.settlement_currency,
        "grid_trading_rule" => grid_rule_dict(options.grid_trading_rule),
    )
    resp = ApiResponse(Client.http_post(ctx.config, "/v1/gridtrading/submit"; body))
    _check(resp)
    construct(SubmitGridOrderResponse, resp.data)
end

"""
    replace(ctx::GridContext, options::ReplaceGridOrderOptions) -> Nothing

修改（替换）网格交易订单。端点：`POST /v1/gridtrading/replace`
"""
function grid_replace(ctx::GridContext, options::ReplaceGridOrderOptions)
    body = Dict{String,Any}(
        "order_id" => options.order_id,
        "grid_trading_rule" => grid_rule_dict(options.grid_trading_rule),
    )
    resp = ApiResponse(Client.http_post(ctx.config, "/v1/gridtrading/replace"; body))
    _check(resp)
    return nothing
end

"""
    grid_list(ctx::GridContext, options::GetGridOrdersOptions = GetGridOrdersOptions()) -> Vector{GridOrder}

查询网格交易订单（分页列表）。端点：`GET /v1/gridtrading/list`
"""
function grid_list(ctx::GridContext, options::GetGridOrdersOptions = GetGridOrdersOptions())
    params = Dict{String,Any}()
    _put!(params, "page", options.page)
    _put!(params, "limit", options.limit)
    _put!(params, "market", options.market)
    _put!(params, "status", options.status)
    _put!(params, "symbol", options.symbol)
    _put!(params, "sort_by", options.sort_by)
    _put!(params, "sort_order", options.sort_order)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/gridtrading/list"; params))
    _check(resp)
    raw = get(resp.data, :grid_order, nothing)
    isnothing(raw) && return GridOrder[]
    GridOrder[construct(GridOrder, x) for x in raw]
end

"""
    list_by_ids(ctx::GridContext, options::GetGridOrdersByIdsOptions) -> Vector{GridOrder}

按 ID 批量查询网格订单。端点：`POST /v1/gridtrading/list`
"""
function grid_list_by_ids(ctx::GridContext, options::GetGridOrdersByIdsOptions)
    body = Dict{String,Any}("order_ids" => options.order_ids)
    resp = ApiResponse(Client.http_post(ctx.config, "/v1/gridtrading/list"; body))
    _check(resp)
    raw = get(resp.data, :grid_order, nothing)
    isnothing(raw) && return GridOrder[]
    GridOrder[construct(GridOrder, x) for x in raw]
end

"""
    detail(ctx::GridContext, options::GetGridOrderDetailOptions) -> GridOrderDetail

查询网格订单详情（含分页历史）。端点：`GET /v1/gridtrading/detail`
"""
function grid_detail(ctx::GridContext, options::GetGridOrderDetailOptions)
    params = Dict{String,Any}("order_id" => options.order_id)
    _put!(params, "history_id", options.history_id)
    _put!(params, "limit", options.limit)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/gridtrading/detail"; params))
    _check(resp)
    construct(GridOrderDetail, resp.data)
end

"""
    trigger_history(ctx::GridContext, options::GetGridTriggerHistoryOptions) -> Vector{TriggerOrder}

查询网格触发历史。端点：`GET /v1/gridtrading/trigger_history_list`
"""
function grid_trigger_history(ctx::GridContext, options::GetGridTriggerHistoryOptions)
    params = Dict{String,Any}("grid_order_id" => options.grid_order_id)
    _put!(params, "page", options.page)
    _put!(params, "limit", options.limit)
    resp =
        ApiResponse(Client.http_get(ctx.config, "/v1/gridtrading/trigger_history_list"; params))
    _check(resp)
    raw = get(resp.data, :trigger_orders, nothing)
    isnothing(raw) && return TriggerOrder[]
    TriggerOrder[construct(TriggerOrder, x) for x in raw]
end

# cancel / suspend / restart 的共享实现
function _grid_action(ctx::GridContext, path::String, order_id::AbstractString)
    body = Dict{String,Any}("order_id" => String(order_id))
    resp = ApiResponse(Client.http_post(ctx.config, path; body))
    _check(resp)
    return nothing
end

"""取消网格交易订单。端点：`POST /v1/gridtrading/cancel`"""
grid_cancel(ctx::GridContext, order_id::AbstractString) =
    _grid_action(ctx, "/v1/gridtrading/cancel", order_id)

"""暂停网格交易订单。端点：`POST /v1/gridtrading/suspend`"""
grid_suspend(ctx::GridContext, order_id::AbstractString) =
    _grid_action(ctx, "/v1/gridtrading/suspend", order_id)

"""重启网格交易订单。端点：`POST /v1/gridtrading/restart`"""
grid_restart(ctx::GridContext, order_id::AbstractString) =
    _grid_action(ctx, "/v1/gridtrading/restart", order_id)

"""
    symbol_info(ctx::GridContext, symbol::AbstractString) -> GridSymbolInfo

取构建网格订单所需的证券信息（手数、授权标志、结算币种等）。
端点：`GET /v1/orders/info`
"""
function grid_symbol_info(ctx::GridContext, symbol::AbstractString)
    params = Dict{String,Any}("symbol" => String(symbol))
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/orders/info"; params))
    _check(resp)
    construct(GridSymbolInfo, resp.data)
end

end # module GridCtx
