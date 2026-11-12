# Forest density: how far from the release point do beetles feed and lay
# eggs, and how far do they get, depending on forest density? See README.md.
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

# Model time step is one week, with `steps_per_tick` movement steps per week.
# To record the position of every beetle after every single step, we run the
# movement system with one step per tick and scale the phase durations accordingly.
# Trees and attraction fields are static here, so this gives the same movement
# as the model's weekly ticks; only the order of random numbers differs.
const steps_per_tick = 7
const duration_feeding = 3 * steps_per_tick
# Maximum beetle age of 18 weeks. The simulation runs until all beetles are dead.
const max_age = 18 * steps_per_tick

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
    steps_per_tick=1,
    distance_per_step=2000.0,
    duration_feeding=duration_feeding,
    feeding_probability=0.5,
    leave_tree_probability=0.25,
    emergence_flight_distance=100.0,
)

"""
    MaxDistances(release, duration_feeding)

System that records, per beetle, the maximum distance from the release point (`release`, cell centers in meters)
in each phase: maturation feeding (the first `duration_feeding` ticks after emergence) and egg laying (after that).
A beetle that leaves the world gets distance `Inf` in the phase it leaves in.
Must come after the movement system, and before `BeetleMortality`, so that it also records the last step
of beetles that die in a tick.

Distances are in `maturation` and `egg_laying`, per beetle, in the order beetles were first recorded.
`NaN` marks a phase a beetle did not reach.
"""
struct MaxDistances <: PWNModel.System
    release::NTuple{2,Float64}
    duration_feeding::Int
    index::Dict{Entity,Int}
    tick_of_death::Vector{Int}
    last_seen::Vector{Int}
    maturation::Vector{Float64}
    egg_laying::Vector{Float64}
end

MaxDistances(release, duration_feeding) =
    MaxDistances(release, duration_feeding, Dict{Entity,Int}(), Int[], Int[], Float64[], Float64[])

# All beetles are released at the release point, during maturation feeding.
function PWNModel.initialize!(s::MaxDistances, w::World)
    for (entities, life_expectancies) in Query(w, (LifeExpectancy,))
        for i in eachindex(entities)
            s.index[entities[i]] = length(s.tick_of_death) + 1
            push!(s.tick_of_death, life_expectancies[i].tick_of_death)
            push!(s.last_seen, -1)
            push!(s.maturation, 0.0)
            push!(s.egg_laying, NaN)
        end
    end
end

function PWNModel.update!(s::MaxDistances, w::World)
    tick = get_resource(w, Time).tick
    cs = get_resource(w, WorldSize).cell_size
    for (entities, positions, emergence_ticks) in Query(w, (BeetlePosition, EmergenceTick))
        for i in eachindex(entities)
            k = s.index[entities[i]]
            s.last_seen[k] = tick
            d = hypot((cell_center(positions[i].x, positions[i].y, cs) .- s.release)...)
            record_distance!(s, k, tick, emergence_ticks[i].tick_of_emergence, d)
        end
    end
    # Beetles that were there in the last tick, but not anymore, and had not reached their age of death
    # by then, were removed by the movement: they left the world.
    for k in eachindex(s.last_seen)
        if s.last_seen[k] == tick - 1 && s.tick_of_death[k] > tick - 1
            # All beetles are released at tick 0.
            record_distance!(s, k, tick, 0, Inf)
        end
    end
end

function record_distance!(s::MaxDistances, k, tick, tick_of_emergence, d)
    if tick < tick_of_emergence + s.duration_feeding
        s.maturation[k] = max(s.maturation[k], d)
    else
        s.egg_laying[k] = isnan(s.egg_laying[k]) ? d : max(s.egg_laying[k], d)
    end
end

# Runs the model for one scenario and seed. Returns its world, the summed feeding and egg laying events per cell,
# and the maximum distances per beetle and phase.
function simulate(scenario, seed)
    world = new_world(; seed=seed, width=2000, height=2000, cell_size=10)
    visits = TreeVisits()
    max_distances = MaxDistances(cell_center(RELEASE_X, RELEASE_Y, 10), duration_feeding)

    systems = (
        InitGrids(),
        InitTrees(;
            km2_probability=1.0, tree_probability=scenario.tree_probability,
            damage_prevalence=DAMAGE_PREVALENCE, beetle_prevalence=0.0,
        ),
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
        visits,
        max_distances,
        BeetleMortality(),
    )

    # One more tick than the maximum age, for BeetleMortality to remove beetles that reached it.
    run!(Scheduler(world, systems), max_age + 1)
    return (; world, visits, max_distances)
end

# Columns of the figures and tables: distances of events, and maximum distances of beetles per phase.
const EVENT_TYPES = (
    (title="Feeding (healthy trees)", short="Feeding", field=:healthy, color=SERIES_COLORS[1]),
    (title="Egg laying (damaged trees)", short="Egg laying", field=:damaged, color=SERIES_COLORS[2]),
)
const PHASES = (
    (title="Maturation feeding phase", short="Maturation", field=:maturation, color=SERIES_COLORS[1]),
    (title="Egg laying phase", short="Egg laying", field=:egg_laying, color=SERIES_COLORS[2]),
)

# Runs the model for one scenario with all seeds. Returns the world of the first seed,
# and per event type and phase the distances of each seed, with their counts:
# event distances (see `event_distances`), and maximum distances of beetles (see `beetle_distances`).
function simulate_seeds(scenario)
    world = nothing
    distances = Dict(c.field => [] for c in (EVENT_TYPES..., PHASES...))
    for seed in SEEDS
        result = simulate(scenario, seed)
        seed == first(SEEDS) && (world = result.world)
        for et in EVENT_TYPES
            push!(distances[et.field], event_distances(getfield(result.visits, et.field)))
        end
        for ph in PHASES
            push!(distances[ph.field], beetle_distances(getfield(result.max_distances, ph.field)))
        end
    end
    return (; world, distances)
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

# Maximum distances of the beetles that reached a phase, each with count 1.
function beetle_distances(max_distances)
    distances = filter(!isnan, max_distances)
    return (; distances, counts=ones(Int, length(distances)))
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

# Distances of all seeds pooled.
pool(seeds) = (; distances=reduce(vcat, s.distances for s in seeds), counts=reduce(vcat, s.counts for s in seeds))

# Quantile `q` of distances, NaN without any. `Inf` if it is beyond the world's edge.
event_quantile(e, q) = isempty(e.counts) ? NaN : weighted_quantile(e.distances, e.counts, q)

# Share of the counts with a distance beyond the world's edge.
beyond_edge_share(e) = sum(e.counts[isinf.(e.distances)]; init=0) / sum(e.counts)

# A distance in whole meters, or "beyond edge".
format_distance(d) = isinf(d) ? "beyond edge" : "$(round(Int, d)) m"

# Quantiles shown in the plots, besides the median.
const UPPER_QUANTILE = 0.95
# Quantiles shown in the tables.
const TABLE_QUANTILES = ((0.5, "Median"), (0.95, "95 %"), (0.99, "99 %"))

# Quantile `q` of distances over all seeds, and the range of the quantiles of the single seeds.
function quantile_summary(per_seed, q)
    seed_values = filter(!isnan, [event_quantile(s, q) for s in per_seed])
    lo, hi = extrema(seed_values)
    return (; pooled=event_quantile(pool(per_seed), q), lo, hi)
end

# Histograms of distances, pooled over all seeds and given as the mean per run:
# one row per scenario, one column per entry of `columns` (event types or phases),
# with a map of the landscape of the first seed in front of each row.
# `unit` is what is counted: "events" or "beetles".
function plot_distances(results, columns; name, unit)
    per_seed = [result.distances[c.field] for result in results, c in columns]
    pooled = map(pool, per_seed)
    max_distance = maximum(maximum(filter(isfinite, e.distances); init=0.0) for e in pooled)
    bins = 0:DISTANCE_BIN_WIDTH:(ceil(max_distance/DISTANCE_BIN_WIDTH)*DISTANCE_BIN_WIDTH)

    println("$(name), over $(length(SEEDS)) seeds")
    fig = Figure(; size=(1400, 1100))
    panel_axes = Matrix{Axis}(undef, size(pooled))
    for (row, (scenario, result)) in enumerate(zip(SCENARIOS, results))
        Label(fig[row, 0], scenario.title; rotation=pi / 2, font=:bold, tellheight=false)
        plot_landscape(fig[row, 1], result.world; title=row == 1 ? "Landscape" : "")
    end
    for (row, scenario) in enumerate(SCENARIOS), (col, c) in enumerate(columns)
        e = pooled[row, col]
        ax = Axis(
            fig[row, col+1];
            title=row == 1 ? c.title : "",
            xlabel=row == length(SCENARIOS) ? "Distance from release point (m)" : "",
            ylabel=col == 1 ? "$(uppercasefirst(unit)) per run" : "",
        )
        panel_axes[row, col] = ax
        n_runs = length(SEEDS)
        mean_total = round(Int, sum(e.counts; init=0) / n_runs)
        texts = ["$mean_total $unit per run"]
        if mean_total > 0
            finite = isfinite.(e.distances)
            hist!(
                ax, e.distances[finite];
                weights=e.counts[finite] ./ n_runs, bins=bins, color=c.color, strokecolor=:white, strokewidth=0.5,
            )
            share = beyond_edge_share(e)
            share > 0 && push!(texts, "$(round(100share; sigdigits=2)) % beyond world edge")
            # Quantiles over all seeds, and range of the quantiles of the single seeds.
            for (q, qname) in ((0.5, "median"), (UPPER_QUANTILE, "$(round(Int, 100UPPER_QUANTILE)) %"))
                s = quantile_summary(per_seed[row, col], q)
                push!(
                    texts,
                    "$qname $(format_distance(s.pooled)) (seeds $(format_distance(s.lo)) – $(format_distance(s.hi)))",
                )
            end
            upper = event_quantile(e, UPPER_QUANTILE)
            isfinite(upper) && vlines!(ax, [upper]; color=:black, linestyle=:dash, linewidth=1)
        end
        text!(
            ax, 1, 1;
            text=join(texts, "\n"),
            space=:relative, align=(:right, :top), justification=:right, offset=(-6, -6),
        )
        row == length(SCENARIOS) || hidexdecorations!(ax; grid=false)

        col == 1 && println("  ", scenario.title)
        println("    ", rpad(c.title * ":", 28), join(texts, ", "))
    end
    linkxaxes!(panel_axes...)
    for col in axes(panel_axes, 2)
        linkyaxes!(panel_axes[:, col]...)
    end
    # Square landscape maps, as high as the rows.
    colsize!(fig.layout, 1, Aspect(1, 1.0))
    save_figure(OUT_DIR, name, fig; png=true)
end

# Quantiles of distances as a Markdown table `<name>.md`, included in the README:
# one row per scenario, one column per entry of `columns` (event types or phases) and quantile.
# Each cell gives the quantile over all seeds.
function write_quantile_table(results, columns; name)
    mkpath(OUT_DIR)
    open(joinpath(OUT_DIR, "$name.md"), "w") do io
        headers = ["$(c.short): $qname" for c in columns for (_, qname) in TABLE_QUANTILES]
        println(io, "| Forest density | ", join(headers, " | "), " |")
        println(io, "| :------------- | ", join(("-----:" for _ in headers), " | "), " |")
        for (scenario, result) in zip(SCENARIOS, results)
            cells = map(((c, q) for c in columns for (q, _) in TABLE_QUANTILES)) do (c, q)
                d = event_quantile(pool(result.distances[c.field]), q)
                isnan(d) ? "–" : format_distance(d)
            end
            println(io, "| $(scenario.title) | ", join(cells, " | "), " |")
        end
    end
end

let
    results = [simulate_seeds(scenario) for scenario in SCENARIOS]
    plot_distances(results, EVENT_TYPES; name="event_distances", unit="events")
    write_quantile_table(results, EVENT_TYPES; name="event_distances")
    plot_distances(results, PHASES; name="max_distances", unit="beetles")
    write_quantile_table(results, PHASES; name="max_distances")
end
