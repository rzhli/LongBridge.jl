module MarketProtocol

using EnumX, JSON3, StructTypes, Dates
using ..Utils: Dec64, counter_id_to_symbol, to_china_time
using ..Constant: Market
import ..Utils: _parse_optional_decimal

export BrokerHoldingPeriod,
    AhPremiumPeriod,
    MarketTimeItem,
    MarketStatusResponse,
    BrokerHoldingEntry,
    BrokerHoldingTop,
    BrokerHoldingChanges,
    BrokerHoldingDetailItem,
    BrokerHoldingDetail,
    BrokerHoldingDailyItem,
    BrokerHoldingDailyHistory,
    AhPremiumKline,
    AhPremiumKlines,
    AhPremiumIntraday,
    TradeStatistics,
    TradePriceLevel,
    TradeStatsResponse,
    AnomalyItem,
    AnomalyResponse,
    ConstituentStock,
    IndexConstituents,
    TopMoversStock,
    TopMoversEvent,
    TopMoversResponse,
    RankCategoriesResponse,
    RankListItem,
    RankListResponse,
    _broker_holding_period_str,
    _ah_premium_period_line_type,
    _market_from_str

@enumx BrokerHoldingPeriod begin
    Rct1 = 1   # 1 日变化
    Rct5 = 5   # 5 日变化
    Rct20 = 20  # 20 日变化
    Rct60 = 60  # 60 日变化
end

@enumx AhPremiumPeriod begin
    Min1 = 1
    Min5 = 5
    Min15 = 15
    Min30 = 30
    Min60 = 60
    Day = 1000
    Week = 2000
    Month = 3000
    Year = 4000
end

function _broker_holding_period_str(p::BrokerHoldingPeriod.T)
    p === BrokerHoldingPeriod.Rct1 ? "rct_1" :
    p === BrokerHoldingPeriod.Rct5 ? "rct_5" :
    p === BrokerHoldingPeriod.Rct20 ? "rct_20" :
    p === BrokerHoldingPeriod.Rct60 ? "rct_60" : error("unknown BrokerHoldingPeriod: $p")
end

function _ah_premium_period_line_type(p::AhPremiumPeriod.T)
    p === AhPremiumPeriod.Min1 ? "1" :
    p === AhPremiumPeriod.Min5 ? "5" :
    p === AhPremiumPeriod.Min15 ? "15" :
    p === AhPremiumPeriod.Min30 ? "30" :
    p === AhPremiumPeriod.Min60 ? "60" :
    p === AhPremiumPeriod.Day ? "1000" :
    p === AhPremiumPeriod.Week ? "2000" :
    p === AhPremiumPeriod.Month ? "3000" :
    p === AhPremiumPeriod.Year ? "4000" : error("unknown AhPremiumPeriod: $p")
end

function _market_from_str(s::AbstractString)
    s == "US" ? Market.US :
    s == "HK" ? Market.HK : s == "CN" ? Market.CN : s == "SG" ? Market.SG : Market.Unknown
end

const RawJSON = Union{JSON3.Object,JSON3.Array,Dict{String,Any},Vector{Any},Nothing}

# ── market_status ──────────────────────────────────────────────────

struct MarketTimeItem
    market::Market.T
    trade_status::Int
    timestamp::String
    delay_trade_status::Int
    delay_timestamp::String
    sub_status::Int
    delay_sub_status::Int
end
StructTypes.StructType(::Type{MarketTimeItem}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{MarketTimeItem}, obj::JSON3.Object)
    MarketTimeItem(
        _market_from_str(String(get(obj, :market, ""))),
        Int(get(obj, :trade_status, 0)),
        String(get(obj, :timestamp, "")),
        Int(get(obj, :delay_trade_status, 0)),
        String(get(obj, :delay_timestamp, "")),
        Int(get(obj, :sub_status, 0)),
        Int(get(obj, :delay_sub_status, 0)),
    )
end

struct MarketStatusResponse
    market_time::Vector{MarketTimeItem}
end
StructTypes.StructType(::Type{MarketStatusResponse}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{MarketStatusResponse}, obj::JSON3.Object)
    items = if haskey(obj, :market_time) && !isnothing(obj.market_time)
        [StructTypes.construct(MarketTimeItem, x) for x in obj.market_time]
    else
        MarketTimeItem[]
    end
    MarketStatusResponse(items)
end

# ── broker_holding (top) ───────────────────────────────────────────

struct BrokerHoldingEntry
    name::String
    parti_number::String
    chg::Union{Dec64,Nothing}
    strong::Bool
end
StructTypes.StructType(::Type{BrokerHoldingEntry}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{BrokerHoldingEntry}, obj::JSON3.Object)
    BrokerHoldingEntry(
        String(get(obj, :name, "")),
        String(get(obj, :parti_number, "")),
        _parse_optional_decimal(get(obj, :chg, nothing)),
        Bool(get(obj, :strong, false)),
    )
end

struct BrokerHoldingTop
    buy::Vector{BrokerHoldingEntry}
    sell::Vector{BrokerHoldingEntry}
    updated_at::String
end
StructTypes.StructType(::Type{BrokerHoldingTop}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{BrokerHoldingTop}, obj::JSON3.Object)
    _list(key) =
        if haskey(obj, key) && !isnothing(obj[key])
            [StructTypes.construct(BrokerHoldingEntry, x) for x in obj[key]]
        else
            BrokerHoldingEntry[]
        end
    BrokerHoldingTop(_list(:buy), _list(:sell), String(get(obj, :updated_at, "")))
end

# ── broker_holding (detail) ────────────────────────────────────────

struct BrokerHoldingChanges
    value::Union{Dec64,Nothing}
    chg_1::Union{Dec64,Nothing}
    chg_5::Union{Dec64,Nothing}
    chg_20::Union{Dec64,Nothing}
    chg_60::Union{Dec64,Nothing}
end
StructTypes.StructType(::Type{BrokerHoldingChanges}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{BrokerHoldingChanges}, obj::JSON3.Object)
    BrokerHoldingChanges(
        _parse_optional_decimal(get(obj, :value, nothing)),
        _parse_optional_decimal(get(obj, :chg_1, nothing)),
        _parse_optional_decimal(get(obj, :chg_5, nothing)),
        _parse_optional_decimal(get(obj, :chg_20, nothing)),
        _parse_optional_decimal(get(obj, :chg_60, nothing)),
    )
end

struct BrokerHoldingDetailItem
    name::String
    parti_number::String
    ratio::BrokerHoldingChanges
    shares::BrokerHoldingChanges
    strong::Bool
end
StructTypes.StructType(::Type{BrokerHoldingDetailItem}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{BrokerHoldingDetailItem}, obj::JSON3.Object)
    BrokerHoldingDetailItem(
        String(get(obj, :name, "")),
        String(get(obj, :parti_number, "")),
        StructTypes.construct(BrokerHoldingChanges, obj.ratio),
        StructTypes.construct(BrokerHoldingChanges, obj.shares),
        Bool(get(obj, :strong, false)),
    )
end

struct BrokerHoldingDetail
    list::Vector{BrokerHoldingDetailItem}
    updated_at::String
end
StructTypes.StructType(::Type{BrokerHoldingDetail}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{BrokerHoldingDetail}, obj::JSON3.Object)
    items = if haskey(obj, :list) && !isnothing(obj.list)
        [StructTypes.construct(BrokerHoldingDetailItem, x) for x in obj.list]
    else
        BrokerHoldingDetailItem[]
    end
    BrokerHoldingDetail(items, String(get(obj, :updated_at, "")))
end

# ── broker_holding (daily) ─────────────────────────────────────────

struct BrokerHoldingDailyItem
    date::String
    holding::Union{Dec64,Nothing}
    ratio::Union{Dec64,Nothing}
    chg::Union{Dec64,Nothing}
end
StructTypes.StructType(::Type{BrokerHoldingDailyItem}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{BrokerHoldingDailyItem}, obj::JSON3.Object)
    BrokerHoldingDailyItem(
        String(get(obj, :date, "")),
        _parse_optional_decimal(get(obj, :holding, nothing)),
        _parse_optional_decimal(get(obj, :ratio, nothing)),
        _parse_optional_decimal(get(obj, :chg, nothing)),
    )
end

struct BrokerHoldingDailyHistory
    list::Vector{BrokerHoldingDailyItem}
end
StructTypes.StructType(::Type{BrokerHoldingDailyHistory}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{BrokerHoldingDailyHistory}, obj::JSON3.Object)
    items = if haskey(obj, :list) && !isnothing(obj.list)
        [StructTypes.construct(BrokerHoldingDailyItem, x) for x in obj.list]
    else
        BrokerHoldingDailyItem[]
    end
    BrokerHoldingDailyHistory(items)
end

# ── ah_premium ─────────────────────────────────────────────────────

"""
`ah_premium` / `ah_premium_intraday` 中价格类字段在 API 缺失时返回空串。
上游用 `decimal_empty_is_0`：空串视为 0。非数字占位符（如 `"--"`）一并视作 0。
"""
function _decimal_empty_is_zero(v)
    (isnothing(v) || (v isa AbstractString && isempty(v))) && return Dec64(0)
    v isa Number && return Dec64(v)
    try
        return parse(Dec64, String(v))
    catch
        return Dec64(0)
    end
end

struct AhPremiumKline
    aprice::Dec64
    apreclose::Dec64
    hprice::Dec64
    hpreclose::Dec64
    currency_rate::Dec64
    ahpremium_rate::Dec64
    price_spread::Dec64
    timestamp::DateTime           # 转换为 UTC+8 时间
end
StructTypes.StructType(::Type{AhPremiumKline}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{AhPremiumKline}, obj::JSON3.Object)
    AhPremiumKline(
        _decimal_empty_is_zero(get(obj, :aprice, "")),
        _decimal_empty_is_zero(get(obj, :apreclose, "")),
        _decimal_empty_is_zero(get(obj, :hprice, "")),
        _decimal_empty_is_zero(get(obj, :hpreclose, "")),
        _decimal_empty_is_zero(get(obj, :currency_rate, "")),
        _decimal_empty_is_zero(get(obj, :ahpremium_rate, "")),
        _decimal_empty_is_zero(get(obj, :price_spread, "")),
        to_china_time(
            obj.timestamp isa Number ? Int64(obj.timestamp) : String(obj.timestamp),
        ),
    )
end

struct AhPremiumKlines
    klines::Vector{AhPremiumKline}
end
StructTypes.StructType(::Type{AhPremiumKlines}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{AhPremiumKlines}, obj::JSON3.Object)
    items = if haskey(obj, :klines) && !isnothing(obj.klines)
        [StructTypes.construct(AhPremiumKline, x) for x in obj.klines]
    else
        AhPremiumKline[]
    end
    AhPremiumKlines(items)
end

# 上游 AhPremiumIntraday 的 JSON 字段名也叫 `klines`
struct AhPremiumIntraday
    klines::Vector{AhPremiumKline}
end
StructTypes.StructType(::Type{AhPremiumIntraday}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{AhPremiumIntraday}, obj::JSON3.Object)
    items = if haskey(obj, :klines) && !isnothing(obj.klines)
        [StructTypes.construct(AhPremiumKline, x) for x in obj.klines]
    else
        AhPremiumKline[]
    end
    AhPremiumIntraday(items)
end

# ── trade_stats ────────────────────────────────────────────────────

struct TradeStatistics
    avgprice::Dec64
    buy::Dec64
    neutral::Dec64
    preclose::Dec64
    sell::Dec64
    timestamp::String
    total_amount::Dec64
    trade_date::Vector{String}
    trades_count::String
end
StructTypes.StructType(::Type{TradeStatistics}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{TradeStatistics}, obj::JSON3.Object)
    dates = if haskey(obj, :trade_date) && !isnothing(obj.trade_date)
        String[String(d) for d in obj.trade_date]
    else
        String[]
    end
    TradeStatistics(
        _decimal_empty_is_zero(get(obj, :avgprice, "")),
        _decimal_empty_is_zero(get(obj, :buy, "")),
        _decimal_empty_is_zero(get(obj, :neutral, "")),
        _decimal_empty_is_zero(get(obj, :preclose, "")),
        _decimal_empty_is_zero(get(obj, :sell, "")),
        String(get(obj, :timestamp, "")),
        _decimal_empty_is_zero(get(obj, :total_amount, "")),
        dates,
        String(get(obj, :trades_count, "")),
    )
end

struct TradePriceLevel
    buy_amount::Dec64
    neutral_amount::Dec64
    price::Dec64
    sell_amount::Dec64
end
StructTypes.StructType(::Type{TradePriceLevel}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{TradePriceLevel}, obj::JSON3.Object)
    TradePriceLevel(
        _decimal_empty_is_zero(get(obj, :buy_amount, "")),
        _decimal_empty_is_zero(get(obj, :neutral_amount, "")),
        _decimal_empty_is_zero(get(obj, :price, "")),
        _decimal_empty_is_zero(get(obj, :sell_amount, "")),
    )
end

struct TradeStatsResponse
    statistics::TradeStatistics
    trades::Vector{TradePriceLevel}
end
StructTypes.StructType(::Type{TradeStatsResponse}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{TradeStatsResponse}, obj::JSON3.Object)
    trades = if haskey(obj, :trades) && !isnothing(obj.trades)
        [StructTypes.construct(TradePriceLevel, x) for x in obj.trades]
    else
        TradePriceLevel[]
    end
    TradeStatsResponse(StructTypes.construct(TradeStatistics, obj.statistics), trades)
end

# ── anomaly ────────────────────────────────────────────────────────

struct AnomalyItem
    symbol::String                     # 由 counter_id 转换
    name::String
    alert_name::String
    alert_time::Int64                  # 毫秒时间戳
    change_values::Vector{String}
    emotion::Int                       # 1=正向 2=负向
end
StructTypes.StructType(::Type{AnomalyItem}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{AnomalyItem}, obj::JSON3.Object)
    vals = if haskey(obj, :change_values) && !isnothing(obj.change_values)
        String[String(v) for v in obj.change_values]
    else
        String[]
    end
    AnomalyItem(
        counter_id_to_symbol(String(get(obj, :counter_id, ""))),
        String(get(obj, :name, "")),
        String(get(obj, :alert_name, "")),
        Int64(get(obj, :alert_time, 0)),
        vals,
        Int(get(obj, :emotion, 0)),
    )
end

struct AnomalyResponse
    all_off::Bool
    changes::Vector{AnomalyItem}
end
StructTypes.StructType(::Type{AnomalyResponse}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{AnomalyResponse}, obj::JSON3.Object)
    items = if haskey(obj, :changes) && !isnothing(obj.changes)
        [StructTypes.construct(AnomalyItem, x) for x in obj.changes]
    else
        AnomalyItem[]
    end
    AnomalyResponse(Bool(get(obj, :all_off, false)), items)
end

# ── constituent ────────────────────────────────────────────────────

struct ConstituentStock
    symbol::String
    name::String
    last_done::Union{Dec64,Nothing}
    prev_close::Union{Dec64,Nothing}
    inflow::Union{Dec64,Nothing}
    balance::Union{Dec64,Nothing}
    amount::Union{Dec64,Nothing}
    total_shares::Union{Dec64,Nothing}
    tags::Vector{String}
    intro::String
    market::String
    circulating_shares::Union{Dec64,Nothing}
    delay::Bool
    chg::Union{Dec64,Nothing}
    trade_status::Int
end
StructTypes.StructType(::Type{ConstituentStock}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{ConstituentStock}, obj::JSON3.Object)
    tags = if haskey(obj, :tags) && !isnothing(obj.tags)
        String[String(t) for t in obj.tags]
    else
        String[]
    end
    ConstituentStock(
        counter_id_to_symbol(String(get(obj, :counter_id, ""))),
        String(get(obj, :name, "")),
        _parse_optional_decimal(get(obj, :last_done, nothing)),
        _parse_optional_decimal(get(obj, :prev_close, nothing)),
        _parse_optional_decimal(get(obj, :inflow, nothing)),
        _parse_optional_decimal(get(obj, :balance, nothing)),
        _parse_optional_decimal(get(obj, :amount, nothing)),
        _parse_optional_decimal(get(obj, :total_shares, nothing)),
        tags,
        String(get(obj, :intro, "")),
        String(get(obj, :market, "")),
        _parse_optional_decimal(get(obj, :circulating_shares, nothing)),
        Bool(get(obj, :delay, false)),
        _parse_optional_decimal(get(obj, :chg, nothing)),
        Int(get(obj, :trade_status, 0)),
    )
end

struct IndexConstituents
    fall_num::Int
    flat_num::Int
    rise_num::Int
    stocks::Vector{ConstituentStock}
end
StructTypes.StructType(::Type{IndexConstituents}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{IndexConstituents}, obj::JSON3.Object)
    items = if haskey(obj, :stocks) && !isnothing(obj.stocks)
        [StructTypes.construct(ConstituentStock, x) for x in obj.stocks]
    else
        ConstituentStock[]
    end
    IndexConstituents(
        Int(get(obj, :fall_num, 0)),
        Int(get(obj, :flat_num, 0)),
        Int(get(obj, :rise_num, 0)),
        items,
    )
end

# ── top_movers ─────────────────────────────────────────────────────

"""
`top_movers` 事件中的证券信息。`symbol` 由 `counter_id` 转换。
"""
struct TopMoversStock
    symbol::String
    code::String
    name::String
    full_name::String
    change::String
    last_done::String
    market::String
    labels::Vector{String}
    logo::String
end
StructTypes.StructType(::Type{TopMoversStock}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{TopMoversStock}, obj::JSON3.Object)
    labels = if haskey(obj, :labels) && !isnothing(obj.labels)
        String[String(l) for l in obj.labels]
    else
        String[]
    end
    TopMoversStock(
        counter_id_to_symbol(String(get(obj, :counter_id, ""))),
        String(get(obj, :code, "")),
        String(get(obj, :name, "")),
        String(get(obj, :full_name, "")),
        String(get(obj, :change, "")),
        String(get(obj, :last_done, "")),
        String(get(obj, :market, "")),
        labels,
        String(get(obj, :logo, "")),
    )
end

"""
`top_movers` 事件单条记录。`timestamp` 从 unix 秒转 `DateTime` (UTC)。
"""
struct TopMoversEvent
    timestamp::DateTime
    alert_reason::String
    alert_type::Int64
    stock::TopMoversStock
    post::RawJSON
end
StructTypes.StructType(::Type{TopMoversEvent}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{TopMoversEvent}, obj::JSON3.Object)
    ts_raw = get(obj, :timestamp, 0)
    ts_int = ts_raw isa AbstractString ? parse(Int64, ts_raw) : Int64(ts_raw)
    stock_obj = get(obj, :stock, nothing)
    stock =
        stock_obj === nothing ? TopMoversStock("", "", "", "", "", "", "", String[], "") :
        StructTypes.construct(TopMoversStock, stock_obj)
    TopMoversEvent(
        unix2datetime(ts_int),
        String(get(obj, :alert_reason, "")),
        Int64(get(obj, :alert_type, 0)),
        stock,
        get(obj, :post, nothing),
    )
end

struct TopMoversResponse
    events::Vector{TopMoversEvent}
    next_params::RawJSON
end
StructTypes.StructType(::Type{TopMoversResponse}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{TopMoversResponse}, obj::JSON3.Object)
    events = if haskey(obj, :events) && !isnothing(obj.events)
        [StructTypes.construct(TopMoversEvent, x) for x in obj.events]
    else
        TopMoversEvent[]
    end
    TopMoversResponse(events, get(obj, :next_params, nothing))
end

# ── rank_categories ────────────────────────────────────────────────

"""
排行榜分类元数据。结构因 API 演进而变，原样保留 JSON。
"""
struct RankCategoriesResponse
    data::RawJSON
end
StructTypes.StructType(::Type{RankCategoriesResponse}) = StructTypes.CustomStruct()
StructTypes.construct(::Type{RankCategoriesResponse}, obj) = RankCategoriesResponse(obj)

# ── rank_list ──────────────────────────────────────────────────────

"""
排行榜单条记录。`symbol` 由 `counter_id` 转换；数值字段保留 API 原字符串。
"""
struct RankListItem
    symbol::String
    code::String
    name::String
    last_done::String
    chg::String
    change::String
    inflow::String
    market_cap::String
    industry::String
    pre_post_price::String
    pre_post_chg::String
    amplitude::String
    five_day_chg::String
    turnover_rate::String
    volume_rate::String
    pb_ttm::String
end
StructTypes.StructType(::Type{RankListItem}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{RankListItem}, obj::JSON3.Object)
    RankListItem(
        counter_id_to_symbol(String(get(obj, :counter_id, ""))),
        String(get(obj, :code, "")),
        String(get(obj, :name, "")),
        String(get(obj, :last_done, "")),
        String(get(obj, :chg, "")),
        String(get(obj, :change, "")),
        String(get(obj, :inflow, "")),
        String(get(obj, :market_cap, "")),
        String(get(obj, :industry, "")),
        String(get(obj, :pre_post_price, "")),
        String(get(obj, :pre_post_chg, "")),
        String(get(obj, :amplitude, "")),
        String(get(obj, :five_day_chg, "")),
        String(get(obj, :turnover_rate, "")),
        String(get(obj, :volume_rate, "")),
        String(get(obj, :pb_ttm, "")),
    )
end

struct RankListResponse
    bmp::Bool
    lists::Vector{RankListItem}
end
StructTypes.StructType(::Type{RankListResponse}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{RankListResponse}, obj::JSON3.Object)
    items = if haskey(obj, :lists) && !isnothing(obj.lists)
        [StructTypes.construct(RankListItem, x) for x in obj.lists]
    else
        RankListItem[]
    end
    RankListResponse(Bool(get(obj, :bmp, false)), items)
end

end # module MarketProtocol
