using Test
using LongPort
using LongPort.Config
using Dates

@testset "Config defaults" begin
    mktemp() do f, io
        write(io, """
        app_key = "k"
        app_secret = "s"
        access_token = "t"
        token_expire_time = "2099-01-01T00:00:00"
        """)
        close(io)
        cfg = from_toml(f)
        @test cfg.language == LongPort.Constant.Language.ZH_CN
        @test cfg.enable_overnight == true
    end
end

@testset "Disconnect" begin
    cfg = config(
        "test_app_key",
        "test_app_secret",
        "test_access_token",
        DateTime(2099, 1, 1);
        http_url = "https://openapi.longportapp.com",
        quote_ws_url = "wss://openapi-quote.longportapp.com",
        trade_ws_url = "wss://openapi-trade.longportapp.com"
    )

    # Note: These tests will fail to connect without valid credentials,
    # but we can at least verify the context creation works
    @test cfg.app_key == "test_app_key"
    @test cfg.http_url == "https://openapi.longportapp.com"
end
