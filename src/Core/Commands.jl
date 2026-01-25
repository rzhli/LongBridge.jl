# 共享命令类型，用于 Quote 和 Trade 模块的 Actor 模式

module Commands

export AbstractCommand, HttpGetCmd, HttpPostCmd, HttpPutCmd, HttpDeleteCmd, DisconnectCmd

abstract type AbstractCommand end

# Performance note: Using parametric types for body field to avoid boxing.
# Channel{Any} is kept for resp_ch as responses are intentionally polymorphic.

struct HttpGetCmd <: AbstractCommand
    path::String
    params::Dict{String,Any}
    resp_ch::Channel{Any}
end

struct HttpPostCmd{B} <: AbstractCommand
    path::String
    body::B
    resp_ch::Channel{Any}
end

struct HttpPutCmd{B} <: AbstractCommand
    path::String
    body::B
    resp_ch::Channel{Any}
end

struct HttpDeleteCmd <: AbstractCommand
    path::String
    params::Dict{String,Any}
    resp_ch::Channel{Any}
end

struct DisconnectCmd <: AbstractCommand end

end # module
