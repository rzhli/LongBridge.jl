# Release Notes

# Release Notes

## v0.6.0 (2026-05-18)

### New Features — 移植上游 LongPort SDK v4.1.0 的 9 个新 Context（共 70 个新方法、~5,100 行）

P0（HTTP-only 只读分析，4 个 Context + QuoteContext 扩展）：

- **`FundamentalContext`** — 20 个方法：财报、分析师评级、股息、EPS 预测、一致预期、估值、行业对比、公司概况、高管、股东、基金持仓、公司行动、回购、多维度评级
- **`MarketContext`** — 9 个方法：市场状态、券商持仓（top/明细/日度）、A/H 溢价（K 线/分时）、成交统计、异动、指数成份股
- **`CalendarContext`** — `finance_calendar` 支持 8 种事件类别（财报/分红/拆股/IPO/宏观/休市/会议/合并）
- **`PortfolioContext`** — 5 个方法：汇率、盈亏分析（总览 + 按市场 + 单只明细 + 流水）
- **`QuoteContext`** — 4 个新方法：`short_positions`、`option_volume`、`option_volume_daily`、`update_pinned`

P1（社区/计划管理，4 个 Context）：

- **`AlertContext`** — 4 个方法：价格提醒 CRUD（`list_alerts`/`add_alert`/`update_alert`/`delete_alerts`）
- **`SharelistContext`** — 8 个方法：社区自选股列表（`list_sharelists`/`sharelist_detail`/`popular_sharelists`/`create_sharelist`/`delete_sharelist`/`add_sharelist_securities`/`remove_sharelist_securities`/`sort_sharelist_securities`）
- **`DCAContext`** — 12 个方法：定投全生命周期（`list_dca`/`create_dca`/`update_dca`/`pause_dca`/`resume_dca`/`stop_dca`/`dca_history`/`dca_stats`/`dca_check_support`/`dca_calc_date`/`dca_set_reminder`）
- **`ContentContext`** — 7 个方法：社区话题与资讯（`my_topics`/`create_topic`/`topics_by_symbol`/`topic_detail`/`topic_replies`/`create_topic_reply`/`news`）

### Architecture

- **HTTP-only Context 不用 actor pattern** — 新 Context 都是简单的 `struct X; config::Settings; end`，直接调 `Client.http_get/post/put/delete`。`institution_rating` / `profit_analysis` 用 `Threads.@spawn` 真并行 fan-out 调用两个端点。
- **typed enums via `EnumX.@enumx`** — 所有 API 参数都是类型安全的（`FinancialReportKind`、`CalendarCategory`、`AlertCondition`、`DCAFrequency` 等共 14 个新枚举）。
- **`DecFP.Dec64` 用于货币/价格/比率字段** — 匹配上游 `rust_decimal::Decimal`，避免 Float64 在分红/盈亏计算的精度问题。`_parse_optional_decimal` 对 `""`、`null`、`"--"` 等占位符统一返回 `nothing`。
- **`MarketCtx/` 文件夹（类型名仍叫 `MarketContext`）** — 避免与 `Constant.Market` 枚举命名冲突。
- **`Client.http_delete` 支持 body** — Alert/Sharelist 的 DELETE 接口需要 JSON body。
- **方法命名加前缀避免顶层冲突** — `list_alerts`/`list_sharelists`/`list_dca` 等（Rust 用方法绑定可全叫 `list`，Julia 顶层导出需要消歧）。

### New Utilities (`Core/Utils.jl`)

- `Dec64` 重导出（无需 `using DecFP`）
- `symbol_to_counter_id("TSLA.US") → "ST/US/TSLA"`（含 4574 行嵌入式美股 ETF 表，懒加载）
- `index_symbol_to_counter_id("HSI.HK") → "IX/HK/HSI"`
- `counter_id_to_symbol("ST/HK/700") → "700.HK"`
- `_parse_optional_decimal` 容错占位符

### Dependencies

- 新增 `DecFP = "1"`

### Tests

- 烟测覆盖 240 项：构造、JSON 反序列化、枚举映射、占位符容错；联机端到端测试通过 `examples/p0_analytics.jl` 与 `examples/p1_community.jl` 手验。

### Examples

- 新增 `examples/p0_analytics.jl` — 4 个新 Context 的全部代表性调用
- 新增 `examples/p1_community.jl` — 价格提醒 / 自选股 / 定投 / 社区 的全套用法（写操作默认注释掉）

## v0.5.2 (2026-05-03)

### Bug fixes

- **`get_otp` 与 `refresh_token` 仍调用旧 `get`**：v0.5.1 把 HTTP 辅助函数从 `get`/`post`/`put`/`delete` 改名为 `http_get` 等，但 `Client.jl::get_otp` (line 197) 和 `Client.jl::refresh_token` (line 175) 内部还在用 `get(config, ...)`。重命名后这两个调用变成 `Base.get(::Settings, ::String)`，立刻报 `MethodError`。修：改为 `http_get(config, ...)`。

## v0.5.1 (2026-05-03)

### Bug fixes

- **消息循环立即崩溃**：`v0.5.0` 在 `Client.jl::start_message_loop` 里用 `get(client.pending, request_id, nothing)` 派发响应。但 `Client.jl:148` 早就定义了一个 `get(config::Config.Settings, path::String; params)` HTTP 辅助函数，在 `Client` 模块内屏蔽了 `Base.get`。结果认证响应一到就抛 `MethodError`，连接直接断掉。修：把 4 个 HTTP 辅助函数从 `get`/`post`/`put`/`delete` 改名为 `http_get`/`http_post`/`http_put`/`http_delete`，停止屏蔽 `Base` 名字（julia-style 第 18 条）；同步更新 `Trade.jl` 和 `Quote.jl` 的两处 `Client.get` 调用点。这些函数都不在 `LongBridge` 顶层导出，仅供内部使用。

## v0.5.0 (2026-05-03)

### Bug Fixes

- **OAuth `build` 永久阻塞**：`authorize!` 中的 `@sync` + `Timer` 组合导致即使浏览器授权完成，仍要等满 5 分钟超时才返回。重写为单 `Channel{Tuple{Symbol,String}}(1)` + `Timer(callback)`，回调即时唤醒。
- **Trade 推送 pipeline 完全无法工作**：
  - `Trade/TradePush.jl` 中本地复制了一个错误结构的 `PushOrderChanged`（字段全是 `String`），与协议层定义不一致；调用 `PushOrderChanged()` 无参构造不存在；`PB` 别名未导入。
  - `Trade/Trade.jl` 中 `PB.decode(IOBuffer(body), Notification)` 调用错误——`PB.decode` 期望 `AbstractProtoDecoder`。
  - 修：重写 TradePush 使用协议层的真实 `PushOrderChanged`，按 `ContentType.CONTENT_JSON` 解析 `Notification.data`；用 `Base.invokelatest` 调用回调；修正 decode 调用。
- **`set_on_candlestick(ctx, cb)` 抛 `UndefVarError`**：调用了不存在的 `QuotePush.set_on_candlestick!`。补齐 `QuotePush.Callbacks.candlestick` 字段、`handle_candlestick`、`set_on_candlestick!`，并在 `PushEventDetail` 中加入 `CandlestickEvent`。
- **`LongportError` 旧符号残留** (Trade/Trade.jl:94)：清理为 `LongBridgeError`，并将 `e.code == "ws-disconnected"` 这种类型不匹配的比较改为 `occursin("WebSocket", e.message)`。
- **`LongBridgeException` 旧符号残留** (Client.jl, Config.jl, Quote.jl 共 5 处)：替换为 `LongBridgeError`。

### Performance

- **`ws_request` 不再 busy-wait**：原实现每次 API 调用都 `while sleep(0.01)` 轮询 `pending_responses::Dict`，最差额外 10ms 延迟。改为每个 request 一个 `Channel{Tuple{UInt8,Vector{UInt8}}}(1)`、`take!` 阻塞唤醒，`Timer(callback) close(ch)` 实现超时；新增 `WSClient.send_lock::ReentrantLock` 保证 (alloc seq_id + register channel + send packet) 原子。
- **`connect!` 认证等待不再 busy-wait**：原实现 `while !connected sleep(0.1)` 轮询。改为 `WSClient.auth_event::Threads.Event`，认证响应到达消息循环时 `notify`，`connect!` 端 `wait` 阻塞，配合 `Timer` 实现 30s 超时。
- **Channel 类型收紧**：`InnerQuoteContext.command_ch`、`InnerTradeContext.command_ch` 从 `Channel{Any}` → `Channel{AbstractCommand}`；Quote 的推送通道从 `Channel{Any}` → `Channel{Tuple{UInt8, Vector{UInt8}}}`。
- **删除死缓存字段**：`InnerQuoteContext` 中 4 个 `Vector{Any}` 类型的 cache 字段 (`cache_participants`/`cache_issuers`/`cache_option_chain_*`) 从未被任何函数读写，删除。

### API

- **`Config.config` → `Config.Settings`**：类型名改为 CamelCase 符合风格惯例；`const config = Settings` 别名保留，`Config.config(...)` 仍然 work。`Settings` 同时在顶层导出。
- **`set_on_candlestick(ctx, cb)`** 现在真正工作（之前直接报错）。

### Workflow

- **PrecompileTools 工作负载**：在 `LongBridge.jl` 顶层加 `@compile_workload`，预热 `Config.Settings`、`OAuth.OAuthToken`、`LongBridgeError` 构造路径，降低 TTFX。
- **Revise 移出 `[deps]`**：之前作为运行时硬依赖不合理。现仅在 `[extras]+[targets].test`，使用方按需 `using Revise`。

### Style cleanup

- 删 `__precompile__()`（Julia 1.5+ 默认行为）。
- 删 `Core/QuoteProtocol.jl` 中 16 处 `show(io, x::T) = ...`——未加 `Base.` 前缀，定义在模块本地永远不会被 `print`/`display` 调用，是死代码（`EnumX` 已自动注册 `Base.show`）。
- `set_on_quote/depth/brokers/trades/candlestick` (Quote.jl)、`set_on_order_changed` (Trade.jl)、各 `set_on_*!` (QuotePush/TradePush) 改为单行赋值式，去掉过严的 `cb::Function` 注解。
- `Core/Utils.jl:80` 去除 `if` 条件外的多余括号。

## v0.4.0 (2026-03-14)

### Breaking Changes

- **SDK Renamed**: Module renamed from `LongPort` to `LongBridge` (`using LongBridge`)
- **Error Type Renamed**: `LongPortError` → `LongBridgeError`

### New Features

- **OAuth 2.0 Authentication**: Added `OAuth` module with browser-based authorization code flow
  - `OAuthBuilder("client-id") |> build(open_url_fn)` for one-line setup
  - Automatic token persistence to `.tokens/<client_id>` and transparent refresh
  - `Config.from_oauth(oauth_handle)` to create config from OAuth handle
  - Dual auth mode in Client: OAuth (Bearer token) and API Key (HMAC signature)

### Fixes

- Fixed extra `Bearer ` prefix in API Key mode HMAC signature

### Other

- Removed `TagBot.yml` workflow
- Updated dependencies (HTTP 1.11, ProtoBuf 1.3, etc.)

## v0.3.1 (2026-01-25)

### Performance Optimizations

- **Type Stability**: Made struct fields type-stable across all modules:
  - `Commands.jl`: Made `HttpPostCmd{B}` and `HttpPutCmd{B}` parametric to avoid `body::Any` boxing
  - `Quote.jl`: Made `GenericRequestCmd{R,T}` parametric for type-stable request/response handling
- **Memory Allocation Reduction**:
  - `Client.jl`: `sign()` uses `IOBuffer` + `print()` instead of string interpolation to reduce intermediate allocations
  - `Client.jl`: `send_request_packet()` uses pre-sized `IOBuffer(sizehint=...)` and writes body_len bytes directly instead of creating intermediate array
  - `Client.jl`: Replaced `"quote_response_$(id)"` with `string("quote_response_", id)` for faster string creation

### Breaking Changes

- **Struct Type Changes**: Several struct types are now parametric:
  - `HttpPostCmd{B}` and `HttpPutCmd{B}` in `Commands` (was non-parametric)
  - `GenericRequestCmd{R,T}` in `Quote` (was non-parametric)

## v0.3.0 (2026-01-23)

### New Features

- **RealtimeStore**: Added local data caching for WebSocket push events
  - `RealtimeStore{Q,D,B,T,C}` parametric struct in Cache module
  - Thread-safe storage with `ReentrantLock`
  - Automatically caches all push data (quotes, depth, brokers, trades)

- **Realtime Data Access Methods**: New methods to read cached push data
  - `realtime_depth(ctx, symbol)` - Get cached depth data
  - `realtime_brokers(ctx, symbol)` - Get cached broker queue
  - `realtime_trades(ctx, symbol; count)` - Get cached trades
  - `realtime_candlesticks(ctx, symbol, period; count)` - Get cached K-lines

- **Candlestick Subscription**: New methods for K-line subscription
  - `subscribe_candlesticks(ctx, symbol, period; count)` - Subscribe and get initial data
  - `unsubscribe_candlesticks(ctx, symbol, period)` - Unsubscribe and clear cache

### Breaking Changes

- **Struct Type Changes**: Several struct types are now parametric, which may affect code that explicitly typed these structs:
  - `LongBridgeError{T}` (was `LongBridgeError`)
  - `PushEvent{T}` in `QuotePush` and `TradeProtocol`
  - `CacheItem{T}` in `Cache`

### Performance Optimizations

- **Type Stability**: Made struct fields type-stable across all modules:
  - `Cache.jl`: Fixed `CacheItem{T}` parametric type, typed callbacks with `F where F`
  - `Errors.jl`: Made `LongBridgeError{T}` parametric with typed payload
  - `TradeProtocol.jl`: Made `PushEvent{T}` parametric
  - `QuotePush.jl`: Made `PushEvent{T}` parametric
  - `TradePush.jl`: Changed `AbstractString` to `String` in `PushOrderChanged`
  - `Quote.jl`: Changed `cache_trading_sessions` from `SimpleCache{Any}` to `SimpleCache{DataFrame}`
- **Typed Arrays**: Replaced untyped `[]` with typed arrays (`String[]`, `K[]`) in `Cache.jl` and `Client.jl` to avoid `Vector{Any}`
- **Pre-allocation**: Added `@inbounds` for hot loops in `Utils.jl`
- **Code Cleanup**: Removed `@show` debug statement from `history_candlesticks_by_offset`

### Refactoring

- **`disconnect!` Function**: Moved `disconnect!` implementations back to `Quote.jl` and `Trade.jl` modules (type defines methods pattern)
- **Module Cleanup**: Removed unused `__init__` function from `LongBridge.jl`

### Bug Fixes

- **QuoteProtocol.jl**: Fixed `ProtoBuf.ProtoBuf.AbstractProtoEncoder` typo → `ProtoBuf.AbstractProtoEncoder`
- **test/runtest.jl**: Fixed config constructor calls to use correct parameter names and added required `token_expire_time`

## v0.2.9 (2025-08-25)

### Bug Fixes

- **WebSocket Connection**: Fixed a critical bug where the `config` object was not being passed to the `WSClient` constructor in the `Quote` and `Trade` contexts. This caused connection failures by preventing necessary parameters, such as `enable_overnight`, from being correctly configured.

## v0.2.8 (2025-08-18)

### New Features

- **Intraday Data**: The `intraday` function now supports a `trade_session` parameter, allowing users to fetch data for specific trading sessions (e.g., pre-market, post-market).

### Refactoring

- **`disconnect!` Function**: Moved the `disconnect!` function from the `Quote` and `Trade` modules to the main `LongBridge` module, using multiple dispatch to handle both `QuoteContext` and `TradeContext` types. This simplifies the API and improves code organization.

## v0.2.7 (2025-08-15)

### Major Improvements

- **Dependencies & Compatibility**: Updated `Project.toml` with strict `[compat]` bounds for all dependencies and raised the minimum Julia version to `1.10` for better performance and stability.
- **WebSocket Stability**: Implemented a robust WebSocket handling mechanism, including:
    - Heartbeat (ping/pong) to keep connections alive.
    - Automatic re-subscription of topics upon reconnection.
- **HTTP Performance**: Introduced `HTTP.ConnectionPool` to reuse connections, significantly reducing latency for frequent API calls. Added timeout and retry strategies for GET requests.
- **Protocol Correctness**: Ensured all `@enum` types have explicit integer values matching the server-side protocol, preventing potential misinterpretations.
- **Error Handling**: Replaced the basic exception type with a more informative `Long
