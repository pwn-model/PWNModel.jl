@testset "Rng" begin
    same_seed_a = PWNModel.Rng(1)
    same_seed_b = PWNModel.Rng(1)
    other_seed = PWNModel.Rng(2)

    @test rand(same_seed_a) == rand(same_seed_b)
    @test rand(PWNModel.Rng(1)) != rand(other_seed)
end

@testset "Rng sequence matches Go implementation" begin
    # Hard-coded sequence produced by seeding the sibling Go implementation's
    # RNG (math/rand/v2's PCG-DXSM, via rand.New(rand.NewPCG(0, 1)).Float64())
    # with the same seed. Both implementations must produce this exact
    # sequence for the model runs to be reproducible across languages.
    expected = [
        0.47114790869927514,
        0.7197903592279431,
        0.8082559527889128,
        0.7087981878729903,
        0.1539910046124079,
    ]

    rng = PWNModel.Rng(1)
    for exp in expected
        @test rand(rng) == exp
    end
end
