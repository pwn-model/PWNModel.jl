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

# Landscape: a dense forest in the west, a gap of varying width, and another dense forest in the east.
# Both forests are 1000 m wide, so the world's width adapts to the gap width.
const HEIGHT = 2000
const WEST_FOREST_END = 1000
const EAST_FOREST_WIDTH = 1000
const GAP_WIDTHS = [100, 250, 500, 1000, 2500, 5000, 10000]
forest(x_min, x_max) = TreeStand(;
    x_min=x_min, y_min=0, x_max=x_max, y_max=HEIGHT,
    tree_probability=0.9, damage_prevalence=0.03, beetle_prevalence=0.0,
)
east_forest_start(gap) = WEST_FOREST_END + gap
world_width(gap) = east_forest_start(gap) + EAST_FOREST_WIDTH
const MAX_WIDTH = maximum(world_width, GAP_WIDTHS)

# Each scenario runs with these seeds, and results are pooled over them.
# Landscape maps show the first seed only.
const SEEDS = 1:10

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

# First column of cells entirely east of the gap, i.e. in the east forest.
first_east_cell(gap, cell_size) = east_forest_start(gap) ÷ cell_size + 1

"""
    GapEvents(first_east_cell)

System that counts the feeding and egg laying events of each update, in total and in the east forest
(cell columns from `first_east_cell`). Like `TreeVisits` (see `../common/recorders.jl`), it reads the
`FeedingInfectedBeetles` grid, so it must come after the movement system, and assigns cells to
feeding or egg laying by the presence grid of the `DamagedTreeAttraction` resource.
Counts of update `k` are in `total[k]` and `east[k]`, as tuples (feeding, egg laying),
i.e. they belong to track position `k + 1` of `BeetleTrajectories`.
"""
struct GapEvents <: PWNModel.System
    first_east_cell::Int
    total::Vector{NTuple{2,Int}}
    east::Vector{NTuple{2,Int}}
end

GapEvents(first_east_cell::Int) = GapEvents(first_east_cell, NTuple{2,Int}[], NTuple{2,Int}[])

function PWNModel.update!(s::GapEvents, w::World)
    events = get_resource(w, FeedingInfectedBeetles).grid
    damaged = get_resource(w, DamagedTreeAttraction).presence
    total, east = [0, 0], [0, 0]
    for x in 1:events.width, y in 1:events.height
        n = Int(events[x, y])
        n == 0 && continue
        kind = damaged[x, y] ? 2 : 1
        total[kind] += n
        x >= s.first_east_cell && (east[kind] += n)
    end
    push!(s.total, Tuple(total))
    push!(s.east, Tuple(east))
end

# Runs the model for one gap width and seed. Returns its world, the beetle tracks, as cells,
# and the feeding and egg laying events.
function simulate(gap, seed)
    width = world_width(gap)
    world = new_world(; seed=seed, width=width, height=HEIGHT, cell_size=10)
    trajectories = BeetleTrajectories()
    events = GapEvents(first_east_cell(gap, get_resource(world, WorldSize).cell_size))

    systems = (
        InitGrids(),
        InitTreeStands(; stands=[forest(0, WEST_FOREST_END), forest(east_forest_start(gap), width)]),
        # The tree the beetles emerge from, at the release point.
        DamageTree(; x=RELEASE_X, y=RELEASE_Y),
        UpdateTime(; ticks_per_year=52*steps_per_tick),
        # tick_of_year 0, so that both fields are calculated in the first tick, before any movement.
        TreeAttraction(; attraction_kwargs(false)...),
        TreeAttraction(; attraction_kwargs(true)...),
        # Life expectancy and maximum age are in ticks, i.e. movement steps here: 5 and 18 weeks.
        ReleaseBeetles(;
            x=RELEASE_X, y=RELEASE_Y, count=10_000, life_expectancy=5.0 * steps_per_tick, max_age=max_age,
        ),
        BeetleMovement(; movement_kwargs...),
        BeetleMortality(),
        trajectories,
        events,
    )

    # One more tick than steps, for BeetleMortality to remove beetles that reached the maximum age.
    run!(Scheduler(world, systems), total_steps + 1)

    cs = get_resource(world, WorldSize).cell_size
    return (; world, tracks=[trajectories.tracks[e] for e in trajectories.entities], events, cell_size=cs)
end

const PHASES = (
    (label="Probability immature", range=1:(duration_feeding+1), color=SERIES_COLORS[1]),
    (label="Probability lifetime", range=1:(total_steps+1), color=SERIES_COLORS[2]),
)

# Whether any position of a track within the given range of steps is in the east forest,
# i.e. in a cell entirely east of the gap. Tracks end early when beetles die.
function crossed(track, range, gap, cell_size)
    first_cell = first_east_cell(gap, cell_size)
    return any(p.x >= first_cell for p in track[first(range):min(last(range), length(track))])
end

# Kinds of events counted, with the kind's index in `GapEvents` counts, and the range of track positions
# (as in PHASES) to count them in. Feeding during maturation feeding and over the whole life,
# egg laying over the whole life.
const EVENTS = (
    (label="Feeding events immature", kind=1, range=PHASES[1].range, color=SERIES_COLORS[1]),
    (label="Feeding events lifetime", kind=1, range=PHASES[2].range, color=SERIES_COLORS[2]),
    (label="Egg-laying events", kind=2, range=PHASES[2].range, color=SERIES_COLORS[3]),
)

# Updates whose events belong to a range of track positions, as update k gives position k + 1.
range_updates(range, events) = max(first(range)-1, 1):min(last(range)-1, length(events.total))

# Runs the model for one gap width with all seeds. Returns the world of the first seed,
# the number of released beetles, per phase the number of beetles that crossed the gap,
# and per kind of events (see EVENTS) their number in total and in the east forest,
# summed over all seeds. Tracks are not kept, to save memory.
function simulate_seeds(gap)
    world, cell_size = nothing, 0
    released, crossings = 0, zeros(Int, length(PHASES))
    events_total, events_east = zeros(Int, length(EVENTS)), zeros(Int, length(EVENTS))
    for seed in SEEDS
        result = simulate(gap, seed)
        seed == first(SEEDS) && ((world, cell_size) = (result.world, result.cell_size))
        released += length(result.tracks)
        for (j, phase) in enumerate(PHASES)
            crossings[j] += count(t -> crossed(t, phase.range, gap, result.cell_size), result.tracks)
        end
        for (j, ev) in enumerate(EVENTS)
            updates = range_updates(ev.range, result.events)
            events_total[j] += sum(c[ev.kind] for c in result.events.total[updates]; init=0)
            events_east[j] += sum(c[ev.kind] for c in result.events.east[updates]; init=0)
        end
    end
    return (; world, cell_size, released, crossings, events_total, events_east)
end

# ---------------------------------------------------------------------------
# Analysis and plots

# Probability of having crossed the gap in a phase, over all released beetles of all seeds.
crossing_probability(result, phase_index) = result.crossings[phase_index] / result.released

# Share of events of a kind (see EVENTS) that are in the east forest, over all seeds.
east_event_share(result, event_index) = result.events_east[event_index] / result.events_total[event_index]

# Landscapes of all gap widths (rows), on the same scale, with the release point (star).
# The area beyond the east edge of a smaller world is gray.
const OUTSIDE_COLOR = "#e0e0e0"

function plot_landscapes(results)
    fig = Figure(; size=(1200, 1450))
    xticks = 0:1000:MAX_WIDTH
    release = cell_center(RELEASE_X, RELEASE_Y, first(results).cell_size)
    for (row, (gap, result)) in enumerate(zip(GAP_WIDTHS, results))
        width = world_width(gap)
        last_row = row == length(GAP_WIDTHS)
        ax = Axis(
            fig[row, 1];
            title="Gap $gap m",
            aspect=DataAspect(),
            xticks=(xticks, string.(xticks)),
            yticks=0:1000:HEIGHT,
            xlabel=last_row ? "x (m)" : "",
            ylabel="y (m)",
        )
        image!(ax, tree_image(result.world; xlims=(0, width), ylims=(0, HEIGHT))...; interpolate=false, rasterize=2)
        width < MAX_WIDTH && poly!(ax, Rect2f(width, 0, MAX_WIDTH - width, HEIGHT); color=OUTSIDE_COLOR)
        scatter!(ax, [Point2f(release...)]; color=:black, marker=:star5, markersize=12)
        limits!(ax, 0, MAX_WIDTH, 0, HEIGHT)
        last_row || hidexdecorations!(ax; grid=false)
    end
    save_figure(OUT_DIR, "landscapes", fig; png=true)
end

const Y_TICKS = [
    0.00001, 0.00002, 0.00005, 0.0001, 0.0002, 0.0005, 0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1.0,
]

# Series shown: the per-beetle crossing probability per phase (solid lines),
# and the share of events of each kind in the east forest (dashed lines).
const SERIES = (
    (
        (; label=p.label, value=r -> crossing_probability(r, j), color=p.color,
            linestyle=:solid, marker=:circle) for (j, p) in enumerate(PHASES)
    )...,
    (
        (; label=e.label, value=r -> east_event_share(r, j), color=e.color,
            linestyle=:dash, marker=:rect) for (j, e) in enumerate(EVENTS)
    )...,
)

function plot_crossing_probability(results)
    series = SERIES
    values = [s.value(result) for result in results, s in series]
    labels = [s.label for s in series]

    println(
        "Crossing the gap, over $(first(results).released) beetles from $(length(SEEDS)) seeds ",
        "(share of beetles that crossed, and of feeding and egg laying events in the east forest)",
    )
    for (i, gap) in enumerate(GAP_WIDTHS)
        println(
            "  ", lpad(gap, 5), " m: ",
            join(("$(labels[k]) $(round(values[i, k]; sigdigits=3))" for k in eachindex(series)), ", "),
        )
    end

    fig = Figure(; size=(700, 450))
    # Logarithmic axes, as gap widths and probabilities range over orders of magnitude.
    ax = Axis(
        fig[1, 1];
        xlabel="Gap width (m)", ylabel="Probability / event share",
        xscale=log10, xticks=(GAP_WIDTHS, string.(GAP_WIDTHS)),
        yscale=log10, yticks=(Y_TICKS, string.(Y_TICKS)),
    )
    for (k, s) in enumerate(series)
        # Zeros can't be shown on the log axis, and are left out.
        v = [x > 0 ? x : NaN for x in values[:, k]]
        scatterlines!(
            ax, GAP_WIDTHS, v;
            color=s.color, linestyle=s.linestyle, marker=s.marker, label=s.label,
        )
    end
    # Keep all gap widths on the x axis, also those without crossings.
    xlims!(ax, 0.8 * first(GAP_WIDTHS), 1.25 * last(GAP_WIDTHS))
    axislegend(ax; position=:rt)
    save_figure(OUT_DIR, "crossing_probability", fig; png=true)

    # The same as a Markdown table, included in the README.
    # Significant digits, as event shares can be much smaller than crossing probabilities.
    open(joinpath(OUT_DIR, "crossing_probability.md"), "w") do io
        println(io, "| Gap width | ", join(labels, " | "), " |")
        println(io, "| --------: | ", join(("-----:" for _ in series), " | "), " |")
        for (i, gap) in enumerate(GAP_WIDTHS)
            percent = ("$(round(100 * v; sigdigits=3)) %" for v in values[i, :])
            println(io, "| $gap m | ", join(percent, " | "), " |")
        end
    end
end

let
    results = [simulate_seeds(gap) for gap in GAP_WIDTHS]
    plot_landscapes(results)
    plot_crossing_probability(results)
end
