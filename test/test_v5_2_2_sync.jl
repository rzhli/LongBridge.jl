using Test, LongBridge, Dates, JSON, HTTP, DataFrames
using DecFP: Dec64

function _attached_fixture()
    JSON.parse("""
        {"order_id":"706388312699592705","attached_type_display":"STOP_LOSS",
         "trigger_price":"10.500","quantity":"200.5","executed_qty":"0",
         "status":"NewStatus","updated_at":"1651644898","withdrawn":false,
         "gtd":"","time_in_force":"Day","counter_id":"","trigger_status":"NOT_USED",
         "executed_amount":"0","tag":"Normal","submitted_at":"1651644897",
         "executed_price":"0.000","force_only_rth":"RTH_ONLY","reviewed":false,
         "activate_order_type":"LIT","activate_rth":"RTH_ONLY","submit_price":""}
        """)
end

function _attached_parent_fixture()
    JSON.parse("""
        {"currency":"USD","executed_price":"0","executed_quantity":"0","expire_date":"",
         "last_done":"","limit_offset":"","msg":"","order_id":"test-order",
         "order_type":"LO","outside_rth":"RTH_ONLY","price":"1.5","quantity":"1",
         "side":"Buy","status":"NewStatus","stock_name":"Apple","submitted_at":"1767225600",
         "symbol":"AAPL.US","tag":"Normal","time_in_force":"Day","trailing_amount":"",
         "trailing_percent":"","trigger_at":"0","trigger_price":"","trigger_status":"NOT_USED",
         "updated_at":"0","remark":"","free_status":"None","free_amount":"","free_currency":"USD",
         "deductions_status":"NONE","deductions_amount":"","deductions_currency":"USD",
         "platform_deducted_status":"NONE","platform_deducted_amount":"","platform_deducted_currency":"USD",
         "history":[],"charge_detail":{"total_charges":"0","currency":"USD","items":[]}}
        """)
end

@testset "v5.2.2 attached types and serialization" begin
    TP = LongBridge.TradeProtocol
    TR = LongBridge.Trade
    @test VersionNumber(LongBridge.VERSION) >= v"0.13.0"
    for name in (:AttachedOrderType, :AttachedOrderDetail, :SubmitAttachedParams, :ReplaceAttachedParams)
        @test name in names(LongBridge)
        @test getproperty(LongBridge, name) === getproperty(TP, name)
    end
    for (kind, wire) in ((AttachedOrderType.Unknown, "Unknown"),
                         (AttachedOrderType.ProfitTaker, "PROFIT_TAKER"),
                         (AttachedOrderType.StopLoss, "STOP_LOSS"),
                         (AttachedOrderType.Bracket, "BRACKET"))
        @test JSON.parse(JSON.json(wire), AttachedOrderType.T) === kind
        for T in (SubmitAttachedParams, ReplaceAttachedParams)
            params = T(attached_order_type = kind)
            @test TR.to_dict(params) == Dict("attached_order_type" => wire)
            @test isnothing(params.profit_taker_depth_level)
            @test isnothing(params.stop_loss_depth_level)
        end
    end
    @test JSON.parse("\"future-type\"", AttachedOrderType.T) === AttachedOrderType.Unknown
    for T in (SubmitAttachedParams, ReplaceAttachedParams), field in (:profit_taker_depth_level, :stop_loss_depth_level)
        for n in (typemin(Int32), -2, 0, 3, typemax(Int32))
            params = T(; attached_order_type = AttachedOrderType.Bracket, field => n)
            @test getproperty(params, field) === Int32(n)
            @test TR.to_dict(params)[string(field)] === Int32(n)
        end
        for n in (Int64(typemin(Int32)) - 1, Int64(typemax(Int32)) + 1, 1.5)
            @test_throws InexactError T(; attached_order_type = AttachedOrderType.Bracket, field => n)
        end
    end
end

@testset "v5.2.2 attached order readback" begin
    TP = LongBridge.TradeProtocol
    raw = _attached_fixture()
    detail = JSON.parse(JSON.json(raw), AttachedOrderDetail)
    @test detail.attached_type_display === AttachedOrderType.StopLoss
    @test detail.quantity == Dec64("200.5")
    @test detail.trigger_price == Dec64("10.5")
    @test detail.executed_price == Dec64(0)
    @test detail.submit_price === nothing
    @test detail.gtd === nothing
    @test detail.trigger_status === nothing
    @test detail.updated_at == unix2datetime(1651644898) + Hour(8)
    @test detail.submitted_at == unix2datetime(1651644897) + Hour(8)
    @test detail.force_only_rth === OutsideRTH.RTH_ONLY
    @test detail.activate_order_type === OrderType.LIT
    @test detail.limit_depth_level === nothing
    encoded = JSON.parse(JSON.json(detail))
    @test encoded.order_id == raw.order_id
    @test encoded.limit_depth_level === nothing
    @test LongBridge.Utils.construct(AttachedOrderDetail, raw).quantity === detail.quantity
    for (wire, expected) in (("DEACTIVE", TP.TriggerStatus.Deactive),
                              ("ACTIVE", TP.TriggerStatus.Active),
                              ("RELEASED", TP.TriggerStatus.Released),
                              ("NOT_USED", nothing), (nothing, nothing))
        raw["trigger_status"] = wire
        @test JSON.parse(JSON.json(raw), AttachedOrderDetail).trigger_status === expected
    end
    merge!(raw, Dict("gtd" => "2026-12-31", "updated_at" => 1651644898,
                     "submitted_at" => 1651644897, "quantity" => 200.5, "executed_qty" => 2,
                     "trigger_price" => nothing, "executed_price" => "", "submit_price" => "10.25",
                     "force_only_rth" => "UnknownOutsideRth", "activate_rth" => "OPTION_PRE_MARKET"))
    detail = JSON.parse(JSON.json(raw), AttachedOrderDetail)
    @test detail.gtd == Date(2026, 12, 31)
    @test detail.quantity == Dec64("200.5")
    @test detail.executed_qty == Dec64(2)
    @test detail.trigger_price === nothing
    @test detail.executed_price === nothing
    @test detail.submit_price == Dec64("10.25")
    @test detail.force_only_rth === nothing
    @test detail.activate_rth === OutsideRTH.OptionPreMarket
end

# Fake credentials; real request serialization/response parsing over loopback only.
@testset "v5.2.2 attached order HTTP contracts" begin
    TR = LongBridge.Trade
    TP = LongBridge.TradeProtocol
    seen = NamedTuple[]
    data = Ref{Any}(Dict("order_id" => "test-order"))
    server = HTTP.serve!("127.0.0.1", 0; listenany = true) do req
        body = String(req.body)
        push!(seen, (method = req.method, path = String(HTTP.URI(req.target).path),
                     body = isempty(body) ? nothing : JSON.parse(body)))
        HTTP.Response(200, ["Content-Type" => "application/json"];
            body = JSON.json(Dict("code" => 0, "message" => "", "data" => data[])))
    end
    cfg = Config.Settings("fake-key", "fake-secret", "fake-token", DateTime(2099);
                          http_url = "http://127.0.0.1:$(HTTP.port(server))",
                          trade_ws_url = "ws://127.0.0.1:1")
    ctx = TR._build_trade_context(cfg; start_tasks = false)
    inner = ctx.inner
    inner.background_task = @async for cmd in inner.command_ch
        TR.handle_command(inner, cmd)
    end
    try
        base = (symbol = "AAPL.US", order_type = OrderType.LO, side = OrderSide.Buy,
                submitted_quantity = 1, time_in_force = TimeInForceType.Day)
        replacebase = (order_id = "test-order", submitted_quantity = 1)
        for (f, T, P, kwargs, method) in (
            (submit_order, SubmitOrderOptions, SubmitAttachedParams, base, "POST"),
            (replace_order, ReplaceOrderOptions, ReplaceAttachedParams, replacebase, "PUT"),
        )
            f(ctx, T(; kwargs...))
            @test !haskey(seen[end].body, "attached_params")
            legacy_body = copy(seen[end].body)
            params = P(attached_order_type = AttachedOrderType.Bracket)
            f(ctx, T(; kwargs..., attached_params = params))
            @test seen[end].body.attached_params == Dict("attached_order_type" => "BRACKET")
            @test delete!(copy(seen[end].body), "attached_params") == legacy_body
            params = P(attached_order_type = AttachedOrderType.Bracket,
                profit_taker_price = Dec64("12.125"), stop_loss_price = Dec64("9.875"),
                time_in_force = TimeInForceType.GTD, expire_time = 1798675200,
                activate_order_type = OrderType.LIT, activate_rth = OutsideRTH.OptionPreMarket,
                profit_taker_submit_price = Dec64("12.1"), stop_loss_submit_price = Dec64("9.8"),
                profit_taker_depth_level = 2, stop_loss_depth_level = -5)
            f(ctx, T(; kwargs..., attached_params = params, delayed_until = DateTime(2026, 12, 1)))
            @test seen[end].method == method
            @test seen[end].path == "/v1/trade/order"
            @test seen[end].body.delayed_until == Int(datetime2unix(DateTime(2026, 12, 1)))
            @test seen[end].body.attached_params == Dict(
                "attached_order_type" => "BRACKET", "profit_taker_price" => "12.125",
                "stop_loss_price" => "9.875", "time_in_force" => "GTD", "expire_time" => 1798675200,
                "activate_order_type" => "LIT", "activate_rth" => "OPTION_PRE_MARKET",
                "profit_taker_submit_price" => "12.1", "stop_loss_submit_price" => "9.8",
                "profit_taker_depth_level" => 2, "stop_loss_depth_level" => -5)
        end
        for cancel in (false, true)
            params = ReplaceAttachedParams(attached_order_type = AttachedOrderType.Bracket,
                profit_taker_id = 9007199254740993, stop_loss_id = 9007199254740994,
                main_id = 9007199254740995, cancel_all_attached = cancel,
                quantity = Dec64("0.5"), market_price = Dec64("10.25"),
                profit_taker_depth_level = 0, stop_loss_depth_level = 0)
            replace_order(ctx, ReplaceOrderOptions(; replacebase..., attached_params = params,
                                                   clear_delayed_until = true))
            @test seen[end].body.delayed_until === 1
            @test seen[end].body.attached_params == Dict(
                "attached_order_type" => "BRACKET", "profit_taker_id" => 9007199254740993,
                "stop_loss_id" => 9007199254740994, "main_id" => 9007199254740995,
                "cancel_all_attached" => cancel, "quantity" => "0.5", "market_price" => "10.25",
                "profit_taker_depth_level" => 0, "stop_loss_depth_level" => 0)
        end

        parent = _attached_parent_fixture()
        # Direct typed parsing must also accept older responses without the new field.
        legacy = TR._parse_order_data(parent)
        delete!(legacy, "attached_orders")
        a = JSON.parse(JSON.json(legacy), TP.Order)
        b = JSON.parse(JSON.json(legacy), TP.Order)
        @test isempty(a.attached_orders)
        @test a.attached_orders !== b.attached_orders
        raw = _attached_fixture()
        parent["attached_orders"] = [raw]
        cases = ((missing, nothing), (nothing, nothing), (0, nothing), ("0", nothing),
                 (3, Int32(3)), (-2, Int32(-2)), ("  +3  ", Int32(3)), ("-2", Int32(-2)),
                 (typemin(Int32), typemin(Int32)), (typemax(Int32), typemax(Int32)),
                 (string(typemin(Int32)), typemin(Int32)), (string(typemax(Int32)), typemax(Int32)),
                 (Int64(typemin(Int32)) - 1, nothing), (Int64(typemax(Int32)) + 1, nothing),
                 ("2147483648", nothing), ("9999999999999999999999999", nothing),
                 ("abc", nothing), ("", nothing), ("  ", nothing), ("3.0", nothing),
                 (3.0, nothing), (1.5, nothing), (true, nothing), (false, nothing),
                 ([], nothing), (Dict(), nothing))
        for (wire, expected) in cases
            ismissing(wire) ? delete!(raw, "limit_depth_level") : (raw["limit_depth_level"] = wire)
            @test JSON.parse(JSON.json(raw), AttachedOrderDetail).limit_depth_level === expected
            order = JSON.parse(JSON.json(TR._parse_order_data(parent)), TP.Order)
            @test only(order.attached_orders).limit_depth_level === expected
            data[] = Dict("orders" => [parent])
            for (f, path) in ((today_orders, "/v1/trade/order/today"),
                               (history_orders, "/v1/trade/order/history"))
                df = f(ctx)
                @test only(df[1, "Attached Orders"]).limit_depth_level === expected
                @test eltype(df[!, "Attached Orders"]) === Vector{AttachedOrderDetail}
                @test seen[end].method == "GET"
                @test seen[end].path == path
            end
            data[] = parent
            @test only(order_detail(ctx, "test-order").attached_orders).limit_depth_level === expected
            @test seen[end].path == "/v1/trade/order"
        end
        for raw_orders in (missing, nothing, [])
            ismissing(raw_orders) ? delete!(parent, "attached_orders") : (parent["attached_orders"] = raw_orders)
            data[] = parent
            @test isempty(order_detail(ctx, "test-order").attached_orders)
            data[] = Dict("orders" => [parent])
            @test isempty(today_orders(ctx)[1, "Attached Orders"])
            @test isempty(history_orders(ctx)[1, "Attached Orders"])
        end
        data[] = Dict("orders" => [])
        for f in (today_orders, history_orders)
            df = f(ctx)
            @test nrow(df) == 0
            @test eltype(df[!, "Attached Orders"]) === Vector{AttachedOrderDetail}
        end
    finally
        close(ctx)
        close(server)
    end
end
