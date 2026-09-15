
function do_setup_world(n)
    world = World(Position, GridCoords)
    add_resource!(world, WorldSize(1000, 1000, 50))
    add_resource!(world, Rng(rand(UInt64)))

    scheduler = Scheduler(
        world,
        (
            InitGrids(),
            InitTrees(0.9),
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
