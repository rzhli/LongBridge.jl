using Test, JSON, Dates, HTTP
using LongBridge
using URIs: unescapeuri

@testset "v0.11.0 fund response compatibility" begin
    @test VersionNumber(LongBridge.VERSION) >= v"0.11.0"
    # All fields in the upstream fund responses have defaults.
    for name in names(LongBridge.FundProtocol)
        T = getfield(LongBridge.FundProtocol, name)
        T isa DataType || continue
        hasmethod(LongBridge.construct, Tuple{Type{T},LongBridge.Utils.JSONObject}) || continue
        @test isdefined(LongBridge, name)
        @test LongBridge.construct(T, JSON.parse("{}")) isa T
    end

    for (T, field) in ((FundDetail, :asset_allocation), (FundTrend, :contrast_performances),
                       (FundPositionDetail, :detail_values), (FundOrderDetail, :order))
        @test getfield(LongBridge.construct(T, JSON.parse(JSON.json(Dict(field => nothing)))), field) === nothing
    end
    detail = LongBridge.construct(FundDetail, JSON.parse("""
        {"name":"Fund A","purchase_amount":"100.0000000000000001",
         "asset_allocation":{"asset_type":1,"report_date":"2026-09-30",
          "lists":[{"counter_id":"ST/US/AAPL","position_ratio":"0.1234"}]}}
        """))
    @test detail.purchase_amount == "100.0000000000000001"
    @test detail.asset_allocation.lists[1].counter_id == "ST/US/AAPL"
    @test detail.asset_allocation.lists[1].position_ratio == "0.1234"
    trend = LongBridge.construct(FundTrend, JSON.parse("""
        {"available_periods":[1,3],"fund_performances":[{"date":"2026-09-30","value":"1.2"}],
         "contrast_performances":{"benchmark_name":"Index","performances":[null,1,"x"]}}
        """))
    @test trend.available_periods == Int32[1,3]
    @test trend.fund_performances[1].value == "1.2"
    @test trend.contrast_performances.performances == Any[nothing,1,"x"]
    analysis = LongBridge.construct(FundAnalysisDetail, JSON.parse("""
        {"cost_level":{"score":3},"risk_ability":null,"return_ability":[1,2],"visible":true}
        """))
    @test analysis.cost_level.score == 3
    @test analysis.risk_ability === nothing
    @test analysis.return_ability == [1,2]
    @test analysis.visible
    pos = LongBridge.construct(FundPositionDetail, JSON.parse("""
        {"detail_values":{"recent_tradingday":"1790726400","holding_units":"1.25"},
         "sum_profit":[{"date":1790726400,"value":"-1.2"}],
         "ut_value":[{"date":"1790726400","unit_value":"3.5"}]}
        """))
    @test pos.detail_values.recent_tradingday == 1790726400
    @test pos.sum_profit[1].value == "-1.2"
    @test pos.ut_value[1].date == 1790726400
    order = LongBridge.construct(FundOrderDetail, JSON.parse("""
        {"order":{"id":"9007199254740993","aaid":42,"created_at":"1790726400"},
         "keywords":[{"key":"fee","content":"0.00"}],"stages":[{"stage":"pending"}]}
        """))
    @test order.order.id == 9007199254740993
    @test order.order.aaid == 42
    @test order.keywords[1].content == "0.00"
    @test order.stages[1].stage == "pending"
    for (wire, expected) in (("123",123), (123,123), (-9,-9), ("",0), ("invalid",0))
        obj = LongBridge.construct(FundOrder, JSON.parse(JSON.json(Dict("id" => wire))))
        @test obj.id === Int64(expected)
    end
    @test FundHoldingPosition !== LongBridge.TradeProtocol.FundPosition
    @test FundPositionsOptions !== LongBridge.TradeProtocol.GetFundPositionsOptions
end

@testset "Trade fund identifier migration" begin
    for (key, value) in (("counter_id","UT/FD/HK0000384492"), ("symbol","HK0000384492"))
        raw = Dict(key => value, "symbol_name" => "F", "currency" => "USD",
                   "holding_units" => "1", "current_net_asset_value" => "2",
                   "cost_net_asset_value" => "1", "net_asset_value_day" => "1790726400")
        response = Dict("list" => [Dict("account_channel" => "lb", "fund_info" => [raw])])
        parsed = JSON.parse(JSON.json(response), LongBridge.TradeProtocol.FundPositionsResponse)
        pos = only(only(parsed.list).fund_info)
        @test pos.counter_id == value
        @test occursin(value, sprint(show, pos))
        encoded = JSON.parse(JSON.json(pos))
        @test encoded.counter_id == value
        @test !haskey(encoded, "symbol")
    end
end

# All requests below target loopback with fake credentials, including order writes.
@testset "v5.2.0 endpoint wire contracts" begin
    seen = NamedTuple[]
    response_data = Ref{Any}(Dict())
    response_code = Ref(0)
    server = HTTP.serve!("127.0.0.1", 0; listenany = true) do req
        uri = HTTP.URI(req.target)
        pairs = isempty(uri.query) ? Pair{String,String}[] : map(split(uri.query, '&')) do part
            k, v = split(part, '='; limit = 2)
            unescapeuri(k) => unescapeuri(v)
        end
        body_text = String(req.body)
        push!(seen, (method = req.method, path = String(uri.path), query = pairs,
                     body = isempty(body_text) ? nothing : JSON.parse(body_text)))
        HTTP.Response(200, ["Content-Type" => "application/json", "x-request-id" => "fund-test"];
            body = JSON.json(Dict("code" => response_code[], "message" => "fixture",
                                 "data" => response_data[])))
    end
    try
        cfg = Config.Settings("fake-key", "fake-secret", "fake-token", DateTime(2099,1,1);
                              http_url = "http://127.0.0.1:$(HTTP.port(server))")
        ctx = FundContext(cfg)
        id = "UT/FD/HK0000384492"
        # method, arguments, HTTP path, response wrapper, response item type
        cases = [
            (hot_funds, (), "/v1/fund/hot-funds", "list", HotFund),
            (fund_filters, (), "/v1/fund/filters", nothing, FundFilters),
            (fund_detail, (id,), "/v1/fund/funds/detail", nothing, FundDetail),
            (fund_analysis, (id,), "/v1/fund/funds/analysis", nothing, FundAnalysis),
            (fund_analysis_detail, (id,), "/v1/fund/funds/analysis/detail", nothing, FundAnalysisDetail),
            (fund_trend, (id,), "/v1/fund/funds/trend", nothing, FundTrend),
            (fund_annual_returns, (id,), "/v1/fund/funds/returns/annual", "list", FundAnnualReturn),
            (fund_quarterly_returns, (id,), "/v1/fund/funds/returns/quarterly", "list", FundQuarterlyReturn),
            (fund_performance, (id,), "/v1/fund/funds/performance", "value", FundPerformance),
            (fund_performance_comparison, (id,), "/v1/fund/funds/performance/comparison", nothing, FundPerformanceComparison),
            (fund_nav, (id,), "/v1/fund/funds/nav", "value", FundNavValue),
            (fund_nav_history, (id,), "/v1/fund/funds/nav-history", "history_value", FundNavValue),
            (fund_nav_range, (id,), "/v1/fund/funds/nav-range", "history_value", FundNavValue),
            (fund_holdings, (id,), "/v1/fund/funds/holdings", nothing, FundHoldings),
            (fund_stock_holdings, (id,), "/v1/fund/funds/stock-holdings", "lists", FundStockHolding),
            (fund_positions, (), "/v1/asset/funds", nothing, FundPositions),
            (fund_position, (id,), "/v1/asset/funds/detail", nothing, FundPositionDetail),
            (fund_position_performance, (id,), "/v1/asset/funds/performance", "value", FundPositionPerformance),
            (fund_position_profits, (id,), "/v1/asset/funds/profits", nothing, FundPositionProfits),
            (fund_position_nav, (id,), "/v1/asset/funds/nav-history", "history_value", FundPositionNav),
            (fund_position_dividends, (id,), "/v1/asset/funds/dividends", nothing, FundDividends),
            (fund_orders, (), "/v1/fund/orders", "orders", FundOrder),
            (fund_order, (Int64(123),), "/v1/fund/orders/123", nothing, FundOrderDetail),
            (fund_transactions, (), "/v1/fund/transactions", "list", FundTransaction),
        ]
        for (f, args, path, wrapper, T) in cases
            @testset "$f" begin
                response_data[] = isnothing(wrapper) ? Dict() : Dict(wrapper => [Dict()])
                result = f(ctx, args...)
                @test result isa (isnothing(wrapper) ? T : Vector{T})
                isnothing(wrapper) || @test length(result) == 1
                got = seen[end]
                @test got.method == "GET"
                @test got.path == path
                @test got.body === nothing
                expected = isempty(args) || f === fund_order ? Dict{String,String}() :
                    f in (fund_nav, fund_performance, fund_position_performance) ?
                    Dict("counter_ids" => "[\"UT/FD/HK0000384492\"]") : Dict("counter_id" => id)
                @test Dict(got.query) == expected
                if !isnothing(wrapper)
                    response_data[] = Dict()
                    @test f(ctx, args...) == T[]
                end
            end
        end
        response_data[] = Dict("funds" => [Dict("counter_id" => id)])
        @test only(funds(ctx)).counter_id == id
        @test seen[end].method == "POST"
        @test seen[end].path == "/v1/fund/funds"
        @test isempty(seen[end].query)
        @test isempty(seen[end].body)
        funds(ctx, GetFundsOptions(filter = Dict("currency" => ["USD"]), quick_ids = [1,2], time_interval = ["1y"]))
        @test seen[end].body.filter.currency == ["USD"]
        @test seen[end].body.quick_ids == [1,2]
        @test seen[end].body.time_interval == ["1y"]
        funds(ctx, GetFundsOptions(filter = []))
        @test seen[end].body.filter == []
        response_data[] = Dict()

        # Optional query fields, zero values and Julia's end_ -> end mapping.
        fund_analysis(ctx, id, GetFundAnalysisOptions(period = 0))
        @test Dict(seen[end].query) == Dict("counter_id" => id, "period" => "0")
        fund_nav_history(ctx, id, FundPageOptions(page = 2, size = 50))
        @test Dict(seen[end].query) == Dict("counter_id" => id, "page" => "2", "size" => "50")
        fund_nav_range(ctx, id, FundNavRangeOptions(month_before = 3, year_before = 1))
        @test Dict(seen[end].query) == Dict("counter_id" => id, "month_before" => "3", "year_before" => "1")
        fund_holdings(ctx, id, GetFundHoldingsOptions(scene = 1))
        @test Dict(seen[end].query)["scene"] == "1"
        fund_stock_holdings(ctx, id, GetFundStockHoldingsOptions(limit = 10))
        @test Dict(seen[end].query)["limit"] == "10"
        fund_positions(ctx, FundPositionsOptions(account_channel = "lb", aaid = 42))
        @test Dict(seen[end].query) == Dict("account_channel" => "lb", "aaid" => "42")
        fund_position(ctx, id, GetFundPositionOptions(start = "2026-09-01", end_ = "2026-09-30"))
        @test Dict(seen[end].query) == Dict("counter_id" => id, "start" => "2026-09-01", "end" => "2026-09-30")
        fund_position_profits(ctx, id, GetFundPositionProfitsOptions(page = 1, size = 20, end_ = "2026-09-30"))
        @test Dict(seen[end].query) == Dict("counter_id" => id, "page" => "1", "size" => "20", "end" => "2026-09-30")
        fund_position_dividends(ctx, id, GetFundPositionDividendsOptions(start = 0, end_ = 1790726400, currency = "USD"))
        @test Dict(seen[end].query) == Dict("counter_id" => id, "start" => "0", "end" => "1790726400", "currency" => "USD")
        fund_orders(ctx, GetFundOrdersOptions(counter_ids = [id, "UT/FD/HK2"], actions = "buy,sell", page = 1))
        @test [v for (k,v) in seen[end].query if k == "counter_id"] == [id,"UT/FD/HK2"]
        @test Dict(seen[end].query)["actions"] == "buy,sell"
        fund_transactions(ctx, GetFundTransactionsOptions(currencies = "USD,HKD", start = 0, end_ = 1790726400))
        @test Dict(seen[end].query) == Dict("currencies" => "USD,HKD", "start" => "0", "end" => "1790726400")

        response_data[] = Dict("msg" => "validated")
        validation = fund_validate_order(ctx, ValidateFundOrderOptions(counter_id = id, action = "buy", currency = "USD", amount = "100.01", dividend_option = 0))
        @test validation.msg == "validated"
        @test seen[end].method == "POST"
        @test seen[end].path == "/v1/fund/orders/validate"
        @test Dict(seen[end].body) == Dict("counter_id" => id, "action" => "buy", "currency" => "USD", "amount" => "100.01", "dividend_option" => 0)
        response_data[] = Dict("id" => "9007199254740993")
        order = fund_submit_order(ctx, SubmitFundOrderOptions(counter_id = id, action = "sell", currency = "USD", units = "1.000001", is_sell_all = false, fee = "0"))
        @test order.id == 9007199254740993
        @test seen[end].method == "POST"
        @test seen[end].path == "/v1/fund/orders"
        @test Dict(seen[end].body) == Dict("counter_id" => id, "action" => "sell", "currency" => "USD", "units" => "1.000001", "is_sell_all" => false, "fee" => "0")
        @test fund_cancel_order(ctx, 9007199254740993) === nothing
        @test seen[end].method == "POST"
        @test seen[end].path == "/v1/fund/orders/9007199254740993/cancel"
        @test seen[end].body.ut_id == 9007199254740993

        # Calendar defaults stay compatible; both pagination directions are explicit.
        cal = CalendarContext(cfg)
        response_data[] = Dict("date" => "2026-09-30", "next_date" => "2026-10-01", "list" => [])
        result = finance_calendar(cal, CalendarCategory.Report, Date(2026,9,30), Date(2026,10,7))
        @test result.next_date == "2026-10-01"
        @test Dict(seen[end].query) == Dict("date" => "2026-09-30", "date_end" => "2026-10-07", "types[]" => "report")
        for (direction, wire) in ((CalendarPageDirection.Later,"later"), (CalendarPageDirection.Earlier,"earlier"))
            finance_calendar(cal, CalendarCategory.Report, Date(result.next_date), Date(2026,10,7);
                             market = "US", count = 100, offset = 0, next = direction)
            @test seen[end].path == "/v1/quote/finance_calendar"
            @test Dict(seen[end].query) == Dict("date" => "2026-10-01", "date_end" => "2026-10-07", "types[]" => "report", "markets[]" => "US", "count" => "100", "offset" => "0", "next" => wire)
        end
        response_data[] = Dict("next_date" => nothing)
        @test finance_calendar(cal, CalendarCategory.Report, Date(2026,9,30), Date(2026,9,30)).next_date == ""
        response_code[] = 12345
        @test_throws LongBridgeError fund_detail(ctx, id)
        @test_throws LongBridgeError fund_submit_order(ctx, SubmitFundOrderOptions(counter_id = id, action = "buy", currency = "USD"))
        @test_throws LongBridgeError fund_cancel_order(ctx, 1)
        @test_throws LongBridgeError finance_calendar(cal, CalendarCategory.Report, Date(2026,9,30), Date(2026,9,30))
    finally
        close(server)
    end
end
