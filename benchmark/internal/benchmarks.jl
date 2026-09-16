using Ark
using BenchmarkTools
using Chairmarks
using PWNModel
using Random

const SECONDS = 0.5
const SUITE = BenchmarkGroup()

include("bench_rng.jl")
