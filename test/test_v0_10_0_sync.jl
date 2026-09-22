using Test, JSON, Dates

# v0.10.0 / 上游 openapi v4.2.1→v5.1.0 同步：
#   #581 valuation_comparison 数组格式 / #591 history_executions 分页 /
#   Execution.side + all_executions / #588 期权链 HTTP 迁移 /
#   #575+#590 多腿期权订单 / #577+#578 SignalContext / #570 GridContext

@testset "v0.10.0 release metadata" begin
    @test VersionNumber(LongBridge.VERSION) >= v"0.10.0"
end

@testset "v0.10.0 exports" begin
    # Trade
    @test isdefined(LongBridge, :all_executions)
    @test isdefined(LongBridge, :submit_multileg)
    @test isdefined(LongBridge, :MultiLegStrategy)
    # Quote 期权链
    @test isdefined(LongBridge, :OptionChainContract)
    @test isdefined(LongBridge, :OptionDirection)
    @test isdefined(LongBridge, :OptionExpiryCycleType)
    @test isdefined(LongBridge, :OptionStandardAttr)
    # Signal
    @test isdefined(LongBridge, :SignalContext)
    @test isdefined(LongBridge, :signals)
    @test isdefined(LongBridge, :security_facts)
    @test isdefined(LongBridge, :SecurityFact)
    # Grid
    @test isdefined(LongBridge, :GridContext)
    @test isdefined(LongBridge, :grid_submit)
    @test isdefined(LongBridge, :grid_list)
    @test isdefined(LongBridge, :GridTradeRule)
end

@testset "v0.10.0 Execution has side field" begin
    @test :side in fieldnames(LongBridge.TradeProtocol.Execution)
    @test fieldtype(LongBridge.TradeProtocol.Execution, :side) == LongBridge.OrderSide.T
end

@testset "v0.10.0 option chain contract parsing (#588)" begin
    QP = LongBridge.QuoteProtocol
    raw = JSON.parse(
        """{"symbol":"BABA250718C100000.US","expiry_date":"20250718",
            "strike_price":"100.5","direction":"C","option_type":"",
            "standard_attr":"","days_to_expiry":5}""",
    )
    c = QP.construct(QP.OptionChainContract, raw)
    @test c.symbol == "BABA250718C100000.US"
    @test c.expiry_date == Date(2025, 7, 18)
    @test c.strike_price == 100.5
    @test c.direction === QP.OptionDirection.Call
    @test c.option_type === QP.OptionExpiryCycleType.Monthly   # 空串→月度
    @test c.standard_attr === QP.OptionStandardAttr.Normal      # 空串→正常
    @test c.days_to_expiry == 5

    # 老合约 / 周期权 / put / 空行权价
    raw2 = JSON.parse(
        """{"symbol":"X.US","expiry_date":"20250718","strike_price":"",
            "direction":"P","option_type":"W","standard_attr":"old",
            "days_to_expiry":-3}""",
    )
    c2 = QP.construct(QP.OptionChainContract, raw2)
    @test c2.direction === QP.OptionDirection.Put
    @test c2.option_type === QP.OptionExpiryCycleType.Weekly
    @test c2.standard_attr === QP.OptionStandardAttr.Old
    @test c2.strike_price == 0.0
    @test c2.days_to_expiry == -3
end

@testset "v0.10.0 multi-leg strategy (#575+#590)" begin
    TP = LongBridge.TradeProtocol
    # 日历价差枚举值
    @test Int(TP.MultiLegStrategy.CalendarCallSpread) == 7
    @test Int(TP.MultiLegStrategy.CalendarPutSpread) == 8
    # 字符串序列化名（提交时用）
    @test TP.multileg_strategy_str(TP.MultiLegStrategy.VerticalCallSpread) ==
          "VerticalCallSpread"
    @test TP.multileg_strategy_str(TP.MultiLegStrategy.CalendarPutSpread) ==
          "CalendarPutSpread"
    # 回读解析
    info = TP.construct(
        TP.MultiLegInfo,
        JSON.parse(
            """{"strategy":"CalendarPutSpread","strategy_name":"n","multileg_id":"m",
                "code":"c","legs":[{"symbol":"X.US","side":"Sell","position":"SHORT",
                "ratio_quantity":"2","strike_price":"","expire_date":"20250718",
                "contract_direction":"P"}]}""",
        ),
    )
    @test info.strategy === TP.MultiLegStrategy.CalendarPutSpread
    @test length(info.legs) == 1
    @test info.legs[1].position === TP.MultiLegPosition.Short
    @test info.legs[1].contract_direction === TP.ContractDirection.Put
    @test info.legs[1].expire_date == Date(2025, 7, 18)
    @test info.legs[1].strike_price === nothing

    # multi_leg 回读到 Order（通过 _parse_order_data 预处理 + JSON.parse）
    @test :multi_leg in fieldnames(TP.Order)
    @test :multi_leg in fieldnames(TP.OrderDetail)
    order_json = """{"order_id":"1","status":"FilledStatus","stock_name":"n",
        "quantity":"1","executed_quantity":"1","price":"10","executed_price":"10",
        "submitted_at":"1651657497","side":"Buy","symbol":"AAPL.US","order_type":"LO",
        "last_done":"10","trigger_price":"","msg":"","tag":"Normal","time_in_force":"Day",
        "expire_date":"","updated_at":"0","trigger_at":"0","trailing_amount":"",
        "trailing_percent":"","limit_offset":"","trigger_status":"NOT_USED","currency":"USD",
        "outside_rth":"UnknownOutsideRth","remark":"",
        "multi_leg":{"strategy":"CalendarPutSpread","strategy_name":"cps","multileg_id":"m",
        "code":"c","legs":[{"symbol":"X.US","side":"Sell","position":"SHORT",
        "ratio_quantity":"2","strike_price":"","expire_date":"20250718",
        "contract_direction":"P"}]}}"""
    o = JSON.parse(
        JSON.json([LongBridge.Trade._parse_order_data(JSON.parse(order_json))]),
        Vector{TP.Order},
    )[1]
    @test o.multi_leg isa TP.MultiLegInfo
    @test o.multi_leg.strategy === TP.MultiLegStrategy.CalendarPutSpread
    @test o.multi_leg.legs[1].contract_direction === TP.ContractDirection.Put
    @test o.multi_leg.legs[1].expire_date == Date(2025, 7, 18)
    # 无 multi_leg 时为 nothing
    raw_no_ml = JSON.parse(order_json)
    delete!(raw_no_ml, "multi_leg")
    o2 = JSON.parse(
        JSON.json([LongBridge.Trade._parse_order_data(raw_no_ml)]),
        Vector{TP.Order},
    )[1]
    @test o2.multi_leg === nothing
end

@testset "v0.10.0 signal parsing (#577+#578)" begin
    SP = LongBridge.SignalProtocol
    s = SP.construct(
        SP.Signal,
        JSON.parse(
            """{"id":"sign_1","symbol":"AAPL.US","outlook":"Strong bullish",
                "status":1,"analysis_price":"150.5","created_at":1737000000000,
                "updated_at":1737000000000}""",
        ),
    )
    @test s.outlook === SP.Outlook.StrongBullish
    @test s.status === SP.SignalStatus.Active
    @test s.analysis_price == 150.5
    @test s.created_at isa DateTime

    f = SP.construct(
        SP.SecurityFact,
        JSON.parse(
            """{"fact_id":"f1","fact_type":"Technical","direction":"long",
                "occur_time":"2025-01-15T08:00:00Z",
                "factors":[{"name":"rsi_14","long_short_direction":"short",
                "factor_groups":["MOMENTUM"]}],
                "nl_info":{"title":"t","summary":"[{\\"tag\\":\\"RSI\\",\\"value\\":\\"70\\"}]"}}""",
        ),
    )
    @test f.fact_type === SP.FactType.Technical
    @test f.direction === SP.FactDirection.Long
    @test f.factors[1].name == "rsi_14"
    @test f.factors[1].long_short_direction === SP.FactDirection.Short
    @test f.factors[1].factor_groups == ["MOMENTUM"]
    tags = SP.nl_tags(f.nl_info.summary)
    @test length(tags) == 1
    @test tags[1].tag == "RSI"
    @test tags[1].value == "70"
end

@testset "v0.10.0 grid parsing + rule serialization (#570)" begin
    GP = LongBridge.GridProtocol
    # 枚举线格式（整数）
    @test Int(GP.TriggerPriceType.Percent) == 2
    @test Int(GP.GridTimeInForce.GoodTilCanceled) == 1
    @test Int(GP.GridLimitEvent.CloseAtLast) == 2

    # grid_rule_dict: 跳过 nothing、decimal→string、enum→int
    rule = GP.GridTradeRule(
        submitted_base_price = 100.5,
        trigger_price_type = GP.TriggerPriceType.Percent,
        time_in_force = GP.GridTimeInForce.GoodTilCanceled,
        trigger_sell_depth = -3,
    )
    d = GP.grid_rule_dict(rule)
    @test d["submitted_base_price"] == "100.5"
    @test d["trigger_price_type"] == 2
    @test d["time_in_force"] == 1
    @test d["trigger_sell_depth"] == -3
    @test !haskey(d, "lower_limit_price")   # nothing 被跳过
end
