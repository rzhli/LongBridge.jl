module SignalCtx

using Dates

using ..Config
using ..Client
using ..Errors
using ..Errors: ApiResponse
using ..Utils: construct, utc_iso8601
using ..SignalProtocol

export SignalContext, signals, signal, security_facts

"""
    SignalContext(config::Config.Settings)

策略信号与催化剂事实上下文。HTTP-only。
"""
struct SignalContext
    config::Config.Settings
end

_check(resp) =
    resp.code == 0 ||
    @lperror(resp.code, resp.message, get(resp.headers, "x-request-id", nothing))

# RFC3339（带 Z）时间字符串
_rfc3339(t::DateTime) = utc_iso8601(t)

function _put!(params, key, val)
    isnothing(val) && return
    params[key] = val isa DateTime ? _rfc3339(val) : val
end

"""
    signals(ctx::SignalContext, opts::SignalsOptions = SignalsOptions()) -> SignalsResponse

按 symbol / 策略 / 催化剂 / 时间范围过滤查询信号，用 `limit` / `offset` 分页。

端点：`GET /v1/signals`
"""
function signals(ctx::SignalContext, opts::SignalsOptions = SignalsOptions())
    params = Dict{String,Any}()
    _put!(params, "symbol_name", opts.symbol_name)
    _put!(params, "strategy_id", opts.strategy_id)
    _put!(params, "strategy_name", opts.strategy_name)
    _put!(params, "catalyst_name", opts.catalyst_name)
    _put!(params, "catalyst_type", opts.catalyst_type)
    _put!(params, "start_time", opts.start_time)
    _put!(params, "end_time", opts.end_time)
    _put!(params, "limit", opts.limit)
    _put!(params, "offset", opts.offset)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/signals"; params))
    _check(resp)
    construct(SignalsResponse, resp.data)
end

"""
    signal(ctx::SignalContext, signal_id::AbstractString) -> Signal

按 ID 取单条信号，含 `json_data` 里的完整策略分析。

端点：`GET /v1/signals/{signal_id}`
"""
function signal(ctx::SignalContext, signal_id::AbstractString)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/signals/$(signal_id)"))
    _check(resp)
    construct(Signal, resp.data.signal)
end

"""
    security_facts(ctx::SignalContext, opts::SecurityFactsOptions) -> Vector{SecurityFact}

列出某证券的事实（催化剂）事件：异常检测、因子读数、来源与文本摘要。
信号在 `key_fact_id` 中引用触发它的事实。

端点：`GET /v1/facts/security_facts`
"""
function security_facts(ctx::SignalContext, opts::SecurityFactsOptions)
    params = Dict{String,Any}("symbol" => opts.symbol)
    _put!(params, "begin_time", opts.begin_time)
    _put!(params, "end_time", opts.end_time)
    _put!(params, "limit", opts.limit)
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/facts/security_facts"; params))
    _check(resp)
    raw = get(resp.data, :facts, nothing)
    isnothing(raw) && return SecurityFact[]
    SecurityFact[construct(SecurityFact, x) for x in raw]
end

end # module SignalCtx
