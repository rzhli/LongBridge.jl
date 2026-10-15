using Test, LongBridge, Dates, JSON, HTTP, DataFrames

@testset "v0.12.0 release metadata" begin
    project = LongBridge.TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
    manifest = LongBridge.TOML.parsefile(joinpath(@__DIR__, "..", "Manifest.toml"))
    @test VersionNumber(LongBridge.VERSION) >= v"0.12.0"
    @test LongBridge.VERSION == project["version"]
    @test Base.pkgversion(LongBridge) == VersionNumber(project["version"])
    @test only(manifest["deps"]["LongBridge"])["version"] == project["version"]
end

@testset "v5.2.1 QuoteTransport configuration" begin
    cfg(; kw...) = Config.Settings("fake-key", "fake-secret", "fake-token", DateTime(2099); kw...)
    withenv("LONGBRIDGE_QUOTE_TRANSPORT" => nothing) do
        @test cfg().quote_transport === QuoteTransport.WebSocket
    end
    withenv("LONGBRIDGE_QUOTE_TRANSPORT" => "http") do
        @test cfg().quote_transport === QuoteTransport.Http
        @test cfg(quote_transport = QuoteTransport.WebSocket).quote_transport === QuoteTransport.WebSocket
        mktemp() do path, io
            write(io, """
                app_key = "fake-key"
                app_secret = "fake-secret"
                access_token = "fake-token"
                token_expire_time = "2099-01-01T00:00:00"
                """)
            flush(io)
            @test Config.from_toml(path).quote_transport === QuoteTransport.Http
            write(io, "quote_transport = \"ws\"\nenable_overnight = false\n")
            flush(io)
            toml_cfg = Config.from_toml(path)
            @test toml_cfg.quote_transport === QuoteTransport.WebSocket
            @test !toml_cfg.enable_overnight
        end
    end
    @test cfg(quote_transport = "http").quote_transport === QuoteTransport.Http
    @test_throws ArgumentError cfg(quote_transport = "websocket")
    token = OAuthToken("client", "token", "refresh", UInt64(4102444800))
    handle = OAuthHandle("client", UInt16(0), token)
    @test from_oauth(handle; quote_transport = QuoteTransport.Http).quote_transport === QuoteTransport.Http
    withenv("LONGBRIDGE_QUOTE_TRANSPORT" => "http") do
        @test from_oauth(handle).quote_transport === QuoteTransport.Http
    end
    withenv("LONGBRIDGE_QUOTE_TRANSPORT" => "invalid") do
        @test_throws ArgumentError cfg()
        @test_throws ArgumentError from_oauth(handle)
        @test cfg(quote_transport = "http").quote_transport === QuoteTransport.Http
        @test from_oauth(handle; quote_transport = "ws").quote_transport === QuoteTransport.WebSocket
        mktemp() do path, io
            write(io, """
                app_key = "fake-key"
                app_secret = "fake-secret"
                access_token = "fake-token"
                token_expire_time = "2099-01-01T00:00:00"
                quote_transport = "http"
                enable_overnight = false
                """)
            flush(io)
            toml_cfg = Config.from_toml(path)
            @test toml_cfg.quote_transport === QuoteTransport.Http
            @test !toml_cfg.enable_overnight
        end
    end
end

@testset "HTTP proto-JSON scalar and trade-type compatibility" begin
    Q = LongBridge.Quote
    P = LongBridge.QuoteProtocol
    PB = Q.ProtoBuf
    # The protocol's trade_type is a string, not the Julia enum ordinal.
    # Missing/null strings must behave like their protobuf default ("").
    for symbol in ("AAPL.US", "700.HK", "D05.SG"), code in (missing, nothing, "", "D", "1", 1, "future-code")
        raw = Dict{String,Any}()
        ismissing(code) || (raw["tradeType"] = code)
        response = Q._quote_http_decode(P.SecurityTradeResponse,
            Dict("symbol" => symbol, "trades" => [raw]))
        io = IOBuffer()
        if !ismissing(code) && !isnothing(code)
            PB.encode(PB.ProtoEncoder(io), 4, string(code))
        end
        ws_trade = PB.decode(PB.ProtoDecoder(IOBuffer(take!(io))), P.Trade; symbol)
        @test only(response.trades).trade_type === ws_trade.trade_type
    end
    @test Q._quote_http_decode(P.Trade, nothing; symbol = "AAPL.US").trade_type === P.TradeType.Automatch
    @test Q._quote_http_decode(P.SecurityQuote, Dict("trade_status" => "")).trade_status === P.TradeStatus.Normal
    @test Q._quote_http_decode(P.Trade, Dict("direction" => "")).direction === P.TradeDirection.Neutral
    for (value, expected) in ((nothing, false), (false, false), (true, true),
                              ("false", false), ("true", true), (0, false), (2, true), (-1, true))
        @test Q._quote_http_decode(Bool, value) === expected
    end
    @test Q._quote_http_decode(P.Brokers, Dict("brokerIds" => ["1", 2, nothing, "-3"])).broker_ids == [1, 2, 0, -3]
    parsed = Q._quote_http_decode(P.SecurityDepthResponse,
        Dict("ask" => [nothing, Dict("order_num" => "3", "orderNum" => 9)], "bid" => nothing))
    @test parsed.ask[1].volume == 0
    @test parsed.ask[2].order_num == 3
    @test isempty(parsed.bid)
    for value in (1.0, 1.5, "1.5", Dict(), [])
        @test_throws Exception Q._quote_http_decode(Int64, value)
    end
    for value in (Dict(), [], [1])
        @test_throws ArgumentError Q._quote_http_decode(String, value)
    end
    @test_throws ArgumentError Q._quote_http_decode(P.SecurityQuote, Dict("trade_status" => "Normal"))
end

# Everything, including order writes, stays on loopback with fake credentials.
@testset "v5.2.1 HTTP quote pull contracts" begin
    Q = LongBridge.Quote
    P = LongBridge.QuoteProtocol
    seen = NamedTuple[]
    data = Ref{Any}(Dict())
    code = Ref(0)
    server = HTTP.serve!("127.0.0.1", 0; listenany = true) do req
        text = String(req.body)
        push!(seen, (method = req.method, path = String(HTTP.URI(req.target).path),
                     body = isempty(text) ? nothing : JSON.parse(text)))
        HTTP.Response(200, ["Content-Type" => "application/json", "x-request-id" => "quote-test"];
                      body = JSON.json(Dict("code" => code[], "message" => "fixture", "data" => data[])))
    end
    cfg = Config.Settings("fake-key", "fake-secret", "fake-token", DateTime(2099);
                          http_url = "http://127.0.0.1:$(HTTP.port(server))",
                          quote_ws_url = "ws://127.0.0.1:1", quote_transport = QuoteTransport.Http)
    ctx = QuoteContext(cfg)
    try
        @test isnothing(ctx.inner.background_task)
        @test isnothing(ctx.inner.push_dispatcher_task)
        # Every mapped command and both historical candle entry points.
        cases = [
            (() -> static_info(ctx, ["AAPL.US"]), "/quote/static-info", Dict("secuStaticInfo" => [Dict("symbol" => "AAPL.US", "totalShares" => "9007199254740993")]), DataFrame),
            (() -> quote_snapshot(ctx, ["AAPL.US"]), "/quote/quotes", Dict("secu_quote" => [Dict("symbol" => "AAPL.US", "last_done" => "1.25", "volume" => "9007199254740993")]), DataFrame),
            (() -> option_quote(ctx, ["OPTION.US"]), "/quote/options/quotes", Dict("secu_quote" => [Dict("symbol" => "OPTION.US", "option_extend" => Dict("expiry_date" => "20261016"))]), Vector),
            (() -> warrant_quote(ctx, ["12345.HK"]), "/quote/warrants/quotes", Dict("secu_quote" => [Dict("symbol" => "12345.HK")]), DataFrame),
            (() -> depth(ctx, "AAPL.US"), "/quote/depth", Dict("symbol" => "AAPL.US", "ask" => [Dict("price" => "1.2", "volume" => "3")], "bid" => []), DataFrame),
            (() -> brokers(ctx, "700.HK"), "/quote/brokers", Dict("symbol" => "700.HK", "ask_brokers" => [Dict("broker_ids" => ["1", 2])]), NamedTuple),
            (() -> participants(ctx), "/quote/participants", Dict("participant_broker_numbers" => [Dict("broker_ids" => ["1", 2])]), DataFrame),
            (() -> trades(ctx, "AAPL.US", 2), "/quote/trades", Dict("symbol" => "AAPL.US", "trades" => [Dict("price" => "1.25", "trade_type" => "", "direction" => 1)]), DataFrame),
            (() -> intraday(ctx, "AAPL.US"), "/quote/intraday", Dict("symbol" => "AAPL.US", "lines" => [Dict("timestamp" => "1791561600", "price" => "1.5")]), DataFrame),
            (() -> candlesticks(ctx, "AAPL.US", P.CandlePeriod.ONE_MINUTE, 2), "/quote/candlesticks", Dict("symbol" => "AAPL.US", "candlesticks" => [Dict("timestamp" => "1791561600", "close" => "1.5")]), DataFrame),
            (() -> history_candlesticks_by_offset(ctx, "AAPL.US", P.CandlePeriod.ONE_MINUTE, AdjustType.NO_ADJUST, Direction.BACKWARD, 2), "/quote/history-candlesticks", Dict("symbol" => "AAPL.US", "candlesticks" => []), DataFrame),
            (() -> history_candlesticks_by_date(ctx, "AAPL.US", P.CandlePeriod.DAY, AdjustType.NO_ADJUST; start_date = Date(2026,10,1), end_date = Date(2026,10,9)), "/quote/history-candlesticks", Dict("symbol" => "AAPL.US", "candlesticks" => []), DataFrame),
            (() -> option_chain_expiry_date_list(ctx, "AAPL.US"), "/quote/options/expiry-dates", Dict("expiry_date" => ["20261016"]), Vector{Date}),
            (() -> warrant_issuers(ctx), "/quote/warrants/issuers", Dict("issuer_info" => [Dict()]), DataFrame),
            (() -> warrant_list(ctx, "700.HK", first(instances(P.WarrantSortBy.T)), first(instances(P.SortOrderType.T))), "/quote/warrants", Dict("warrant_list" => [Dict("symbol" => "12345.HK")], "total_count" => "1"), NamedTuple),
            (() -> trading_session(ctx), "/quote/markets/trading-sessions", Dict("market_trade_session" => [Dict("market" => "US", "trade_session" => [Dict("beg_time" => "930", "end_time" => "1600")])]), DataFrame),
            (() -> trading_days(ctx, Market.US, Date(2026,10,1), Date(2026,10,9)), "/quote/markets/trading-days", Dict("trade_day" => ["20261001"], "half_trade_day" => nothing), DataFrame),
            (() -> capital_flow(ctx, "AAPL.US"), "/quote/capital-flow", Dict("symbol" => "AAPL.US", "capital_flow_lines" => [Dict("inflow" => "1.5", "timestamp" => "1791561600")]), DataFrame),
            (() -> capital_distribution(ctx, "AAPL.US"), "/quote/capital-distribution", Dict("symbol" => "AAPL.US", "timestamp" => "1791561600", "capital_in" => Dict("large" => "1.2")), DataFrame),
            (() -> calc_indexes(ctx, ["AAPL.US"]), "/quote/calc-indexes", Dict("security_calc_index" => [Dict("symbol" => "AAPL.US", "last_done" => "1.2")]), DataFrame),
        ]
        for (f, path, fixture, T) in cases
            @testset "$path" begin
                data[] = fixture
                result = f()
                @test result isa T
                @test seen[end].method == "POST"
                @test seen[end].path == path
                @test isnothing(ctx.inner.ws_client)
                @test isnothing(ctx.inner.background_task)
                body = seen[end].body
                @test !occursin("null", JSON.json(body))
                if path == "/quote/calc-indexes"
                    @test body.symbols == ["AAPL.US"]
                    @test all(x -> x isa Integer, body.calc_index)
                elseif path in ("/quote/static-info", "/quote/quotes", "/quote/options/quotes", "/quote/warrants/quotes")
                    @test body.symbol isa Vector
                elseif path in ("/quote/participants", "/quote/warrants/issuers", "/quote/markets/trading-sessions")
                    @test isempty(body)
                end
                if path == "/quote/static-info"
                    @test result.total_shares == [9007199254740993]
                elseif path == "/quote/quotes"
                    @test result.last_done == [1.25]
                    @test result.volume == [9007199254740993]
                elseif path == "/quote/markets/trading-days"
                    @test body.beg_day == "20261001"
                    @test body.end_day == "20261009"
                    @test result.date == [Date(2026,10,1)]
                elseif path == "/quote/history-candlesticks"
                    @test body.period isa Integer
                    if body.query_type == 1
                        @test body.offset_request.count == 2
                        @test body.offset_request.direction == 0
                        @test !haskey(body, "date_request")
                    else
                        @test body.date_request.start_date == "20261001"
                        @test !haskey(body, "offset_request")
                    end
                end
            end
        end
        @test length(Q.QUOTE_HTTP_PATHS) == 19
        @test Set(x.path for x in seen) == Set(values(Q.QUOTE_HTTP_PATHS))
        # Decode defaults, nested null, camelCase, integer strings and unknown fields.
        parsed = Q._quote_http_decode(P.SecurityQuoteResponse, JSON.parse("""
            {"secuQuote":[{"symbol":"AAPL.US","lastDone":null,"volume":"9007199254740993",
              "preMarketQuote":{"lastDone":"1.25"},"postMarketQuote":null,"futureField":1}]}"""))
        @test only(parsed.secu_quote).pre_market_quote.last_done == 1.25
        @test only(parsed.secu_quote).post_market_quote === nothing
        @test only(parsed.secu_quote).last_done == 0.0
        @test Q._quote_http_decode(P.SecurityQuoteResponse, nothing).secu_quote == P.SecurityQuote[]
        @test_throws ArgumentError Q._quote_http_decode(P.SecurityQuote, Dict("volume" => "invalid"))
        @test_throws OverflowError Q._quote_http_decode(P.SecurityQuote, Dict("volume" => "999999999999999999999"))
        code[] = 12345
        err = try quote_snapshot(ctx, ["AAPL.US"]) catch e; e end
        @test err isa LongBridgeError
        @test err.code == 12345
        @test err.request_id == "quote-test"
        @test isnothing(ctx.inner.background_task)
        # Existing HTTP-only commands must not wake the socket.
        code[] = 0
        data[] = Dict("temperature" => 50, "description" => "test", "valuation" => 1,
                      "sentiment" => 2, "updated_at" => "1791561600")
        @test market_temperature(ctx, Market.US).temperature == 50
        @test isnothing(ctx.inner.background_task)
        @test realtime_quote(ctx, "AAPL.US") === nothing
        close(ctx)
        @test_throws LongBridgeError quote_snapshot(ctx, ["AAPL.US"])
    finally
        close(ctx)
        close(server)
    end
end

@testset "v5.2.1 delayed order wire contracts and readback" begin
    TP = LongBridge.TradeProtocol
    TR = LongBridge.Trade
    seen = NamedTuple[]
    data = Ref{Any}(Dict("order_id" => "test-order"))
    server = HTTP.serve!("127.0.0.1", 0; listenany = true) do req
        text = String(req.body)
        push!(seen, (method = req.method, path = String(HTTP.URI(req.target).path),
                     body = isempty(text) ? nothing : JSON.parse(text)))
        HTTP.Response(200; body = JSON.json(Dict("code" => 0, "message" => "", "data" => data[])))
    end
    cfg = Config.Settings("fake-key", "fake-secret", "fake-token", DateTime(2099);
                          http_url = "http://127.0.0.1:$(HTTP.port(server))")
    ctx = TR._build_trade_context(cfg; start_tasks = false)
    # Drive the real command handler without connecting a trade WebSocket.
    inner = ctx.inner
    inner.background_task = @async for cmd in inner.command_ch
        TR.handle_command(inner, cmd)
    end
    try
        @test Int(OrderStatus.PartialWithdrawal) == 17
        @test Int(OrderStatus.DelayedNotReported) == 18
        @test Int.(instances(OrderStatus.T)) == Tuple(0:18)
        @test JSON.parse("\"DelayedNotReported\"", OrderStatus.T) === OrderStatus.DelayedNotReported
        base = (symbol = "AAPL.US", order_type = OrderType.LO, side = OrderSide.Buy,
                submitted_quantity = 1, time_in_force = TimeInForceType.Day)
        legbase = (side = OrderSide.Buy, order_type = OrderType.MO, submitted_quantity = 1,
                   strategy = TP.MultiLegStrategy.Straddle, legs = TP.SubmitMultiLegOrderLeg[])
        for (f, constructor, kwargs, path) in (
            (submit_order, SubmitOrderOptions, base, "/v1/trade/order"),
            (submit_multileg, TP.SubmitMultiLegOrderOptions, legbase, "/v1/trade/order/multileg"),
        )
            @test f(ctx, constructor(; kwargs...)).order_id == "test-order"
            @test !haskey(seen[end].body, "delayed_until")
            for (dt, expected) in ((DateTime(2026,1,1), 1767225600),
                                   (DateTime(2026,1,1) + Millisecond(999), 1767225600),
                                   (DateTime(1970), 2), (DateTime(1970) + Second(1), 2),
                                   (DateTime(1960), 2))
                f(ctx, constructor(; kwargs..., delayed_until = dt))
                @test seen[end].path == path
                @test seen[end].method == "POST"
                @test seen[end].body.delayed_until === expected
            end
        end
        replace_order(ctx, ReplaceOrderOptions(order_id = "1", submitted_quantity = 1))
        @test !haskey(seen[end].body, "delayed_until")
        @test !haskey(seen[end].body, "clear_delayed_until")
        for (dt, expected) in ((DateTime(2026,1,1), 1767225600),
                               (DateTime(2026,1,1) + Millisecond(999), 1767225600),
                               (DateTime(1960), 2), (DateTime(1970), 2),
                               (DateTime(1970) + Second(1), 2))
            replace_order(ctx, ReplaceOrderOptions(order_id = "1", submitted_quantity = 1,
                          delayed_until = dt))
            @test seen[end].body.delayed_until === expected
        end
        for dt in (nothing, DateTime(2026,1,1))
            replace_order(ctx, ReplaceOrderOptions(order_id = "1", submitted_quantity = 1,
                          delayed_until = dt, clear_delayed_until = true))
            @test seen[end].method == "PUT"
            @test seen[end].body.delayed_until === 1
            @test !haskey(seen[end].body, "clear_delayed_until")
        end
        raw = JSON.parse("""
            {"currency":"USD","executed_price":"0","executed_quantity":"0","expire_date":"",
             "last_done":"","limit_offset":"","msg":"","order_id":"test-order",
             "order_type":"LO","outside_rth":"RTH_ONLY","price":"1.5","quantity":"1",
             "side":"Buy","status":"DelayedNotReported","stock_name":"Apple","submitted_at":"1767225600",
             "symbol":"AAPL.US","tag":"Normal","time_in_force":"Day","trailing_amount":"",
             "trailing_percent":"","trigger_at":"0","trigger_price":"","trigger_status":"NOT_USED",
             "updated_at":"0","remark":"","free_status":"None","free_amount":"","free_currency":"USD",
             "deductions_status":"NONE","deductions_amount":"","deductions_currency":"USD",
             "platform_deducted_status":"NONE","platform_deducted_amount":"","platform_deducted_currency":"USD",
             "history":[],"charge_detail":{"total_charges":"0","currency":"USD","items":[]}}
            """)
        for (wire, expected) in (("1767225600", DateTime(2026,1,1,8)),
                                  (1767225600, DateTime(2026,1,1,8)),
                                  (" 1767225600 ", DateTime(2026,1,1,8)),
                                  (1, DateTime(1970,1,1,8,0,1)),
                                  (253402300799, DateTime(10000,1,1,7,59,59)),
                                  (nothing, nothing), ("0", nothing), (0, nothing),
                                  ("", nothing), ("bad", nothing), (-5, nothing),
                                  ("99999999999999999999", nothing), (253402300800, nothing),
                                  (true, nothing), (1767225600.0, nothing), (1.5, nothing),
                                  (Dict(), nothing), ([], nothing))
            raw["delayed_until"] = wire
            order = JSON.parse(JSON.json(TR._parse_order_data(raw)), TP.Order)
            @test order.delayed_until === expected
            @test order.status === OrderStatus.DelayedNotReported
            data[] = Dict("orders" => [raw])
            @test today_orders(ctx)[1, "Delayed Until"] === expected
            @test history_orders(ctx)[1, "Delayed Until"] === expected
            data[] = raw
            @test order_detail(ctx, "test-order").delayed_until === expected
        end
        delete!(raw, "delayed_until")
        data[] = raw
        @test order_detail(ctx, "test-order").delayed_until === nothing
        @test JSON.parse(JSON.json(TR._parse_order_data(raw)), TP.Order).delayed_until === nothing
        # The order-changed push parser must recognize the new status as well.
        push_raw = Dict{String,Any}(string(f) => nothing for f in fieldnames(TP.PushOrderChanged))
        for (f, T) in zip(fieldnames(TP.PushOrderChanged), fieldtypes(TP.PushOrderChanged))
            T === String && (push_raw[string(f)] = "")
        end
        merge!(push_raw, Dict("side" => "Buy", "order_type" => "LO", "status" => "DelayedNotReported", "tag" => "Normal"))
        callbacks = LongBridge.TradePush.Callbacks()
        received = Ref{Any}(nothing)
        LongBridge.TradePush.set_on_order_changed!(callbacks, x -> (received[] = x))
        notification = TP.Notification("private", TP.ContentType.CONTENT_JSON,
            TP.DispatchType.DISPATCH_DIRECT, Vector{UInt8}(codeunits(JSON.json(push_raw))))
        LongBridge.TradePush.handle_push_event!(callbacks, notification)
        @test received[].status === OrderStatus.DelayedNotReported
    finally
        close(ctx)
        close(server)
    end
end
