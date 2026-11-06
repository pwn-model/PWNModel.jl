# Uses _setup_tree_attraction_world and _place_tree from tree_attraction.jl.

function _tree_attraction_octants(; damaged_trees=false, tick_of_year=0, density_radius=20, density_weight=1.0)
    return PWNModel.TreeAttractionOctants(
        tick_of_year=tick_of_year, damaged_trees=damaged_trees, half_distance=50.0,
        density_radius=density_radius, density_weight=density_weight,
    )
end

# The published sources are exactly those propagate_octants! computes from
# seeds counted by brute force, for random trees incl. near the edges.
@testset "TreeAttractionOctants matches brute-force seeds" begin
    world = World(PWNModel.Position, PWNModel.Damaged)
    ws = PWNModel.WorldSize(width=300, height=200, cell_size=10)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Time(0, 0, 0))

    rng = PWNModel.Rng(1)
    w, h = ws.width, ws.height
    for _ in 1:200
        _place_tree(world, floor(Int, rand(rng) * w) + 1, floor(Int, rand(rng) * h) + 1)
    end

    s = PWNModel.TreeAttractionOctants(
        tick_of_year=0, damaged_trees=false, half_distance=50.0, density_radius=40, density_weight=1.5,
    )
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    res = get_resource(world, PWNModel.HealthyTreeAttractionOctants)

    r = 4
    max_count = (2r + 1)^2
    seeds = PWNModel.Grid(w, h, ws.cell_size, 0.0)
    for x in 1:w, y in 1:h
        res.presence[x, y] || continue
        count = 0
        for xx in max(x-r, 1):min(x+r, w), yy in max(y-r, 1):min(y+r, h)
            count += res.presence[xx, yy]
        end
        seeds[x, y] = (count / max_count)^1.5
    end
    expected = _run_octants(seeds, 50.0)

    @test count(res.presence._values) > 0
    @test res.sources._values == expected._values
end

# Two instances, one for healthy and one for damaged trees, publish
# separate resources, each driven only by its own tree type.
@testset "TreeAttractionOctants healthy and damaged instances are independent" begin
    world = _setup_tree_attraction_world()
    _place_tree(world, 50, 25)
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged)) do (_, positions, _)
        positions[1] = PWNModel.Position(80, 25)
    end

    healthy = _tree_attraction_octants(damaged_trees=false)
    damaged = _tree_attraction_octants(damaged_trees=true)
    PWNModel.initialize!(healthy, world)
    PWNModel.initialize!(damaged, world)
    PWNModel.update!(healthy, world)
    PWNModel.update!(damaged, world)

    h = get_resource(world, PWNModel.HealthyTreeAttractionOctants)
    d = get_resource(world, PWNModel.DamagedTreeAttractionOctants)
    @test h.presence[50, 25] && !h.presence[80, 25]
    @test d.presence[80, 25] && !d.presence[50, 25]

    # From (60, 25), the healthy tree is 10 cells towards -x (octant 5), the
    # damaged one 20 cells towards +x (octant 1).
    hr, dr = h.sources[60, 25], d.sources[60, 25]
    @test hr.offsets[5] == (Int16(-10), Int16(0))
    @test all(k -> k == 5 || hr.attraction[k] == 0, 1:8)
    @test dr.offsets[1] == (Int16(20), Int16(0))
    @test all(k -> k == 1 || dr.attraction[k] == 0, 1:8)

    # A tree's own cell is not its own source.
    @test all(==(0.0f0), h.sources[50, 25].attraction)
end

# Sources and presence are only updated on tick_of_year.
@testset "TreeAttractionOctants updates only on tick of year" begin
    world = _setup_tree_attraction_world()
    e = _place_tree(world, 50, 25)

    s = _tree_attraction_octants(tick_of_year=5)
    PWNModel.initialize!(s, world)
    res = get_resource(world, PWNModel.HealthyTreeAttractionOctants)

    PWNModel.update!(s, world)
    @test !res.presence[50, 25]
    @test all(==(0.0f0), res.sources[60, 25].attraction)

    time = get_resource(world, PWNModel.Time)
    time.tick_of_year = 5
    PWNModel.update!(s, world)
    @test res.presence[50, 25]
    @test res.sources[60, 25].attraction[5] > 0

    # A tree becoming damaged is not reflected outside tick_of_year...
    add_components!(world, e, (PWNModel.Damaged(),))
    time.tick_of_year = 6
    PWNModel.update!(s, world)
    @test res.presence[50, 25]

    # ...but on the next tick_of_year.
    time.tick_of_year = 5
    PWNModel.update!(s, world)
    @test !res.presence[50, 25]
    @test all(==(0.0f0), res.sources[60, 25].attraction)
end

@testset "TreeAttractionOctants zero weight skips density_radius validation" begin
    world = _setup_tree_attraction_world()
    _place_tree(world, 50, 25)

    s = _tree_attraction_octants(density_radius=7, density_weight=0.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # Seed 1, decayed over 10 cells (100 m) at half_distance 50 m.
    res = get_resource(world, PWNModel.HealthyTreeAttractionOctants)
    @test res.sources[60, 25].attraction[5] ≈ 0.25f0

    world = _setup_tree_attraction_world()
    s = _tree_attraction_octants(density_radius=7, density_weight=1.0)
    @test_throws ArgumentError PWNModel.initialize!(s, world)
end

@testset "TreeAttractionOctants rejects worlds too large for Int16 offsets" begin
    for (width, height) in ((32768, 1), (1, 32768))
        world = World(PWNModel.Position, PWNModel.Damaged)
        add_resource!(world, PWNModel.WorldSize(width=width, height=height, cell_size=1))
        s = _tree_attraction_octants(density_weight=0.0)
        PWNModel.initialize!(s, world)
    end
    for (width, height) in ((32769, 1), (1, 32769))
        world = World(PWNModel.Position, PWNModel.Damaged)
        add_resource!(world, PWNModel.WorldSize(width=width, height=height, cell_size=1))
        s = _tree_attraction_octants(density_weight=0.0)
        @test_throws ArgumentError PWNModel.initialize!(s, world)
    end
end

@testset "TreeAttractionOctants from config" begin
    cfg = PWNModel.parse_config("""
    systems:
      - type: TreeAttractionOctants
        tick_of_year: 18
        damaged_trees: true
        half_distance: 50
        density_radius: 20
        density_weight: 1
    """)
    s = cfg.systems[1]
    @test s isa PWNModel.TreeAttractionOctants
    @test s.tick_of_year == 18
    @test s.damaged_trees
    @test s.half_distance === 50.0
    @test s.density_radius === 20
    @test s.density_weight === 1.0
end
