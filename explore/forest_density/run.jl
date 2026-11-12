# Forest density: how far from the release point do beetles feed and lay
# eggs, depending on forest density? See README.md.
#
# Run from the PWNModel.jl/ directory:
#   julia --project=explore explore/forest_density/run.jl

using Ark
using CairoMakie
using PWNModel
using Statistics

include("../common/world.jl")
include("../common/recorders.jl")
include("../common/plotting.jl")

const OUT_DIR = joinpath(@__DIR__, "out")

# Native model time step of one week, with 7 movement steps per week.
const duration_feeding = 3
# Maximum beetle age of 18 weeks. The simulation runs until all beetles are dead.
const max_age = 18

# Scenarios differ only in the tree probability per cell. Everything else is the same,
# including the random seeds.
const DAMAGE_PREVALENCE = 0.03
const SCENARIOS = [
    (title="$(round(Int, 100p)) % trees", tree_probability=p) for p in (0.9, 0.75, 0.5, 0.25)
]

# Each scenario runs with these seeds, and results are aggregated over them.
# Landscape maps show the first seed only.
const SEEDS = 1:10

# Release point, as a cell, in the center of the world.
const RELEASE_X, RELEASE_Y = 100, 100

attraction_kwargs(damaged) =
    (; tick_of_year=0, damaged_trees=damaged, half_distance=50.0, density_radius=20, density_weight=1.0)
const movement_kwargs = (;
    steps_per_tick=7,
    distance_per_step=2000.0,
    duration_feeding=duration_feeding,
    feeding_probability=0.5,
    leave_tree_probability=0.25,
    emergence_flight_distance=100.0,
)

# Runs the model for one scenario and seed. Returns its world, and the summed feeding and egg laying events per cell.
function simulate(scenario, seed)
    world = new_world(; seed=seed, width=2000, height=2000, cell_size=10)
    visits = TreeVisits()

    systems = (
        InitGrids(),
        InitTrees(;
            km2_probability=1.0, tree_probability=scenario.tree_probability,
            damage_prevalence=DAMAGE_PREVALENCE, beetle_prevalence=0.0,
        ),
        # The tree the beetles emerge from, at the release point.
        DamageTree(; x=RELEASE_X, y=RELEASE_Y),
        UpdateTime(; ticks_per_year=52),
        # tick_of_year 0, so that both fields are calculated in the first tick, before any movement.
        TreeAttraction(; attraction_kwargs(false)...),
        TreeAttraction(; attraction_kwargs(true)...),
        ReleaseBeetles(; x=RELEASE_X, y=RELEASE_Y, count=10_000, life_expectancy=5.0, max_age=max_age),
        BeetleMovement(; movement_kwargs...),
        BeetleMortality(),
        visits,
    )

    # One more tick than the maximum age, for BeetleMortality to remove beetles that reached it.
    run!(Scheduler(world, systems), max_age + 1)
    return (; world, visits)
end

const EVENT_TYPES = (
    (title="Feeding (healthy trees)", field=:healthy, color=SERIES_COLORS[1]),
    (title="Egg laying (damaged trees)", field=:damaged, color=SERIES_COLORS[2]),
)

# Runs the model for one scenario with all seeds. Returns the world of the first seed,
# and per event type the event distances of each seed (see `event_distances`).
function simulate_seeds(scenario)
    world = nothing
    events = Dict(et.field => [] for et in EVENT_TYPES)
    for seed in SEEDS
        result = simulate(scenario, seed)
        seed == first(SEEDS) && (world = result.world)
        for et in EVENT_TYPES
            push!(events[et.field], event_distances(getfield(result.visits, et.field)))
        end
    end
    return (; world, events)
end

# ---------------------------------------------------------------------------
# Analysis and plots

# Distances of all cells with events from the release point (between cell centers), with their event counts.
function event_distances(grid::Grid)
    release = cell_center(RELEASE_X, RELEASE_Y, grid.cell_size)
    distances, counts = Float64[], Int[]
    for x in 1:grid.width, y in 1:grid.height
        n = grid[x, y]
        n == 0 && continue
        push!(distances, hypot((cell_center(x, y, grid.cell_size) .- release)...))
        push!(counts, n)
    end
    return (; distances, counts)
end

# Quantile `q` of values weighted by integer counts: the smallest value with at least
# a fraction `q` of the counts at or below it.
function weighted_quantile(values, counts, q)
    order = sortperm(values)
    threshold = q * sum(counts)
    total = 0
    for i in order
        total += counts[i]
        total >= threshold && return values[i]
    end
    return NaN
end

const DISTANCE_BIN_WIDTH = 50.0

# Landscape maps show a small section of the world around the release point.
const MAP_RADIUS = 100.0

# Trees in a small section of the landscape around the release point (star), with one pixel per cell.
function plot_landscape(pos, world; title)
    cs = get_resource(world, WorldSize).cell_size
    release = cell_center(RELEASE_X, RELEASE_Y, cs)
    xlims = (release[1] - MAP_RADIUS, release[1] + MAP_RADIUS)
    ylims = (release[2] - MAP_RADIUS, release[2] + MAP_RADIUS)
    ax = Axis(pos; title=title, aspect=DataAspect())
    hidedecorations!(ax)
    image!(ax, tree_image(world; xlims=xlims, ylims=ylims)...; interpolate=false, rasterize=2)
    scatter!(ax, [Point2f(release...)]; color=:black, marker=:star5, markersize=12)
    limits!(ax, xlims..., ylims...)
    return ax
end

# Event distances of all seeds pooled.
pool(events) = (; distances=reduce(vcat, e.distances for e in events), counts=reduce(vcat, e.counts for e in events))

# Quantile `q` of event distances, NaN without events.
event_quantile(e, q) = isempty(e.counts) ? NaN : weighted_quantile(e.distances, e.counts, q)

# Quantiles shown in the plots, besides the median.
const UPPER_QUANTILE = 0.95

# Histograms of event distances, pooled over all seeds and given as the mean per run:
# one row per scenario, one column per event type, with a map of the landscape of the first seed
# in front of each row.
function plot_event_distances(results)
    per_seed = [result.events[et.field] for result in results, et in EVENT_TYPES]
    events = map(pool, per_seed)
    max_distance = maximum(maximum(e.distances) for e in events if !isempty(e.distances))
    bins = 0:DISTANCE_BIN_WIDTH:(ceil(max_distance/DISTANCE_BIN_WIDTH)*DISTANCE_BIN_WIDTH)

    println("Events by distance from the release point, over $(length(SEEDS)) seeds")
    fig = Figure(; size=(1400, 1100))
    panel_axes = Matrix{Axis}(undef, size(events))
    for (row, (scenario, result)) in enumerate(zip(SCENARIOS, results))
        Label(fig[row, 0], scenario.title; rotation=pi / 2, font=:bold, tellheight=false)
        plot_landscape(fig[row, 1], result.world; title=row == 1 ? "Landscape" : "")
    end
    for (row, scenario) in enumerate(SCENARIOS), (col, et) in enumerate(EVENT_TYPES)
        e = events[row, col]
        ax = Axis(
            fig[row, col+1];
            title=row == 1 ? et.title : "",
            xlabel=row == length(SCENARIOS) ? "Distance from release point (m)" : "",
            ylabel=col == 1 ? "Events per run" : "",
        )
        panel_axes[row, col] = ax
        n_runs = length(SEEDS)
        mean_total = round(Int, sum(e.counts; init=0) / n_runs)
        quantile_text = ""
        if mean_total > 0
            hist!(
                ax, e.distances;
                weights=e.counts ./ n_runs, bins=bins, color=et.color, strokecolor=:white, strokewidth=0.5,
            )
            # Quantiles over all seeds, and range of the quantiles of the single seeds.
            texts = map(((0.5, "median"), (UPPER_QUANTILE, "$(round(Int, 100UPPER_QUANTILE)) %"))) do (q, name)
                seed_values = filter(!isnan, [event_quantile(s, q) for s in per_seed[row, col]])
                lo, hi = round.(Int, extrema(seed_values))
                "$name $(round(Int, event_quantile(e, q))) m (seeds $(lo)–$(hi) m)"
            end
            quantile_text = join(
                texts,
                "
",
            )
            vlines!(ax, [event_quantile(e, UPPER_QUANTILE)]; color=:black, linestyle=:dash, linewidth=1)
        end
        text!(
            ax, 1, 1;
            text="$mean_total events per run
$quantile_text",
            space=:relative, align=(:right, :top), justification=:right, offset=(-6, -6),
        )
        row == length(SCENARIOS) || hidexdecorations!(ax; grid=false)

        col == 1 && println("  ", scenario.title)
        println(
            "    ",
            rpad(et.title * ":", 28),
            lpad(mean_total, 9),
            " events per run, ",
            replace(quantile_text, "
" => ", "),
        )
    end
    linkxaxes!(panel_axes...)
    for col in axes(panel_axes, 2)
        linkyaxes!(panel_axes[:, col]...)
    end
    # Square landscape maps, as high as the rows.
    colsize!(fig.layout, 1, Aspect(1, 1.0))
    save_figure(OUT_DIR, "event_distances", fig; png=true)
end

let
    results = [simulate_seeds(scenario) for scenario in SCENARIOS]
    plot_event_distances(results)
end
