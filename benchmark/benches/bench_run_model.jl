
function do_setup_world(n)
    world = World(Position)
    add_resource!(world, TreeGrid(1000, 1000))
    add_resource!(world, Rng(rand(UInt64)))

    scheduler = Scheduler(
        world,
        (
            InitTrees(0.9),
        ),
    )

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
