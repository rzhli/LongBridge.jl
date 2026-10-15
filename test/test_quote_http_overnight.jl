using Test, LongBridge, Dates, JSON, HTTP

@testset "HTTP quote overnight alignment and refill" begin
    Q = LongBridge.Quote
    P = LongBridge.QuoteProtocol
    # Three full days in EDT, one-minute bars, including the contiguous night block.
    base = Int64(datetime2unix(DateTime(2026,10,8,4)))
    timeline = [Dict("timestamp" => base + i * 60, "close" => "1.5",
                     "trade_session" => Q._is_us_overnight(base + i * 60) ? 3 : 0)
                for i in 0:(3 * 24 * 60 - 1)]
    fixture = Ref{Any}(Dict())
    seen = NamedTuple[]
    refill_error = Ref(false)
    server = HTTP.serve!("127.0.0.1", 0; listenany = true) do req
        body = JSON.parse(String(req.body))
        path = String(HTTP.URI(req.target).path)
        push!(seen, (; path, body))
        code = 0
        data = fixture[]
        if path == "/quote/history-candlesticks" && haskey(body, "offset_request") &&
           !isempty(body.offset_request.date)
            offset = body.offset_request
            anchor = DateTime(offset.date * offset.minute, dateformat"yyyymmddHHMM") + Hour(4)
            ts = Int64(datetime2unix(anchor))
            page = if offset.direction == 1
                first(filter(c -> c["timestamp"] >= ts, timeline), offset.count)
            else
                last(filter(c -> c["timestamp"] <= ts, timeline), offset.count)
            end
            data = Dict("symbol" => "AAPL.US", "candlesticks" => page)
            refill_error[] && (code = 12345)
        end
        HTTP.Response(200; body = JSON.json(Dict("code" => code, "message" => "fixture", "data" => data)))
    end
    cfg = Config.Settings("fake-key", "fake-secret", "fake-token", DateTime(2099);
                          http_url = "http://127.0.0.1:$(HTTP.port(server))",
                          quote_transport = QuoteTransport.Http, enable_overnight = false)
    ctx = QuoteContext(cfg)
    try
        @test Q._is_us_equity("aapl.us")
        @test !Q._is_us_equity(".VIX.US")
        @test !Q._is_us_equity("700.HK")
        for (utc, localtime) in (
            (DateTime(2026,1,1,5), DateTime(2026,1,1)),
            (DateTime(2026,7,1,4), DateTime(2026,7,1)),
            (DateTime(2026,3,8,6,59), DateTime(2026,3,8,1,59)),
            (DateTime(2026,3,8,7), DateTime(2026,3,8,3)),
            (DateTime(2026,11,1,5,59), DateTime(2026,11,1,1,59)),
            (DateTime(2026,11,1,6), DateTime(2026,11,1,1)),
        )
            @test Q._new_york_local(Int64(datetime2unix(utc))) == localtime
        end
        fixture[] = Dict("secu_quote" => [Dict("symbol" => s, "over_night_quote" => Dict("last_done" => "2.5"))
                                           for s in ("AAPL.US", ".VIX.US", "700.HK")])
        result = quote_snapshot(ctx, ["AAPL.US", ".VIX.US", "700.HK"])
        @test result.over_night_quote[1] === nothing
        @test result.over_night_quote[2].last_done == 2.5
        @test result.over_night_quote[3].last_done == 2.5
        cfg.enable_overnight = true
        @test quote_snapshot(ctx, ["AAPL.US"]).over_night_quote[1].last_done == 2.5
        cfg.enable_overnight = false
        fixture[] = Dict("symbol" => "AAPL.US", "lines" => [Dict("timestamp" => base + h * 3600)
                                                           for h in (0,3,4,19,20,23)])
        @test size(intraday(ctx, "AAPL.US"), 1) == 2
        @test size(intraday(ctx, ".VIX.US"), 1) == 6

        # Tiny shortfalls on either side of an eight-hour block must escalate
        # to a full page, not inch through it until the round limit is hit.
        for forward in (false, true)
            start = 1440 + (forward ? 19 * 60 + 50 : 3 * 60 + 50)
            raw = timeline[(start + 1):(start + 100)]
            fixture[] = Dict("symbol" => "AAPL.US", "candlesticks" => raw)
            empty!(seen)
            direction = forward ? Direction.FORWARD : Direction.BACKWARD
            result = history_candlesticks_by_offset(ctx, "AAPL.US", P.CandlePeriod.ONE_MINUTE,
                AdjustType.NO_ADJUST, direction, 100; trade_sessions = TradeSession.All,
                include_timestamp_unix = true)
            available = filter(timeline) do c
                c["trade_session"] != 3 && (forward ? c["timestamp"] >= raw[1]["timestamp"] :
                                                       c["timestamp"] <= raw[end]["timestamp"])
            end
            expected = forward ? first(available, 100) : last(available, 100)
            @test result.timestamp_unix == [c["timestamp"] for c in expected]
            @test issorted(result.timestamp_unix)
            @test allunique(result.timestamp_unix)
            @test all(!=(TradeSession.OvernightTrade), result.trade_session)
            @test length(seen) <= 4
            @test any(x -> x.body.offset_request.count == 1000, seen[2:end])
            @test all(x -> x.path == "/quote/history-candlesticks", seen)
        end
        # Recent count windows share the same refill path.
        raw = timeline[(1440 + 19 * 60 + 1):(1440 + 20 * 60 + 40)]
        fixture[] = Dict("symbol" => "AAPL.US", "candlesticks" => raw)
        empty!(seen)
        result = candlesticks(ctx, "AAPL.US", P.CandlePeriod.ONE_MINUTE, 100;
                              trade_sessions = TradeSession.All)
        @test size(result, 1) == 100
        @test seen[1].path == "/quote/candlesticks"
        @test seen[2].path == "/quote/history-candlesticks"
        @test seen[2].body.offset_request.date == "20261009"
        @test seen[2].body.offset_request.minute == "1900"
        for (symbol, session, enabled) in (("700.HK", TradeSession.All, false),
                                          (".VIX.US", TradeSession.All, false),
                                          ("AAPL.US", TradeSession.Intraday, false),
                                          ("AAPL.US", TradeSession.All, true))
            cfg.enable_overnight = enabled
            empty!(seen)
            result = candlesticks(ctx, symbol, P.CandlePeriod.ONE_MINUTE, 100; trade_sessions = session)
            @test length(seen) == 1
            @test size(result, 1) == 100
            @test TradeSession.OvernightTrade in result.trade_session
        end
        cfg.enable_overnight = false
        # Uncapped ranges only filter; capped ranges refill backwards and stop
        # at the start date even if the requested target cannot be reached.
        for (raw, startdate, capped) in (
            (timeline[1:100], Date(2026,10,8), false),
            (timeline[(1440 + 1):(1440 + 1440)], Date(2026,10,9), false),
            (timeline[(1440 + 60 + 1):(1440 + 1060)], Date(2026,10,9), true),
            (timeline[(1440 + 8 * 60 + 1):(1440 + 8 * 60 + 1000)], Date(2026,10,8), true),
        )
            fixture[] = Dict("symbol" => "AAPL.US", "candlesticks" => raw)
            empty!(seen)
            result = history_candlesticks_by_date(ctx, "AAPL.US", P.CandlePeriod.ONE_MINUTE,
                AdjustType.NO_ADJUST; start_date = startdate, end_date = Date(2026,10,10),
                trade_sessions = TradeSession.All, include_timestamp_unix = true)
            expected = if capped
                available = filter(c -> c["trade_session"] != 3 &&
                    Date(Q._new_york_local(c["timestamp"])) >= startdate &&
                    c["timestamp"] <= raw[end]["timestamp"], timeline)
                last(available, min(length(raw), length(available)))
            else
                filter(c -> c["trade_session"] != 3, raw)
            end
            if isempty(expected)
                @test size(result, 1) == 0
            else
                @test result.timestamp_unix == [c["timestamp"] for c in expected]
            end
            @test capped ? length(seen) > 1 : length(seen) == 1
        end
        # Errors on a refill page are not silently replaced by partial data.
        fixture[] = Dict("symbol" => "AAPL.US", "candlesticks" => timeline[(1440 + 231):(1440 + 330)])
        refill_error[] = true
        @test_throws LongBridgeError candlesticks(ctx, "AAPL.US", P.CandlePeriod.ONE_MINUTE, 100;
                                                 trade_sessions = TradeSession.All)
        @test isnothing(ctx.inner.background_task)
    finally
        close(ctx)
        close(server)
    end
end

@testset "HTTP transport preserves WS-only command routing" begin
    Q = LongBridge.Quote
    P = LongBridge.QuoteProtocol
    cfg = Config.Settings("fake-key", "fake-secret", "fake-token", DateTime(2099);
                          quote_transport = QuoteTransport.Http)
    ctx = QuoteContext(cfg)
    inner = ctx.inner
    commands = Any[]
    # Emulate the WS worker, so routing tests require neither OTP nor credentials.
    inner.background_task = @async for cmd in inner.command_ch
        push!(commands, cmd.cmd_code)
        resp = if cmd.cmd_code == P.QuoteCommand.QueryUserQuoteProfile
            Q._quote_http_decode(P.UserQuoteProfileResponse, Dict("member_id" => 42, "quote_level" => "LV1"))
        elseif cmd.cmd_code == P.QuoteCommand.Subscription
            P.SubscriptionResponse(P.SubTypeList[])
        else
            cmd.response_type()
        end
        put!(cmd.resp_ch, resp)
    end
    try
        Q.subscribe(ctx, ["AAPL.US"], [SubType.QUOTE])
        @test commands[end] === P.QuoteCommand.Subscribe
        Q.unsubscribe(ctx, ["AAPL.US"], [SubType.QUOTE])
        @test commands[end] === P.QuoteCommand.Unsubscribe
        @test isempty(subscriptions(ctx))
        @test commands[end] === P.QuoteCommand.Subscription
        @test member_id(ctx) == 42
        @test commands[end] === P.QuoteCommand.QueryUserQuoteProfile
        @test quote_level(ctx) == "LV1"
        @test count(==(P.QuoteCommand.QueryUserQuoteProfile), commands) == 1
    finally
        close(ctx)
    end
end
