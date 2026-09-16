@testset "frozen_shuffle! sequence matches Go implementation" begin
    # Hard-coded permutation produced by seeding the sibling Go
    # implementation's util.Shuffle (pwn/util/shuffle_test.go) with the same
    # seed and shuffling the same slice:
    #   Shuffle(res.NewXoshiro256pp(1), []int{1, ..., 10})
    # util.Shuffle is a deliberate Go port of frozen_shuffle!'s algorithm, so
    # both implementations must select the same permutation from the same
    # seed, regardless of what Random.shuffle! itself would produce on the
    # Julia version actually running.
    expected = [2, 7, 4, 5, 1, 6, 10, 9, 3, 8]

    rng = PWNModel.Rng(1)
    values = collect(1:10)
    PWNModel.frozen_shuffle!(rng.xoshiro, values)

    @test values == expected
end

@testset "frozen_shuffle! is a permutation" begin
    rng = PWNModel.Rng(1)
    n = 2500
    values = collect(1:n)
    PWNModel.frozen_shuffle!(rng.xoshiro, values)

    @test sort(values) == collect(1:n)
end
