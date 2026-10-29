@testset "CoarseTreeAttractionMap reports the log of the selected field" begin
    world = World()

    healthy = Grid(3, 2, 50, 0.0)
    damaged = Grid(3, 2, 50, 0.0)
    healthy[3, 2] = 0.5
    damaged[3, 2] = 0.25
    add_resource!(world, PWNModel.HealthyTreeAttractionCoarse(healthy))
    add_resource!(world, PWNModel.DamagedTreeAttractionCoarse(damaged))

    for (damaged_trees, want) in ((false, 0.5), (true, 0.25))
        o = PWNModel.CoarseTreeAttractionMap(damaged_trees=damaged_trees)
        PWNModel.initialize!(o, world)

        values = PWNModel.data(o, world)
        @test size(values) == (3, 2)
        @test isapprox(values[3, 2], log(want); atol=1e-12)
        @test values[1, 1] == -Inf # an empty cell's log is -Inf
    end
end
