module Fundamental

    using JSON3, StructTypes

    using ..Config
    using ..Client
    using ..Errors
    using ..Utils: symbol_to_counter_id
    using ..FundamentalProtocol

    export FundamentalContext,
           financial_report, institution_rating, institution_rating_detail,
           dividend, dividend_detail, forecast_eps, consensus,
           valuation, valuation_history, industry_valuation, industry_valuation_dist,
           company, executive, shareholder, fund_holder,
           corp_action, invest_relation, operating, buyback, ratings

    """
        FundamentalContext(config::Config.Settings)

    基本面数据上下文。HTTP-only。
    """
    struct FundamentalContext
        config::Config.Settings
    end

    _check(resp) = resp.code == 0 || @lperror(resp.code, resp.message, get(resp.headers, "x-request-id", nothing))

    # ── 1. financial_report ────────────────────────────────────────────

    """
        financial_report(ctx, symbol; kind, period=nothing) -> FinancialReports

    财务报表（嵌套结构因 kind 而异，list 字段保留原 JSON）。

    端点：`GET /v1/quote/financial-reports`
    """
    function financial_report(
        ctx::FundamentalContext, symbol::AbstractString;
        kind::FinancialReportKind.T,
        period::Union{FinancialReportPeriod.T,Nothing}=nothing,
    )
        params = Dict{String,Any}(
            "counter_id" => symbol_to_counter_id(symbol),
            "kind"       => FundamentalProtocol._financial_report_kind_str(kind),
        )
        isnothing(period) || (params["report"] = FundamentalProtocol._financial_report_period_str(period))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/financial-reports"; params))
        _check(resp)
        StructTypes.construct(FinancialReports, resp.data)
    end

    # ── 2. institution_rating (fan-out) ────────────────────────────────

    """
        institution_rating(ctx, symbol) -> InstitutionRating

    机构评级（最新快照 + 共识汇总），两个端点并行调用。

    端点：`GET /v1/quote/institution-rating-latest` + `GET /v1/quote/institution-ratings`
    """
    function institution_rating(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        latest_t  = Threads.@spawn ApiResponse(Client.http_get(ctx.config, "/v1/quote/institution-rating-latest"; params=params))
        summary_t = Threads.@spawn ApiResponse(Client.http_get(ctx.config, "/v1/quote/institution-ratings";       params=params))
        latest, summary = fetch(latest_t), fetch(summary_t)
        _check(latest)
        _check(summary)
        InstitutionRating(
            StructTypes.construct(InstitutionRatingLatest,  latest.data),
            StructTypes.construct(InstitutionRatingSummary, summary.data),
        )
    end

    # ── 3. institution_rating_detail ───────────────────────────────────

    """
        institution_rating_detail(ctx, symbol) -> InstitutionRatingDetail

    机构评级历史明细（按周快照）。

    端点：`GET /v1/quote/institution-ratings/detail`
    """
    function institution_rating_detail(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/institution-ratings/detail"; params))
        _check(resp)
        StructTypes.construct(InstitutionRatingDetail, resp.data)
    end

    # ── 4. dividend ────────────────────────────────────────────────────

    """
        dividend(ctx, symbol) -> DividendList

    分红历史。

    端点：`GET /v1/quote/dividends`
    """
    function dividend(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/dividends"; params))
        _check(resp)
        StructTypes.construct(DividendList, resp.data)
    end

    # ── 5. dividend_detail ─────────────────────────────────────────────

    """
        dividend_detail(ctx, symbol) -> DividendList

    详细分红信息（含分配方案）。

    端点：`GET /v1/quote/dividends/details`
    """
    function dividend_detail(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/dividends/details"; params))
        _check(resp)
        StructTypes.construct(DividendList, resp.data)
    end

    # ── 6. forecast_eps ────────────────────────────────────────────────

    """
        forecast_eps(ctx, symbol) -> ForecastEps

    分析师 EPS 预测。

    端点：`GET /v1/quote/forecast-eps`
    """
    function forecast_eps(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/forecast-eps"; params))
        _check(resp)
        StructTypes.construct(ForecastEps, resp.data)
    end

    # ── 7. consensus ───────────────────────────────────────────────────

    """
        consensus(ctx, symbol) -> FinancialConsensus

    营收/利润/EPS 一致预期（含实际值对比）。

    端点：`GET /v1/quote/financial-consensus-detail`
    """
    function consensus(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/financial-consensus-detail"; params))
        _check(resp)
        StructTypes.construct(FinancialConsensus, resp.data)
    end

    # ── 8. valuation ───────────────────────────────────────────────────

    """
        valuation(ctx, symbol) -> ValuationData

    P/E、P/B、P/S、股息率快照（含历史 high/low/median）。

    端点：`GET /v1/quote/valuation`（固定 `indicator=pe`、`range=1`）
    """
    function valuation(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}(
            "counter_id" => symbol_to_counter_id(symbol),
            "indicator"  => "pe",
            "range"      => "1",
        )
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/valuation"; params))
        _check(resp)
        StructTypes.construct(ValuationData, resp.data)
    end

    # ── 9. valuation_history ───────────────────────────────────────────

    """
        valuation_history(ctx, symbol) -> ValuationHistoryResponse

    历史估值时间序列。

    端点：`GET /v1/quote/valuation/detail`
    """
    function valuation_history(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/valuation/detail"; params))
        _check(resp)
        StructTypes.construct(ValuationHistoryResponse, resp.data)
    end

    # ── 10. industry_valuation ─────────────────────────────────────────

    """
        industry_valuation(ctx, symbol) -> IndustryValuationList

    与同行业可比公司估值对比。

    端点：`GET /v1/quote/industry-valuation-comparison`
    """
    function industry_valuation(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/industry-valuation-comparison"; params))
        _check(resp)
        StructTypes.construct(IndustryValuationList, resp.data)
    end

    # ── 11. industry_valuation_dist ────────────────────────────────────

    """
        industry_valuation_dist(ctx, symbol) -> IndustryValuationDist

    本行业 PE/PB/PS 分位分布。

    端点：`GET /v1/quote/industry-valuation-distribution`
    """
    function industry_valuation_dist(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/industry-valuation-distribution"; params))
        _check(resp)
        StructTypes.construct(IndustryValuationDist, resp.data)
    end

    # ── 12. company ────────────────────────────────────────────────────

    """
        company(ctx, symbol) -> CompanyOverview

    公司概况（含地址、网站、董事长、高管等）。

    端点：`GET /v1/quote/comp-overview`
    """
    function company(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/comp-overview"; params))
        _check(resp)
        StructTypes.construct(CompanyOverview, resp.data)
    end

    # ── 13. executive ──────────────────────────────────────────────────

    """
        executive(ctx, symbol) -> ExecutiveList

    管理层与董事会成员。

    端点：`GET /v1/quote/company-professionals`（注意 query 参数是 `counter_ids` 而非 `counter_id`）
    """
    function executive(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_ids" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/company-professionals"; params))
        _check(resp)
        StructTypes.construct(ExecutiveList, resp.data)
    end

    # ── 14. shareholder ────────────────────────────────────────────────

    """
        shareholder(ctx, symbol) -> ShareholderList

    主要股东列表（含变动追踪与交叉持仓）。

    端点：`GET /v1/quote/shareholders`
    """
    function shareholder(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/shareholders"; params))
        _check(resp)
        StructTypes.construct(ShareholderList, resp.data)
    end

    # ── 15. fund_holder ────────────────────────────────────────────────

    """
        fund_holder(ctx, symbol) -> FundHolders

    持有该证券的基金和 ETF 列表。

    端点：`GET /v1/quote/fund-holders`
    """
    function fund_holder(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/fund-holders"; params))
        _check(resp)
        StructTypes.construct(FundHolders, resp.data)
    end

    # ── 16. corp_action ────────────────────────────────────────────────

    """
        corp_action(ctx, symbol) -> CorpActions

    公司行动（分红、拆股、回购等事件）。

    端点：`GET /v1/quote/company-act`（固定 `req_type=1`、`version=3`）
    """
    function corp_action(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}(
            "counter_id" => symbol_to_counter_id(symbol),
            "req_type"   => "1",
            "version"    => "3",
        )
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/company-act"; params))
        _check(resp)
        StructTypes.construct(CorpActions, resp.data)
    end

    # ── 17. invest_relation ────────────────────────────────────────────

    """
        invest_relation(ctx, symbol) -> InvestRelations

    本公司持有的其他公司股权（投资者关系/对外投资）。

    端点：`GET /v1/quote/invest-relations`（固定 `count=0`）
    """
    function invest_relation(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}(
            "counter_id" => symbol_to_counter_id(symbol),
            "count"      => "0",
        )
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/invest-relations"; params))
        _check(resp)
        StructTypes.construct(InvestRelations, resp.data)
    end

    # ── 18. operating ──────────────────────────────────────────────────

    """
        operating(ctx, symbol) -> OperatingList

    经营报告（含管理层讨论与关键财务指标）。

    端点：`GET /v1/quote/operatings`
    """
    function operating(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/operatings"; params))
        _check(resp)
        StructTypes.construct(OperatingList, resp.data)
    end

    # ── 19. buyback ────────────────────────────────────────────────────

    """
        buyback(ctx, symbol) -> BuybackData

    股票回购数据（含 TTM 摘要、历史与比率）。

    端点：`GET /v1/quote/buy-backs`
    """
    function buyback(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/buy-backs"; params))
        _check(resp)
        StructTypes.construct(BuybackData, resp.data)
    end

    # ── 20. ratings ────────────────────────────────────────────────────

    """
        ratings(ctx, symbol) -> StockRatings

    多维度股票评级（成长、盈利、估值等子指标 + 行业排名）。

    端点：`GET /v1/quote/ratings`
    """
    function ratings(ctx::FundamentalContext, symbol::AbstractString)
        params = Dict{String,Any}("counter_id" => symbol_to_counter_id(symbol))
        resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/ratings"; params))
        _check(resp)
        StructTypes.construct(StockRatings, resp.data)
    end

end # module Fundamental
