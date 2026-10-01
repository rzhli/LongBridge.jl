# Mutual-fund channel, aligned with upstream openapi v5.2.0 (b2f749a3).
# Numeric strings are preserved; timestamps are Unix seconds. Server-defined
# JSON values remain decoded JSON objects/arrays rather than JSON text.
module FundProtocol

using ..Utils: JSONObject
import ..Utils: construct

export FundNavValue,
    FundPerformancePoint,
    HotFund,
    FundBrief,
    FundFilters,
    FundAssetAllocationItem,
    FundAssetAllocation,
    FundDetail,
    FundAnalysis,
    FundAnalysisDetail,
    FundTrendContrast,
    FundTrend,
    FundNamedContrast,
    FundPerformanceComparison,
    FundAnnualReturn,
    FundQuarterlyReturn,
    FundPerformance,
    FundHolding,
    FundHoldings,
    FundStockHolding,
    FundHoldingPosition,
    FundPositions,
    FundDatedValue,
    FundUnitValue,
    FundPositionDetailValues,
    FundPositionDetail,
    FundPositionPerformance,
    FundPositionProfits,
    FundPositionNav,
    FundDividend,
    FundDividends,
    FundOrder,
    FundOrderKeyword,
    FundOrderStage,
    FundOrderInfo,
    FundOrderDetail,
    FundTransaction,
    FundOrderValidation,
    FundOrderSubmitResponse,
    GetFundsOptions,
    GetFundAnalysisOptions,
    FundPageOptions,
    FundNavRangeOptions,
    GetFundHoldingsOptions,
    GetFundStockHoldingsOptions,
    FundPositionsOptions,
    GetFundPositionOptions,
    GetFundPositionProfitsOptions,
    GetFundPositionDividendsOptions,
    GetFundOrdersOptions,
    GetFundTransactionsOptions,
    ValidateFundOrderOptions,
    SubmitFundOrderOptions

_str(obj, key) = String(get(obj, key, ""))
_i32(obj, key) = Int32(get(obj, key, 0))
function _i64(obj, key)
    value = get(obj, key, 0)
    value isa AbstractString && return something(tryparse(Int64, value), Int64(0))
    Int64(value)
end
_bool(obj, key) = Bool(get(obj, key, false))
_vec(obj, key, ::Type{T}) where {T} = T[construct(T, x) for x in get(obj, key, [])]
function _opt(obj, key, ::Type{T}) where {T}
    value = get(obj, key, nothing)
    isnothing(value) ? nothing : construct(T, value)
end

struct FundNavValue
    change::String
    change_percent::String
    change_percent_format::String
    counter_id::String
    counter_name::String
    currency::String
    date_format::String
    isin::String
    last_update_time::Int64
    value::String
    value_format::String
end
function construct(::Type{FundNavValue}, obj::JSONObject)
    FundNavValue(
        _str(obj, :change),
        _str(obj, :change_percent),
        _str(obj, :change_percent_format),
        _str(obj, :counter_id),
        _str(obj, :counter_name),
        _str(obj, :currency),
        _str(obj, :date_format),
        _str(obj, :isin),
        _i64(obj, :last_update_time),
        _str(obj, :value),
        _str(obj, :value_format),
    )
end

struct FundPerformancePoint
    date::String
    last_done::String
end
function construct(::Type{FundPerformancePoint}, obj::JSONObject)
    FundPerformancePoint(
        _str(obj, :date),
        _str(obj, :last_done),
    )
end

struct HotFund
    asset_class::Int32
    asset_class_name::String
    counter_id::String
    currency::String
    earning_rate::String
    fund_performances::Vector{FundPerformancePoint}
    name::String
    purchase_amount::String
    recommendation_text::String
    risk_level::Int32
    risk_level_name::String
    time_interval::String
end
function construct(::Type{HotFund}, obj::JSONObject)
    HotFund(
        _i32(obj, :asset_class),
        _str(obj, :asset_class_name),
        _str(obj, :counter_id),
        _str(obj, :currency),
        _str(obj, :earning_rate),
        _vec(obj, :fund_performances, FundPerformancePoint),
        _str(obj, :name),
        _str(obj, :purchase_amount),
        _str(obj, :recommendation_text),
        _i32(obj, :risk_level),
        _str(obj, :risk_level_name),
        _str(obj, :time_interval),
    )
end

struct FundBrief
    asset_class::Int32
    asset_class_name::String
    code::String
    counter_id::String
    currency::String
    description::String
    earning_rate::String
    holding::Bool
    isin::String
    name::String
    product::String
    purchase_amount::String
    recommendation_text::String
    risk_level::Int32
    risk_level_name::String
    time_interval::String
    unit_value::String
end
function construct(::Type{FundBrief}, obj::JSONObject)
    FundBrief(
        _i32(obj, :asset_class),
        _str(obj, :asset_class_name),
        _str(obj, :code),
        _str(obj, :counter_id),
        _str(obj, :currency),
        _str(obj, :description),
        _str(obj, :earning_rate),
        _bool(obj, :holding),
        _str(obj, :isin),
        _str(obj, :name),
        _str(obj, :product),
        _str(obj, :purchase_amount),
        _str(obj, :recommendation_text),
        _i32(obj, :risk_level),
        _str(obj, :risk_level_name),
        _str(obj, :time_interval),
        _str(obj, :unit_value),
    )
end

struct FundFilters
    asset_class::Vector{Any}
    company::Vector{Any}
    currency::Vector{Any}
    industry_category_name::Vector{Any}
    risk_level::Vector{Any}
end
function construct(::Type{FundFilters}, obj::JSONObject)
    FundFilters(
        Any[get(obj, :asset_class, [])...],
        Any[get(obj, :company, [])...],
        Any[get(obj, :currency, [])...],
        Any[get(obj, :industry_category_name, [])...],
        Any[get(obj, :risk_level, [])...],
    )
end

struct FundAssetAllocationItem
    code::String
    counter_id::String
    name::String
    position_ratio::String
end
function construct(::Type{FundAssetAllocationItem}, obj::JSONObject)
    FundAssetAllocationItem(
        _str(obj, :code),
        _str(obj, :counter_id),
        _str(obj, :name),
        _str(obj, :position_ratio),
    )
end

struct FundAssetAllocation
    asset_type::Int32
    lists::Vector{FundAssetAllocationItem}
    report_date::String
end
function construct(::Type{FundAssetAllocation}, obj::JSONObject)
    FundAssetAllocation(
        _i32(obj, :asset_type),
        _vec(obj, :lists, FundAssetAllocationItem),
        _str(obj, :report_date),
    )
end

struct FundDetail
    additional_purchase_amount::String
    affirm_day::Int32
    amount_affirm_day::String
    asset_allocation::Union{FundAssetAllocation,Nothing}
    asset_class::Int32
    asset_class_name::String
    bill_purchase_rate::String
    channel::String
    close_period::String
    code::String
    currency::String
    cut_off_time::String
    derivatives::Bool
    done_day::Int32
    excess_return_fee::String
    gst_rate::String
    introduce::String
    is_cash_plus::Bool
    is_complex::Bool
    is_new_cash_plus::Bool
    is_yinghebao::Bool
    isin::String
    manage_rate::String
    manager::String
    min_hold_cash::String
    min_hold_share::String
    min_sell_share::String
    month_raise_day::String
    name::String
    nav_deadline::String
    no_load::Bool
    open_date::String
    open_period::String
    product::String
    product_information_locals::String
    profile::String
    purchasable::Int32
    purchase_affirm_day::String
    purchase_amount::String
    purchase_rate::String
    rating::Int32
    redeemable::Int32
    redemption_advance_day::String
    redemption_amount::String
    redemption_close_period_shows::String
    redemption_done_day::String
    redemption_open_day_shows::String
    risk_level::Int32
    risk_level_name::String
    verify_status::Int32
    virtual_currency::Bool
    year_to_date_yield::String
    ytd_yield_type::Int32
end
function construct(::Type{FundDetail}, obj::JSONObject)
    FundDetail(
        _str(obj, :additional_purchase_amount),
        _i32(obj, :affirm_day),
        _str(obj, :amount_affirm_day),
        _opt(obj, :asset_allocation, FundAssetAllocation),
        _i32(obj, :asset_class),
        _str(obj, :asset_class_name),
        _str(obj, :bill_purchase_rate),
        _str(obj, :channel),
        _str(obj, :close_period),
        _str(obj, :code),
        _str(obj, :currency),
        _str(obj, :cut_off_time),
        _bool(obj, :derivatives),
        _i32(obj, :done_day),
        _str(obj, :excess_return_fee),
        _str(obj, :gst_rate),
        _str(obj, :introduce),
        _bool(obj, :is_cash_plus),
        _bool(obj, :is_complex),
        _bool(obj, :is_new_cash_plus),
        _bool(obj, :is_yinghebao),
        _str(obj, :isin),
        _str(obj, :manage_rate),
        _str(obj, :manager),
        _str(obj, :min_hold_cash),
        _str(obj, :min_hold_share),
        _str(obj, :min_sell_share),
        _str(obj, :month_raise_day),
        _str(obj, :name),
        _str(obj, :nav_deadline),
        _bool(obj, :no_load),
        _str(obj, :open_date),
        _str(obj, :open_period),
        _str(obj, :product),
        _str(obj, :product_information_locals),
        _str(obj, :profile),
        _i32(obj, :purchasable),
        _str(obj, :purchase_affirm_day),
        _str(obj, :purchase_amount),
        _str(obj, :purchase_rate),
        _i32(obj, :rating),
        _i32(obj, :redeemable),
        _str(obj, :redemption_advance_day),
        _str(obj, :redemption_amount),
        _str(obj, :redemption_close_period_shows),
        _str(obj, :redemption_done_day),
        _str(obj, :redemption_open_day_shows),
        _i32(obj, :risk_level),
        _str(obj, :risk_level_name),
        _i32(obj, :verify_status),
        _bool(obj, :virtual_currency),
        _str(obj, :year_to_date_yield),
        _i32(obj, :ytd_yield_type),
    )
end

struct FundAnalysis
    actual_period::Int32
    cost_level::Any
    return_ability::Any
    risk_ability::Any
    updated_at::String
    value_for_money::Any
    visible::Bool
end
function construct(::Type{FundAnalysis}, obj::JSONObject)
    FundAnalysis(
        _i32(obj, :actual_period),
        get(obj, :cost_level, nothing),
        get(obj, :return_ability, nothing),
        get(obj, :risk_ability, nothing),
        _str(obj, :updated_at),
        get(obj, :value_for_money, nothing),
        _bool(obj, :visible),
    )
end

struct FundAnalysisDetail
    actual_period::Int32
    available_periods::Vector{Int32}
    cost_level::Any
    return_ability::Any
    risk_ability::Any
    updated_at::String
    value_for_money::Any
    visible::Bool
end
function construct(::Type{FundAnalysisDetail}, obj::JSONObject)
    FundAnalysisDetail(
        _i32(obj, :actual_period),
        Int32[get(obj, :available_periods, [])...],
        get(obj, :cost_level, nothing),
        get(obj, :return_ability, nothing),
        get(obj, :risk_ability, nothing),
        _str(obj, :updated_at),
        get(obj, :value_for_money, nothing),
        _bool(obj, :visible),
    )
end

struct FundTrendContrast
    benchmark_name::String
    performances::Vector{Any}
end
function construct(::Type{FundTrendContrast}, obj::JSONObject)
    FundTrendContrast(
        _str(obj, :benchmark_name),
        Any[get(obj, :performances, [])...],
    )
end

struct FundTrend
    actual_period::Int32
    available_periods::Vector{Int32}
    category_average_performances::Vector{Any}
    contrast_performances::Union{FundTrendContrast,Nothing}
    fund_performances::Vector{Any}
end
function construct(::Type{FundTrend}, obj::JSONObject)
    FundTrend(
        _i32(obj, :actual_period),
        Int32[get(obj, :available_periods, [])...],
        Any[get(obj, :category_average_performances, [])...],
        _opt(obj, :contrast_performances, FundTrendContrast),
        Any[get(obj, :fund_performances, [])...],
    )
end

struct FundNamedContrast
    name::String
    performances::Vector{Any}
end
function construct(::Type{FundNamedContrast}, obj::JSONObject)
    FundNamedContrast(
        _str(obj, :name),
        Any[get(obj, :performances, [])...],
    )
end

struct FundPerformanceComparison
    contrast_performances::Vector{FundNamedContrast}
    fund_performances::Vector{Any}
end
function construct(::Type{FundPerformanceComparison}, obj::JSONObject)
    FundPerformanceComparison(
        _vec(obj, :contrast_performances, FundNamedContrast),
        Any[get(obj, :fund_performances, [])...],
    )
end

struct FundAnnualReturn
    change_percent::String
    year::Int32
end
function construct(::Type{FundAnnualReturn}, obj::JSONObject)
    FundAnnualReturn(
        _str(obj, :change_percent),
        _i32(obj, :year),
    )
end

struct FundQuarterlyReturn
    change_percent::String
    quarter::Int32
    year::Int32
end
function construct(::Type{FundQuarterlyReturn}, obj::JSONObject)
    FundQuarterlyReturn(
        _str(obj, :change_percent),
        _i32(obj, :quarter),
        _i32(obj, :year),
    )
end

struct FundPerformance
    annualized_return_five::String
    annualized_return_one::String
    annualized_return_ten::String
    annualized_return_three::String
    annualized_return_two::String
    counter_id::String
    fund_name::String
    performance_rank_five_years::Int32
    performance_rank_one_day::Int32
    performance_rank_one_month::Int32
    performance_rank_one_week::Int32
    performance_rank_one_year::Int32
    performance_rank_six_months::Int32
    performance_rank_ten_years::Int32
    performance_rank_three_months::Int32
    performance_rank_three_years::Int32
    performance_rank_two_years::Int32
    performance_rank_ytd::Int32
    performance_return_five_years::String
    performance_return_one_day::String
    performance_return_one_month::String
    performance_return_one_week::String
    performance_return_one_year::String
    performance_return_six_months::String
    performance_return_ten_years::String
    performance_return_three_months::String
    performance_return_three_years::String
    performance_return_two_years::String
    performance_return_ytd::String
    performance_total_five_years::Int32
    performance_total_one_day::Int32
    performance_total_one_month::Int32
    performance_total_one_week::Int32
    performance_total_one_year::Int32
    performance_total_six_months::Int32
    performance_total_ten_years::Int32
    performance_total_three_months::Int32
    performance_total_three_years::Int32
    performance_total_two_years::Int32
    performance_total_ytd::Int32
    seven_days_annualized::String
    ten_thousand_price::String
    update_time::Int64
end
function construct(::Type{FundPerformance}, obj::JSONObject)
    FundPerformance(
        _str(obj, :annualized_return_five),
        _str(obj, :annualized_return_one),
        _str(obj, :annualized_return_ten),
        _str(obj, :annualized_return_three),
        _str(obj, :annualized_return_two),
        _str(obj, :counter_id),
        _str(obj, :fund_name),
        _i32(obj, :performance_rank_five_years),
        _i32(obj, :performance_rank_one_day),
        _i32(obj, :performance_rank_one_month),
        _i32(obj, :performance_rank_one_week),
        _i32(obj, :performance_rank_one_year),
        _i32(obj, :performance_rank_six_months),
        _i32(obj, :performance_rank_ten_years),
        _i32(obj, :performance_rank_three_months),
        _i32(obj, :performance_rank_three_years),
        _i32(obj, :performance_rank_two_years),
        _i32(obj, :performance_rank_ytd),
        _str(obj, :performance_return_five_years),
        _str(obj, :performance_return_one_day),
        _str(obj, :performance_return_one_month),
        _str(obj, :performance_return_one_week),
        _str(obj, :performance_return_one_year),
        _str(obj, :performance_return_six_months),
        _str(obj, :performance_return_ten_years),
        _str(obj, :performance_return_three_months),
        _str(obj, :performance_return_three_years),
        _str(obj, :performance_return_two_years),
        _str(obj, :performance_return_ytd),
        _i32(obj, :performance_total_five_years),
        _i32(obj, :performance_total_one_day),
        _i32(obj, :performance_total_one_month),
        _i32(obj, :performance_total_one_week),
        _i32(obj, :performance_total_one_year),
        _i32(obj, :performance_total_six_months),
        _i32(obj, :performance_total_ten_years),
        _i32(obj, :performance_total_three_months),
        _i32(obj, :performance_total_three_years),
        _i32(obj, :performance_total_two_years),
        _i32(obj, :performance_total_ytd),
        _str(obj, :seven_days_annualized),
        _str(obj, :ten_thousand_price),
        _i64(obj, :update_time),
    )
end

struct FundHolding
    bond_type::String
    bond_type_name::String
    country_name::String
    holding_type::String
    industry_name::String
    market_value::String
    maturity_date::String
    name::String
    share_change::String
    share_change_percent::String
    shares::String
    weighting::String
end
function construct(::Type{FundHolding}, obj::JSONObject)
    FundHolding(
        _str(obj, :bond_type),
        _str(obj, :bond_type_name),
        _str(obj, :country_name),
        _str(obj, :holding_type),
        _str(obj, :industry_name),
        _str(obj, :market_value),
        _str(obj, :maturity_date),
        _str(obj, :name),
        _str(obj, :share_change),
        _str(obj, :share_change_percent),
        _str(obj, :shares),
        _str(obj, :weighting),
    )
end

struct FundHoldings
    holdings::Vector{FundHolding}
    report_date::String
    weighting::String
end
function construct(::Type{FundHoldings}, obj::JSONObject)
    FundHoldings(
        _vec(obj, :holdings, FundHolding),
        _str(obj, :report_date),
        _str(obj, :weighting),
    )
end

struct FundStockHolding
    code::String
    counter_id::String
    currency::String
    name::String
    position_ratio::String
    report_date::String
end
function construct(::Type{FundStockHolding}, obj::JSONObject)
    FundStockHolding(
        _str(obj, :code),
        _str(obj, :counter_id),
        _str(obj, :currency),
        _str(obj, :name),
        _str(obj, :position_ratio),
        _str(obj, :report_date),
    )
end

struct FundHoldingPosition
    amount::String
    counter_id::String
    currency::String
    freeze_units::String
    holding_profit::String
    holding_units::String
    name::String
    recent_profit::String
    recent_trading_day::Int64
    sum_recent_profit::String
end
function construct(::Type{FundHoldingPosition}, obj::JSONObject)
    FundHoldingPosition(
        _str(obj, :amount),
        _str(obj, :counter_id),
        _str(obj, :currency),
        _str(obj, :freeze_units),
        _str(obj, :holding_profit),
        _str(obj, :holding_units),
        _str(obj, :name),
        _str(obj, :recent_profit),
        _i64(obj, :recent_trading_day),
        _str(obj, :sum_recent_profit),
    )
end

struct FundPositions
    account_channel::String
    list::Vector{FundHoldingPosition}
    pending_buy_orders::String
    recent_trading_day::Int64
    sold_pending_credit_orders::String
end
function construct(::Type{FundPositions}, obj::JSONObject)
    FundPositions(
        _str(obj, :account_channel),
        _vec(obj, :list, FundHoldingPosition),
        _str(obj, :pending_buy_orders),
        _i64(obj, :recent_trading_day),
        _str(obj, :sold_pending_credit_orders),
    )
end

struct FundDatedValue
    date::Int64
    value::String
end
function construct(::Type{FundDatedValue}, obj::JSONObject)
    FundDatedValue(
        _i64(obj, :date),
        _str(obj, :value),
    )
end

struct FundUnitValue
    date::Int64
    day_increase_rate::String
    total_value::String
    unit_value::String
end
function construct(::Type{FundUnitValue}, obj::JSONObject)
    FundUnitValue(
        _i64(obj, :date),
        _str(obj, :day_increase_rate),
        _str(obj, :total_value),
        _str(obj, :unit_value),
    )
end

struct FundPositionDetailValues
    amount::String
    currency::String
    holding_cost::String
    holding_profit::String
    holding_profit_rate::String
    holding_units::String
    holding_value::String
    pending_buy_value::String
    pending_sell_value::String
    profit_amount_accum_td::String
    profit_amount_accum_td_rate::String
    recent_profit::String
    recent_tradingday::Int64
    recent_unit_value::String
    sold_pending_confirm_units::String
end
function construct(::Type{FundPositionDetailValues}, obj::JSONObject)
    FundPositionDetailValues(
        _str(obj, :amount),
        _str(obj, :currency),
        _str(obj, :holding_cost),
        _str(obj, :holding_profit),
        _str(obj, :holding_profit_rate),
        _str(obj, :holding_units),
        _str(obj, :holding_value),
        _str(obj, :pending_buy_value),
        _str(obj, :pending_sell_value),
        _str(obj, :profit_amount_accum_td),
        _str(obj, :profit_amount_accum_td_rate),
        _str(obj, :recent_profit),
        _i64(obj, :recent_tradingday),
        _str(obj, :recent_unit_value),
        _str(obj, :sold_pending_confirm_units),
    )
end

struct FundPositionDetail
    detail_values::Union{FundPositionDetailValues,Nothing}
    sum_profit::Vector{FundDatedValue}
    ut_value::Vector{FundUnitValue}
end
function construct(::Type{FundPositionDetail}, obj::JSONObject)
    FundPositionDetail(
        _opt(obj, :detail_values, FundPositionDetailValues),
        _vec(obj, :sum_profit, FundDatedValue),
        _vec(obj, :ut_value, FundUnitValue),
    )
end

struct FundPositionPerformance
    annualized_return_five::String
    annualized_return_one::String
    annualized_return_ten::String
    annualized_return_three::String
    annualized_return_two::String
    counter_id::String
    fund_name::String
    performance_return_five_years::String
    performance_return_one_day::String
    performance_return_one_month::String
    performance_return_one_week::String
    performance_return_one_year::String
    performance_return_six_months::String
    performance_return_ten_years::String
    performance_return_three_months::String
    performance_return_three_years::String
    performance_return_two_years::String
    performance_return_ytd::String
    update_time::Int64
end
function construct(::Type{FundPositionPerformance}, obj::JSONObject)
    FundPositionPerformance(
        _str(obj, :annualized_return_five),
        _str(obj, :annualized_return_one),
        _str(obj, :annualized_return_ten),
        _str(obj, :annualized_return_three),
        _str(obj, :annualized_return_two),
        _str(obj, :counter_id),
        _str(obj, :fund_name),
        _str(obj, :performance_return_five_years),
        _str(obj, :performance_return_one_day),
        _str(obj, :performance_return_one_month),
        _str(obj, :performance_return_one_week),
        _str(obj, :performance_return_one_year),
        _str(obj, :performance_return_six_months),
        _str(obj, :performance_return_ten_years),
        _str(obj, :performance_return_three_months),
        _str(obj, :performance_return_three_years),
        _str(obj, :performance_return_two_years),
        _str(obj, :performance_return_ytd),
        _i64(obj, :update_time),
    )
end

struct FundPositionProfits
    currency::String
    history_value::Vector{FundDatedValue}
    last_update_time::Int64
    sum_profit::String
end
function construct(::Type{FundPositionProfits}, obj::JSONObject)
    FundPositionProfits(
        _str(obj, :currency),
        _vec(obj, :history_value, FundDatedValue),
        _i64(obj, :last_update_time),
        _str(obj, :sum_profit),
    )
end

struct FundPositionNav
    change::String
    change_percent::String
    counter_id::String
    counter_name::String
    last_update_time::Int64
    value::String
end
function construct(::Type{FundPositionNav}, obj::JSONObject)
    FundPositionNav(
        _str(obj, :change),
        _str(obj, :change_percent),
        _str(obj, :counter_id),
        _str(obj, :counter_name),
        _i64(obj, :last_update_time),
        _str(obj, :value),
    )
end

struct FundDividend
    amount::String
    counter_id::String
    currency::String
    date::Int64
    div_method::String
    name::String
end
function construct(::Type{FundDividend}, obj::JSONObject)
    FundDividend(
        _str(obj, :amount),
        _str(obj, :counter_id),
        _str(obj, :currency),
        _i64(obj, :date),
        _str(obj, :div_method),
        _str(obj, :name),
    )
end

struct FundDividends
    currency::String
    div_cash_infos::Vector{FundDividend}
    lastest_date::Int64
    total_div_cash::String
end
function construct(::Type{FundDividends}, obj::JSONObject)
    FundDividends(
        _str(obj, :currency),
        _vec(obj, :div_cash_infos, FundDividend),
        _i64(obj, :lastest_date),
        _str(obj, :total_div_cash),
    )
end

struct FundOrder
    action::String
    amount::String
    counter_id::String
    created_at::Int64
    currency::String
    fund_name::String
    id::Int64
    is_auto::Bool
    net_worth::String
    product_type::String
    state::String
    state_desc::String
    units::String
end
function construct(::Type{FundOrder}, obj::JSONObject)
    FundOrder(
        _str(obj, :action),
        _str(obj, :amount),
        _str(obj, :counter_id),
        _i64(obj, :created_at),
        _str(obj, :currency),
        _str(obj, :fund_name),
        _i64(obj, :id),
        _bool(obj, :is_auto),
        _str(obj, :net_worth),
        _str(obj, :product_type),
        _str(obj, :state),
        _str(obj, :state_desc),
        _str(obj, :units),
    )
end

struct FundOrderKeyword
    content::String
    group::String
    key::String
    line_strategy::String
    title::String
end
function construct(::Type{FundOrderKeyword}, obj::JSONObject)
    FundOrderKeyword(
        _str(obj, :content),
        _str(obj, :group),
        _str(obj, :key),
        _str(obj, :line_strategy),
        _str(obj, :title),
    )
end

struct FundOrderStage
    desc::String
    key::String
    link::String
    link_text::String
    progress::String
    stage::String
end
function construct(::Type{FundOrderStage}, obj::JSONObject)
    FundOrderStage(
        _str(obj, :desc),
        _str(obj, :key),
        _str(obj, :link),
        _str(obj, :link_text),
        _str(obj, :progress),
        _str(obj, :stage),
    )
end

struct FundOrderInfo
    aaid::Int64
    account_channel::String
    action::String
    amount::String
    channel::String
    counter_id::String
    created_at::Int64
    currency::String
    dividend_option::String
    eq_at::Int64
    fee::String
    fund_name::String
    fund_source::String
    histories::String
    id::Int64
    message::String
    net_worth::String
    price_at::Int64
    processed_at::Int64
    product_type::String
    repurchaseable::Bool
    sale_proceeds::String
    sales_charge::String
    sales_price::String
    sales_unit::String
    state::String
    state_desc::String
    status::Int32
    status_ex::Int32
    t_description::String
    time_partition::String
    total_amount::String
    transaction_at::Int64
    units::String
    withdraw_at::Int64
    withdrawable::Bool
end
function construct(::Type{FundOrderInfo}, obj::JSONObject)
    FundOrderInfo(
        _i64(obj, :aaid),
        _str(obj, :account_channel),
        _str(obj, :action),
        _str(obj, :amount),
        _str(obj, :channel),
        _str(obj, :counter_id),
        _i64(obj, :created_at),
        _str(obj, :currency),
        _str(obj, :dividend_option),
        _i64(obj, :eq_at),
        _str(obj, :fee),
        _str(obj, :fund_name),
        _str(obj, :fund_source),
        _str(obj, :histories),
        _i64(obj, :id),
        _str(obj, :message),
        _str(obj, :net_worth),
        _i64(obj, :price_at),
        _i64(obj, :processed_at),
        _str(obj, :product_type),
        _bool(obj, :repurchaseable),
        _str(obj, :sale_proceeds),
        _str(obj, :sales_charge),
        _str(obj, :sales_price),
        _str(obj, :sales_unit),
        _str(obj, :state),
        _str(obj, :state_desc),
        _i32(obj, :status),
        _i32(obj, :status_ex),
        _str(obj, :t_description),
        _str(obj, :time_partition),
        _str(obj, :total_amount),
        _i64(obj, :transaction_at),
        _str(obj, :units),
        _i64(obj, :withdraw_at),
        _bool(obj, :withdrawable),
    )
end

struct FundOrderDetail
    keywords::Vector{FundOrderKeyword}
    order::Union{FundOrderInfo,Nothing}
    stages::Vector{FundOrderStage}
end
function construct(::Type{FundOrderDetail}, obj::JSONObject)
    FundOrderDetail(
        _vec(obj, :keywords, FundOrderKeyword),
        _opt(obj, :order, FundOrderInfo),
        _vec(obj, :stages, FundOrderStage),
    )
end

struct FundTransaction
    amount::String
    category::String
    created_at::Int64
    currency::String
    description::String
    detail_created_at::Int64
    detail_type::String
    done_at::Int64
    quantity_description::String
    redirect_page::String
    redirect_page_v2::String
    ref_no::String
    stock_quantity::String
    tx_type::String
    type_name::String
end
function construct(::Type{FundTransaction}, obj::JSONObject)
    FundTransaction(
        _str(obj, :amount),
        _str(obj, :category),
        _i64(obj, :created_at),
        _str(obj, :currency),
        _str(obj, :description),
        _i64(obj, :detail_created_at),
        _str(obj, :detail_type),
        _i64(obj, :done_at),
        _str(obj, :quantity_description),
        _str(obj, :redirect_page),
        _str(obj, :redirect_page_v2),
        _str(obj, :ref_no),
        _str(obj, :stock_quantity),
        _str(obj, :tx_type),
        _str(obj, :type_name),
    )
end

struct FundOrderValidation
    auth_token::String
    eval_address::String
    fund_risk_level::Int32
    msg::String
    user_pi::Int32
    user_risk_level::Int32
end
function construct(::Type{FundOrderValidation}, obj::JSONObject)
    FundOrderValidation(
        _str(obj, :auth_token),
        _str(obj, :eval_address),
        _i32(obj, :fund_risk_level),
        _str(obj, :msg),
        _i32(obj, :user_pi),
        _i32(obj, :user_risk_level),
    )
end

struct FundOrderSubmitResponse
    action::String
    amount::String
    counter_id::String
    created_at::Int64
    fund_name::String
    id::Int64
    msg::String
    status::Int32
    units::String
end
function construct(::Type{FundOrderSubmitResponse}, obj::JSONObject)
    FundOrderSubmitResponse(
        _str(obj, :action),
        _str(obj, :amount),
        _str(obj, :counter_id),
        _i64(obj, :created_at),
        _str(obj, :fund_name),
        _i64(obj, :id),
        _str(obj, :msg),
        _i32(obj, :status),
        _str(obj, :units),
    )
end

# Request options: omitted fields use server defaults. `end_` is sent as `end`.

Base.@kwdef struct GetFundsOptions
    filter::Union{Any,Nothing} = nothing
    quick_ids::Vector{Int64} = Int64[]
    time_interval::Vector{String} = String[]
end

Base.@kwdef struct GetFundAnalysisOptions
    period::Union{Int32,Nothing} = nothing
end

Base.@kwdef struct FundPageOptions
    page::Union{Int32,Nothing} = nothing
    size::Union{Int32,Nothing} = nothing
end

Base.@kwdef struct FundNavRangeOptions
    month_before::Union{Int32,Nothing} = nothing
    year_before::Union{Int32,Nothing} = nothing
end

Base.@kwdef struct GetFundHoldingsOptions
    scene::Union{Int32,Nothing} = nothing
end

Base.@kwdef struct GetFundStockHoldingsOptions
    limit::Union{Int32,Nothing} = nothing
end

Base.@kwdef struct FundPositionsOptions
    account_channel::Union{String,Nothing} = nothing
    aaid::Union{Int64,Nothing} = nothing
end

Base.@kwdef struct GetFundPositionOptions
    account_channel::Union{String,Nothing} = nothing
    aaid::Union{Int64,Nothing} = nothing
    start::Union{String,Nothing} = nothing
    end_::Union{String,Nothing} = nothing
end

Base.@kwdef struct GetFundPositionProfitsOptions
    account_channel::Union{String,Nothing} = nothing
    aaid::Union{Int64,Nothing} = nothing
    start::Union{String,Nothing} = nothing
    end_::Union{String,Nothing} = nothing
    page::Union{Int32,Nothing} = nothing
    size::Union{Int32,Nothing} = nothing
end

Base.@kwdef struct GetFundPositionDividendsOptions
    account_channel::Union{String,Nothing} = nothing
    aaid::Union{Int64,Nothing} = nothing
    currency::Union{String,Nothing} = nothing
    start::Union{Int64,Nothing} = nothing
    end_::Union{Int64,Nothing} = nothing
    page::Union{Int32,Nothing} = nothing
    size::Union{Int32,Nothing} = nothing
end

Base.@kwdef struct GetFundOrdersOptions
    counter_ids::Vector{String} = String[]
    actions::Union{String,Nothing} = nothing
    states::Union{String,Nothing} = nothing
    currency::Union{String,Nothing} = nothing
    start::Union{Int64,Nothing} = nothing
    end_::Union{Int64,Nothing} = nothing
    page::Union{Int32,Nothing} = nothing
    size::Union{Int32,Nothing} = nothing
end

Base.@kwdef struct GetFundTransactionsOptions
    account_channel::Union{String,Nothing} = nothing
    business_type::Union{String,Nothing} = nothing
    category::Union{String,Nothing} = nothing
    currencies::Union{String,Nothing} = nothing
    start::Union{Int64,Nothing} = nothing
    end_::Union{Int64,Nothing} = nothing
    page::Union{Int32,Nothing} = nothing
    size::Union{Int32,Nothing} = nothing
end

Base.@kwdef struct ValidateFundOrderOptions
    counter_id::String
    action::String
    currency::String
    amount::Union{String,Nothing} = nothing
    units::Union{String,Nothing} = nothing
    dividend_option::Union{Int32,Nothing} = nothing
    fund_source::Union{Int32,Nothing} = nothing
    account_channel::Union{String,Nothing} = nothing
end

Base.@kwdef struct SubmitFundOrderOptions
    counter_id::String
    action::String
    currency::String
    amount::Union{String,Nothing} = nothing
    units::Union{String,Nothing} = nothing
    dividend_option::Union{Int32,Nothing} = nothing
    fee::Union{String,Nothing} = nothing
    is_sell_all::Union{Bool,Nothing} = nothing
    remark::Union{String,Nothing} = nothing
    trade_method::Union{Int32,Nothing} = nothing
end

end # module FundProtocol
