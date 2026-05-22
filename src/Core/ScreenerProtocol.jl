module ScreenerProtocol

    using JSON3, StructTypes

    export ScreenerRecommendStrategiesResponse,
           ScreenerUserStrategiesResponse,
           ScreenerStrategyResponse,
           ScreenerSearchResponse,
           ScreenerIndicatorsResponse

    # 上游 5 个端点均返回结构多变的 JSON——这里统一保留原始 JSON 对象，
    # 由调用方按需取字段。后续若 API 稳定可再细化类型。

    """
    `screener_recommend_strategies` 的原始 JSON 响应包装。
    """
    struct ScreenerRecommendStrategiesResponse
        data::Any
    end
    StructTypes.StructType(::Type{ScreenerRecommendStrategiesResponse}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{ScreenerRecommendStrategiesResponse}, obj) =
        ScreenerRecommendStrategiesResponse(obj)

    """
    `screener_user_strategies` 的原始 JSON 响应包装。
    """
    struct ScreenerUserStrategiesResponse
        data::Any
    end
    StructTypes.StructType(::Type{ScreenerUserStrategiesResponse}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{ScreenerUserStrategiesResponse}, obj) =
        ScreenerUserStrategiesResponse(obj)

    """
    `screener_strategy` 的原始 JSON 响应包装。
    """
    struct ScreenerStrategyResponse
        data::Any
    end
    StructTypes.StructType(::Type{ScreenerStrategyResponse}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{ScreenerStrategyResponse}, obj) =
        ScreenerStrategyResponse(obj)

    """
    `screener_search` 的原始 JSON 响应包装（含分页结果）。
    """
    struct ScreenerSearchResponse
        data::Any
    end
    StructTypes.StructType(::Type{ScreenerSearchResponse}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{ScreenerSearchResponse}, obj) =
        ScreenerSearchResponse(obj)

    """
    `screener_indicators` 的原始 JSON 响应包装。
    """
    struct ScreenerIndicatorsResponse
        data::Any
    end
    StructTypes.StructType(::Type{ScreenerIndicatorsResponse}) = StructTypes.CustomStruct()
    StructTypes.construct(::Type{ScreenerIndicatorsResponse}, obj) =
        ScreenerIndicatorsResponse(obj)

end # module ScreenerProtocol
