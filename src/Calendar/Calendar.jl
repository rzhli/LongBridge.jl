module Calendar

using Dates

using ..Config
using ..Client
using ..Errors
using ..Utils: construct
using ..CalendarProtocol

export CalendarContext, finance_calendar

"""
    CalendarContext(config::Config.Settings)

财务日历上下文。无 WebSocket 连接，所有方法都是同步 HTTP 调用。
"""
struct CalendarContext
    config::Config.Settings
end

"""
    finance_calendar(ctx::CalendarContext, category::CalendarCategory.T, start::Date, end_::Date; market=nothing, count=nothing, offset=nothing, next=nothing)

查询财务日历事件（财报 / 分红 / 拆股 / IPO / 宏观数据 / 休市等）。

# 参数
- `category`: 事件类型，见 [`CalendarCategory`](@ref)
- `start`, `end_`: 起止日期（含）
- `market`: 可选，按市场过滤（如 `"HK"`、`"US"`、`"CN"`）
- `count`: 每页最大事件数；省略时使用服务端默认值（可能仅返回 10 条）
- `offset`: 跳过的事件数
- `next`: 分页方向，`CalendarPageDirection.Later` / `Earlier`

返回的 `CalendarEventsResponse.next_date` 是下一页游标；非空时可将
`Date(page.next_date)` 作为 `start`，并保持同一个 `end_`；游标为空时结束。

# 端点
`GET /v1/quote/finance_calendar`
"""
function finance_calendar(
    ctx::CalendarContext,
    category::CalendarCategory.T,
    start::Date,
    end_::Date;
    market::Union{AbstractString,Nothing} = nothing,
    count::Union{Integer,Nothing} = nothing,
    offset::Union{Integer,Nothing} = nothing,
    next::Union{CalendarPageDirection.T,Nothing} = nothing,
)
    params = Dict{String,Any}(
        "date" => Dates.format(start, dateformat"yyyy-mm-dd"),
        "date_end" => Dates.format(end_, dateformat"yyyy-mm-dd"),
        "types[]" => _calendar_category_str(category),
    )
    isnothing(market) || (params["markets[]"] = String(market))
    isnothing(count) || (params["count"] = count)
    isnothing(offset) || (params["offset"] = offset)
    isnothing(next) || (params["next"] = next === CalendarPageDirection.Later ? "later" : "earlier")
    resp = ApiResponse(Client.http_get(ctx.config, "/v1/quote/finance_calendar"; params))
    resp.code == 0 ||
        @lperror(resp.code, resp.message, get(resp.headers, "x-request-id", nothing))
    construct(CalendarEventsResponse, resp.data)
end

end # module Calendar
