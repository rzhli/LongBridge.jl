module FundCtx

using JSON
using ..Config
using ..Client
using ..Errors
using ..Utils: construct
using ..FundProtocol
import ..Trade: fund_positions

export FundContext,
    hot_funds,
    funds,
    fund_filters,
    fund_detail,
    fund_analysis,
    fund_analysis_detail,
    fund_trend,
    fund_annual_returns,
    fund_quarterly_returns,
    fund_performance,
    fund_performance_comparison,
    fund_nav,
    fund_nav_history,
    fund_nav_range,
    fund_holdings,
    fund_stock_holdings,
    fund_positions,
    fund_position,
    fund_position_performance,
    fund_position_profits,
    fund_position_nav,
    fund_position_dividends,
    fund_orders,
    fund_order,
    fund_transactions,
    fund_validate_order,
    fund_submit_order,
    fund_cancel_order

"""
    FundContext(config::Config.Settings)

Mutual-fund catalog, market data, positions and orders. Synchronous HTTP only.
Pass full counter IDs such as `"UT/FD/HK0000384492"`; they are query parameters,
never URL path segments. Numeric-string response fields retain their precision.
"""
struct FundContext
    config::Config.Settings
end

_check(resp) =
    resp.code == 0 ||
    @lperror(resp.code, resp.message, get(resp.headers, "x-request-id", nothing))

function _options_dict(options)
    params = Dict{String,Any}()
    for field in fieldnames(typeof(options))
        value = getfield(options, field)
        isnothing(value) && continue
        field in (:quick_ids, :time_interval, :counter_ids) && isempty(value) && continue
        key = field === :end_ ? "end" : field === :counter_ids ? "counter_id" : String(field)
        params[key] = value
    end
    params
end

"""
    hot_funds(ctx::FundContext) -> Vector{HotFund}

Endpoint: `GET /v1/fund/hot-funds`.
"""
function hot_funds(ctx::FundContext)
    params = Dict{String,Any}()
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/hot-funds"; params))
    _check(resp)
    HotFund[construct(HotFund, x) for x in get(resp.data, :list, [])]
end

"""
    funds(ctx::FundContext, options::GetFundsOptions = GetFundsOptions()) -> Vector{FundBrief}

Endpoint: `POST /v1/fund/funds`.
"""
function funds(ctx::FundContext, options::GetFundsOptions = GetFundsOptions())
    body = _options_dict(options)
    resp = ApiResponse(Client.http_post(ctx.config, "/v1/fund/funds"; body))
    _check(resp)
    FundBrief[construct(FundBrief, x) for x in get(resp.data, :funds, [])]
end

"""
    fund_filters(ctx::FundContext) -> FundFilters

Endpoint: `GET /v1/fund/filters`.
"""
function fund_filters(ctx::FundContext)
    params = Dict{String,Any}()
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/filters"; params))
    _check(resp)
    construct(FundFilters, resp.data)
end

"""
    fund_detail(ctx::FundContext, counter_id::AbstractString) -> FundDetail

Endpoint: `GET /v1/fund/funds/detail`.
"""
function fund_detail(ctx::FundContext, counter_id::AbstractString)
    params = Dict{String,Any}()
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/detail"; params))
    _check(resp)
    construct(FundDetail, resp.data)
end

"""
    fund_analysis(ctx::FundContext, counter_id::AbstractString, options::GetFundAnalysisOptions = GetFundAnalysisOptions()) -> FundAnalysis

Endpoint: `GET /v1/fund/funds/analysis`.
"""
function fund_analysis(ctx::FundContext, counter_id::AbstractString, options::GetFundAnalysisOptions = GetFundAnalysisOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/analysis"; params))
    _check(resp)
    construct(FundAnalysis, resp.data)
end

"""
    fund_analysis_detail(ctx::FundContext, counter_id::AbstractString, options::GetFundAnalysisOptions = GetFundAnalysisOptions()) -> FundAnalysisDetail

Endpoint: `GET /v1/fund/funds/analysis/detail`.
"""
function fund_analysis_detail(ctx::FundContext, counter_id::AbstractString, options::GetFundAnalysisOptions = GetFundAnalysisOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/analysis/detail"; params))
    _check(resp)
    construct(FundAnalysisDetail, resp.data)
end

"""
    fund_trend(ctx::FundContext, counter_id::AbstractString, options::GetFundAnalysisOptions = GetFundAnalysisOptions()) -> FundTrend

Endpoint: `GET /v1/fund/funds/trend`.
"""
function fund_trend(ctx::FundContext, counter_id::AbstractString, options::GetFundAnalysisOptions = GetFundAnalysisOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/trend"; params))
    _check(resp)
    construct(FundTrend, resp.data)
end

"""
    fund_annual_returns(ctx::FundContext, counter_id::AbstractString, options::FundPageOptions = FundPageOptions()) -> Vector{FundAnnualReturn}

Endpoint: `GET /v1/fund/funds/returns/annual`.
"""
function fund_annual_returns(ctx::FundContext, counter_id::AbstractString, options::FundPageOptions = FundPageOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/returns/annual"; params))
    _check(resp)
    FundAnnualReturn[construct(FundAnnualReturn, x) for x in get(resp.data, :list, [])]
end

"""
    fund_quarterly_returns(ctx::FundContext, counter_id::AbstractString, options::FundPageOptions = FundPageOptions()) -> Vector{FundQuarterlyReturn}

Endpoint: `GET /v1/fund/funds/returns/quarterly`.
"""
function fund_quarterly_returns(ctx::FundContext, counter_id::AbstractString, options::FundPageOptions = FundPageOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/returns/quarterly"; params))
    _check(resp)
    FundQuarterlyReturn[construct(FundQuarterlyReturn, x) for x in get(resp.data, :list, [])]
end

"""
    fund_performance(ctx::FundContext, counter_id::AbstractString) -> Vector{FundPerformance}

Endpoint: `GET /v1/fund/funds/performance`.
"""
function fund_performance(ctx::FundContext, counter_id::AbstractString)
    params = Dict{String,Any}()
    params["counter_ids"] = JSON.json([String(counter_id)])
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/performance"; params))
    _check(resp)
    FundPerformance[construct(FundPerformance, x) for x in get(resp.data, :value, [])]
end

"""
    fund_performance_comparison(ctx::FundContext, counter_id::AbstractString, options::GetFundAnalysisOptions = GetFundAnalysisOptions()) -> FundPerformanceComparison

Endpoint: `GET /v1/fund/funds/performance/comparison`.
"""
function fund_performance_comparison(ctx::FundContext, counter_id::AbstractString, options::GetFundAnalysisOptions = GetFundAnalysisOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/performance/comparison"; params))
    _check(resp)
    construct(FundPerformanceComparison, resp.data)
end

"""
    fund_nav(ctx::FundContext, counter_id::AbstractString) -> Vector{FundNavValue}

Endpoint: `GET /v1/fund/funds/nav`.
"""
function fund_nav(ctx::FundContext, counter_id::AbstractString)
    params = Dict{String,Any}()
    params["counter_ids"] = JSON.json([String(counter_id)])
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/nav"; params))
    _check(resp)
    FundNavValue[construct(FundNavValue, x) for x in get(resp.data, :value, [])]
end

"""
    fund_nav_history(ctx::FundContext, counter_id::AbstractString, options::FundPageOptions = FundPageOptions()) -> Vector{FundNavValue}

Endpoint: `GET /v1/fund/funds/nav-history`.
"""
function fund_nav_history(ctx::FundContext, counter_id::AbstractString, options::FundPageOptions = FundPageOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/nav-history"; params))
    _check(resp)
    FundNavValue[construct(FundNavValue, x) for x in get(resp.data, :history_value, [])]
end

"""
    fund_nav_range(ctx::FundContext, counter_id::AbstractString, options::FundNavRangeOptions = FundNavRangeOptions()) -> Vector{FundNavValue}

Endpoint: `GET /v1/fund/funds/nav-range`.
"""
function fund_nav_range(ctx::FundContext, counter_id::AbstractString, options::FundNavRangeOptions = FundNavRangeOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/nav-range"; params))
    _check(resp)
    FundNavValue[construct(FundNavValue, x) for x in get(resp.data, :history_value, [])]
end

"""
    fund_holdings(ctx::FundContext, counter_id::AbstractString, options::GetFundHoldingsOptions = GetFundHoldingsOptions()) -> FundHoldings

Endpoint: `GET /v1/fund/funds/holdings`.
"""
function fund_holdings(ctx::FundContext, counter_id::AbstractString, options::GetFundHoldingsOptions = GetFundHoldingsOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/holdings"; params))
    _check(resp)
    construct(FundHoldings, resp.data)
end

"""
    fund_stock_holdings(ctx::FundContext, counter_id::AbstractString, options::GetFundStockHoldingsOptions = GetFundStockHoldingsOptions()) -> Vector{FundStockHolding}

Endpoint: `GET /v1/fund/funds/stock-holdings`.
"""
function fund_stock_holdings(ctx::FundContext, counter_id::AbstractString, options::GetFundStockHoldingsOptions = GetFundStockHoldingsOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/funds/stock-holdings"; params))
    _check(resp)
    FundStockHolding[construct(FundStockHolding, x) for x in get(resp.data, :lists, [])]
end

"""
    fund_positions(ctx::FundContext, options::FundPositionsOptions = FundPositionsOptions()) -> FundPositions

Endpoint: `GET /v1/asset/funds`.
"""
function fund_positions(ctx::FundContext, options::FundPositionsOptions = FundPositionsOptions())
    params = _options_dict(options)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/asset/funds"; params))
    _check(resp)
    construct(FundPositions, resp.data)
end

"""
    fund_position(ctx::FundContext, counter_id::AbstractString, options::GetFundPositionOptions = GetFundPositionOptions()) -> FundPositionDetail

Endpoint: `GET /v1/asset/funds/detail`.
"""
function fund_position(ctx::FundContext, counter_id::AbstractString, options::GetFundPositionOptions = GetFundPositionOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/asset/funds/detail"; params))
    _check(resp)
    construct(FundPositionDetail, resp.data)
end

"""
    fund_position_performance(ctx::FundContext, counter_id::AbstractString) -> Vector{FundPositionPerformance}

Endpoint: `GET /v1/asset/funds/performance`.
"""
function fund_position_performance(ctx::FundContext, counter_id::AbstractString)
    params = Dict{String,Any}()
    params["counter_ids"] = JSON.json([String(counter_id)])
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/asset/funds/performance"; params))
    _check(resp)
    FundPositionPerformance[construct(FundPositionPerformance, x) for x in get(resp.data, :value, [])]
end

"""
    fund_position_profits(ctx::FundContext, counter_id::AbstractString, options::GetFundPositionProfitsOptions = GetFundPositionProfitsOptions()) -> FundPositionProfits

Endpoint: `GET /v1/asset/funds/profits`.
"""
function fund_position_profits(ctx::FundContext, counter_id::AbstractString, options::GetFundPositionProfitsOptions = GetFundPositionProfitsOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/asset/funds/profits"; params))
    _check(resp)
    construct(FundPositionProfits, resp.data)
end

"""
    fund_position_nav(ctx::FundContext, counter_id::AbstractString, options::FundNavRangeOptions = FundNavRangeOptions()) -> Vector{FundPositionNav}

Endpoint: `GET /v1/asset/funds/nav-history`.
"""
function fund_position_nav(ctx::FundContext, counter_id::AbstractString, options::FundNavRangeOptions = FundNavRangeOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/asset/funds/nav-history"; params))
    _check(resp)
    FundPositionNav[construct(FundPositionNav, x) for x in get(resp.data, :history_value, [])]
end

"""
    fund_position_dividends(ctx::FundContext, counter_id::AbstractString, options::GetFundPositionDividendsOptions = GetFundPositionDividendsOptions()) -> FundDividends

Endpoint: `GET /v1/asset/funds/dividends`.
"""
function fund_position_dividends(ctx::FundContext, counter_id::AbstractString, options::GetFundPositionDividendsOptions = GetFundPositionDividendsOptions())
    params = _options_dict(options)
    params["counter_id"] = String(counter_id)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/asset/funds/dividends"; params))
    _check(resp)
    construct(FundDividends, resp.data)
end

"""
    fund_orders(ctx::FundContext, options::GetFundOrdersOptions = GetFundOrdersOptions()) -> Vector{FundOrder}

Endpoint: `GET /v1/fund/orders`.
"""
function fund_orders(ctx::FundContext, options::GetFundOrdersOptions = GetFundOrdersOptions())
    params = _options_dict(options)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/orders"; params))
    _check(resp)
    FundOrder[construct(FundOrder, x) for x in get(resp.data, :orders, [])]
end

"""
    fund_order(ctx::FundContext, order_id::Integer) -> FundOrderDetail

Endpoint: `GET /v1/fund/orders/{order_id}`.
"""
function fund_order(ctx::FundContext, order_id::Integer)
    params = Dict{String,Any}()
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/orders/$order_id"; params))
    _check(resp)
    construct(FundOrderDetail, resp.data)
end

"""
    fund_transactions(ctx::FundContext, options::GetFundTransactionsOptions = GetFundTransactionsOptions()) -> Vector{FundTransaction}

Endpoint: `GET /v1/fund/transactions`.
"""
function fund_transactions(ctx::FundContext, options::GetFundTransactionsOptions = GetFundTransactionsOptions())
    params = _options_dict(options)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/fund/transactions"; params))
    _check(resp)
    FundTransaction[construct(FundTransaction, x) for x in get(resp.data, :list, [])]
end

"""
    fund_validate_order(ctx::FundContext, options::ValidateFundOrderOptions) -> FundOrderValidation

Endpoint: `POST /v1/fund/orders/validate`.
"""
function fund_validate_order(ctx::FundContext, options::ValidateFundOrderOptions)
    body = _options_dict(options)
    resp = ApiResponse(Client.http_post(ctx.config, "/v1/fund/orders/validate"; body))
    _check(resp)
    construct(FundOrderValidation, resp.data)
end

"""
    fund_submit_order(ctx::FundContext, options::SubmitFundOrderOptions) -> FundOrderSubmitResponse

Endpoint: `POST /v1/fund/orders`.
"""
function fund_submit_order(ctx::FundContext, options::SubmitFundOrderOptions)
    body = _options_dict(options)
    resp = ApiResponse(Client.http_post(ctx.config, "/v1/fund/orders"; body))
    _check(resp)
    construct(FundOrderSubmitResponse, resp.data)
end

"""
    fund_cancel_order(ctx::FundContext, order_id::Integer) -> Nothing

Endpoint: `POST /v1/fund/orders/{order_id}/cancel`.
"""
function fund_cancel_order(ctx::FundContext, order_id::Integer)
    body = Dict{String,Any}("ut_id" => order_id)
    resp = ApiResponse(Client.http_post(ctx.config, "/v1/fund/orders/$order_id/cancel"; body))
    _check(resp)
    nothing
end

end # module FundCtx
