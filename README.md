[English](./README.md) | [中文](./README.zh-CN.md)

# Julia SDK for LongBridge API
This is an unofficial SDK, currently for personal use only. Some functions in the Trade module have not been tested yet. Issues are welcome.

## Release Notes
See [NEWS.md](NEWS.md) for detailed release notes.

Latest release: **v0.12.0** — sync with upstream openapi v5.2.1: time-condition orders and HTTP quote transport.

### v0.12.0 highlights

- **HTTP quote pulls:** use `Config.from_oauth(oauth; quote_transport=QuoteTransport.Http)` or `Config.Settings(...; quote_transport=QuoteTransport.Http)`. Alternatively set `LONGBRIDGE_QUOTE_TRANSPORT=http` before constructing the config, or add `quote_transport = "http"` to TOML. The default is `ws`; explicit configuration wins over the environment. Pull-only usage opens no WebSocket; subscriptions and quote-profile queries connect on demand. Realtime getters still read the push cache. `enable_overnight=false` (also read from TOML) applies over HTTP, including bounded K-line refill after filtering overnight bars.
- **Time-condition orders:** set `delayed_until=now(Dates.UTC)+Hour(1)` in `SubmitOrderOptions` or `SubmitMultiLegOrderOptions`. The server holds the order in `OrderStatus.DelayedNotReported` until then. The time must be in the future and within 90 days; multi-leg time conditions only support LO / MO. Validation is server-side, as upstream.
- **Replace / readback:** set `ReplaceOrderOptions.delayed_until` to reschedule, or `clear_delayed_until=true` to remove the condition (clear wins if both are set). Omit both to keep it unchanged. Read `order_detail(ctx, id).delayed_until` or the `Delayed Until` order-list column. Request `DateTime`s are **UTC**; readback follows existing trade timestamps (**UTC+8**, `nothing` when unset).

HTTP gateway errors/data can differ from WebSocket results. See [NEWS.md](NEWS.md) for transport caveats, test coverage, and earlier release notes.

### v0.12.0 migration notes

- Existing keyword-based order options remain valid. Positional constructors for order options, `Order`, and `OrderDetail` must include the new trailing fields (`nothing` / `false` when unset).
- Order-list DataFrames append `Delayed Until`; status handling should recognize `DelayedNotReported`. Clearing a time condition is **not cancellation**: a regular order may be reported immediately. Do not reuse UTC+8 readback dates in UTC requests without subtracting `Hour(8)`.
- HTTP.jl **2.8 or later within major version 2** is required. The default quote transport remains WebSocket; `QuoteTransport` does not affect trade transport.

References:

1. [Official Documentation](https://open.longbridge.com/docs)

2. [OpenAPI SDK Base](https://github.com/longbridge/openapi)

## Quick Start

### Installation

```julia
using Pkg
Pkg.add(url="https://github.com/rzhli/LongBridge.jl")
```

### Authentication

LongBridge supports two authentication methods:

#### 1. OAuth 2.0 (Recommended)

OAuth 2.0 uses Bearer tokens without requiring HMAC signatures. Tokens are persisted locally and refreshed automatically.

**Step 1: Register an OAuth client**

```bash
curl -X POST https://openapi.longbridgeapp.com/oauth2/register \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "My Application",
    "redirect_uris": ["http://localhost:60355/callback"],
    "grant_types": ["authorization_code", "refresh_token"]
  }'
```

**Step 2: Build OAuth handle and create config**

```julia
using LongBridge

oauth = OAuthBuilder("your-client-id") |> build(url -> run(`xdg-open $url`))
cfg = Config.from_oauth(oauth)
```

On first run, this opens the browser for authorization. Subsequent runs use the cached token automatically.

#### 2. API Key (Legacy)

Create a `config.toml` file:

```toml
# Required
app_key = "your_app_key"
app_secret = "your_app_secret"
access_token = "your_access_token"
token_expire_time = "2025-07-22T00:00:00"  # ISO8601 format, UTC time

# Optional (uses China endpoints by default)
# http_url = "https://openapi.longportapp.com"
# quote_ws_url = "wss://openapi-quote.longportapp.com"
# trade_ws_url = "wss://openapi-trade.longportapp.com"
# enable_papertrading = false
# quote_transport = "http"  # optional; "ws" by default, or LONGBRIDGE_QUOTE_TRANSPORT
# enable_overnight = false  # optional; true by default in this Julia SDK
```

```julia
using LongBridge

cfg = Config.from_toml()
```

Credentials prefixed with `us_` automatically use the US data center. To route
requests to a paper-trading account, set `enable_papertrading = true` in TOML or
call `enable_papertrading!(cfg)` before creating a context. US-only endpoints,
such as `us_company_overview`, `us_crypto_overview`, `us_query_orders`, and
`us_asset_overview`, reject non-US credentials with a clear error.

### Quotes

Set `quote_transport = "http"` in TOML or use
`Config.from_oauth(oauth; quote_transport=QuoteTransport.Http, enable_overnight=false)`
to pull over HTTP without opening a WebSocket. Do not query `member_id`,
`quote_level`, or other quote-profile fields if you want HTTP-only usage: profile
queries and subscriptions connect to WS on demand. `realtime_*` still reads the
push cache, not HTTP snapshots.

```julia
using LongBridge

cfg = Config.from_toml()

# Create QuoteContext (connects eagerly only with the default WS transport)
ctx = QuoteContext(cfg)

# Get basic static information for securities
resp = static_info(ctx, ["700.HK", "AAPL.US", "TSLA.US"])

# Get real-time quotes for securities (one-shot server snapshot)
quotes = quote_snapshot(ctx, ["GOOGL.US", "AAPL.US", "TSLA.US"])

# Get real-time option quotes
resp = option_quote(ctx, ["AAPL230317P160000.US"])

# Get real-time warrant quotes
resp = warrant_quote(ctx, ["14993.HK", "66642.HK"])

# Get market depth for a security
resp = depth(ctx, "700.HK")

# Get candlestick data
candlesticks_data = candlesticks(ctx, "GOOGL.US", CandlePeriod.SIXTY_MINUTE, 365)

# Get trade details for a security
trades_data = trades(ctx, "AAPL.US", 10)

# Get intraday data for a security
intraday_data = intraday(ctx, "700.HK")

# Get historical K-line data
using Dates
history_data = history_candlesticks_by_date(
    ctx, "700.HK", CandlePeriod.DAY, AdjustType.NO_ADJUST; start_date=Date(2023, 1, 1), end_date=Date(2023, 2, 1)
)

# Candlestick timestamps are UTC-semantic DateTime values. To retain the raw
# Unix seconds alongside the converted column:
history_data = history_candlesticks_by_date(
    ctx, "COHR.US", CandlePeriod.ONE_MINUTE, AdjustType.NO_ADJUST;
    start_date=Date(2026, 6, 17), end_date=Date(2026, 6, 18),
    include_timestamp_unix=true,
)

# Optional timezone-aware display (install TimeZones.jl once if needed):
# using Pkg; Pkg.add("TimeZones")
# using TimeZones
# to_market_time(history_data.timestamp[1], "America/New_York")

# Get the list of expiry dates for an option chain
expiry_dates = option_chain_expiry_date_list(ctx, "AAPL.US")

# Get trading days for a market
trading_days_df = trading_days(ctx, Market.HK, Date(2025, 8, 1), Date(2025, 8, 30))

# Get capital flow for a security
capital_flow_data = capital_flow(ctx, "700.HK")

# Get market temperature
temp = market_temperature(ctx, Market.US)

# Get historical market temperature
history_temp = history_market_temperature(ctx, Market.US, Date(2025, 7, 1), Date(2025, 7, 31))

# Disconnect
disconnect!(ctx)
```

`close(ctx)` is equivalent. Context finalizers perform best-effort automatic
cleanup, but call `close` or `disconnect!` explicitly when deterministic
connection teardown matters.

### Trading

```julia
using LongBridge, Dates

cfg = Config.from_toml()

# Create and connect to TradeContext
ctx = TradeContext(cfg)

# Get account balance
resp = account_balance(ctx)

# Get stock positions (optionally filter by symbol)
resp = stock_positions(ctx)
resp = stock_positions(ctx; symbol = "700.HK")

# Get today's orders
resp = today_orders(ctx)

# Get historical orders (date range via keyword args)
resp = history_orders(ctx; start_at = Date(2024, 1, 1), end_at = Date(2024, 2, 1))

# Get today's executions
resp = today_executions(ctx)

# Get historical executions
resp = history_executions(ctx; start_at = Date(2024, 1, 1), end_at = Date(2024, 2, 1))

# Submit an order via SubmitOrderOptions
resp = submit_order(
    ctx, SubmitOrderOptions(
        symbol = "700.HK",
        order_type = OrderType.LO,
        side = OrderSide.Buy,
        submitted_quantity = 100,
        time_in_force = TimeInForceType.Day,
        submitted_price = 300.0,
    )
)

# Modify an order
resp = replace_order(
    ctx, ReplaceOrderOptions(
        order_id = "709043056541253632",
        submitted_quantity = 100,
        submitted_price = 301.0,
    )
)

# Cancel an order
resp = cancel_order(ctx, "709043056541253632")

# Disconnect
disconnect!(ctx)
```

### Time-condition Orders

Constructing options does not place an order. The write calls below are commented
out; review the account, price, quantity and trading hours before using them.
Compute the future UTC time immediately before submitting.

```julia
using LongBridge, Dates

options = SubmitOrderOptions(
    symbol = "700.HK", order_type = OrderType.LO, side = OrderSide.Buy,
    submitted_quantity = 100, time_in_force = TimeInForceType.Day,
    submitted_price = 300.0, delayed_until = now(Dates.UTC) + Hour(1),
)
# submitted = submit_order(trade_ctx, options)

# Reschedule; use the actual order ID and quantity:
# replace_order(trade_ctx, ReplaceOrderOptions(
#     order_id = "<order-id>", submitted_quantity = 100,
#     delayed_until = now(Dates.UTC) + Hour(2),
# ))
# OR clear the condition (not a cancellation; may submit immediately):
# replace_order(trade_ctx, ReplaceOrderOptions(
#     order_id = "<order-id>", submitted_quantity = 100, clear_delayed_until = true,
# ))

# Read-only examples with an existing TradeContext:
# pending = today_orders(trade_ctx; status = [OrderStatus.DelayedNotReported])
# pending[:, ["Order ID", "Status", "Delayed Until"]]  # UTC+8, nothing when unset
# detail = order_detail(trade_ctx, "<order-id>")
# detail.delayed_until  # UTC+8; subtract Hour(8) before reusing in a UTC request
```

For multi-leg orders, explicitly import
`using LongBridge.TradeProtocol: SubmitMultiLegOrderOptions, SubmitMultiLegOrderLeg, MultiLegStrategy`
and pass `delayed_until` in `SubmitMultiLegOrderOptions`. Time conditions support
only `LO` / `MO` for multi-leg orders. Choose valid, unexpired contracts. All time
conditions must be later than now and at most 90 days ahead (server validation).

### Real-time Quote Subscription

```julia
# 1. Define a callback function
function on_quote_callback(symbol::String, event::PushQuote)
    println(symbol, event)
end

# 2. Set the callback
set_on_quote(ctx, on_quote_callback)

# 3. Subscribe to quotes (can choose different types: QUOTE, DEPTH, BROKERS, TRADE)
Quote.subscribe(ctx, ["GOOGL.US"], [SubType.DEPTH]; is_first_push=true)

# 4. Unsubscribe from quotes
Quote.unsubscribe(ctx, ["GOOGL.US"], [SubType.QUOTE, SubType.DEPTH])
```

## API Overview

### Context Management
- `Config.from_toml()`: Load configuration from `config.toml` file
- `Config.from_oauth(oauth_handle)`: Create configuration from an OAuth handle
- `OAuthBuilder(client_id) |> build(open_url_fn)`: Build an OAuth handle with browser-based authorization
- `QuoteContext(config)`: Create a quote context; HTTP pulls are socket-free, while WS-only operations connect on demand in HTTP mode
- `TradeContext(config)`: Create and connect to `TradeContext`
- `disconnect!(ctx)` / `close(ctx)`: Disconnect and stop the Context background tasks

### Quote Fetching
- `static_info(ctx, symbols)`: Get basic static information for securities
- `quote_snapshot(ctx, symbols)`: Get a one-shot snapshot of real-time stock quotes (server query)
- `realtime_quote(ctx, symbol_or_symbols)`: Read the latest pushed quote from the local cache (requires prior `subscribe`)
- `option_quote(ctx, symbols)`: Get real-time option quotes
- `warrant_quote(ctx, symbols)`: Get real-time warrant quotes
- `depth(ctx, symbol)`: Get market depth data for a security
- `brokers(ctx, symbol)`: Get broker queue for a security
- `participants(ctx)`: Get a list of broker seat IDs
- `trades(ctx, symbol, count)`: Get trade details for a security
- `intraday(ctx, symbol)`: Get intraday data for a security
- `history_candlesticks_by_date(ctx, ...)`: Get historical K-line data by date
- `option_chain_expiry_date_list(ctx, symbol)`: Get a list of expiry dates for an option chain
- `warrant_issuers(ctx)`: Get a list of warrant issuer IDs
- `warrant_list(ctx, ...)`: Get a filtered list of warrants
- `trading_session(ctx)`: Get the trading session for each market for the current day
- `trading_days(ctx, market, start_date, end_date)`: Get trading days for a market
- `capital_flow(ctx, symbol)`: Get capital flow for a security for the current day
- `capital_distribution(ctx, symbol)`: Get capital distribution for a security for the current day
- `candlesticks(ctx, symbol, period, count)`: Get candlestick data
- `history_candlesticks_by_offset(ctx, ...)`: Get historical K-line data by offset
- `option_chain_info_by_date(ctx, symbol, expiry_date; standard_only=false)`: Get the option chain contracts for a specific expiry date (returns `Vector{OptionChainContract}`; filter on `direction`)
- `subscriptions(ctx)`: Query currently subscribed securities
- `calc_indexes(ctx, symbols)`: Get calculated indexes
- `market_temperature(ctx, market)`: Get market temperature
- `history_market_temperature(ctx, market, start_date, end_date)`: Get historical market temperature
- `security_list(ctx, market, category)`: Get a list of securities

### Real-time Quote Subscription
- `set_on_quote(ctx, callback)`: Set the callback function for quote pushes
- `set_on_depth(ctx, callback)`: Set the callback function for market depth pushes
- `set_on_brokers(ctx, callback)`: Set the callback function for broker queue pushes
- `set_on_trades(ctx, callback)`: Set the callback function for trade detail pushes
- `set_on_candlestick(ctx, callback)`: Set the callback function for candlestick pushes
- `subscribe(ctx, symbols, sub_types)`: Subscribe to quotes
- `unsubscribe(ctx, symbols, sub_types)`: Unsubscribe from quotes

### Realtime Data Access (Local Cache)
- `realtime_depth(ctx, symbol)`: Get cached depth data for subscribed symbol
- `realtime_brokers(ctx, symbol)`: Get cached broker queue for subscribed symbol
- `realtime_trades(ctx, symbol; count)`: Get cached trades for subscribed symbol
- `realtime_candlesticks(ctx, symbol, period; count)`: Get cached K-line data

### Candlestick Subscription
- `subscribe_candlesticks(ctx, symbol, period; count)`: Subscribe and get initial K-line data
- `unsubscribe_candlesticks(ctx, symbol, period)`: Unsubscribe and clear cached data

### Watchlist Management
- `create_watchlist_group(ctx, name; securities)`: Create a watchlist group
- `watchlist(ctx)`: View watchlist groups
- `delete_watchlist_group(ctx, group_id, with_securities)`: Delete a watchlist
- `update_watchlist_group(ctx, group_id; name, securities, mode)`: Update a watchlist group

### Trading
- `account_balance(ctx)`: Get account balance
- `stock_positions(ctx; symbol)`: Get stock positions (optional symbol filter)
- `fund_positions(ctx)`: Get fund positions
- `today_orders(ctx; symbol, status, side)`: Get today's orders
- `history_orders(ctx; symbol, status, side, start_at, end_at)`: Get historical orders
- `today_executions(ctx; symbol)`: Get today's executions
- `history_executions(ctx; symbol, start_at, end_at)`: Get all historical executions (auto-paged, returns `Vector{Execution}`)
- `all_executions(ctx; symbol, order_id, start_at, end_at, page)`: Get all executions (`AllExecutionsResponse`)
- `order_detail(ctx, order_id)`: Get order detail (includes `multi_leg` for combination orders and optional `delayed_until`)
- `submit_order(ctx, ::SubmitOrderOptions)`: Submit an order; optional `delayed_until` schedules server-side submission
- `submit_multileg(ctx, ::SubmitMultiLegOrderOptions)`: Submit a multi-leg option combination order; time conditions require LO / MO
- `replace_order(ctx, ::ReplaceOrderOptions)`: Modify an order; reschedule with `delayed_until` or remove the time condition with `clear_delayed_until=true`
- `cancel_order(ctx, order_id)`: Cancel an order
- `estimate_max_purchase_quantity(ctx, ::EstimateMaxPurchaseQuantityOptions)`: Estimate max purchase quantity
- `cash_flow(ctx; start_at, end_at)`: Get cash flow records
- `margin_ratio(ctx, symbol)`: Get margin ratio for a security
- `set_on_order_changed(ctx, callback)`: Set the callback function for order status change pushes
- `Trade.subscribe(ctx, topics::Vector{TopicType.T})`: Subscribe to trade pushes (e.g. `[TopicType.Private]`)
- `Trade.unsubscribe(ctx, topics::Vector{TopicType.T})`: Unsubscribe from trade pushes

### Fundamental Data (`FundamentalContext`)
- `FundamentalContext(config)`: Create context (HTTP-only, no disconnect needed)
- `financial_report(ctx, symbol; kind, period)`: Full financial statements (IS/BS/CF/All)
- `institution_rating(ctx, symbol)`: Analyst ratings (latest + summary, parallel fan-out)
- `institution_rating_detail(ctx, symbol)`: Historical rating distribution
- `dividend(ctx, symbol)` / `dividend_detail(ctx, symbol)`: Dividend history / details
- `forecast_eps(ctx, symbol)`: Analyst EPS forecasts
- `consensus(ctx, symbol)`: Revenue / profit / EPS consensus vs actual
- `valuation(ctx, symbol)` / `valuation_history(ctx, symbol)`: PE/PB/PS/dividend yield
- `industry_valuation(ctx, symbol)` / `industry_valuation_dist(ctx, symbol)`: Peer comparison
- `company(ctx, symbol)` / `executive(ctx, symbol)` / `shareholder(ctx, symbol)` / `fund_holder(ctx, symbol)`
- `corp_action(ctx, symbol)`: Corporate actions (dividends, splits, buybacks)
- `invest_relation(ctx, symbol)`, `operating(ctx, symbol)`, `buyback(ctx, symbol)`, `ratings(ctx, symbol)`

### Market Data (`MarketContext`)
- `market_status(ctx)`: Market open/close status across regions; status fields use `MarketTradeStatus`
- `broker_holding(ctx, symbol, period)` / `broker_holding_detail(ctx, symbol)` / `broker_holding_daily(ctx, symbol, broker_id)`
- `ah_premium(ctx, symbol, period, count)` / `ah_premium_intraday(ctx, symbol)`: A/H premium klines & intraday
- `trade_stats(ctx, symbol)`: Buy/sell/neutral trade statistics
- `anomaly(ctx, market)`: Market anomaly events
- `constituent(ctx, symbol)`: Index constituents (e.g. `"HSI.HK"`)

### Calendar (`CalendarContext`)
- `finance_calendar(ctx, category, start, end_; market, count, offset, next)`: Financial calendar events; `count` sets the page size, `offset` skips events, and `next` is `CalendarPageDirection.Later` / `Earlier`
  - `CalendarEventsResponse.next_date`: pass `Date(page.next_date)` as the next `start` with the same `end_`; stop when the cursor is empty
  - `CalendarCategory`: `Report` / `Dividend` / `Split` / `Ipo` / `MacroData` / `Closed` / `Meeting` / `Merge`

### Mutual Funds (`FundContext`, new in v0.11.0)

Create `fund_ctx = FundContext(cfg)`. All 28 methods are synchronous HTTP calls. Pass a full `counter_id` from `funds` or `fund_positions`, e.g. `"UT/FD/HK0000384492"`.

| Area | Methods |
| --- | --- |
| Catalog | `hot_funds`, `funds`, `fund_filters`, `fund_detail` |
| Analysis | `fund_analysis`, `fund_analysis_detail`, `fund_trend`, `fund_performance_comparison` |
| Returns | `fund_annual_returns`, `fund_quarterly_returns`, `fund_performance` |
| NAV and holdings | `fund_nav`, `fund_nav_history`, `fund_nav_range`, `fund_holdings`, `fund_stock_holdings` |
| Account positions | `fund_positions`, `fund_position`, `fund_position_performance`, `fund_position_profits`, `fund_position_nav`, `fund_position_dividends` |
| Orders | `fund_orders`, `fund_order`, `fund_transactions`, `fund_validate_order`, `fund_submit_order`, `fund_cancel_order` |

```julia
fund_ctx = FundContext(cfg)
catalog = funds(fund_ctx, GetFundsOptions())
if !isempty(catalog)
    counter_id = first(catalog).counter_id
    nav = fund_nav(fund_ctx, counter_id)  # Vector{FundNavValue}
    history = fund_nav_history(fund_ctx, counter_id, FundPageOptions(page=1, size=20))
end
positions = fund_positions(fund_ctx, FundPositionsOptions())  # FundPositions
orders = fund_orders(fund_ctx, GetFundOrdersOptions(page=1, size=20))
```

Optional settings use positional keyword-constructed option structs, as in the examples. Date-range option fields use `end_` (sent as `end`). Monetary values remain strings; timestamps and order IDs are `Int64`. Dynamic JSON fields remain decoded objects/arrays. `asset_allocation`, `contrast_performances` on `FundTrend`, `detail_values`, and `order` on `FundOrderDetail` may be `nothing`.

The fund-channel holding type is `FundHoldingPosition` and its overview options are `FundPositionsOptions`. The existing trade holding remains `TradeProtocol.FundPosition`; `fund_positions(::TradeContext; symbol=...)` still uses its existing endpoint and filter. Submission requires `SubmitFundOrderOptions(counter_id=..., action="buy", currency="USD", amount="100.00")`; cancellation takes the returned numeric order ID. Commented order examples are in `trade_test.jl`.

### Portfolio Analytics (`PortfolioContext`)
- `exchange_rate(ctx)`: Current rates for all supported currencies
- `profit_analysis(ctx; start, end_)`: Account P&L (summary + sublist parallel fan-out)
- `profit_analysis_by_market(ctx; page, size, market, ...)`: Paginated by market
- `profit_analysis_detail(ctx, symbol; ...)`: Per-security P&L breakdown
- `profit_analysis_flows(ctx, symbol; page, size, derivative, ...)`: Per-security flows

### Price Alerts (`AlertContext`)
- `list_alerts(ctx)`: List all alerts grouped by security
- `add_alert(ctx, symbol, condition, trigger_value, frequency)`: Add alert
  - `AlertCondition`: `PriceRise` / `PriceFall` / `PercentRise` / `PercentFall`
  - `AlertFrequency`: `Daily` / `EveryTime` / `Once`
- `update_alert(ctx, item::AlertItem)`: Update alert (toggle enabled etc.)
- `delete_alerts(ctx, ids::Vector{String})`: Delete alerts

### Community Sharelists (`SharelistContext`)
- `list_sharelists(ctx; count)` / `popular_sharelists(ctx; count)` / `sharelist_detail(ctx, id)`
- `create_sharelist(ctx, name; description)` / `delete_sharelist(ctx, id)`
- `add_sharelist_securities(ctx, id, symbols)` / `remove_sharelist_securities(ctx, id, symbols)` / `sort_sharelist_securities(ctx, id, symbols)`

### DCA Plans (`DCAContext`)
- `list_dca(ctx; status, symbol)` / `dca_stats(ctx; symbol)`
- `create_dca(ctx, symbol, amount, frequency; day_of_week, day_of_month, allow_margin)`
  - `DCAFrequency`: `Daily` / `Weekly` / `Fortnightly` / `Monthly`
  - `DCAStatus`: `Active` / `Suspended` / `Finished`
- `update_dca(ctx, plan_id; amount, frequency, ...)`
- `pause_dca(ctx, plan_id)` / `resume_dca(ctx, plan_id)` / `stop_dca(ctx, plan_id)`
- `dca_history(ctx, plan_id; page, limit)` / `dca_check_support(ctx, symbols)` / `dca_calc_date(ctx, symbol, frequency; ...)` / `dca_set_reminder(ctx, hours)`

### Community Content (`ContentContext`)
- `news(ctx, symbol)`: News for a security
- `topics_by_symbol(ctx, symbol)` / `topic_detail(ctx, id)` / `topic_replies(ctx, topic_id; page, size)`
- `my_topics(ctx; page, size, topic_type)`: List topics you've published
- `create_topic(ctx, title, body; topic_type, tickers, hashtags)`: Publish a topic, returns ID
- `create_topic_reply(ctx, topic_id, body; reply_to_id)`: Post a reply (plain text)

### Option Volume and Pinned Securities (`QuoteContext`)
- `option_volume(ctx, symbol)` / `option_volume_daily(ctx, symbol, timestamp, count)`: Option volume stats
- `update_pinned(ctx, mode::PinnedMode.T, symbols)`: Pin/unpin watchlist securities

### Quote Snapshots and Profiles (`QuoteContext`)
- `quote_snapshot(ctx, symbols)`: One-shot quote snapshot via WebSocket
- `realtime_quote(ctx, symbol_or_symbols)`: Read latest pushed quote from local cache (subscribe first); aligned with `realtime_depth/brokers/trades`
- `filings(ctx, symbol)`: Company filings list (REST `/v1/quote/filings`), returns `Vector{FilingItem}`
- `member_id(ctx)` / `quote_level(ctx)` / `quote_package_details(ctx)`: Account profile values retrieved through `QueryUserQuoteProfile` on connect
- `subscribe_limit(ctx)` / `history_candlestick_limit(ctx)`: Account limits reported by `QueryUserQuoteProfile`; return `nothing` until the profile has loaded

Historical candlestick `timestamp` columns are timezone-naive `DateTime` values
with UTC semantics. Use `utc_iso8601` to render an explicit `Z` suffix, or load
TimeZones.jl and call `to_market_time(timestamp, "America/New_York")` for a
market-local representation. `include_timestamp_unix=true` adds the original
Unix-seconds value as `timestamp_unix` without changing the default columns.

### Account Statements (`AssetContext`)
- `AssetContext(config)`: Create context (HTTP-only, no disconnect needed)
- `statements(ctx, type::StatementType.T; page, page_size)`: Paginated list of statement records (`type` = `Daily` / `Monthly`)
- `statement_download_url(ctx, file_key)`: Resolve a statement record's download URL

### Stock Screener (`ScreenerContext`)
- `ScreenerContext(config)`: Create context (HTTP-only, no disconnect needed)
- `screener_recommend_strategies(ctx, market)`: Preset built-in screener strategies for a market (e.g. `"US"`/`"HK"`)
- `screener_user_strategies(ctx, market)`: Current user's saved screener strategies for a market
- `screener_strategy(ctx, id)`: Detail of one strategy (path-param id); `filter_` prefix is stripped from filter keys
- `screener_search(ctx, market; strategy_id=nothing, conditions=ScreenerCondition[], show=String[], page=0, size=20)`:
  Mode A (when `strategy_id` is given — fetches strategy and forwards filters) or Mode B (typed `ScreenerCondition` objects). `DEFAULT_RETURNS` always included; `filter_` prefix is stripped from response indicator keys.
- `screener_indicators(ctx)`: Available indicator definitions; `filter_` prefix stripped + `tech_values` rebuilt from `tech_indicators`

### Fundamental (`FundamentalContext`)
- `business_segments(ctx, symbol)`: Latest business segment revenue breakdown
- `business_segments_history(ctx, symbol; report, cate)`: Historical business + regional segment snapshots
- `institution_rating_views(ctx, symbol)`: Historical analyst rating distribution time series
- `industry_rank(ctx, market, indicator, sort_type, limit)`: Industry rank in a market
- `industry_peers(ctx, counter_or_symbol, market; industry_id)`: Recursive industry peer chain
- `financial_report_snapshot(ctx, symbol; report, fiscal_year, fiscal_period)`: Earnings snapshot (actual vs estimate, key ratios)
- `shareholder_top(ctx, symbol)`: Top-shareholder ranking (raw JSON)
- `shareholder_detail(ctx, symbol, object_id)`: Holding history for one shareholder object (raw JSON)
- `valuation_comparison(ctx, symbol, currency; comparison_symbols)`: Valuation comparison (PE/PB/PS) with historical curve
- `etf_asset_allocation(ctx, symbol)`: ETF asset allocation (holdings / regional / asset class / industry groups)
- `macroeconomic_indicators(ctx; country, keyword, offset, limit)`: List macroeconomic indicators, optional `MacroeconomicCountry` and fuzzy keyword filters
- `macroeconomic(ctx, id; start_date, end_date, offset, limit, sort)`: Historical data for one macroeconomic indicator, newest-first by default

### Market (`MarketContext`)
- `top_movers(ctx, markets, sort, limit; date)`: Top movers across one or more markets
- `rank_categories(ctx)`: Available rank category keys/labels (raw JSON)
- `rank_list(ctx, key; need_article)`: Ranked securities for one category

### Quote (`QuoteContext`)
- `short_positions(ctx, symbol; count=20)`: HK/US short-position data with `ShortPositionsItem` entries and UTC `DateTime` timestamps.
- `short_trades(ctx, symbol; count=20)`: HK/US short-trade records, endpoint auto-selected by `.HK` suffix.

### Strategy Signals (`SignalContext`)
- `SignalContext(config)`: Create context (HTTP-only, no disconnect needed)
- `signals(ctx, ::SignalsOptions)`: Query signals, filtered by symbol/strategy/catalyst/time, paged with `limit`/`offset`
- `signal(ctx, signal_id)`: One signal including the full analysis in `json_data`
- `security_facts(ctx, ::SecurityFactsOptions)`: A security's catalyst-fact events (anomaly detections, factor readings, sources, NL summaries)

### Grid Trading (`GridContext`)
- `GridContext(config)`: Create context (HTTP-only, no disconnect needed)
- `grid_submit(ctx, ::SubmitGridOrderOptions)`: Submit a grid order
- `grid_replace(ctx, ::ReplaceGridOrderOptions)`: Modify a grid order
- `grid_list(ctx, GetGridOrdersOptions(; page, limit, market, status, symbol, sort_by, sort_order))`: List grid orders
- `grid_list_by_ids(ctx, ::GetGridOrdersByIdsOptions)`: List grid orders by IDs
- `grid_detail(ctx, ::GetGridOrderDetailOptions)`: Grid order detail
- `grid_trigger_history(ctx, ::GetGridTriggerHistoryOptions)`: Grid trigger history
- `grid_cancel` / `grid_suspend` / `grid_restart(ctx, order_id)`: Cancel / suspend / restart a grid order
- `grid_symbol_info(ctx, symbol)`: Grid symbol info

## License

MIT License
