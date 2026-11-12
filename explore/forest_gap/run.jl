# Forest gap: how likely do beetles cross a gap between two forests, depending on the gap width?
# See README.md.
#
# Run from the PWNModel.jl/ directory:
#   julia --project=explore explore/forest_gap/run.jl

using Ark
using CairoMakie
using PWNModel

include("../common/world.jl")
include("../common/recorders.jl")
include("../common/plotting.jl")

const OUT_DIR = joinpath(@__DIR__, "out")

# Model time step is one week, with `steps_per_tick` movement steps per week.
# To record every single step, we run the movement system with one step per
# tick and scale the phase durations accordingly. Trees and attraction fields
# are static here, so this gives the same movement as the model's weekly
# ticks; only the order of random numbers differs.
const steps_per_tick = 7
const duration_feeding = 3 * steps_per_tick
# Maximum beetle age of 18 weeks. The simulation runs until all beetles are dead.
const max_age = 18 * steps_per_tick
const total_steps = max_age

# Landscape: a dense forest in the west, a gap of varying width, and another dense forest
# from the end of the gap to the east edge of the world.
const WIDTH, HEIGHT = 3000, 2000
const WEST_FOREST_END = 1000
const GAP_WIDTHS = [100, 250, 500, 1000]
forest(x_min, x_max) = TreeStand(;
    x_min=x_min, y_min=0, x_max=x_max, y_max=HEIGHT,
    tree_probability=0.9, damage_prevalence=0.03, beetle_prevalence=0.0,
)
east_forest_start(gap) = WEST_FOREST_END + gap

# Release point, as a cell, in the easternmost column of cells of the west forest.
const RELEASE_X, RELEASE_Y = 100, 100

attraction_kwargs(damaged) =
    (; tick_of_year=0, damaged_trees=damaged, half_distance=50.0, density_radius=20, density_weight=1.0)
const movement_kwargs = (;
    steps_per_tick=1,
    distance_per_step=2000.0,
    duration_feeding=duration_feeding,
    feeding_probability=0.5,
    leave_tree_probability=0.25,
    emergence_flight_distance=100.0,
)

# Runs the model for one gap width. Returns its world, and the beetle tracks, as cells.
function simulate(gap)
    world = new_world(; seed=1, width=WIDTH, height=HEIGHT, cell_size=10)
    trajectories = BeetleTrajectories()

    systems = (
        InitGrids(),
        InitTreeStands(; stands=[forest(0, WEST_FOREST_END), forest(east_forest_start(gap), WIDTH)]),
        # The tree the beetles emerge from, at the release point.
        DamageTree(; x=RELEASE_X, y=RELEASE_Y),
        UpdateTime(; ticks_per_year=52*steps_per_tick),
        # tick_of_year 0, so that both fields are calculated in the first tick, before any movement.
        TreeAttraction(; attraction_kwargs(false)...),
        TreeAttraction(; attraction_kwargs(true)...),
        # Life expectancy and maximum age are in ticks, i.e. movement steps here: 5 and 18 weeks.
        ReleaseBeetles(; x=RELEASE_X, y=RELEASE_Y, count=10_000, life_expectancy=5.0 * steps_per_tick, max_age=max_age),
        BeetleMovement(; movement_kwargs...),
        BeetleMortality(),
        trajectories,
    )

    # One more tick than steps, for BeetleMortality to remove beetles that reached the maximum age.
    run!(Scheduler(world, systems), total_steps + 1)

    cs = get_resource(world, WorldSize).cell_size
    return (; world, tracks=[trajectories.tracks[e] for e in trajectories.entities], cell_size=cs)
end

# ---------------------------------------------------------------------------
# Analysis and plots

# Whether any position of a track within the given range of steps is in the east forest,
# i.e. in a cell entirely east of the gap. Tracks end early when beetles die.
function crossed(track, range, gap, cell_size)
    first_cell = east_forest_start(gap) ÷ cell_size + 1
    return any(p.x >= first_cell for p in track[first(range):min(last(range), length(track))])
end

# Probability of having crossed the gap, over all released beetles.
crossing_probability(result, range, gap) =
    count(t -> crossed(t, range, gap, result.cell_size), result.tracks) / length(result.tracks)

const PHASES = (
    (title="Maturation feeding", range=1:(duration_feeding+1), color=SERIES_COLORS[1]),
    (title="Lifetime", range=1:(total_steps+1), color=SERIES_COLORS[2]),
)

# Landscapes of all gap widths (panels), with the release point (star).
function plot_landscapes(results)
    fig = Figure(; size=(1100, 800))
    release = cell_center(RELEASE_X, RELEASE_Y, first(results).cell_size)
    for (k, (gap, result)) in enumerate(zip(GAP_WIDTHS, results))
        row, col = fldmod1(k, 2)
        ax = Axis(
            fig[row, col];
            title="Gap $gap m",
            aspect=DataAspect(),
            # No tick at the east edge, where it would collide with the next panel's first tick.
            xticks=0:1000:(WIDTH-1),
            xlabel=row == 2 ? "x (m)" : "",
            ylabel=col == 1 ? "y (m)" : "",
        )
        image!(ax, tree_image(result.world; xlims=(0, WIDTH), ylims=(0, HEIGHT))...; interpolate=false, rasterize=2)
        scatter!(ax, [Point2f(release...)]; color=:black, marker=:star5, markersize=14)
        limits!(ax, 0, WIDTH, 0, HEIGHT)
        row == 2 || hidexdecorations!(ax; grid=false)
        col == 1 || hideydecorations!(ax; grid=false)
    end
    save_figure(OUT_DIR, "landscapes", fig; png=true)
end

function plot_crossing_probability(results)
    probabilities = [
        crossing_probability(result, phase.range, gap) for (gap, result) in zip(GAP_WIDTHS, results), phase in PHASES
    ]

    println("Probability to cross the gap")
    for (i, gap) in enumerate(GAP_WIDTHS)
        println(
            "  ", lpad(gap, 4), " m: ",
            join(("$(phase.title) $(round(probabilities[i, j]; digits=4))" for (j, phase) in enumerate(PHASES)), ", "),
        )
    end

    fig = Figure(; size=(700, 450))
    ax = Axis(fig[1, 1]; xlabel="Gap width (m)", ylabel="Probability to cross the gap", xticks=GAP_WIDTHS)
    for (j, phase) in enumerate(PHASES)
        scatterlines!(ax, GAP_WIDTHS, probabilities[:, j]; color=phase.color, label=phase.title)
    end
    ylims!(ax, 0, nothing)
    axislegend(ax; position=:rt)
    save_figure(OUT_DIR, "crossing_probability", fig; png=true)
end

let
    results = [simulate(gap) for gap in GAP_WIDTHS]
    plot_landscapes(results)
    plot_crossing_probability(results)
end
