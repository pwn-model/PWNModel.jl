function _setup_colonization_world(width::Int, height::Int, resolution::Int)
    world = World(PWNModel.Position, PWNModel.GridCoords, PWNModel.Damaged, PWNModel.Colonized)

    add_resource!(world, PWNModel.WorldSize(width, height, 10, resolution))

    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    return world
end

@testset "build_kernel self-only at radius zero" begin
    offsets = PWNModel.build_kernel(0, 1.0)
    @test offsets == [PWNModel.KernelOffset(0, 0, 1.0)]
end

@testset "build_kernel normalizes weights" begin
    # Radius 1: the center cell plus its 4 orthogonal neighbors; the
    # diagonal neighbors are farther than the radius and excluded.
    offsets = PWNModel.build_kernel(1, 1.0)
    @test length(offsets) == 5

    total = sum(o.weight for o in offsets)
    @test isapprox(total, 1.0; atol=1e-9)

    center = only(o.weight for o in offsets if o.dx == 0 && o.dy == 0)
    for o in offsets
        if !(o.dx == 0 && o.dy == 0)
            @test o.weight < center
        end
    end
end

@testset "Colonization calc_arrivals! conserves beetle count" begin
    world = World(PWNModel.GridCoords)
    add_resource!(world, PWNModel.WorldSize(30, 30, 10, 10))
    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    s = PWNModel.Colonization(
        tick_of_year=0, kernel_radius=1, kernel_scale=1.0,
        beetles_per_tree=10.0, trees_per_beetle=1.0,
    )
    PWNModel.initialize!(s, world)

    # Place the source away from any edge so the kernel's full support
    # stays in-bounds and beetle count is exactly conserved.
    s._density[2, 2] = 2

    PWNModel.calc_arrivals!(s)

    total = sum(s._arrivals[x, y] for x in 1:s._arrivals.width, y in 1:s._arrivals.height)
    @test isapprox(total, 20.0; atol=1e-9)

    center = s._arrivals[2, 2]
    neighbor = s._arrivals[1, 2]
    corner = s._arrivals[1, 1]
    @test center > neighbor
    @test neighbor > 0.0
    @test corner == 0.0
end

@testset "Colonization calc_probability! occupancy formula" begin
    world = World(PWNModel.GridCoords)
    add_resource!(world, PWNModel.WorldSize(30, 10, 10, 10))
    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    s = PWNModel.Colonization(
        tick_of_year=0, kernel_radius=0, kernel_scale=1.0,
        beetles_per_tree=1.0, trees_per_beetle=1.0,
    )
    PWNModel.initialize!(s, world)

    # Cell (1,1): no susceptible trees -- must be left untouched.
    s._susceptible[1, 1] = 0
    s._arrivals[1, 1] = 5.0

    # Cell (2,1): a single susceptible tree and one attempt -- that
    # attempt necessarily lands on it, so probability must be exactly 1.
    s._susceptible[2, 1] = 1
    s._arrivals[2, 1] = 1.0

    # Cell (3,1): two susceptible trees and one attempt -- the classic
    # occupancy result 1 - (1 - 1/2)^1 = 0.5.
    s._susceptible[3, 1] = 2
    s._arrivals[3, 1] = 1.0

    PWNModel.calc_probability!(s)

    @test s._probability[1, 1] == 0.0
    @test isapprox(s._probability[2, 1], 1.0; atol=1e-9)
    @test isapprox(s._probability[3, 1], 0.5; atol=1e-9)
end

@testset "Colonization skips wrong tick of year" begin
    world = _setup_colonization_world(100, 100, 100)
    add_resource!(world, PWNModel.Rng(1))
    add_resource!(world, PWNModel.Time(0, 0, 0))

    s = PWNModel.Colonization(
        tick_of_year=5, kernel_radius=0, kernel_scale=1.0,
        beetles_per_tree=100.0, trees_per_beetle=100.0,
    )
    PWNModel.initialize!(s, world)

    source = nothing
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Colonized)) do (entities, positions, _)
        positions[1] = PWNModel.Position(1, 1)
        source = entities[1]
    end

    target = nothing
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged)) do (entities, positions, _)
        positions[1] = PWNModel.Position(2, 2)
        target = entities[1]
    end

    PWNModel.update!(s, world)

    @test has_components(world, source, (PWNModel.Colonized,))
    @test !has_components(world, target, (PWNModel.Colonized,))
end

@testset "Colonization colonizes susceptible tree when beetles arrive" begin
    world = _setup_colonization_world(100, 100, 100)
    add_resource!(world, PWNModel.Rng(1))
    add_resource!(world, PWNModel.Time(0, 3, 0))

    # kernel_radius 0 keeps all beetles in the source's own cell, and the
    # large beetles/trees_per_beetle values push the occupancy
    # probability for the cell's single susceptible tree to (effectively)
    # exactly 1, regardless of the RNG draw.
    s = PWNModel.Colonization(
        tick_of_year=3, kernel_radius=0, kernel_scale=1.0,
        beetles_per_tree=5.0, trees_per_beetle=5.0,
    )
    PWNModel.initialize!(s, world)

    source = nothing
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Colonized)) do (entities, positions, _)
        positions[1] = PWNModel.Position(1, 1)
        source = entities[1]
    end

    target = nothing
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged)) do (entities, positions, _)
        positions[1] = PWNModel.Position(5, 5)
        target = entities[1]
    end

    PWNModel.update!(s, world)

    @test has_components(world, target, (PWNModel.Colonized,))

    # The beetles that emerged from the source tree have flown out to lay
    # their eggs elsewhere, so the source tree empties out and becomes
    # available for colonization again.
    @test !has_components(world, source, (PWNModel.Colonized,))
end

@testset "Colonization no colonization without source" begin
    world = _setup_colonization_world(100, 100, 100)
    add_resource!(world, PWNModel.Rng(1))
    add_resource!(world, PWNModel.Time(0, 3, 0))

    s = PWNModel.Colonization(
        tick_of_year=3, kernel_radius=2, kernel_scale=1.0,
        beetles_per_tree=1000.0, trees_per_beetle=1000.0,
    )
    PWNModel.initialize!(s, world)

    targets = Entity[]
    new_entities!(world, 5, (PWNModel.Position, PWNModel.Damaged)) do (entities, positions, _)
        for i in eachindex(entities)
            positions[i] = PWNModel.Position(i, 1)
        end
        append!(targets, entities)
    end

    PWNModel.update!(s, world)

    for e in targets
        @test !has_components(world, e, (PWNModel.Colonized,))
    end
end
