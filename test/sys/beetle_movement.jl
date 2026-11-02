function max_field_neighbor_setup(seed)
    s = PWNModel.BeetleMovement(;
        steps_per_tick=1, duration_feeding=1, duration_egg_laying=1,
        leave_tree_probability=0.0, random_walk_probability=0.0,
    )
    s._width, s._height = 10, 10
    field = Grid(10, 10, 10, 0.5)
    return s, field, Rng(seed)
end

@testset "max_field_neighbor unique max" begin
    s, field, rng = max_field_neighbor_setup(1)
    field[7, 5] = 0.9

    ref = Rng(1)

    @test PWNModel.max_field_neighbor(s, rng, field, 6, 6) == (7, 5)

    # Without a tie, no random number is drawn.
    @test rand(rng.xoshiro, UInt64) == rand(ref.xoshiro, UInt64)
end

@testset "max_field_neighbor tie only picks candidates" begin
    s, field, rng = max_field_neighbor_setup(1)
    field[5, 5] = 0.9
    field[7, 7] = 0.9

    counts = Dict{Tuple{Int,Int},Int}()
    for _ in 1:1000
        c = PWNModel.max_field_neighbor(s, rng, field, 6, 6)
        counts[c] = get(counts, c, 0) + 1
    end

    @test length(counts) == 2
    @test abs(counts[(5, 5)] - 500) <= 75
    @test abs(counts[(7, 7)] - 500) <= 75
end

# On a flat field, all neighbors are equally likely, without bias towards
# the first NEIGHBOR_OFFSETS.
@testset "max_field_neighbor flat field uniform" begin
    s, field, rng = max_field_neighbor_setup(1)

    n = 8000
    counts = Dict{Tuple{Int,Int},Int}()
    for _ in 1:n
        x, y = PWNModel.max_field_neighbor(s, rng, field, 6, 6)
        counts[(x - 6, y - 6)] = get(counts, (x - 6, y - 6), 0) + 1
    end

    @test length(counts) == length(PWNModel.NEIGHBOR_OFFSETS)
    for o in PWNModel.NEIGHBOR_OFFSETS
        @test abs(counts[o] - n ÷ length(PWNModel.NEIGHBOR_OFFSETS)) <= 120
    end
end

# At the world's corner, only in-bounds neighbors are candidates.
@testset "max_field_neighbor flat field corner" begin
    s, field, rng = max_field_neighbor_setup(1)

    counts = Dict{Tuple{Int,Int},Int}()
    for _ in 1:300
        c = PWNModel.max_field_neighbor(s, rng, field, 1, 1)
        counts[c] = get(counts, c, 0) + 1
    end

    @test length(counts) == 3
    for c in ((2, 1), (1, 2), (2, 2))
        @test get(counts, c, 0) > 0
    end
end
