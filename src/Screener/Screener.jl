module Screener

    using JSON3, StructTypes

    using ..Config
    using ..Client
    using ..Errors
    using ..ScreenerProtocol

    export ScreenerContext,
           screener_recommend_strategies, screener_user_strategies,
           screener_strategy, screener_search, screener_indicators

    """
        ScreenerContext(config::Config.Settings)

    选股器（stock screener）上下文。HTTP-only。

    上游 SDK 此 Context 的 5 个端点均返回结构多变的 JSON，本端口保留原始数据
    （以 `data::Any` 字段返回）；调用方可用 `JSON3.read`/索引语法按需取字段。
    """
    struct ScreenerContext
        config::Config.Settings
    end

    _check(resp) = resp.code == 0 || @lperror(resp.code, resp.message, get(resp.headers, "x-request-id", nothing))

    # ── screener_recommend_strategies ──────────────────────────────────

    """
        screener_recommend_strategies(ctx) -> ScreenerRecommendStrategiesResponse

    推荐策略列表（内置策略）。

    端点：`GET /v1/quote/screener/strategies/recommend`
    """
    function screener_recommend_strategies(ctx::ScreenerContext)
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/screener/strategies/recommend"))
        _check(resp)
        StructTypes.construct(ScreenerRecommendStrategiesResponse, resp.data)
    end

    # ── screener_user_strategies ───────────────────────────────────────

    """
        screener_user_strategies(ctx) -> ScreenerUserStrategiesResponse

    当前账户已保存的策略列表。

    端点：`GET /v1/quote/screener/strategies/mine`
    """
    function screener_user_strategies(ctx::ScreenerContext)
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/screener/strategies/mine"))
        _check(resp)
        StructTypes.construct(ScreenerUserStrategiesResponse, resp.data)
    end

    # ── screener_strategy ──────────────────────────────────────────────

    """
        screener_strategy(ctx, id) -> ScreenerStrategyResponse

    按 ID 获取策略详情。

    端点：`GET /v1/quote/screener/strategy?id=<id>`
    """
    function screener_strategy(ctx::ScreenerContext, id::Integer)
        params = Dict{String,Any}("id" => Int64(id))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/screener/strategy"; params))
        _check(resp)
        StructTypes.construct(ScreenerStrategyResponse, resp.data)
    end

    # ── screener_search ────────────────────────────────────────────────

    """
        screener_search(ctx, market, strategy_id, page, size) -> ScreenerSearchResponse

    用指定策略筛选证券。当 `strategy_id` 为 `nothing` 时，仅按 `market/page/size` 翻页。

    端点：`POST /v1/quote/screener/search`
    """
    function screener_search(
        ctx::ScreenerContext,
        market::AbstractString,
        strategy_id::Union{Integer,Nothing},
        page::Integer,
        size::Integer,
    )
        body = Dict{String,Any}(
            "market" => String(market),
            "page"   => Int(page),
            "size"   => Int(size),
        )
        isnothing(strategy_id) || (body["strategy_id"] = Int64(strategy_id))
        resp = ApiResponse(Client.http_post(ctx.config, "/v1/quote/screener/search"; body))
        _check(resp)
        StructTypes.construct(ScreenerSearchResponse, resp.data)
    end

    # ── screener_indicators ────────────────────────────────────────────

    """
        screener_indicators(ctx) -> ScreenerIndicatorsResponse

    所有可用的筛选指标元数据。

    端点：`GET /v1/quote/screener/indicators`
    """
    function screener_indicators(ctx::ScreenerContext)
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/screener/indicators"))
        _check(resp)
        StructTypes.construct(ScreenerIndicatorsResponse, resp.data)
    end

end # module Screener
