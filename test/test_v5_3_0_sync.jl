using Test, LongBridge, JSON, HTTP, Dates, Logging
using DecFP: Dec64

function _v530_execution(; side = missing, trade_id = "t1")
    row = Dict{String,Any}("order_id" => "1", "trade_id" => trade_id,
        "symbol" => "ETHUSD.BKKT", "trade_done_at" => "1790203596",
        "quantity" => "0.168", "price" => "2690.34165646")
    ismissing(side) || (row["side"] = side)
    row
end

@testset "v5.3.0 execution wire compatibility" begin
    TP = LongBridge.TradeProtocol
    for (side, expected) in ((missing, OrderSide.UnknownSide), (nothing, OrderSide.UnknownSide),
                             ("Buy", OrderSide.Buy), ("Sell", OrderSide.Sell))
        raw = _v530_execution(; side)
        for timestamp in ("1790203596", 1790203596, "2026-09-24T09:30:00")
            raw["trade_done_at"] = timestamp
            execution = JSON.parse(JSON.json(raw), TP.Execution)
            @test execution.side === expected
            @test execution.quantity === Dec64("0.168")
            @test execution.price === Dec64("2690.34165646")
            @test execution.trade_done_at == (timestamp == "2026-09-24T09:30:00" ?
                DateTime(2026, 9, 24, 9, 30) : unix2datetime(1790203596) + Hour(8))
            again = JSON.parse(JSON.json(execution), TP.Execution)
            @test all(f -> getfield(again, f) == getfield(execution, f), fieldnames(TP.Execution))
        end
    end
    raw = _v530_execution(side = "Buy")
    raw["quantity"] = 2
    raw["price"] = 12.5
    @test JSON.parse(JSON.json(raw), TP.Execution).quantity == Dec64(2)
end

@testset "v5.3.0 US asset response contracts" begin
    for T in (USAvailableHolding, USBuyLimitInfo, USCashDetail, USMarginStatus,
              USCashAndBuyPower, USTransaction, USTransactionHistory, USExchangeRate,
              USExchangeRates, USCryptoEntry)
        @test nameof(T) in names(LongBridge)
        # Omitted and explicit null fields both keep defaults, including nested objects/lists.
        absent = JSON.parse("{}", T)
        nulls = JSON.parse(JSON.json(Dict(string(f) => nothing for f in fieldnames(T))), T)
        @test JSON.json(absent) == JSON.json(nulls)
    end
    for name in (:GetUSAvailableHoldingOptions, :GetUSTransactionHistoryOptions,
                 :us_cash_and_buy_power, :us_available_holding, :us_transaction_history, :us_exchange_rates)
        @test name in names(LongBridge)
    end
    cash = JSON.parse("""{"buy_limit_info":{"cash_buy_power":"100.123456789","crypto_buy_power":"10"},
        "cash_list":[{"currency":"USD","available_cash":"50","external_amount":null}],
        "margin_status":{"nlv":"200","margin_maintenance_excess":"80"}}""", USCashAndBuyPower)
    @test cash.buy_limit_info.cash_buy_power == "100.123456789"
    @test cash.buy_limit_info.crypto_buy_power == "10"
    @test only(cash.cash_list).external_amount == ""
    @test cash.margin_status.margin_maintenance_excess == "80"
    @test JSON.parse("{\"available_qty\":\"-0.000001\"}", USAvailableHolding).available_qty == "-0.000001"

    raw = Dict{String,Any}("asset_type" => "CRYPTO", "counter_id" => "VA/BKKT/ETHUSD",
        "symbol" => "ETHUSD", "market" => "BKKT", "quantity" => "0.10000001", "currency" => "USD",
        "last_done" => "2500", "market_price" => "2501", "name" => "Ethereum", "position_side" => "LONG")
    for counter_id in ("VA/BKKT/ETHUSD", nothing, missing)
        ismissing(counter_id) ? delete!(raw, "counter_id") : (raw["counter_id"] = counter_id)
        crypto = JSON.parse(JSON.json(raw), USCryptoEntry)
        @test crypto.symbol == "ETHUSD.BKKT"
        @test crypto.quantity == "0.10000001"
        @test crypto.market_price == "2501"
        @test crypto.name == "Ethereum"
        @test crypto.position_side == "LONG"
        @test JSON.parse(JSON.json(crypto), USCryptoEntry).symbol == "ETHUSD.BKKT"
    end
    legacy = USCryptoEntry("CRYPTO", "0", "BTCUSD.BKKT", "USD", "")
    @test legacy.quantity == ""
    @test legacy.symbol == "BTCUSD.BKKT"

    for (timestamp, expected) in ((1791478565, unix2datetime(1791478565)),
        (" 1791478565 ", unix2datetime(1791478565)), (253402300799, DateTime(9999, 12, 31, 23, 59, 59)),
        (0, nothing), (-1, nothing), ("", nothing), ("bad", nothing), (nothing, nothing),
        (true, nothing), (1.5, nothing), (1.0, nothing), (253402300800, nothing),
        (typemax(Int64), nothing), ("9223372036854775808", nothing))
        txn = JSON.parse(JSON.json(Dict("create_at" => timestamp, "done_at" => timestamp)), USTransaction)
        @test txn.create_at === expected
        @test txn.done_at === expected
        @test JSON.parse(JSON.json(txn), USTransaction).create_at === expected
    end
    for (page, expected) in ((2, 2), ("2", 2), ("bad", 0), (nothing, 0))
        result = JSON.parse(JSON.json(Dict("current_page" => page, "items" => nothing)), USTransactionHistory)
        @test result.current_page == expected
        @test isempty(result.items)
    end
    for invalid in (true, 1.0, [], Dict())
        @test_throws Exception JSON.parse(JSON.json(Dict("current_page" => invalid)), USTransactionHistory)
    end

    rates = JSON.parse("""{"universal_exchanges":{
        "z":{"spec_exchanges":{"reference":{"exchanges":[{"base_currency":"USD","other_currency":"USD","bid_rate":1}]}}},
        "a":{"spec_exchanges":{
            "reference":{"exchanges":[{"base_currency":"USD","other_currency":"HKD","bid_rate":"7.8000001","offer_rate":7.85,"average_rate":null}]},
            "am":{"exchanges":[{"bid_rate":1}]}, "empty":{"exchanges":null}}}}}""", USExchangeRates)
    @test [(r.universal_key, r.spec_key) for r in rates.exchanges] == [("a", "am"), ("a", "reference"), ("z", "reference")]
    @test rates.exchanges[1].bid_rate == "1"
    @test rates.exchanges[2].bid_rate == "7.8000001"
    @test rates.exchanges[2].offer_rate == "7.85"
    @test rates.exchanges[2].average_rate == ""
    @test JSON.json(JSON.parse(JSON.json(rates), USExchangeRates)) == JSON.json(rates)
    @test isempty(JSON.parse("{\"universal_exchanges\":null}", USExchangeRates).exchanges)
end

# Fake credentials, no WebSocket workers, and loopback HTTP only.
@testset "v5.3.0 HTTP contracts and region restrictions" begin
    TR = LongBridge.Trade
    TP = LongBridge.TradeProtocol
    seen = NamedTuple[]
    data = Ref{Any}(Dict())
    code = Ref(0)
    paging = Ref(false)
    server = HTTP.serve!("127.0.0.1", 0; listenany = true) do req
        uri = HTTP.URI(req.target)
        query = Dict{String,String}()
        if !isempty(uri.query)
            for part in split(uri.query, '&')
                key, value = split(part, '='; limit = 2)
                query[HTTP.URIs.unescapeuri(key)] = HTTP.URIs.unescapeuri(value)
            end
        end
        headers = Dict(lowercase(k) => v for (k, v) in req.headers)
        body = String(req.body)
        push!(seen, (method = req.method, path = String(uri.path),
            query = query, body = isempty(body) ? nothing : JSON.parse(body),
            headers = headers, region = get(headers, "x-dc-region", ""),
            auth = get(headers, "authorization", "")))
        response_data = if paging[]
            page = parse(Int, get(query, "page", "1"))
            page == 1 ? Dict("trades" => [_v530_execution()], "has_more" => true) :
                Dict("trades" => [_v530_execution(), _v530_execution(trade_id = "t2")], "has_more" => false)
        else
            data[]
        end
        HTTP.Response(200, ["Content-Type" => "application/json", "x-request-id" => "v530-fixture"];
            body = JSON.json(Dict("code" => code[], "message" => "fixture", "data" => response_data)))
    end
    url = "http://127.0.0.1:$(HTTP.port(server))"
    configs = [Settings("fake-key", "fake-secret", "fake-token", DateTime(2099); http_url = url),
               Settings("us_fake-key", "fake-secret", "us_fake-token", DateTime(2099); http_url = url)]
    for token in ("ap_test-token", "us_test-token")
        oauth = OAuthHandle("test-client", UInt16(0), OAuthToken("test-client", token, nothing, UInt64(4102444800)))
        push!(configs, from_oauth(oauth; http_url = url))
    end
    contexts = [TR._build_trade_context(cfg; start_tasks = false) for cfg in configs]
    for ctx in contexts
        inner = ctx.inner
        inner.background_task = @async with_logger(NullLogger()) do
            for cmd in inner.command_ch
                TR.handle_command(inner, cmd)
            end
        end
    end
    function error_from(f)
        with_logger(NullLogger()) do
            try
                f()
                nothing
            catch err
                err
            end
        end
    end
    ap_calls = [
        (ctx -> account_balance(ctx), "/v1/asset/account", "/v1/us/assets/cash-and-buy-power"),
        (ctx -> cash_flow(ctx; start_at = Date(2026, 1, 1), end_at = Date(2026, 1, 2)), "/v1/asset/cashflow", "/v1/us/assets/transaction-history"),
        (ctx -> fund_positions(ctx), "/v1/asset/fund", "no US equivalent"),
        (ctx -> stock_positions(ctx), "/v1/asset/stock", "/v1/us/assets/overview"),
        (ctx -> margin_ratio(ctx, "AAPL.US"), "/v1/risk/margin-ratio", "margin_status"),
        (ctx -> all_executions(ctx), "/v3/trade/execution/all", "/v1/trade/execution/history"),
        (ctx -> order_detail(ctx, "1"), "/v1/trade/order", "/v1/us/orders/{order_id}"),
        (ctx -> exchange_rate(PortfolioContext(ctx.inner.config)), "/v1/asset/exchange_rates", "/v1/us/assets/exchange-rates"),
    ]
    opts = GetUSTransactionHistoryOptions(start_at = DateTime(2026, 1, 1), end_at = DateTime(2026, 1, 2))
    us_calls = [
        (ctx -> us_cash_and_buy_power(ctx), "/v1/us/assets/cash-and-buy-power", "/v1/asset/account"),
        (ctx -> us_available_holding(ctx, GetUSAvailableHoldingOptions(symbol = "AAPL.US")), "/v1/us/assets/available-holding", "/v1/asset/stock"),
        (ctx -> us_transaction_history(ctx, opts), "/v1/us/assets/transaction-history", "/v1/asset/cashflow"),
        (ctx -> us_exchange_rates(ctx), "/v1/us/assets/exchange-rates", "/v1/asset/exchange_rates"),
    ]
    try
        # Both API-key and OAuth routing; permitted requests reach the fixture error unchanged.
        code[] = 987654
        function check_region(ctx, region)
            cfg = ctx.inner.config
            for (calls, required) in ((ap_calls, :ap), (us_calls, :us)), (call, path, hint) in calls
                before = length(seen)
                err = error_from(() -> call(ctx))
                @test err isa LongBridgeError
                if region === required
                    @test err.code == 987654
                    @test length(seen) == before + 1
                    @test seen[end].path == path
                    @test seen[end].region == String(region)
                    method = path == "/v1/us/assets/transaction-history" ? "POST" : "GET"
                    @test seen[end].method == method
                    @test seen[end].headers["content-type"] == "application/json; charset=utf-8"
                    @test seen[end].headers["x-api-key"] == cfg.app_key
                    if cfg.auth_mode === :oauth
                        @test seen[end].auth == "Bearer $(cfg.oauth.token.access_token)"
                        @test !haskey(seen[end].headers, "x-api-signature")
                    else
                        @test seen[end].auth == cfg.access_token
                        @test startswith(seen[end].headers["x-api-signature"], "HMAC-SHA256 ")
                    end
                    if method == "GET"
                        @test isnothing(seen[end].body)
                    else
                        @test isempty(seen[end].query)
                    end
                else
                    @test err.code == 403
                    @test length(seen) == before
                    @test occursin(hint, err.message)
                    @test startswith(err.message, "API endpoint $path requires")
                end
            end
        end
        for (ctx, region) in zip(contexts, (:ap, :us, :ap, :us))
            check_region(ctx, region)
        end
        # The current OAuth token controls routing, even after the context was built.
        for (ctx, token, region) in ((contexts[3], "us_rotated-token", :us),
                                     (contexts[4], "ap_rotated-token", :ap))
            oauth = ctx.inner.config.oauth
            original = oauth.token
            try
                oauth.token = OAuthToken(oauth.client_id, token, nothing, UInt64(4102444800))
                check_region(ctx, region)
            finally
                oauth.token = original
            end
        end
        code[] = 0
        us = contexts[2]
        data[] = Dict("buy_limit_info" => Dict("cash_buy_power" => "100.25"),
            "margin_status" => nothing, "cash_list" => [Dict("currency" => "USD", "total_amount" => "100")])
        balance = us_cash_and_buy_power(us)
        @test balance.buy_limit_info.cash_buy_power == "100.25"
        @test balance.margin_status.nlv == ""
        @test isempty(seen[end].query)
        us_cash_and_buy_power(us, "USD")
        @test seen[end].query == Dict("currency" => "USD")
        @test seen[end].method == "GET"
        data[] = Dict("available_qty" => "-0.25")
        holding = us_available_holding(us, GetUSAvailableHoldingOptions(symbol = "BTCUSD.BKKT", equity_type = "CRYPTO", position_side = "SHORT"))
        @test holding.available_qty == "-0.25"
        @test seen[end].query == Dict("symbol" => "BTCUSD.BKKT", "equity_type" => "CRYPTO", "position_side" => "SHORT")
        us_available_holding(us, GetUSAvailableHoldingOptions(symbol = "AAPL.US", equity_type = "", position_side = ""))
        @test seen[end].query["equity_type"] == "STOCK"
        @test seen[end].query["position_side"] == "LONG"

        data[] = Dict("current_page" => "1", "items" => [Dict("symbol" => "BTCUSD.BKKT", "quantity" => "0.1", "create_at" => "1791478565")])
        before = length(seen)
        txn = us_transaction_history(us, opts)
        @test length(seen) == before + 1
        @test seen[end].method == "POST"
        @test isempty(seen[end].query)
        @test seen[end].body == Dict("start" => 1767225600, "end" => 1767312000, "page" => 1, "size" => 20)
        @test txn.current_page == 1
        @test only(txn.items).create_at == unix2datetime(1791478565)
        @test only(txn.items).quantity == "0.1"
        filtered = GetUSTransactionHistoryOptions(start_at = opts.start_at, end_at = opts.end_at,
            page = 2, size = 50, types = ["TT_CRYPTO_TRADING"], currency = "USD")
        us_transaction_history(us, filtered)
        @test seen[end].body["page"] == 2
        @test seen[end].body["size"] == 50
        @test seen[end].body["types"] == ["TT_CRYPTO_TRADING"]
        @test seen[end].body["currency"] == "USD"
        us_transaction_history(us, GetUSTransactionHistoryOptions(start_at = opts.start_at, end_at = opts.end_at, page = -1, size = 0))
        @test seen[end].body["page"] == 1
        @test seen[end].body["size"] == 20
        data[] = JSON.parse("""{"universal_exchanges":{"us_lb_apex":{"spec_exchanges":{"am":{"exchanges":[{"bid_rate":1}]}}}}}""")
        rates = us_exchange_rates(us)
        @test only(rates.exchanges).universal_key == "us_lb_apex"
        @test only(rates.exchanges).bid_rate == "1"
        @test isempty(seen[end].query)

        # History supports US tokens and continues paging with absent side and fractional fills.
        paging[] = true
        fills = history_executions(us)
        @test length(fills) == 2
        @test all(t -> t.side === OrderSide.UnknownSide, fills)
        @test all(t -> t.quantity === Dec64("0.168"), fills)
        @test [seen[end-1].query["page"], seen[end].query["page"]] == ["1", "2"]
        paging[] = false
        data[] = Dict("trades" => [_v530_execution()], "has_more" => false)
        @test only(today_executions(us).trades).quantity === Dec64("0.168")
        @test only(all_executions(contexts[1]).trades).side === OrderSide.UnknownSide

        # Method-specific restriction: US cancel/replace still reach the gateway.
        code[] = 987654
        for call in (() -> cancel_order(us, "1"),
                     () -> replace_order(us, ReplaceOrderOptions(order_id = "1", submitted_quantity = 1)))
            before = length(seen)
            @test error_from(call).code == 987654
            @test length(seen) == before + 1
        end
        code[] = 0

        # Option chains always use the same HTTP contract, regardless of quote transport/region.
        for transport in (QuoteTransport.Http, QuoteTransport.WebSocket), key in ("fake-key", "us_fake-key")
            cfg = Settings(key, "fake-secret", "fake-token", DateTime(2099); http_url = url, quote_transport = transport)
            q = LongBridge.Quote._build_quote_context(cfg; start_tasks = false)
            try
                data[] = Dict("list" => [Dict("symbol" => "AAPL261120C345000.US", "expiry_date" => "20261120",
                    "strike_price" => "345", "direction" => "C", "option_type" => "", "standard_attr" => "")])
                for standard in (false, true, false)
                    before = length(seen)
                    contracts = option_chain_info_by_date(q, "AAPL.US", Date(2026, 11, 20); standard_only = standard)
                    @test length(seen) == before + 1
                    @test only(contracts).symbol == "AAPL261120C345000.US"
                    @test only(contracts).expiry_date == Date(2026, 11, 20)
                    @test seen[end].method == "POST"
                    @test seen[end].path == "/v1/quote/options/strikes"
                    @test seen[end].headers["content-type"] == "application/json; charset=utf-8"
                    @test seen[end].region == (startswith(key, "us_") ? "us" : "ap")
                    @test isempty(seen[end].query)
                    expected = Dict{String,Any}("symbol" => "AAPL.US", "expiry_date" => "20261120")
                    standard && (expected["standard_only"] = true)
                    @test seen[end].body == expected
                    standard && @test seen[end].body["standard_only"] === true
                    @test isnothing(q.inner.background_task)
                end
                for emptydata in (Dict(), Dict("list" => nothing), Dict("list" => []))
                    data[] = emptydata
                    @test isempty(option_chain_info_by_date(q, "AAPL.US", Date(2026, 11, 20)))
                end
                code[] = 987654
                @test error_from(() -> option_chain_info_by_date(q, "AAPL.US", Date(2026, 11, 20))).code == 987654
                code[] = 0
            finally
                close(q)
            end
        end
    finally
        foreach(close, contexts)
        close(server)
    end
end
