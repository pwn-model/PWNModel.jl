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

@testset "Random.shuffle! sequence matches Go implementation" begin
    # Hard-coded permutation produced by seeding the sibling Go
    # implementation's util.Shuffle (pwn/util/shuffle_test.go) with the same
    # seed and shuffling the same slice:
    #   Shuffle(res.NewXoshiro256pp(1), []int{1, ..., 10})
    # util.Shuffle is a deliberate Go port of Julia's Random.shuffle!
    # algorithm (see its doc comment), so both implementations must select
    # the same permutation from the same seed.
    expected = [4, 3, 5, 10, 6, 1, 7, 9, 8, 2]

    rng = PWNModel.Rng(1)
    values = collect(1:10)
    Random.shuffle!(rng.xoshiro, values)

    @test values == expected
end
