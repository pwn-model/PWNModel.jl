# Benchmarks of the two attraction models (TreeAttraction, TreeAttractionOctants)
# and the two beetle movement models using them (BeetleMovement,
# BeetleMovementOctants), on a 10 km x 10 km world with 10 m cells and a
# tree in 90 % of the cells, 3 % of them damaged.
#
# Attraction benchmarks measure one calculation of the healthy-tree field
# (n=1). Movement benchmarks measure one tick of 10,000 beetles with 7 steps
# each, per beetle step (n=70000), without the attraction calculation, which
# is done once beforehand.
#
# Mirrors the sibling Go implementation's sys/attraction_bench_test.go.

const ATTRACTION_WORLD_CELLS = 1000
const MOVEMENT_BEETLES = 10_000
const MOVEMENT_STEPS = 7

attraction_kwargs(damaged) =
    (; tick_of_year=0, damaged_trees=damaged, half_distance=50.0, density_radius=20, density_weight=1.0)

# A world with randomly placed trees, and the resources the attraction and
# movement systems need. The current tick and tick of year are 0.
function attraction_bench_world()
    world = World(Position, Damaged, BeetlePosition, EmergenceTick)
    add_resource!(
        world,
        WorldSize(; width=10 * ATTRACTION_WORLD_CELLS, height=10 * ATTRACTION_WORLD_CELLS, cell_size=10),
    )
    add_resource!(world, Time(0, 0, 0))
    add_resource!(world, Rng(1))

    rng = Random.Xoshiro(1)
    for x in 1:ATTRACTION_WORLD_CELLS, y in 1:ATTRACTION_WORLD_CELLS
        rand(rng) < 0.9 || continue
        if rand(rng) < 0.03
            new_entity!(world, (Position(x, y), Damaged()))
        else
            new_entity!(world, (Position(x, y),))
        end
    end
    return world
end

# Attraction

function setup_attraction(system)
    world = attraction_bench_world()
    PWNModel.initialize!(system, world)
    return (system, world)
end

function benchmark_attraction(args)
    system, world = args
    PWNModel.update!(system, world)
    return system
end

init_tree_attraction() = setup_attraction(TreeAttraction(; attraction_kwargs(false)...))
init_tree_attraction_octants() = setup_attraction(TreeAttractionOctants(; attraction_kwargs(false)...))

# The world is set up once (init), as each calculation starts from scratch.
SUITE["benchmark_tree_attraction n=1"] = @be init_tree_attraction _ benchmark_attraction(_) _ seconds = 2 * SECONDS

SUITE["benchmark_tree_attraction_octants n=1"] =
    @be init_tree_attraction_octants _ benchmark_attraction(_) _ seconds = 2 * SECONDS

# Movement

# init: the world, with both attraction fields of the given type computed,
# and the movement system.
function init_movement(attraction_type, movement)
    world = attraction_bench_world()
    for damaged in (false, true)
        a = attraction_type(; attraction_kwargs(damaged)...)
        PWNModel.initialize!(a, world)
        PWNModel.update!(a, world)
    end
    PWNModel.initialize!(movement, world)
    return (movement, world, Filter(world, (BeetlePosition,)))
end

# setup: fresh beetles at random positions, emerged before the current tick
# (no emergence flight), and a re-seeded RNG.
function setup_movement(args)
    movement, world, beetles = args
    remove_entities!(world, beetles)

    Random.seed!(get_resource(world, Rng).xoshiro, 1)
    rng = Random.Xoshiro(2)
    new_entities!(world, MOVEMENT_BEETLES, (BeetlePosition, EmergenceTick)) do (_, positions, ticks)
        for i in eachindex(positions)
            positions[i] = BeetlePosition(rand(rng, 1:ATTRACTION_WORLD_CELLS), rand(rng, 1:ATTRACTION_WORLD_CELLS))
            ticks[i] = EmergenceTick(-1)
        end
    end
    return (movement, world)
end

function benchmark_movement(args)
    movement, world = args
    PWNModel.update!(movement, world)
    return movement
end

# duration_feeding 0, so that beetles target healthy and damaged trees with
# equal probability in every step.
movement_kwargs() = (;
    steps_per_tick=MOVEMENT_STEPS,
    distance_per_step=2000.0,
    emergence_flight_distance=100.0,
    duration_feeding=0,
    feeding_probability=0.5,
    leave_tree_probability=0.25,
)

init_beetle_movement() = init_movement(TreeAttraction, BeetleMovement(; movement_kwargs()...))
init_beetle_movement_octants() = init_movement(TreeAttractionOctants, BeetleMovementOctants(; movement_kwargs()...))

const N_MOVEMENT = MOVEMENT_BEETLES * MOVEMENT_STEPS

SUITE["benchmark_beetle_movement n=$N_MOVEMENT"] =
    @be init_beetle_movement setup_movement benchmark_movement _ evals = 1 seconds = SECONDS

SUITE["benchmark_beetle_movement_octants n=$N_MOVEMENT"] =
    @be init_beetle_movement_octants setup_movement benchmark_movement _ evals = 1 seconds = SECONDS
