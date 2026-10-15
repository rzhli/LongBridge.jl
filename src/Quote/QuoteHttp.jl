# REST equivalents of quote protobuf commands (upstream #604).
const QUOTE_HTTP_PATHS = Dict(
    QuoteCommand.QueryMarketTradePeriod => "/quote/markets/trading-sessions",
    QuoteCommand.QueryMarketTradeDay => "/quote/markets/trading-days",
    QuoteCommand.QuerySecurityStaticInfo => "/quote/static-info",
    QuoteCommand.QuerySecurityQuote => "/quote/quotes",
    QuoteCommand.QueryOptionQuote => "/quote/options/quotes",
    QuoteCommand.QueryWarrantQuote => "/quote/warrants/quotes",
    QuoteCommand.QueryDepth => "/quote/depth",
    QuoteCommand.QueryBrokers => "/quote/brokers",
    QuoteCommand.QueryParticipantBrokerIds => "/quote/participants",
    QuoteCommand.QueryTrade => "/quote/trades",
    QuoteCommand.QueryIntraday => "/quote/intraday",
    QuoteCommand.QueryCandlestick => "/quote/candlesticks",
    QuoteCommand.QueryOptionChainDate => "/quote/options/expiry-dates",
    QuoteCommand.QueryWarrantIssuerInfo => "/quote/warrants/issuers",
    QuoteCommand.QueryWarrantFilterList => "/quote/warrants",
    QuoteCommand.QueryCapitalFlowIntraday => "/quote/capital-flow",
    QuoteCommand.QueryCapitalFlowDistribution => "/quote/capital-distribution",
    QuoteCommand.QuerySecurityCalcIndex => "/quote/calc-indexes",
    QuoteCommand.QueryHistoryCandlestick => "/quote/history-candlesticks",
)

# Use protocol field names and numeric enums, not JSON.lower (which exposes the
# Julia-facing date/enum representation). Omit absent nested messages recursively.
_quote_http_body(x::Union{AbstractString,Number,Bool}) = x
_quote_http_body(x::Enum) = Int(x)
_quote_http_body(x::Date) = Dates.format(x, dateformat"yyyymmdd")
_quote_http_body(x::AbstractVector) = map(_quote_http_body, x)
_quote_http_body(::Vector{UInt8}) = Dict{String,Any}() # bodyless protobuf command
_quote_http_body(x) = Dict{String,Any}(
    string(f) => _quote_http_body(getfield(x, f)) for f in fieldnames(typeof(x))
    if !isnothing(getfield(x, f))
)

_camel_key(name::Symbol) = replace(string(name), r"_([a-z])" => s -> uppercase(s[2:end]))

# Decode into the same Julia protocol types as WS, including their defaults.
# JSON int64 strings must never pass through Float64. Unknown keys are ignored.
function _quote_http_decode(::Type{T}, value; symbol::String = "") where {T}
    if T isa Union
        return isnothing(value) ? nothing :
               _quote_http_decode(only(filter(t -> t !== Nothing, Base.uniontypes(T))), value; symbol)
    elseif T <: AbstractVector
        isnothing(value) && return T()
        return T([_quote_http_decode(eltype(T), v; symbol) for v in value])
    elseif T === String
        isnothing(value) && return ""
        value isa Union{AbstractString,Number} ||
            throw(ArgumentError("expected a quote JSON scalar for String, got $(repr(value))"))
        return string(value)
    elseif T === Date
        return isnothing(value) || value == "" ? Date(1970, 1, 1) :
               Date(string(value), dateformat"yyyymmdd")
    elseif T <: Enum
        isnothing(value) && return first(instances(T))
        # These enums are numeric on the wire (empty string means proto zero).
        return T(_quote_http_decode(Int32, value))
    elseif T === Bool
        isnothing(value) && return false
        value isa Number && return !iszero(value)
        return parse(Bool, value)
    elseif T <: Number
        if T <: Integer && value isa AbstractFloat
            throw(ArgumentError("expected integer quote JSON value, got $(repr(value))"))
        end
        return isnothing(value) || value == "" ? zero(T) :
               value isa AbstractString ? parse(T, value) : convert(T, value)
    end
    defaults = ProtoBuf.default_values(T)
    obj = isnothing(value) ? Dict{String,Any}() : value
    symbol = String(something(get(obj, "symbol", nothing), symbol))
    vals = map(fieldnames(T)) do f
        raw = get(obj, string(f), get(obj, _camel_key(f), nothing))
        if T === Trade && f === :trade_type
            # Unlike numeric enums, this is a market-specific string on the
            # wire. Missing/null means "" (automatch for HK/US); numeric 1 is
            # the US code "1", not the Julia enum with discriminant 1.
            QuoteProtocol.trade_type_from_string(_quote_http_decode(String, raw), symbol)
        elseif isnothing(raw) && haskey(defaults, f)
            getproperty(defaults, f)
        else
            _quote_http_decode(fieldtype(T, f), raw; symbol)
        end
    end
    return T(vals...)
end

function _quote_http_request(ctx::QuoteContext, path::String, req, ::Type{T}) where {T}
    _is_shutdown(ctx.inner) && throw(LongBridgeError(500, "Quote context is closed"))
    resp = ApiResponse(Client.http_post(ctx.inner.config, path; body = _quote_http_body(req)))
    resp.code == 0 ||
        @lperror(resp.code, resp.message, get(resp.headers, "x-request-id", nothing))
    return _quote_http_decode(T, resp.data)::T
end

_is_us_equity(symbol::AbstractString) =
    length(symbol) > 3 && endswith(lowercase(symbol), ".us") && !startswith(symbol, ".")

# US Eastern offset rules since 1967. This small UTC -> wall-clock conversion is
# internal to the HTTP overnight workaround; no optional TimeZones dependency is
# needed. Modern overnight trading uses the post-2007 rules. Include older DST
# rules because historical refill queries can cross earlier years.
function _new_york_local(timestamp::Integer)
    utc = unix2datetime(timestamp)
    y = year(utc)
    first_sunday(m) = Date(y, m, 1) + Day(mod(7 - dayofweek(Date(y, m, 1)), 7))
    last_sunday(m) = lastdayofmonth(Date(y, m, 1)) -
                     Day(mod(dayofweek(lastdayofmonth(Date(y, m, 1))), 7))
    start = y >= 2007 ? first_sunday(3) + Day(7) :
            y >= 1987 ? first_sunday(4) :
            y == 1974 ? Date(y, 1, 6) : y == 1975 ? Date(y, 2, 23) : last_sunday(4)
    stop = y >= 2007 ? first_sunday(11) : last_sunday(10)
    dst = y >= 1967 && DateTime(start) + Hour(7) <= utc < DateTime(stop) + Hour(6)
    return utc - Hour(dst ? 4 : 5)
end
_is_us_overnight(timestamp::Integer) = (h = hour(_new_york_local(timestamp)); h < 4 || h >= 20)

# HTTP always includes overnight data; WS only includes it after opting in.
_align_http_overnight(ctx, req, resp) = resp
function _align_http_overnight(ctx, req, resp::SecurityQuoteResponse)
    ctx.inner.config.enable_overnight && return resp
    quotes = map(resp.secu_quote) do q
        !_is_us_equity(q.symbol) && return q
        SecurityQuote((f === :over_night_quote ? nothing : getfield(q, f)
                       for f in fieldnames(SecurityQuote))...)
    end
    return SecurityQuoteResponse(quotes)
end
function _align_http_overnight(ctx, req::SecurityIntradayRequest, resp::SecurityIntradayResponse)
    (ctx.inner.config.enable_overnight || !_is_us_equity(req.symbol)) && return resp
    return SecurityIntradayResponse(resp.symbol, filter(l -> !_is_us_overnight(l.timestamp), resp.lines))
end

const MAX_HTTP_HISTORY_CANDLESTICKS = 1000
const MAX_HTTP_REFILL_ROUNDS = 8
_raw_edge(bars, forward) = isempty(bars) ? nothing :
    (forward ? maximum(c.timestamp for c in bars) : minimum(c.timestamp for c in bars))
_drop_overnight(bars) = filter(c -> c.trade_session !== TradeSession.OvernightTrade, bars)

function _align_http_overnight(
    ctx, req::Union{SecurityCandlestickRequest,SecurityHistoryCandlestickRequest},
    resp::SecurityCandlestickResponse,
)
    (ctx.inner.config.enable_overnight || !_is_us_equity(req.symbol) ||
     req.trade_session !== TradeSession.All) && return resp
    raw = resp.candlesticks
    kept = _drop_overnight(raw)
    length(kept) == length(raw) && return resp
    forward = false
    bound = nothing
    if req isa SecurityCandlestickRequest
        target = min(req.count, length(raw))
    elseif req.query_type === HistoryCandlestickQueryType.QUERY_BY_OFFSET
        forward = req.offset_request.direction === Direction.FORWARD
        target = min(req.offset_request.count, length(raw))
    else
        start = req.date_request.start_date
        bound = isempty(start) ? nothing : Date(start, dateformat"yyyymmdd")
        edge = _raw_edge(raw, false)
        capped = length(raw) >= MAX_HTTP_HISTORY_CANDLESTICKS && !isnothing(edge) &&
                 (isnothing(bound) || _new_york_local(edge) > DateTime(bound))
        capped || return SecurityCandlestickResponse(resp.symbol, kept)
        target = length(raw)
    end
    cursor = _raw_edge(raw, forward)
    stalled = false
    for round in 1:MAX_HTTP_REFILL_ROUNDS
        (length(kept) >= target || isnothing(cursor)) && break
        need = target - length(kept)
        count = stalled ? MAX_HTTP_HISTORY_CANDLESTICKS :
                min(need + need ÷ 2 + 1, MAX_HTTP_HISTORY_CANDLESTICKS)
        anchor = _new_york_local(cursor)
        offset = OffsetQuery(forward ? Direction.FORWARD : Direction.BACKWARD,
                             Dates.format(anchor, dateformat"yyyymmdd"),
                             Dates.format(anchor, dateformat"HHMM"), count)
        next_req = SecurityHistoryCandlestickRequest(
            req.symbol, req.period, req.adjust_type,
            HistoryCandlestickQueryType.QUERY_BY_OFFSET, offset, nothing, req.trade_session,
        )
        page = _quote_http_request(ctx, "/quote/history-candlesticks", next_req,
                                  SecurityCandlestickResponse).candlesticks
        next_cursor = _raw_edge(page, forward)
        more = filter(c -> forward ? c.timestamp > cursor : c.timestamp < cursor,
                      _drop_overnight(page))
        crossed_bound = false
        if !isnothing(bound)
            inside(c) = forward ? Date(_new_york_local(c.timestamp)) <= bound :
                                  Date(_new_york_local(c.timestamp)) >= bound
            crossed_bound = any(c -> !inside(c), more)
            filter!(inside, more)
        end
        sort!(more; by = c -> c.timestamp)
        unique!(c -> c.timestamp, more)
        stalled = isempty(more)
        if forward
            append!(kept, first(more, min(need, length(more))))
        else
            prepend!(kept, last(more, min(need, length(more))))
        end
        (length(page) < count || crossed_bound || isnothing(next_cursor) ||
         next_cursor == cursor) && break
        cursor = next_cursor
        if round == MAX_HTTP_REFILL_ROUNDS && length(kept) < target
            @warn "HTTP overnight top-up hit its round limit" symbol=req.symbol target got=length(kept)
        end
    end
    return SecurityCandlestickResponse(resp.symbol, kept)
end
