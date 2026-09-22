# 策略信号与催化剂事实（SignalContext）类型定义
# 对应上游 rust/src/signal/types.rs（#577 + #578）。全部走 HTTP，用 construct 解析。

module SignalProtocol

using EnumX, Dates, JSON
using ..Utils: JSONObject
import ..Utils: construct

export Outlook,
    SignalStatus,
    FactType,
    FactDirection,
    Signal,
    SignalsResponse,
    SignalsOptions,
    SecurityFact,
    SecurityFactsOptions,
    FactDataSource,
    AnomalyThresholds,
    AnomalyDetection,
    FactFactor,
    FactSymbol,
    NlTag,
    FactNlInfo,
    nl_tags

# ── 枚举 ────────────────────────────────────────────────────────────

# 策略对标的的方向判断（对应 core_conclusion.outlook_enum 1..5）
@enumx Outlook begin
    Unknown = 0
    StrongBullish = 1
    Bullish = 2
    Neutral = 3
    Bearish = 4
    StrongBearish = 5
end
function _parse_outlook(v)::Outlook.T
    s = v isa AbstractString ? v : string(v)
    s == "Strong bullish" && return Outlook.StrongBullish
    s == "Bullish" && return Outlook.Bullish
    s == "Neutral" && return Outlook.Neutral
    s == "Bearish" && return Outlook.Bearish
    s == "Strong bearish" && return Outlook.StrongBearish
    return Outlook.Unknown
end

# 信号生命周期状态（服务端用整数）
@enumx SignalStatus begin
    Unknown = -1
    Pending = 0
    Active = 1
    Deleted = 2
    AiFailed = 3
    FilteredByManual = 4
    AiSubmitFailed = 5
end
function _parse_signal_status(v)::SignalStatus.T
    n = v isa Integer ? Int(v) : (v isa AbstractString ? something(tryparse(Int, v), -1) : -1)
    (0 <= n <= 5) ? SignalStatus.T(n) : SignalStatus.Unknown
end

# 事实类型（及来源类型）
@enumx FactType begin
    Unknown = 0
    News = 1
    Fundamental = 2
    Technical = 3
end
function _parse_fact_type(v)::FactType.T
    s = v isa AbstractString ? v : string(v)
    s == "News" && return FactType.News
    s == "Fundamental" && return FactType.Fundamental
    s == "Technical" && return FactType.Technical
    return FactType.Unknown
end

# 事实/因子指向的方向
@enumx FactDirection begin
    Unknown = 0
    Long = 1
    Short = 2
    Neutral = 3
end
function _parse_fact_direction(v)::FactDirection.T
    s = v isa AbstractString ? v : string(v)
    s == "long" && return FactDirection.Long
    s == "short" && return FactDirection.Short
    s == "neutral" && return FactDirection.Neutral
    return FactDirection.Unknown
end

# ── 时间辅助 ────────────────────────────────────────────────────────

# 毫秒 unix 时间戳 → UTC DateTime
function _ms_to_datetime(v)::DateTime
    ms = v isa Integer ? Int64(v) : something(tryparse(Int64, string(v)), Int64(0))
    unix2datetime(ms / 1000)
end

# RFC3339 字符串 → UTC DateTime（容忍 Z / 时区偏移，取日期时间部分）
function _rfc3339_to_datetime(v)::DateTime
    s = v isa AbstractString ? String(v) : string(v)
    isempty(s) && return unix2datetime(0)
    core = replace(s, "Z" => "")
    # 去掉时区偏移，如 +08:00 / -05:00
    m = match(r"^(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?)", core)
    core = isnothing(m) ? core : m.captures[1]
    core = replace(core, " " => "T")
    try
        return DateTime(core)
    catch
        return unix2datetime(0)
    end
end

_str(obj, k) = String(get(obj, k, ""))
_f64(obj, k) = (v = get(obj, k, 0.0); v isa Number ? Float64(v) :
                (v isa AbstractString && !isempty(v) ? something(tryparse(Float64, v), 0.0) : 0.0))
_i32(obj, k) = (v = get(obj, k, 0); v isa Integer ? Int32(v) :
                (v isa AbstractString ? Int32(something(tryparse(Int, v), 0)) : Int32(0)))

# ── 信号类型 ────────────────────────────────────────────────────────

"""一条信号：某策略对某标的的判断，由某催化剂触发。"""
struct Signal
    id::String
    symbol::String
    company_name::String
    market::String
    title::String
    summary::String
    strategy_id::String
    strategy_name::String
    recommend_by::String
    expression::String
    key_fact_id::String
    key_catalyst::String
    analysis_price::Float64
    conservative_price::Float64
    benchmark_price::Float64
    optimistic_price::Float64
    outlook::Outlook.T
    outlook_desc::String
    status::SignalStatus.T
    json_data::String
    created_at::DateTime
    updated_at::DateTime
end
function construct(::Type{Signal}, obj::JSONObject)
    Signal(
        _str(obj, :id),
        _str(obj, :symbol),
        _str(obj, :company_name),
        _str(obj, :market),
        _str(obj, :title),
        _str(obj, :summary),
        _str(obj, :strategy_id),
        _str(obj, :strategy_name),
        _str(obj, :recommend_by),
        _str(obj, :expression),
        _str(obj, :key_fact_id),
        _str(obj, :key_catalyst),
        _f64(obj, :analysis_price),
        _f64(obj, :conservative_price),
        _f64(obj, :benchmark_price),
        _f64(obj, :optimistic_price),
        _parse_outlook(get(obj, :outlook, "")),
        _str(obj, :outlook_desc),
        _parse_signal_status(get(obj, :status, 1)),
        _str(obj, :json_data),
        _ms_to_datetime(get(obj, :created_at, 0)),
        _ms_to_datetime(get(obj, :updated_at, 0)),
    )
end

"""`signals` 返回的一页信号。`total` 为匹配过滤条件的总数，供分页。"""
struct SignalsResponse
    signals::Vector{Signal}
    total::Int32
end
function construct(::Type{SignalsResponse}, obj::JSONObject)
    raw = get(obj, :signals, nothing)
    sigs = isnothing(raw) ? Signal[] : Signal[construct(Signal, x) for x in raw]
    SignalsResponse(sigs, _i32(obj, :total))
end

# ── 事实（催化剂）类型 ──────────────────────────────────────────────

"""事实的来源。"""
struct FactDataSource
    source_name::String
    source_type::FactType.T
    url::String
    icon::String
end
function construct(::Type{FactDataSource}, obj::JSONObject)
    FactDataSource(
        _str(obj, :source_name),
        _parse_fact_type(get(obj, :type, "")),
        _str(obj, :url),
        _str(obj, :icon),
    )
end

"""异常检测的评分阈值。"""
struct AnomalyThresholds
    low::String
    medium::String
    high::String
end
construct(::Type{AnomalyThresholds}, obj::JSONObject) =
    AnomalyThresholds(_str(obj, :low), _str(obj, :medium), _str(obj, :high))

"""因子背后的异常检测结果（未跑测试的因子各字段为空）。"""
struct AnomalyDetection
    anomaly_result::String
    significance_level::String
    test_method::String
    thresholds::AnomalyThresholds
end
function construct(::Type{AnomalyDetection}, obj::JSONObject)
    th = get(obj, :thresholds, nothing)
    AnomalyDetection(
        _str(obj, :anomaly_result),
        _str(obj, :significance_level),
        _str(obj, :test_method),
        isnothing(th) ? AnomalyThresholds("", "", "") : construct(AnomalyThresholds, th),
    )
end

"""贡献于某事实的一个因子。"""
struct FactFactor
    name::String
    factor_groups::Vector{String}
    long_short_direction::FactDirection.T
    trigger_condition::String
    anomaly_detection::AnomalyDetection
end
function construct(::Type{FactFactor}, obj::JSONObject)
    groups_raw = get(obj, :factor_groups, nothing)
    groups = isnothing(groups_raw) ? String[] : String[String(g) for g in groups_raw]
    ad = get(obj, :anomaly_detection, nothing)
    FactFactor(
        _str(obj, :name),
        groups,
        _parse_fact_direction(get(obj, :long_short_direction, "")),
        _str(obj, :trigger_condition),
        isnothing(ad) ? AnomalyDetection("", "", "", AnomalyThresholds("", "", "")) :
        construct(AnomalyDetection, ad),
    )
end

"""事实涉及的一只证券。"""
struct FactSymbol
    symbol::String
    security_name::String
end
construct(::Type{FactSymbol}, obj::JSONObject) =
    FactSymbol(_str(obj, :symbol), _str(obj, :security_name))

"""自然语言字段里的一个 `{tag, value}` 条目。"""
struct NlTag
    tag::String
    value::String
end
construct(::Type{NlTag}, obj::JSONObject) = NlTag(_str(obj, :tag), _str(obj, :value))

"""事实的自然语言呈现。`summary`/`invest_anal`/`eli_explain` 是内嵌 JSON 字符串，
用 [`nl_tags`](@ref) 解析为 `{tag, value}` 列表。"""
struct FactNlInfo
    title::String
    sub_title::String
    summary::String
    invest_anal::String
    eli_explain::String
end
function construct(::Type{FactNlInfo}, obj::JSONObject)
    FactNlInfo(
        _str(obj, :title),
        _str(obj, :sub_title),
        _str(obj, :summary),
        _str(obj, :invest_anal),
        _str(obj, :eli_explain),
    )
end

"""
    nl_tags(s::AbstractString) -> Vector{NlTag}

把 `FactNlInfo` 里内嵌 JSON 字符串的字段（summary/invest_anal/eli_explain）解析为
`{tag, value}` 条目。字段为空或非预期 JSON 时返回空列表。
"""
function nl_tags(s::AbstractString)
    isempty(s) && return NlTag[]
    try
        arr = JSON.parse(s)
        arr isa AbstractVector || return NlTag[]
        return NlTag[NlTag(String(get(x, :tag, "")), String(get(x, :value, ""))) for x in arr]
    catch
        return NlTag[]
    end
end

"""一个事实（催化剂）事件：发生在某证券上的事，附带因子、来源与文本。"""
struct SecurityFact
    fact_id::String
    fact_type::FactType.T
    direction::FactDirection.T
    occur_time::DateTime
    symbols_info::Vector{FactSymbol}
    factors::Vector{FactFactor}
    data_source::Vector{FactDataSource}
    nl_info::FactNlInfo
end
function construct(::Type{SecurityFact}, obj::JSONObject)
    _vec(k, T) = (raw = get(obj, k, nothing);
                  isnothing(raw) ? T[] : T[construct(T, x) for x in raw])
    nl = get(obj, :nl_info, nothing)
    SecurityFact(
        _str(obj, :fact_id),
        _parse_fact_type(get(obj, :fact_type, "")),
        _parse_fact_direction(get(obj, :direction, "")),
        _rfc3339_to_datetime(get(obj, :occur_time, "")),
        _vec(:symbols_info, FactSymbol),
        _vec(:factors, FactFactor),
        _vec(:data_source, FactDataSource),
        isnothing(nl) ? FactNlInfo("", "", "", "", "") : construct(FactNlInfo, nl),
    )
end

# ── 请求参数 ────────────────────────────────────────────────────────

"""`signals` 的过滤参数，每个字段都是可选过滤器。"""
Base.@kwdef struct SignalsOptions
    symbol_name::Union{String,Nothing} = nothing
    strategy_id::Union{String,Nothing} = nothing
    strategy_name::Union{String,Nothing} = nothing   # 已废弃，优先用 strategy_id
    catalyst_name::Union{String,Nothing} = nothing
    catalyst_type::Union{String,Nothing} = nothing
    start_time::Union{DateTime,Nothing} = nothing
    end_time::Union{DateTime,Nothing} = nothing
    limit::Union{Int,Nothing} = nothing
    offset::Union{Int,Nothing} = nothing
end

"""`security_facts` 的参数，`symbol` 必填。"""
Base.@kwdef struct SecurityFactsOptions
    symbol::String
    begin_time::Union{DateTime,Nothing} = nothing
    end_time::Union{DateTime,Nothing} = nothing
    limit::Union{Int,Nothing} = nothing
end

end # module SignalProtocol
