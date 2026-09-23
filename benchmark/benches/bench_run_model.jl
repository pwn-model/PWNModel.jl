
function do_setup_world(n)
    world = World(
        Position, GridCoords, Damaged, Infected, Colonized, Relation{InCell},
        BeetlePosition, EmergenceTick, LifeExpectancy,
    )

    # Resources
    add_resource!(world, WorldSize(width=10000, height=10000, cell_size=10, grid_cell_size=500))
    add_resource!(world, Rng(1))

    scheduler = Scheduler(
        world,
        (
            # Initialization
            InitGrids(),
            InitTrees(cell_probability=1.0, tree_probability=0.9, damage_prevalence=0.03, beetle_prevalence=0.2),

            # Systems
            UpdateTime(ticks_per_year=52),
            DiseaseCourse(ticks_to_damage=8),
            RandomInfection(
                tick_of_infection=0,
                num_trees=100,
                cell_x=11, cell_y=11,
            ),
            DamageTrees(
                tick_of_year=35,
                damage_probability=0.01,
                removal_probability=0.333,
            ),
            BeetleEmergence(
                tick_of_year=19,
                beetles_per_tree=10,
                life_expectancy=5.0,
            ),
            TreeAttraction(
                tick_of_year=18,
                half_distance=50,
                density_radius=20,
                density_weight=1.0,
            ),
            BeetleMortality(),
            Colonization(
                tick_of_year=20,
                cell_size=100,
                kernel_half_distance=50,
                kernel_radius=300,
                beetles_per_tree=2.2,
                trees_per_beetle=1.0,
            ),

            # Stop criterion
            FixedTermination(steps=520),
        ),
    )

    initialize!(scheduler)

    return scheduler
end

function setup_setup_and_run_world(n)
end

function benchmark_setup_and_run_world(args, n)
    scheduler = do_setup_world(n)
    run!(scheduler)

    return scheduler
end

SUITE["benchmark_setup_and_run n=1"] =
    @be setup_setup_and_run_world($1) benchmark_setup_and_run_world(_, $1) seconds = SECONDS

function setup_only_run_world(n)
    return do_setup_world(n)
end

function benchmark_only_run_world(args, n)
    scheduler = args
    run!(scheduler)

    return scheduler
end

SUITE["benchmark_only_run n=1"] =
    @be setup_only_run_world($1) benchmark_only_run_world(_, $1) seconds = SECONDS

function setup_only_setup_world(n)
end

function benchmark_only_setup_world(args, n)
    scheduler = do_setup_world(n)

    return scheduler
end

SUITE["benchmark_only_setup n=1"] =
    @be setup_only_setup_world($1) benchmark_only_setup_world(_, $1) seconds = SECONDS
