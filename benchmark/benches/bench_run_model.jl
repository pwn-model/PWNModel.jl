
function do_setup_world(n)
    world = World(Position, GridCoords, Damaged, NematodeInfected, Relation{InCell})
    add_resource!(world, WorldSize(1000, 1000, 50))
    add_resource!(world, Rng(rand(UInt64)))

    scheduler = Scheduler(
        world,
        (
            InitGrids(),
            InitTrees(tree_probability=0.9, damage_prevalence=0.03),
            DiseaseCourse(ticks_to_damage=8),
            RandomInfection(tick_of_infection=0, num_trees=100, cell_x=11, cell_y=11),
        ),
    )

    initialize!(scheduler)

    return scheduler
end

function setup_setup_and_run_world(n)
end

function benchmark_setup_and_run_world(args, n)
    scheduler = do_setup_world(n)
    run!(scheduler, 100)

    return scheduler
end

SUITE["benchmark_setup_and_run n=1"] =
    @be setup_setup_and_run_world($1) benchmark_setup_and_run_world(_, $1) seconds = SECONDS

function setup_only_run_world(n)
    return do_setup_world(n)
end

function benchmark_only_run_world(args, n)
    scheduler = args
    run!(scheduler, 100)

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
