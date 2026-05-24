module FundamentalProtocol

    using EnumX, JSON3, StructTypes, Dates
    using ..Utils: Dec64, counter_id_to_symbol, to_china_time
    import ..Utils: _parse_optional_decimal

    export FinancialReportKind, FinancialReportPeriod, InstitutionRecommend,
           FinancialReports,
           RatingEvaluate, RatingTarget, RatingSummaryEvaluate,
           InstitutionRatingLatest, InstitutionRatingSummary, InstitutionRating,
           InstitutionRatingDetailEvaluateItem, InstitutionRatingDetailEvaluate,
           InstitutionRatingDetailTargetItem, InstitutionRatingDetailTarget,
           InstitutionRatingDetail,
           DividendItem, DividendList,
           ForecastEpsItem, ForecastEps,
           ConsensusDetail, ConsensusReport, FinancialConsensus,
           ValuationPoint, ValuationMetricData, ValuationMetricsData, ValuationData,
           ValuationHistoryMetric, ValuationHistoryMetrics, ValuationHistoryData, ValuationHistoryResponse,
           IndustryValuationHistory, IndustryValuationItem, IndustryValuationList,
           ValuationDist, IndustryValuationDist,
           CompanyOverview,
           Professional, ExecutiveGroup, ExecutiveList,
           ShareholderStock, Shareholder, ShareholderList,
           FundHolder, FundHolders,
           CorpActionLive, CorpActionItem, CorpActions,
           InvestSecurity, InvestRelations,
           OperatingIndicator, OperatingFinancial, OperatingItem, OperatingList,
           RecentBuybacks, BuybackHistoryItem, BuybackRatios, BuybackData,
           RatingLeafIndicator, RatingIndicator, RatingSubIndicatorGroup, RatingCategory, StockRatings,
           BusinessSegmentItem, BusinessSegments,
           BusinessSegmentHistoryItem, BusinessSegmentsHistoricalItem, BusinessSegmentsHistory,
           InstitutionRatingViewItem, InstitutionRatingViews,
           IndustryRankItem, IndustryRankGroup, IndustryRankResponse,
           IndustryPeersTop, IndustryPeerNode, IndustryPeersResponse,
           SnapshotForecastMetric, SnapshotReportedMetric, FinancialReportSnapshot,
           ShareholderTopResponse, ShareholderDetailResponse,
           ValuationHistoryPoint, ValuationComparisonItem, ValuationComparisonResponse,
           _financial_report_kind_str, _financial_report_period_str, _institution_recommend_from_str

    @enumx FinancialReportKind begin
        IncomeStatement = 1   # 利润表 (IS)
        BalanceSheet    = 2   # 资产负债表 (BS)
        CashFlow        = 3   # 现金流量表 (CF)
        All             = 4   # 全部 (ALL)
    end

    @enumx FinancialReportPeriod begin
        Annual        = 1   # af
        SemiAnnual    = 2   # saf
        Q1            = 3
        Q2            = 4
        Q3            = 5
        QuarterlyFull = 6   # qf
        ThreeQ        = 7   # 3q (前三季)
    end

    @enumx InstitutionRecommend begin
        Unknown      = 0
        StrongBuy    = 1
        Buy          = 2
        Hold         = 3
        Sell         = 4
        StrongSell   = 5
        Underperform = 6
        NoOpinion    = 7
    end

    function _financial_report_kind_str(k::FinancialReportKind.T)
        k === FinancialReportKind.IncomeStatement ? "IS"  :
        k === FinancialReportKind.BalanceSheet    ? "BS"  :
        k === FinancialReportKind.CashFlow        ? "CF"  :
        k === FinancialReportKind.All             ? "ALL" :
        error("unknown FinancialReportKind: $k")
    end

    function _financial_report_period_str(p::FinancialReportPeriod.T)
        p === FinancialReportPeriod.Annual        ? "af"  :
        p === FinancialReportPeriod.SemiAnnual    ? "saf" :
        p === FinancialReportPeriod.Q1            ? "q1"  :
        p === FinancialReportPeriod.Q2            ? "q2"  :
        p === FinancialReportPeriod.Q3            ? "q3"  :
        p === FinancialReportPeriod.QuarterlyFull ? "qf"  :
        p === FinancialReportPeriod.ThreeQ        ? "3q"  :
        error("unknown FinancialReportPeriod: $p")
    end

    function _institution_recommend_from_str(s::AbstractString)
        s == "strong_buy"   ? InstitutionRecommend.StrongBuy    :
        s == "buy"          ? InstitutionRecommend.Buy          :
        s == "hold"         ? InstitutionRecommend.Hold         :
        s == "sell"         ? InstitutionRecommend.Sell         :
        s == "strong_sell"  ? InstitutionRecommend.StrongSell   :
        s == "underperform" ? InstitutionRecommend.Underperform :
        s == "no_opinion"   ? InstitutionRecommend.NoOpinion    :
        InstitutionRecommend.Unknown
    end

    # ── financial_report ───────────────────────────────────────────────

    struct FinancialReports
        list::Any                            # 嵌套数据结构因 kind 而异，保留原 JSON
    end
    StructTypes.StructType(::Type{FinancialReports}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{FinancialReports}, obj::JSON3.Object) =
        FinancialReports(get(obj, :list, nothing))

    # ── institution_rating ─────────────────────────────────────────────

    struct RatingEvaluate
        buy::Int
        over::Int
        hold::Int
        under::Int
        sell::Int
        no_opinion::Int
        total::Int
        start_date::String
        end_date::String
    end
    StructTypes.StructType(::Type{RatingEvaluate}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{RatingEvaluate}, obj::JSON3.Object)
        RatingEvaluate(
            Int(get(obj, :buy, 0)),
            Int(get(obj, :over, 0)),
            Int(get(obj, :hold, 0)),
            Int(get(obj, :under, 0)),
            Int(get(obj, :sell, 0)),
            Int(get(obj, :no_opinion, 0)),
            Int(get(obj, :total, 0)),
            String(get(obj, :start_date, "")),
            String(get(obj, :end_date, "")),
        )
    end

    struct RatingTarget
        highest_price::Union{Dec64,Nothing}
        lowest_price::Union{Dec64,Nothing}
        prev_close::Union{Dec64,Nothing}
        start_date::String
        end_date::String
    end
    StructTypes.StructType(::Type{RatingTarget}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{RatingTarget}, obj::JSON3.Object)
        RatingTarget(
            _parse_optional_decimal(get(obj, :highest_price, nothing)),
            _parse_optional_decimal(get(obj, :lowest_price, nothing)),
            _parse_optional_decimal(get(obj, :prev_close, nothing)),
            String(get(obj, :start_date, "")),
            String(get(obj, :end_date, "")),
        )
    end

    struct RatingSummaryEvaluate
        buy::Int
        date::String
        hold::Int
        sell::Int
        strong_buy::Int
        under::Int
    end
    StructTypes.StructType(::Type{RatingSummaryEvaluate}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{RatingSummaryEvaluate}, obj::JSON3.Object)
        RatingSummaryEvaluate(
            Int(get(obj, :buy, 0)),
            String(get(obj, :date, "")),
            Int(get(obj, :hold, 0)),
            Int(get(obj, :sell, 0)),
            Int(get(obj, :strong_buy, 0)),
            Int(get(obj, :under, 0)),
        )
    end

    struct InstitutionRatingLatest
        evaluate::RatingEvaluate
        target::RatingTarget
        industry_id::Int64
        industry_name::String
        industry_rank::Int
        industry_total::Int
        industry_mean::Int
        industry_median::Int
    end
    StructTypes.StructType(::Type{InstitutionRatingLatest}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{InstitutionRatingLatest}, obj::JSON3.Object)
        InstitutionRatingLatest(
            StructTypes.construct(RatingEvaluate, obj.evaluate),
            StructTypes.construct(RatingTarget, obj.target),
            Int64(get(obj, :industry_id, 0)),
            String(get(obj, :industry_name, "")),
            Int(get(obj, :industry_rank, 0)),
            Int(get(obj, :industry_total, 0)),
            Int(get(obj, :industry_mean, 0)),
            Int(get(obj, :industry_median, 0)),
        )
    end

    struct InstitutionRatingSummary
        ccy_symbol::String
        change::Union{Dec64,Nothing}
        evaluate::RatingSummaryEvaluate
        recommend::InstitutionRecommend.T
        target::Union{Dec64,Nothing}
        updated_at::String
    end
    StructTypes.StructType(::Type{InstitutionRatingSummary}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{InstitutionRatingSummary}, obj::JSON3.Object)
        InstitutionRatingSummary(
            String(get(obj, :ccy_symbol, "")),
            _parse_optional_decimal(get(obj, :change, nothing)),
            StructTypes.construct(RatingSummaryEvaluate, obj.evaluate),
            _institution_recommend_from_str(String(get(obj, :recommend, ""))),
            _parse_optional_decimal(get(obj, :target, nothing)),
            String(get(obj, :updated_at, "")),
        )
    end

    struct InstitutionRating
        latest::InstitutionRatingLatest
        summary::InstitutionRatingSummary
    end

    # ── institution_rating_detail ──────────────────────────────────────

    struct InstitutionRatingDetailEvaluateItem
        buy::Int
        date::String
        hold::Int
        sell::Int
        strong_buy::Int
        no_opinion::Int
        under::Int
    end
    StructTypes.StructType(::Type{InstitutionRatingDetailEvaluateItem}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{InstitutionRatingDetailEvaluateItem}, obj::JSON3.Object)
        InstitutionRatingDetailEvaluateItem(
            Int(get(obj, :buy, 0)),
            String(get(obj, :date, "")),
            Int(get(obj, :hold, 0)),
            Int(get(obj, :sell, 0)),
            Int(get(obj, :strong_buy, 0)),
            Int(get(obj, :no_opinion, 0)),
            Int(get(obj, :under, 0)),
        )
    end

    struct InstitutionRatingDetailEvaluate
        list::Vector{InstitutionRatingDetailEvaluateItem}
    end
    StructTypes.StructType(::Type{InstitutionRatingDetailEvaluate}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{InstitutionRatingDetailEvaluate}, obj::JSON3.Object)
        items = if haskey(obj, :list) && !isnothing(obj.list)
            [StructTypes.construct(InstitutionRatingDetailEvaluateItem, x) for x in obj.list]
        else
            InstitutionRatingDetailEvaluateItem[]
        end
        InstitutionRatingDetailEvaluate(items)
    end

    struct InstitutionRatingDetailTargetItem
        avg_target::Union{Dec64,Nothing}
        date::String
        max_target::Union{Dec64,Nothing}
        min_target::Union{Dec64,Nothing}
        meet::Bool
        price::Union{Dec64,Nothing}
        timestamp::String
    end
    StructTypes.StructType(::Type{InstitutionRatingDetailTargetItem}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{InstitutionRatingDetailTargetItem}, obj::JSON3.Object)
        InstitutionRatingDetailTargetItem(
            _parse_optional_decimal(get(obj, :avg_target, nothing)),
            String(get(obj, :date, "")),
            _parse_optional_decimal(get(obj, :max_target, nothing)),
            _parse_optional_decimal(get(obj, :min_target, nothing)),
            Bool(get(obj, :meet, false)),
            _parse_optional_decimal(get(obj, :price, nothing)),
            String(get(obj, :timestamp, "")),
        )
    end

    struct InstitutionRatingDetailTarget
        data_percent::Union{Dec64,Nothing}
        prediction_accuracy::Union{Dec64,Nothing}
        updated_at::String
        list::Vector{InstitutionRatingDetailTargetItem}
    end
    StructTypes.StructType(::Type{InstitutionRatingDetailTarget}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{InstitutionRatingDetailTarget}, obj::JSON3.Object)
        items = if haskey(obj, :list) && !isnothing(obj.list)
            [StructTypes.construct(InstitutionRatingDetailTargetItem, x) for x in obj.list]
        else
            InstitutionRatingDetailTargetItem[]
        end
        # data_percent 也可能是数字或 null
        dp_raw = get(obj, :data_percent, nothing)
        data_percent = _parse_optional_decimal(dp_raw)
        InstitutionRatingDetailTarget(
            data_percent,
            _parse_optional_decimal(get(obj, :prediction_accuracy, nothing)),
            String(get(obj, :updated_at, "")),
            items,
        )
    end

    struct InstitutionRatingDetail
        ccy_symbol::String
        evaluate::InstitutionRatingDetailEvaluate
        target::InstitutionRatingDetailTarget
    end
    StructTypes.StructType(::Type{InstitutionRatingDetail}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{InstitutionRatingDetail}, obj::JSON3.Object)
        InstitutionRatingDetail(
            String(get(obj, :ccy_symbol, "")),
            StructTypes.construct(InstitutionRatingDetailEvaluate, obj.evaluate),
            StructTypes.construct(InstitutionRatingDetailTarget, obj.target),
        )
    end

    # ── dividend ───────────────────────────────────────────────────────

    struct DividendItem
        symbol::String
        id::String
        desc::String
        record_date::String
        ex_date::String
        payment_date::String
    end
    StructTypes.StructType(::Type{DividendItem}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{DividendItem}, obj::JSON3.Object)
        DividendItem(
            counter_id_to_symbol(String(get(obj, :counter_id, ""))),
            String(get(obj, :id, "")),
            String(get(obj, :desc, "")),
            String(get(obj, :record_date, "")),
            String(get(obj, :ex_date, "")),
            String(get(obj, :payment_date, "")),
        )
    end

    struct DividendList
        list::Vector{DividendItem}
    end
    StructTypes.StructType(::Type{DividendList}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{DividendList}, obj::JSON3.Object)
        items = if haskey(obj, :list) && !isnothing(obj.list)
            [StructTypes.construct(DividendItem, x) for x in obj.list]
        else
            DividendItem[]
        end
        DividendList(items)
    end

    # ── forecast_eps ───────────────────────────────────────────────────

    struct ForecastEpsItem
        forecast_eps_median::Union{Dec64,Nothing}
        forecast_eps_mean::Union{Dec64,Nothing}
        forecast_eps_lowest::Union{Dec64,Nothing}
        forecast_eps_highest::Union{Dec64,Nothing}
        institution_total::Int
        institution_up::Int
        institution_down::Int
        forecast_start_date::DateTime    # API 返回 unix 时间戳
        forecast_end_date::DateTime
    end
    StructTypes.StructType(::Type{ForecastEpsItem}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ForecastEpsItem}, obj::JSON3.Object)
        ForecastEpsItem(
            _parse_optional_decimal(get(obj, :forecast_eps_median, nothing)),
            _parse_optional_decimal(get(obj, :forecast_eps_mean, nothing)),
            _parse_optional_decimal(get(obj, :forecast_eps_lowest, nothing)),
            _parse_optional_decimal(get(obj, :forecast_eps_highest, nothing)),
            Int(get(obj, :institution_total, 0)),
            Int(get(obj, :institution_up, 0)),
            Int(get(obj, :institution_down, 0)),
            to_china_time(obj.forecast_start_date isa Number ? Int64(obj.forecast_start_date) : String(obj.forecast_start_date)),
            to_china_time(obj.forecast_end_date isa Number ? Int64(obj.forecast_end_date) : String(obj.forecast_end_date)),
        )
    end

    struct ForecastEps
        items::Vector{ForecastEpsItem}
    end
    StructTypes.StructType(::Type{ForecastEps}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ForecastEps}, obj::JSON3.Object)
        items = if haskey(obj, :items) && !isnothing(obj.items)
            [StructTypes.construct(ForecastEpsItem, x) for x in obj.items]
        else
            ForecastEpsItem[]
        end
        ForecastEps(items)
    end

    # ── consensus ──────────────────────────────────────────────────────

    struct ConsensusDetail
        key::String
        name::String
        description::String
        actual::Union{Dec64,Nothing}
        estimate::Union{Dec64,Nothing}
        comp_value::Union{Dec64,Nothing}
        comp_desc::String
        comp::String
        is_released::Bool
    end
    StructTypes.StructType(::Type{ConsensusDetail}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ConsensusDetail}, obj::JSON3.Object)
        ConsensusDetail(
            String(get(obj, :key, "")),
            String(get(obj, :name, "")),
            String(get(obj, :description, "")),
            _parse_optional_decimal(get(obj, :actual, nothing)),
            _parse_optional_decimal(get(obj, :estimate, nothing)),
            _parse_optional_decimal(get(obj, :comp_value, nothing)),
            String(get(obj, :comp_desc, "")),
            String(get(obj, :comp, "")),
            Bool(get(obj, :is_released, false)),
        )
    end

    struct ConsensusReport
        fiscal_year::Int
        fiscal_period::String
        period_text::String
        details::Vector{ConsensusDetail}
    end
    StructTypes.StructType(::Type{ConsensusReport}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ConsensusReport}, obj::JSON3.Object)
        details = if haskey(obj, :details) && !isnothing(obj.details)
            [StructTypes.construct(ConsensusDetail, x) for x in obj.details]
        else
            ConsensusDetail[]
        end
        ConsensusReport(
            Int(get(obj, :fiscal_year, 0)),
            String(get(obj, :fiscal_period, "")),
            String(get(obj, :period_text, "")),
            details,
        )
    end

    struct FinancialConsensus
        list::Vector{ConsensusReport}
        current_index::Int
        currency::String
        opt_periods::Vector{String}
        current_period::String
    end
    StructTypes.StructType(::Type{FinancialConsensus}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{FinancialConsensus}, obj::JSON3.Object)
        reports = if haskey(obj, :list) && !isnothing(obj.list)
            [StructTypes.construct(ConsensusReport, x) for x in obj.list]
        else
            ConsensusReport[]
        end
        periods = if haskey(obj, :opt_periods) && !isnothing(obj.opt_periods)
            String[String(p) for p in obj.opt_periods]
        else
            String[]
        end
        FinancialConsensus(
            reports,
            Int(get(obj, :current_index, 0)),
            String(get(obj, :currency, "")),
            periods,
            String(get(obj, :current_period, "")),
        )
    end

    # ── valuation ──────────────────────────────────────────────────────

    struct ValuationPoint
        timestamp::DateTime
        value::Union{Dec64,Nothing}
    end
    StructTypes.StructType(::Type{ValuationPoint}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ValuationPoint}, obj::JSON3.Object)
        ValuationPoint(
            to_china_time(obj.timestamp isa Number ? Int64(obj.timestamp) : String(obj.timestamp)),
            _parse_optional_decimal(get(obj, :value, nothing)),
        )
    end

    struct ValuationMetricData
        desc::String
        high::Union{Dec64,Nothing}
        low::Union{Dec64,Nothing}
        median::Union{Dec64,Nothing}
        list::Vector{ValuationPoint}
    end
    StructTypes.StructType(::Type{ValuationMetricData}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ValuationMetricData}, obj::JSON3.Object)
        points = if haskey(obj, :list) && !isnothing(obj.list)
            [StructTypes.construct(ValuationPoint, x) for x in obj.list]
        else
            ValuationPoint[]
        end
        ValuationMetricData(
            String(get(obj, :desc, "")),
            _parse_optional_decimal(get(obj, :high, nothing)),
            _parse_optional_decimal(get(obj, :low, nothing)),
            _parse_optional_decimal(get(obj, :median, nothing)),
            points,
        )
    end

    _opt_metric(v::Nothing) = nothing
    _opt_metric(v) = StructTypes.construct(ValuationMetricData, v)

    struct ValuationMetricsData
        pe::Union{ValuationMetricData,Nothing}
        pb::Union{ValuationMetricData,Nothing}
        ps::Union{ValuationMetricData,Nothing}
        dvd_yld::Union{ValuationMetricData,Nothing}
    end
    StructTypes.StructType(::Type{ValuationMetricsData}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ValuationMetricsData}, obj::JSON3.Object)
        ValuationMetricsData(
            _opt_metric(get(obj, :pe, nothing)),
            _opt_metric(get(obj, :pb, nothing)),
            _opt_metric(get(obj, :ps, nothing)),
            _opt_metric(get(obj, :dvd_yld, nothing)),
        )
    end

    struct ValuationData
        metrics::ValuationMetricsData
    end
    StructTypes.StructType(::Type{ValuationData}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{ValuationData}, obj::JSON3.Object) =
        ValuationData(StructTypes.construct(ValuationMetricsData, obj.metrics))

    # ── valuation_history ──────────────────────────────────────────────

    struct ValuationHistoryMetric
        desc::String
        high::Union{Dec64,Nothing}
        low::Union{Dec64,Nothing}
        median::Union{Dec64,Nothing}
        list::Vector{ValuationPoint}
    end
    StructTypes.StructType(::Type{ValuationHistoryMetric}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ValuationHistoryMetric}, obj::JSON3.Object)
        points = if haskey(obj, :list) && !isnothing(obj.list)
            [StructTypes.construct(ValuationPoint, x) for x in obj.list]
        else
            ValuationPoint[]
        end
        ValuationHistoryMetric(
            String(get(obj, :desc, "")),
            _parse_optional_decimal(get(obj, :high, nothing)),
            _parse_optional_decimal(get(obj, :low, nothing)),
            _parse_optional_decimal(get(obj, :median, nothing)),
            points,
        )
    end

    _opt_hmetric(v::Nothing) = nothing
    _opt_hmetric(v) = StructTypes.construct(ValuationHistoryMetric, v)

    struct ValuationHistoryMetrics
        pe::Union{ValuationHistoryMetric,Nothing}
        pb::Union{ValuationHistoryMetric,Nothing}
        ps::Union{ValuationHistoryMetric,Nothing}
    end
    StructTypes.StructType(::Type{ValuationHistoryMetrics}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ValuationHistoryMetrics}, obj::JSON3.Object)
        ValuationHistoryMetrics(
            _opt_hmetric(get(obj, :pe, nothing)),
            _opt_hmetric(get(obj, :pb, nothing)),
            _opt_hmetric(get(obj, :ps, nothing)),
        )
    end

    struct ValuationHistoryData
        metrics::ValuationHistoryMetrics
    end
    StructTypes.StructType(::Type{ValuationHistoryData}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{ValuationHistoryData}, obj::JSON3.Object) =
        ValuationHistoryData(StructTypes.construct(ValuationHistoryMetrics, obj.metrics))

    struct ValuationHistoryResponse
        history::ValuationHistoryData
    end
    StructTypes.StructType(::Type{ValuationHistoryResponse}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{ValuationHistoryResponse}, obj::JSON3.Object) =
        ValuationHistoryResponse(StructTypes.construct(ValuationHistoryData, obj.history))

    # ── industry_valuation ─────────────────────────────────────────────

    struct IndustryValuationHistory
        date::String
        pe::Union{Dec64,Nothing}
        pb::Union{Dec64,Nothing}
        ps::Union{Dec64,Nothing}
    end
    StructTypes.StructType(::Type{IndustryValuationHistory}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{IndustryValuationHistory}, obj::JSON3.Object)
        IndustryValuationHistory(
            String(get(obj, :date, "")),
            _parse_optional_decimal(get(obj, :pe, nothing)),
            _parse_optional_decimal(get(obj, :pb, nothing)),
            _parse_optional_decimal(get(obj, :ps, nothing)),
        )
    end

    struct IndustryValuationItem
        symbol::String                    # 由 counter_id 转换
        name::String
        currency::String
        assets::Union{Dec64,Nothing}
        bps::Union{Dec64,Nothing}
        eps::Union{Dec64,Nothing}
        dps::Union{Dec64,Nothing}
        div_yld::Union{Dec64,Nothing}
        div_payout_ratio::Union{Dec64,Nothing}
        five_y_avg_dps::Union{Dec64,Nothing}
        pe::Union{Dec64,Nothing}
        history::Vector{IndustryValuationHistory}
    end
    StructTypes.StructType(::Type{IndustryValuationItem}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{IndustryValuationItem}, obj::JSON3.Object)
        history = if haskey(obj, :history) && !isnothing(obj.history)
            [StructTypes.construct(IndustryValuationHistory, x) for x in obj.history]
        else
            IndustryValuationHistory[]
        end
        IndustryValuationItem(
            counter_id_to_symbol(String(get(obj, :counter_id, ""))),
            String(get(obj, :name, "")),
            String(get(obj, :currency, "")),
            _parse_optional_decimal(get(obj, :assets, nothing)),
            _parse_optional_decimal(get(obj, :bps, nothing)),
            _parse_optional_decimal(get(obj, :eps, nothing)),
            _parse_optional_decimal(get(obj, :dps, nothing)),
            _parse_optional_decimal(get(obj, :div_yld, nothing)),
            _parse_optional_decimal(get(obj, :div_payout_ratio, nothing)),
            _parse_optional_decimal(get(obj, :five_y_avg_dps, nothing)),
            _parse_optional_decimal(get(obj, :pe, nothing)),
            history,
        )
    end

    struct IndustryValuationList
        list::Vector{IndustryValuationItem}
    end
    StructTypes.StructType(::Type{IndustryValuationList}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{IndustryValuationList}, obj::JSON3.Object)
        items = if haskey(obj, :list) && !isnothing(obj.list)
            [StructTypes.construct(IndustryValuationItem, x) for x in obj.list]
        else
            IndustryValuationItem[]
        end
        IndustryValuationList(items)
    end

    # ── industry_valuation_dist ────────────────────────────────────────

    struct ValuationDist
        low::Union{Dec64,Nothing}
        high::Union{Dec64,Nothing}
        median::Union{Dec64,Nothing}
        value::Union{Dec64,Nothing}
        ranking::Union{Dec64,Nothing}
        rank_index::String
        rank_total::String
    end
    StructTypes.StructType(::Type{ValuationDist}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ValuationDist}, obj::JSON3.Object)
        ValuationDist(
            _parse_optional_decimal(get(obj, :low, nothing)),
            _parse_optional_decimal(get(obj, :high, nothing)),
            _parse_optional_decimal(get(obj, :median, nothing)),
            _parse_optional_decimal(get(obj, :value, nothing)),
            _parse_optional_decimal(get(obj, :ranking, nothing)),
            String(get(obj, :rank_index, "")),
            String(get(obj, :rank_total, "")),
        )
    end

    _opt_dist(v::Nothing) = nothing
    _opt_dist(v) = StructTypes.construct(ValuationDist, v)

    struct IndustryValuationDist
        pe::Union{ValuationDist,Nothing}
        pb::Union{ValuationDist,Nothing}
        ps::Union{ValuationDist,Nothing}
    end
    StructTypes.StructType(::Type{IndustryValuationDist}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{IndustryValuationDist}, obj::JSON3.Object)
        IndustryValuationDist(
            _opt_dist(get(obj, :pe, nothing)),
            _opt_dist(get(obj, :pb, nothing)),
            _opt_dist(get(obj, :ps, nothing)),
        )
    end

    # ── company ────────────────────────────────────────────────────────

    struct CompanyOverview
        name::String
        company_name::String
        founded::String
        listing_date::String
        market::String
        region::String
        address::String
        office_address::String
        website::String
        issue_price::Union{Dec64,Nothing}
        shares_offered::String
        chairman::String
        secretary::String
        audit_inst::String
        category::String
        year_end::String
        employees::String
        phone::String                  # JSON 字段名 "Phone"（首字母大写）
        fax::String
        email::String
        legal_repr::String
        manager::String
        bus_license::String
        accounting_firm::String
        securities_rep::String
        legal_counsel::String
        zip_code::String
        ticker::String
        icon::String
        profile::String
        ads_ratio::String
        sector::Int
    end
    StructTypes.StructType(::Type{CompanyOverview}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{CompanyOverview}, obj::JSON3.Object)
        CompanyOverview(
            String(get(obj, :name, "")),
            String(get(obj, :company_name, "")),
            String(get(obj, :founded, "")),
            String(get(obj, :listing_date, "")),
            String(get(obj, :market, "")),
            String(get(obj, :region, "")),
            String(get(obj, :address, "")),
            String(get(obj, :office_address, "")),
            String(get(obj, :website, "")),
            _parse_optional_decimal(get(obj, :issue_price, nothing)),
            String(get(obj, :shares_offered, "")),
            String(get(obj, :chairman, "")),
            String(get(obj, :secretary, "")),
            String(get(obj, :audit_inst, "")),
            String(get(obj, :category, "")),
            String(get(obj, :year_end, "")),
            String(get(obj, :employees, "")),
            String(get(obj, :Phone, "")),
            String(get(obj, :fax, "")),
            String(get(obj, :email, "")),
            String(get(obj, :legal_repr, "")),
            String(get(obj, :manager, "")),
            String(get(obj, :bus_license, "")),
            String(get(obj, :accounting_firm, "")),
            String(get(obj, :securities_rep, "")),
            String(get(obj, :legal_counsel, "")),
            String(get(obj, :zip_code, "")),
            String(get(obj, :ticker, "")),
            String(get(obj, :icon, "")),
            String(get(obj, :profile, "")),
            String(get(obj, :ads_ratio, "")),
            Int(get(obj, :sector, 0)),
        )
    end

    # ── executive ──────────────────────────────────────────────────────

    struct Professional
        id::String
        name::String
        name_zhcn::String
        name_en::String
        title::String
        biography::String
        photo::String
        wiki_url::String
    end
    StructTypes.StructType(::Type{Professional}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{Professional}, obj::JSON3.Object)
        Professional(
            String(get(obj, :id, "")),
            String(get(obj, :name, "")),
            String(get(obj, :name_zhcn, "")),
            String(get(obj, :name_en, "")),
            String(get(obj, :title, "")),
            String(get(obj, :biography, "")),
            String(get(obj, :photo, "")),
            String(get(obj, :wiki_url, "")),
        )
    end

    struct ExecutiveGroup
        symbol::String                      # 由 counter_id 转换
        forward_url::String
        total::Int
        professionals::Vector{Professional}
    end
    StructTypes.StructType(::Type{ExecutiveGroup}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ExecutiveGroup}, obj::JSON3.Object)
        pros = if haskey(obj, :professionals) && !isnothing(obj.professionals)
            [StructTypes.construct(Professional, x) for x in obj.professionals]
        else
            Professional[]
        end
        ExecutiveGroup(
            counter_id_to_symbol(String(get(obj, :counter_id, ""))),
            String(get(obj, :forward_url, "")),
            Int(get(obj, :total, length(pros))),
            pros,
        )
    end

    struct ExecutiveList
        professional_list::Vector{ExecutiveGroup}
    end
    StructTypes.StructType(::Type{ExecutiveList}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ExecutiveList}, obj::JSON3.Object)
        groups = if haskey(obj, :professional_list) && !isnothing(obj.professional_list)
            [StructTypes.construct(ExecutiveGroup, x) for x in obj.professional_list]
        else
            ExecutiveGroup[]
        end
        ExecutiveList(groups)
    end

    # ── shareholder ────────────────────────────────────────────────────

    struct ShareholderStock
        symbol::String
        code::String
        market::String
        chg::String
    end
    StructTypes.StructType(::Type{ShareholderStock}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ShareholderStock}, obj::JSON3.Object)
        ShareholderStock(
            counter_id_to_symbol(String(get(obj, :counter_id, ""))),
            String(get(obj, :code, "")),
            String(get(obj, :market, "")),
            String(get(obj, :chg, "")),
        )
    end

    struct Shareholder
        shareholder_id::String
        shareholder_name::String
        institution_type::String
        percent_of_shares::Union{Dec64,Nothing}
        shares_changed::Union{Dec64,Nothing}
        report_date::String
        stocks::Vector{ShareholderStock}
    end
    StructTypes.StructType(::Type{Shareholder}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{Shareholder}, obj::JSON3.Object)
        stocks = if haskey(obj, :stocks) && !isnothing(obj.stocks)
            [StructTypes.construct(ShareholderStock, x) for x in obj.stocks]
        else
            ShareholderStock[]
        end
        Shareholder(
            String(get(obj, :shareholder_id, "")),
            String(get(obj, :shareholder_name, "")),
            String(get(obj, :institution_type, "")),
            _parse_optional_decimal(get(obj, :percent_of_shares, nothing)),
            _parse_optional_decimal(get(obj, :shares_changed, nothing)),
            String(get(obj, :report_date, "")),
            stocks,
        )
    end

    struct ShareholderList
        shareholder_list::Vector{Shareholder}
        forward_url::String
        total::Int
    end
    StructTypes.StructType(::Type{ShareholderList}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ShareholderList}, obj::JSON3.Object)
        list = if haskey(obj, :shareholder_list) && !isnothing(obj.shareholder_list)
            [StructTypes.construct(Shareholder, x) for x in obj.shareholder_list]
        else
            Shareholder[]
        end
        ShareholderList(list, String(get(obj, :forward_url, "")), Int(get(obj, :total, length(list))))
    end

    # ── fund_holder ────────────────────────────────────────────────────

    struct FundHolder
        code::String
        symbol::String
        currency::String
        name::String
        position_ratio::Dec64
        report_date::String
    end
    StructTypes.StructType(::Type{FundHolder}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{FundHolder}, obj::JSON3.Object)
        # position_ratio uses decimal_empty_is_0 in upstream; tolerate "--" placeholder.
        pr_raw = get(obj, :position_ratio, "")
        pr = if isnothing(pr_raw) || (pr_raw isa AbstractString && isempty(pr_raw))
            Dec64(0)
        elseif pr_raw isa Number
            Dec64(pr_raw)
        else
            try
                parse(Dec64, String(pr_raw))
            catch
                Dec64(0)
            end
        end
        FundHolder(
            String(get(obj, :code, "")),
            counter_id_to_symbol(String(get(obj, :counter_id, ""))),
            String(get(obj, :currency, "")),
            String(get(obj, :name, "")),
            pr,
            String(get(obj, :report_date, "")),
        )
    end

    struct FundHolders
        lists::Vector{FundHolder}
    end
    StructTypes.StructType(::Type{FundHolders}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{FundHolders}, obj::JSON3.Object)
        items = if haskey(obj, :lists) && !isnothing(obj.lists)
            [StructTypes.construct(FundHolder, x) for x in obj.lists]
        else
            FundHolder[]
        end
        FundHolders(items)
    end

    # ── corp_action ────────────────────────────────────────────────────

    struct CorpActionLive
        id::String
        status::Any
        started_at::String
        name::String
        icon::String
    end
    StructTypes.StructType(::Type{CorpActionLive}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{CorpActionLive}, obj::JSON3.Object)
        CorpActionLive(
            String(get(obj, :id, "")),
            get(obj, :status, nothing),
            String(get(obj, :started_at, "")),
            String(get(obj, :name, "")),
            String(get(obj, :icon, "")),
        )
    end

    _opt_live(::Nothing) = nothing
    _opt_live(v) = StructTypes.construct(CorpActionLive, v)

    struct CorpActionItem
        id::String
        date::String
        date_str::String
        date_type::String
        date_zone::String
        act_type::String
        act_desc::String
        action::String
        recent::Bool
        is_delay::Bool
        delay_content::String
        live::Union{CorpActionLive,Nothing}
        security::Any              # 通常为 null，保留原值
    end
    StructTypes.StructType(::Type{CorpActionItem}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{CorpActionItem}, obj::JSON3.Object)
        CorpActionItem(
            String(get(obj, :id, "")),
            String(get(obj, :date, "")),
            String(get(obj, :date_str, "")),
            String(get(obj, :date_type, "")),
            String(get(obj, :date_zone, "")),
            String(get(obj, :act_type, "")),
            String(get(obj, :act_desc, "")),
            String(get(obj, :action, "")),
            Bool(get(obj, :recent, false)),
            Bool(get(obj, :is_delay, false)),
            String(get(obj, :delay_content, "")),
            _opt_live(get(obj, :live, nothing)),
            get(obj, :security, nothing),
        )
    end

    struct CorpActions
        items::Vector{CorpActionItem}
    end
    StructTypes.StructType(::Type{CorpActions}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{CorpActions}, obj::JSON3.Object)
        items = if haskey(obj, :items) && !isnothing(obj.items)
            [StructTypes.construct(CorpActionItem, x) for x in obj.items]
        else
            CorpActionItem[]
        end
        CorpActions(items)
    end

    # ── invest_relation ────────────────────────────────────────────────

    struct InvestSecurity
        company_id::String
        company_name::String
        company_name_en::String
        company_name_zhcn::String
        symbol::String
        currency::String
        percent_of_shares::Union{Dec64,Nothing}
        shares_rank::String
        shares_value::Union{Dec64,Nothing}
    end
    StructTypes.StructType(::Type{InvestSecurity}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{InvestSecurity}, obj::JSON3.Object)
        InvestSecurity(
            String(get(obj, :company_id, "")),
            String(get(obj, :company_name, "")),
            String(get(obj, :company_name_en, "")),
            String(get(obj, :company_name_zhcn, "")),
            counter_id_to_symbol(String(get(obj, :counter_id, ""))),
            String(get(obj, :currency, "")),
            _parse_optional_decimal(get(obj, :percent_of_shares, nothing)),
            String(get(obj, :shares_rank, "")),
            _parse_optional_decimal(get(obj, :shares_value, nothing)),
        )
    end

    struct InvestRelations
        forward_url::String
        invest_securities::Vector{InvestSecurity}
    end
    StructTypes.StructType(::Type{InvestRelations}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{InvestRelations}, obj::JSON3.Object)
        sec = if haskey(obj, :invest_securities) && !isnothing(obj.invest_securities)
            [StructTypes.construct(InvestSecurity, x) for x in obj.invest_securities]
        else
            InvestSecurity[]
        end
        InvestRelations(String(get(obj, :forward_url, "")), sec)
    end

    # ── operating ──────────────────────────────────────────────────────

    struct OperatingIndicator
        field_name::String
        indicator_name::String
        indicator_value::String
        yoy::Union{Dec64,Nothing}
    end
    StructTypes.StructType(::Type{OperatingIndicator}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{OperatingIndicator}, obj::JSON3.Object)
        OperatingIndicator(
            String(get(obj, :field_name, "")),
            String(get(obj, :indicator_name, "")),
            String(get(obj, :indicator_value, "")),
            _parse_optional_decimal(get(obj, :yoy, nothing)),
        )
    end

    struct OperatingFinancial
        code::String
        symbol::String                       # 由 counter_id 转换（如 ST/US/AAPL → AAPL.US）
        currency::String
        name::String
        region::String
        report::String
        report_txt::String
        indicators::Vector{OperatingIndicator}
    end
    StructTypes.StructType(::Type{OperatingFinancial}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{OperatingFinancial}, obj::JSON3.Object)
        inds = if haskey(obj, :indicators) && !isnothing(obj.indicators)
            [StructTypes.construct(OperatingIndicator, x) for x in obj.indicators]
        else
            OperatingIndicator[]
        end
        OperatingFinancial(
            String(get(obj, :code, "")),
            counter_id_to_symbol(String(get(obj, :counter_id, ""))),
            String(get(obj, :currency, "")),
            String(get(obj, :name, "")),
            String(get(obj, :region, "")),
            String(get(obj, :report, "")),
            String(get(obj, :report_txt, "")),
            inds,
        )
    end

    struct OperatingItem
        id::String
        report::String
        title::String
        txt::String
        latest::Bool
        keywords::Vector{Any}
        web_url::String
        financial::OperatingFinancial
    end
    StructTypes.StructType(::Type{OperatingItem}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{OperatingItem}, obj::JSON3.Object)
        kws = if haskey(obj, :keywords) && !isnothing(obj.keywords)
            Any[k for k in obj.keywords]
        else
            Any[]
        end
        OperatingItem(
            String(get(obj, :id, "")),
            String(get(obj, :report, "")),
            String(get(obj, :title, "")),
            String(get(obj, :txt, "")),
            Bool(get(obj, :latest, false)),
            kws,
            String(get(obj, :web_url, "")),
            StructTypes.construct(OperatingFinancial, obj.financial),
        )
    end

    struct OperatingList
        list::Vector{OperatingItem}
    end
    StructTypes.StructType(::Type{OperatingList}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{OperatingList}, obj::JSON3.Object)
        items = if haskey(obj, :list) && !isnothing(obj.list)
            [StructTypes.construct(OperatingItem, x) for x in obj.list]
        else
            OperatingItem[]
        end
        OperatingList(items)
    end

    # ── buyback ────────────────────────────────────────────────────────

    struct RecentBuybacks
        currency::String
        net_buyback_ttm::Union{Dec64,Nothing}
        net_buyback_yield_ttm::Union{Dec64,Nothing}
    end
    StructTypes.StructType(::Type{RecentBuybacks}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{RecentBuybacks}, obj::JSON3.Object)
        RecentBuybacks(
            String(get(obj, :currency, "")),
            _parse_optional_decimal(get(obj, :net_buyback_ttm, nothing)),
            _parse_optional_decimal(get(obj, :net_buyback_yield_ttm, nothing)),
        )
    end

    _opt_recent(::Nothing) = nothing
    _opt_recent(v) = StructTypes.construct(RecentBuybacks, v)

    struct BuybackHistoryItem
        fiscal_year::String
        fiscal_year_range::String
        net_buyback::Union{Dec64,Nothing}
        net_buyback_yield::Union{Dec64,Nothing}
        net_buyback_growth_rate::Union{Dec64,Nothing}
        currency::String
    end
    StructTypes.StructType(::Type{BuybackHistoryItem}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{BuybackHistoryItem}, obj::JSON3.Object)
        BuybackHistoryItem(
            String(get(obj, :fiscal_year, "")),
            String(get(obj, :fiscal_year_range, "")),
            _parse_optional_decimal(get(obj, :net_buyback, nothing)),
            _parse_optional_decimal(get(obj, :net_buyback_yield, nothing)),
            _parse_optional_decimal(get(obj, :net_buyback_growth_rate, nothing)),
            String(get(obj, :currency, "")),
        )
    end

    struct BuybackRatios
        net_buyback_payout_ratio::Union{Dec64,Nothing}
        net_buyback_to_cashflow_ratio::Union{Dec64,Nothing}
    end
    StructTypes.StructType(::Type{BuybackRatios}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{BuybackRatios}, obj::JSON3.Object)
        BuybackRatios(
            _parse_optional_decimal(get(obj, :net_buyback_payout_ratio, nothing)),
            _parse_optional_decimal(get(obj, :net_buyback_to_cashflow_ratio, nothing)),
        )
    end

    struct BuybackData
        recent_buybacks::Union{RecentBuybacks,Nothing}
        buyback_history::Vector{BuybackHistoryItem}
        buyback_ratios::Vector{BuybackRatios}
    end
    StructTypes.StructType(::Type{BuybackData}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{BuybackData}, obj::JSON3.Object)
        history = if haskey(obj, :buyback_history) && !isnothing(obj.buyback_history)
            [StructTypes.construct(BuybackHistoryItem, x) for x in obj.buyback_history]
        else
            BuybackHistoryItem[]
        end
        ratios = if haskey(obj, :buyback_ratios) && !isnothing(obj.buyback_ratios)
            [StructTypes.construct(BuybackRatios, x) for x in obj.buyback_ratios]
        else
            BuybackRatios[]
        end
        BuybackData(_opt_recent(get(obj, :recent_buybacks, nothing)), history, ratios)
    end

    # ── ratings ────────────────────────────────────────────────────────

    struct RatingLeafIndicator
        name::String
        value::String
        value_type::String
        score::Any                 # API 可能返回 int / float / null
        letter::String
    end
    StructTypes.StructType(::Type{RatingLeafIndicator}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{RatingLeafIndicator}, obj::JSON3.Object)
        RatingLeafIndicator(
            String(get(obj, :name, "")),
            String(get(obj, :value, "")),
            String(get(obj, :value_type, "")),
            get(obj, :score, nothing),
            String(get(obj, :letter, "")),
        )
    end

    struct RatingIndicator
        name::String
        score::Any
        letter::String
    end
    StructTypes.StructType(::Type{RatingIndicator}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{RatingIndicator}, obj::JSON3.Object)
        RatingIndicator(
            String(get(obj, :name, "")),
            get(obj, :score, nothing),
            String(get(obj, :letter, "")),
        )
    end

    struct RatingSubIndicatorGroup
        indicator::RatingIndicator
        sub_indicators::Vector{RatingLeafIndicator}
    end
    StructTypes.StructType(::Type{RatingSubIndicatorGroup}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{RatingSubIndicatorGroup}, obj::JSON3.Object)
        subs = if haskey(obj, :sub_indicators) && !isnothing(obj.sub_indicators)
            [StructTypes.construct(RatingLeafIndicator, x) for x in obj.sub_indicators]
        else
            RatingLeafIndicator[]
        end
        RatingSubIndicatorGroup(StructTypes.construct(RatingIndicator, obj.indicator), subs)
    end

    struct RatingCategory
        kind::Int
        sub_indicators::Vector{RatingSubIndicatorGroup}
    end
    StructTypes.StructType(::Type{RatingCategory}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{RatingCategory}, obj::JSON3.Object)
        groups = if haskey(obj, :sub_indicators) && !isnothing(obj.sub_indicators)
            [StructTypes.construct(RatingSubIndicatorGroup, x) for x in obj.sub_indicators]
        else
            RatingSubIndicatorGroup[]
        end
        RatingCategory(Int(get(obj, :type, 0)), groups)
    end

    struct StockRatings
        style_txt_name::String
        scale_txt_name::String
        report_period_txt::String
        multi_score::Any
        multi_letter::String
        multi_score_change::Int
        industry_name::String
        industry_rank::Any
        industry_total::Any
        industry_mean_score::Any
        industry_median_score::Any
        ratings::Vector{RatingCategory}
    end
    StructTypes.StructType(::Type{StockRatings}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{StockRatings}, obj::JSON3.Object)
        cats = if haskey(obj, :ratings) && !isnothing(obj.ratings)
            [StructTypes.construct(RatingCategory, x) for x in obj.ratings]
        else
            RatingCategory[]
        end
        StockRatings(
            String(get(obj, :style_txt_name, "")),
            String(get(obj, :scale_txt_name, "")),
            String(get(obj, :report_period_txt, "")),
            get(obj, :multi_score, nothing),
            String(get(obj, :multi_letter, "")),
            Int(get(obj, :multi_score_change, 0)),
            String(get(obj, :industry_name, "")),
            get(obj, :industry_rank, nothing),
            get(obj, :industry_total, nothing),
            get(obj, :industry_mean_score, nothing),
            get(obj, :industry_median_score, nothing),
            cats,
        )
    end

    # ════════════════════════════════════════════════════════════════════
    # v4.2.0 新增类型
    # ════════════════════════════════════════════════════════════════════

    # ── business_segments ──────────────────────────────────────────────

    struct BusinessSegmentItem
        name::String
        percent::String
    end
    StructTypes.StructType(::Type{BusinessSegmentItem}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{BusinessSegmentItem}, obj::JSON3.Object) =
        BusinessSegmentItem(String(get(obj, :name, "")), String(get(obj, :percent, "")))

    struct BusinessSegments
        date::String
        total::String
        currency::String
        business::Vector{BusinessSegmentItem}
    end
    StructTypes.StructType(::Type{BusinessSegments}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{BusinessSegments}, obj::JSON3.Object)
        items = if haskey(obj, :business) && !isnothing(obj.business)
            [StructTypes.construct(BusinessSegmentItem, x) for x in obj.business]
        else
            BusinessSegmentItem[]
        end
        BusinessSegments(
            String(get(obj, :date,     "")),
            String(get(obj, :total,    "")),
            String(get(obj, :currency, "")),
            items,
        )
    end

    struct BusinessSegmentHistoryItem
        name::String
        percent::String
        value::String
    end
    StructTypes.StructType(::Type{BusinessSegmentHistoryItem}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{BusinessSegmentHistoryItem}, obj::JSON3.Object) =
        BusinessSegmentHistoryItem(
            String(get(obj, :name,    "")),
            String(get(obj, :percent, "")),
            String(get(obj, :value,   "")),
        )

    struct BusinessSegmentsHistoricalItem
        date::String
        total::String
        currency::String
        business::Vector{BusinessSegmentHistoryItem}
        regionals::Vector{BusinessSegmentHistoryItem}
    end
    StructTypes.StructType(::Type{BusinessSegmentsHistoricalItem}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{BusinessSegmentsHistoricalItem}, obj::JSON3.Object)
        bs = if haskey(obj, :business) && !isnothing(obj.business)
            [StructTypes.construct(BusinessSegmentHistoryItem, x) for x in obj.business]
        else
            BusinessSegmentHistoryItem[]
        end
        rs = if haskey(obj, :regionals) && !isnothing(obj.regionals)
            [StructTypes.construct(BusinessSegmentHistoryItem, x) for x in obj.regionals]
        else
            BusinessSegmentHistoryItem[]
        end
        BusinessSegmentsHistoricalItem(
            String(get(obj, :date,     "")),
            String(get(obj, :total,    "")),
            String(get(obj, :currency, "")),
            bs, rs,
        )
    end

    struct BusinessSegmentsHistory
        historical::Vector{BusinessSegmentsHistoricalItem}
    end
    StructTypes.StructType(::Type{BusinessSegmentsHistory}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{BusinessSegmentsHistory}, obj::JSON3.Object)
        items = if haskey(obj, :historical) && !isnothing(obj.historical)
            [StructTypes.construct(BusinessSegmentsHistoricalItem, x) for x in obj.historical]
        else
            BusinessSegmentsHistoricalItem[]
        end
        BusinessSegmentsHistory(items)
    end

    # ── institution_rating_views ───────────────────────────────────────

    """
    机构评级历史分布的单条快照。`date` 是 unix 时间戳字符串（API 偶尔返回裸整数，原样保留）。
    """
    struct InstitutionRatingViewItem
        date::String
        buy::String
        over::String
        hold::String
        under::String
        sell::String
        total::String
    end
    StructTypes.StructType(::Type{InstitutionRatingViewItem}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{InstitutionRatingViewItem}, obj::JSON3.Object)
        d = get(obj, :date, "")
        InstitutionRatingViewItem(
            d isa AbstractString ? String(d) : string(d),
            String(get(obj, :buy,   "")),
            String(get(obj, :over,  "")),
            String(get(obj, :hold,  "")),
            String(get(obj, :under, "")),
            String(get(obj, :sell,  "")),
            String(get(obj, :total, "")),
        )
    end

    struct InstitutionRatingViews
        elist::Vector{InstitutionRatingViewItem}
    end
    StructTypes.StructType(::Type{InstitutionRatingViews}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{InstitutionRatingViews}, obj::JSON3.Object)
        items = if haskey(obj, :elist) && !isnothing(obj.elist)
            [StructTypes.construct(InstitutionRatingViewItem, x) for x in obj.elist]
        else
            InstitutionRatingViewItem[]
        end
        InstitutionRatingViews(items)
    end

    # ── industry_rank ──────────────────────────────────────────────────

    struct IndustryRankItem
        name::String
        counter_id::String
        chg::String
        leading_name::String
        leading_ticker::String
        leading_chg::String
        value_name::String
        value_data::String
    end
    StructTypes.StructType(::Type{IndustryRankItem}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{IndustryRankItem}, obj::JSON3.Object) =
        IndustryRankItem(
            String(get(obj, :name,            "")),
            String(get(obj, :counter_id,      "")),
            String(get(obj, :chg,             "")),
            String(get(obj, :leading_name,    "")),
            String(get(obj, :leading_ticker,  "")),
            String(get(obj, :leading_chg,     "")),
            String(get(obj, :value_name,      "")),
            String(get(obj, :value_data,      "")),
        )

    struct IndustryRankGroup
        lists::Vector{IndustryRankItem}
    end
    StructTypes.StructType(::Type{IndustryRankGroup}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{IndustryRankGroup}, obj::JSON3.Object)
        items = if haskey(obj, :lists) && !isnothing(obj.lists)
            [StructTypes.construct(IndustryRankItem, x) for x in obj.lists]
        else
            IndustryRankItem[]
        end
        IndustryRankGroup(items)
    end

    struct IndustryRankResponse
        items::Vector{IndustryRankGroup}
    end
    StructTypes.StructType(::Type{IndustryRankResponse}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{IndustryRankResponse}, obj::JSON3.Object)
        groups = if haskey(obj, :items) && !isnothing(obj.items)
            [StructTypes.construct(IndustryRankGroup, x) for x in obj.items]
        else
            IndustryRankGroup[]
        end
        IndustryRankResponse(groups)
    end

    # ── industry_peers ─────────────────────────────────────────────────

    struct IndustryPeersTop
        name::String
        market::String
    end
    StructTypes.StructType(::Type{IndustryPeersTop}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{IndustryPeersTop}, obj::JSON3.Object) =
        IndustryPeersTop(String(get(obj, :name, "")), String(get(obj, :market, "")))

    """
    递归的行业同业节点（`next` 字段含子节点）。
    """
    struct IndustryPeerNode
        name::String
        counter_id::String
        stock_num::Int
        chg::String
        ytd_chg::String
        next::Vector{IndustryPeerNode}
    end
    StructTypes.StructType(::Type{IndustryPeerNode}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{IndustryPeerNode}, obj::JSON3.Object)
        children = if haskey(obj, :next) && !isnothing(obj.next)
            [StructTypes.construct(IndustryPeerNode, x) for x in obj.next]
        else
            IndustryPeerNode[]
        end
        IndustryPeerNode(
            String(get(obj, :name,       "")),
            String(get(obj, :counter_id, "")),
            Int(get(obj, :stock_num, 0)),
            String(get(obj, :chg,        "")),
            String(get(obj, :ytd_chg,    "")),
            children,
        )
    end

    struct IndustryPeersResponse
        top::IndustryPeersTop
        chain::Union{IndustryPeerNode,Nothing}
    end
    StructTypes.StructType(::Type{IndustryPeersResponse}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{IndustryPeersResponse}, obj::JSON3.Object)
        top_obj = get(obj, :top, nothing)
        top = top_obj === nothing ? IndustryPeersTop("", "") :
                                    StructTypes.construct(IndustryPeersTop, top_obj)
        chain_obj = get(obj, :chain, nothing)
        chain = chain_obj === nothing ? nothing :
                                        StructTypes.construct(IndustryPeerNode, chain_obj)
        IndustryPeersResponse(top, chain)
    end

    # ── financial_report_snapshot ──────────────────────────────────────

    struct SnapshotForecastMetric
        value::String
        yoy::String
        cmp_desc::String
        est_value::String
    end
    StructTypes.StructType(::Type{SnapshotForecastMetric}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{SnapshotForecastMetric}, obj::JSON3.Object) =
        SnapshotForecastMetric(
            String(get(obj, :value,     "")),
            String(get(obj, :yoy,       "")),
            String(get(obj, :cmp_desc,  "")),
            String(get(obj, :est_value, "")),
        )

    struct SnapshotReportedMetric
        value::String
        yoy::String
    end
    StructTypes.StructType(::Type{SnapshotReportedMetric}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{SnapshotReportedMetric}, obj::JSON3.Object) =
        SnapshotReportedMetric(String(get(obj, :value, "")), String(get(obj, :yoy, "")))

    struct FinancialReportSnapshot
        name::String
        ticker::String
        fp_start::String
        fp_end::String
        currency::String
        report_desc::String
        fo_revenue::Union{SnapshotForecastMetric,Nothing}
        fo_ebit::Union{SnapshotForecastMetric,Nothing}
        fo_eps::Union{SnapshotForecastMetric,Nothing}
        fr_revenue::Union{SnapshotReportedMetric,Nothing}
        fr_profit::Union{SnapshotReportedMetric,Nothing}
        fr_operate_cash::Union{SnapshotReportedMetric,Nothing}
        fr_invest_cash::Union{SnapshotReportedMetric,Nothing}
        fr_finance_cash::Union{SnapshotReportedMetric,Nothing}
        fr_total_assets::Union{SnapshotReportedMetric,Nothing}
        fr_total_liability::Union{SnapshotReportedMetric,Nothing}
        fr_roe_ttm::String
        fr_profit_margin::String
        fr_profit_margin_ttm::String
        fr_asset_turn_ttm::String
        fr_leverage_ttm::String
        fr_debt_assets_ratio::String
    end
    StructTypes.StructType(::Type{FinancialReportSnapshot}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{FinancialReportSnapshot}, obj::JSON3.Object)
        _opt_f(k) = let v = get(obj, k, nothing)
            v === nothing ? nothing : StructTypes.construct(SnapshotForecastMetric, v)
        end
        _opt_r(k) = let v = get(obj, k, nothing)
            v === nothing ? nothing : StructTypes.construct(SnapshotReportedMetric, v)
        end
        FinancialReportSnapshot(
            String(get(obj, :name,        "")),
            String(get(obj, :ticker,      "")),
            String(get(obj, :fp_start,    "")),
            String(get(obj, :fp_end,      "")),
            String(get(obj, :currency,    "")),
            String(get(obj, :report_desc, "")),
            _opt_f(:fo_revenue),
            _opt_f(:fo_ebit),
            _opt_f(:fo_eps),
            _opt_r(:fr_revenue),
            _opt_r(:fr_profit),
            _opt_r(:fr_operate_cash),
            _opt_r(:fr_invest_cash),
            _opt_r(:fr_finance_cash),
            _opt_r(:fr_total_assets),
            _opt_r(:fr_total_liability),
            String(get(obj, :fr_roe_ttm,           "")),
            String(get(obj, :fr_profit_margin,     "")),
            String(get(obj, :fr_profit_margin_ttm, "")),
            String(get(obj, :fr_asset_turn_ttm,    "")),
            String(get(obj, :fr_leverage_ttm,      "")),
            String(get(obj, :fr_debt_assets_ratio, "")),
        )
    end

    # ── shareholder_top / shareholder_detail (raw JSON) ────────────────

    """
    `shareholder_top` 的原始 JSON 响应包装。结构因品种而变，保留原 `JSON3.Object`。
    """
    struct ShareholderTopResponse
        data::Any
    end
    StructTypes.StructType(::Type{ShareholderTopResponse}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{ShareholderTopResponse}, obj) = ShareholderTopResponse(obj)

    """
    `shareholder_detail` 的原始 JSON 响应包装。
    """
    struct ShareholderDetailResponse
        data::Any
    end
    StructTypes.StructType(::Type{ShareholderDetailResponse}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{ShareholderDetailResponse}, obj) = ShareholderDetailResponse(obj)

    # ── valuation_comparison ───────────────────────────────────────────

    """
    一条历史估值数据点。`date` 由 unix 秒字符串转 `DateTime` (UTC)。
    """
    struct ValuationHistoryPoint
        date::DateTime
        pe::String
        pb::String
        ps::String
    end
    StructTypes.StructType(::Type{ValuationHistoryPoint}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ValuationHistoryPoint}, obj::JSON3.Object)
        ts_raw = get(obj, :date, 0)
        ts_int = ts_raw isa AbstractString ? parse(Int64, ts_raw) : Int64(ts_raw)
        ValuationHistoryPoint(
            unix2datetime(ts_int),
            String(get(obj, :pe, "")),
            String(get(obj, :pb, "")),
            String(get(obj, :ps, "")),
        )
    end

    """
    一只证券在估值对比中的一行。`symbol` 由 `counter_id` 转换。
    """
    struct ValuationComparisonItem
        symbol::String
        name::String
        currency::String
        market_value::String
        price_close::String
        pe::String
        pb::String
        ps::String
        roe::String
        eps::String
        bps::String
        dps::String
        div_yld::String
        assets::String
        history::Vector{ValuationHistoryPoint}
    end
    StructTypes.StructType(::Type{ValuationComparisonItem}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ValuationComparisonItem}, obj::JSON3.Object)
        hist = if haskey(obj, :history) && !isnothing(obj.history)
            [StructTypes.construct(ValuationHistoryPoint, x) for x in obj.history]
        else
            ValuationHistoryPoint[]
        end
        ValuationComparisonItem(
            counter_id_to_symbol(String(get(obj, :counter_id, ""))),
            String(get(obj, :name,         "")),
            String(get(obj, :currency,     "")),
            String(get(obj, :market_value, "")),
            String(get(obj, :price_close,  "")),
            String(get(obj, :pe,           "")),
            String(get(obj, :pb,           "")),
            String(get(obj, :ps,           "")),
            String(get(obj, :roe,          "")),
            String(get(obj, :eps,          "")),
            String(get(obj, :bps,          "")),
            String(get(obj, :dps,          "")),
            String(get(obj, :div_yld,      "")),
            String(get(obj, :assets,       "")),
            hist,
        )
    end

    struct ValuationComparisonResponse
        list::Vector{ValuationComparisonItem}
    end
    StructTypes.StructType(::Type{ValuationComparisonResponse}) = StructTypes.CustomStruct()
    function StructTypes.construct(::Type{ValuationComparisonResponse}, obj::JSON3.Object)
        items = if haskey(obj, :list) && !isnothing(obj.list)
            [StructTypes.construct(ValuationComparisonItem, x) for x in obj.list]
        else
            ValuationComparisonItem[]
        end
        ValuationComparisonResponse(items)
    end

end # module FundamentalProtocol
