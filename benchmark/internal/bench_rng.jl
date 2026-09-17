function setup_rng_default(n::Int)
    return Random.default_rng()
end

function benchmark_rng_default(args, n)
    rng = args
    x = 0.0
    for _ in 1:n
        x += rand(rng)
    end
    return x
end

SUITE["benchmark_rng_default n=100000"] =
    @be setup_rng_default(100000) benchmark_rng_default(_, 100000) seconds = SECONDS

function setup_rng_go(n::Int)
    return PWNModel.Rng(1)
end

function benchmark_rng_go(args, n)
    rng = args
    x = 0.0
    for _ in 1:n
        x += rand(rng)
    end
    return x
end

SUITE["benchmark_rng_go n=100000"] =
    @be setup_rng_go(100000) benchmark_rng_go(_, 100000) seconds = SECONDS
