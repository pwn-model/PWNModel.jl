using Ark
using BenchmarkTools
using Chairmarks
using PWNModel

const SECONDS = 0.5
const SUITE = BenchmarkGroup()

include("bench_run_model.jl")
