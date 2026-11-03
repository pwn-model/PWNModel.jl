@testset "Rng" begin
    same_seed_a = PWNModel.Rng(1)
    same_seed_b = PWNModel.Rng(1)
    other_seed = PWNModel.Rng(2)

    @test rand(same_seed_a) == rand(same_seed_b)
    @test rand(PWNModel.Rng(1)) != rand(other_seed)
end

@testset "Rng sequence matches Go implementation" begin
    # Hard-coded sequence produced by seeding the sibling Go implementation's
    # RNG (res.Xoshiro256pp, via rand.New(res.NewXoshiro256pp(1)).Float64())
    # with the same seed. Both implementations must produce this exact
    # sequence for the model runs to be reproducible across languages.
    expected = [
        0.2542939531119204,
        0.24657061311742734,
        0.19704820012757895,
        0.6861882214435763,
        0.774599501478695,
    ]

    rng = PWNModel.Rng(1)
    for exp in expected
        @test rand(rng) == exp
    end
end

@testset "randexp sequence matches Go's util.ExpFloat64" begin
    # Hard-coded sequence produced by calling Julia's own randexp directly on
    # the raw Xoshiro (not through Rng's low-53-bit rand override, which
    # randexp never goes through):
    #   rng = Random.Xoshiro(1); [randexp(rng) for _ in 1:5]
    # The sibling Go implementation's util.ExpFloat64 (pwn/util/random.go) is
    # a deliberate port of this same algorithm, seeded from the shared
    # Xoshiro256++ source, so both implementations must produce this exact
    # sequence from the same seed. Exponential draws must always go through
    # randexp on rng.xoshiro directly, not through Rng's rand override, for
    # this to hold.
    expected = [
        0.09423776100793935,
        2.1457972199590083,
        1.3231948887670477,
        5.464092249100119,
        2.207171812272818,
    ]

    rng = PWNModel.Rng(1)
    for exp in expected
        @test randexp(rng.xoshiro) == exp
    end
end

@testset "random_direction matches Go implementation" begin
    # The same values are hard-coded in the sibling Go implementation's test
    # of util.RandomDirection (pwn/util/random_test.go), for the same seed.
    expected = [
        (-0.6960820844311084, -0.7179622077338357),
        (-0.851964016542242, 0.5236003385380975),
        (0.59490343410105, 0.8037971784565915),
    ]

    rng = PWNModel.Rng(1)
    for e in expected
        @test PWNModel.random_direction(rng) == e
    end
end

@testset "random_direction is a uniform unit vector" begin
    rng = PWNModel.Rng(1)

    n = 80000
    sectors = 16
    counts = zeros(Int, sectors)
    for _ in 1:n
        dx, dy = PWNModel.random_direction(rng)
        @test isapprox(dx * dx + dy * dy, 1.0; atol=1e-12)

        angle = atan(dy, dx) + pi
        counts[min(floor(Int, angle / (2pi) * sectors) + 1, sectors)] += 1
    end
    @test all(c -> abs(c - n ÷ sectors) <= 300, counts)
end
