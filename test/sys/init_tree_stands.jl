function _init_tree_stands_world(stands; width=1000, height=500)
    world = World(PWNModel.Position, PWNModel.Damaged, PWNModel.Colonized)
    add_resource!(world, PWNModel.WorldSize(width=width, height=height, cell_size=10))
    add_resource!(world, PWNModel.Rng(1))
    PWNModel.initialize!(PWNModel.InitGrids(), world)
    PWNModel.initialize!(PWNModel.InitTreeStands(; stands=stands), world)
    return world
end

function _stand(; x_min, y_min, x_max, y_max, tree_probability=1.0, damage_prevalence=0.0, beetle_prevalence=0.0)
    return PWNModel.TreeStand(; x_min, y_min, x_max, y_max, tree_probability, damage_prevalence, beetle_prevalence)
end

@testset "InitTreeStands bounds" begin
    # Cells with centers in [100, 300) x [50, 250): x 11..30, y 6..25.
    world = _init_tree_stands_world([_stand(; x_min=100, y_min=50, x_max=300, y_max=250)])
    grid = get_resource(world, PWNModel.TreeGrid).grid

    @test count_entities(Filter(world, (PWNModel.Position,))) == 20 * 20
    for (entities, positions) in Query(world, (PWNModel.Position,))
        for i in eachindex(entities)
            pos = positions[i]
            @test 11 <= pos.x <= 30
            @test 6 <= pos.y <= 25
            @test grid[pos.x, pos.y] == entities[i]
        end
    end
end

@testset "InitTreeStands outside world" begin
    # Clipped to the world: x 1..100, y 41..50.
    world = _init_tree_stands_world([_stand(; x_min=-500, y_min=400, x_max=5000, y_max=1e9)])
    @test count_entities(Filter(world, (PWNModel.Position,))) == 100 * 10

    world = _init_tree_stands_world([_stand(; x_min=2000, y_min=0, x_max=3000, y_max=500)])
    @test count_entities(Filter(world, (PWNModel.Position,))) == 0

    world = _init_tree_stands_world(PWNModel.TreeStand[])
    @test count_entities(Filter(world, (PWNModel.Position,))) == 0
end

@testset "InitTreeStands overlap" begin
    # Second stand is empty and overwrites the right half of the first one.
    world = _init_tree_stands_world([
        _stand(; x_min=0, y_min=0, x_max=1000, y_max=500),
        _stand(; x_min=500, y_min=0, x_max=1000, y_max=500, tree_probability=0.0),
    ])
    @test count_entities(Filter(world, (PWNModel.Position,))) == 50 * 50
    for (_, positions) in Query(world, (PWNModel.Position,))
        for pos in positions
            @test pos.x <= 50
        end
    end

    # Second stand fully damaged, overwriting the center of the first one.
    world = _init_tree_stands_world([
        _stand(; x_min=0, y_min=0, x_max=1000, y_max=500),
        _stand(; x_min=200, y_min=100, x_max=400, y_max=300, damage_prevalence=1.0),
    ])
    @test count_entities(Filter(world, (PWNModel.Position,))) == 100 * 50
    @test count_entities(Filter(world, (PWNModel.Damaged,))) == 20 * 20
    for (_, positions) in Query(world, (PWNModel.Position,); with=(PWNModel.Damaged,))
        for pos in positions
            @test 21 <= pos.x <= 40
            @test 11 <= pos.y <= 30
        end
    end
end

@testset "InitTreeStands prevalences" begin
    world = _init_tree_stands_world([
        _stand(; x_min=0, y_min=0, x_max=500, y_max=500, tree_probability=0.9),
        _stand(;
            x_min=500, y_min=0, x_max=1000, y_max=500,
            tree_probability=0.5, damage_prevalence=0.2, beetle_prevalence=0.3,
        ),
    ])

    left = right = left_damaged = right_damaged = right_colonized = 0
    for (entities, positions) in Query(world, (PWNModel.Position,))
        for i in eachindex(entities)
            e = entities[i]
            damaged = has_components(world, e, (PWNModel.Damaged,))
            colonized = has_components(world, e, (PWNModel.Colonized,))
            colonized && @test damaged
            if positions[i].x <= 50
                left += 1
                left_damaged += damaged
            else
                right += 1
                right_damaged += damaged
                right_colonized += colonized
            end
        end
    end

    cells = 50 * 50
    @test abs(left - 0.9 * cells) < 0.05 * cells
    @test abs(right - 0.5 * cells) < 0.05 * cells
    @test left_damaged == 0
    @test abs(right_damaged - 0.2 * right) < 0.25 * 0.2 * right
    @test abs(right_colonized - 0.06 * right) < 0.25 * 0.06 * right
end

@testset "InitTreeStands config" begin
    cfg = parse_config(
        """
systems:
  - type: InitTreeStands
    stands:
      - {x_min: 0, y_min: 0, x_max: 500, y_max: 1000, tree_probability: 0.9, damage_prevalence: 0.03, beetle_prevalence: 0}
      - {x_min: 500, y_min: 0, x_max: 1000, y_max: 1000, tree_probability: 0.025, damage_prevalence: 0.25, beetle_prevalence: 0.1}
""",
    )
    s = only(cfg.systems)
    @test s isa PWNModel.InitTreeStands
    @test length(s.stands) == 2
    @test s.stands[2] == _stand(;
        x_min=500, y_min=0, x_max=1000, y_max=1000,
        tree_probability=0.025, damage_prevalence=0.25, beetle_prevalence=0.1,
    )

    @test_throws "unknown parameter(s) \"foo\"" parse_config(
        """
systems:
  - type: InitTreeStands
    stands:
      - {x_min: 0, y_min: 0, x_max: 500, y_max: 1000, tree_probability: 0.9, damage_prevalence: 0.03, beetle_prevalence: 0, foo: 1}
""",
    )
    @test_throws "missing parameter \"beetle_prevalence\"" parse_config("""
    systems:
      - type: InitTreeStands
        stands:
          - {x_min: 0, y_min: 0, x_max: 500, y_max: 1000, tree_probability: 0.9, damage_prevalence: 0.03}
    """)
end
