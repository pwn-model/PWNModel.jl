# Beetle trajectories: how do beetles carrying nematodes move through a
# landscape during maturation feeding and egg laying? See README.md.
#
# Run from the PWNModel.jl/ directory:
#   julia --project=explore explore/beetle_trajectories/run.jl

using Ark
using CairoMakie
using PWNModel
using Statistics

include("../common/world.jl")
include("../common/recorders.jl")
include("../common/plotting.jl")

const OUT_DIR = joinpath(@__DIR__, "out")

# Model time step is one week, with `steps_per_tick` movement steps per week.
# To record every single step, we run BeetleMovement with one step per tick
# and scale the phase durations accordingly. Trees and attraction fields are
# static here, so this gives the same movement as the model's weekly ticks;
# only the order of random numbers differs.
const steps_per_tick = 7
const duration_feeding = 3 * steps_per_tick
# Maximum beetle age of 18 weeks. The simulation runs until all beetles are dead.
const max_age = 18 * steps_per_tick
const total_steps = max_age

# Scenarios differ only in the tree landscape. Everything else is the same,
# including the random seed.
const SCENARIOS = [
    (
        name="dense",
        title="Dense forest",
        init_trees=InitTrees(;
            km2_probability=1.0, tree_probability=0.9, damage_prevalence=0.03, beetle_prevalence=0.0,
        ),
    ),
    (
        name="sparse",
        title="Sparse forest",
        init_trees=InitTrees(;
            km2_probability=1.0, tree_probability=0.025, damage_prevalence=0.25, beetle_prevalence=0.0,
        ),
    ),
]

# Runs the model for one scenario. Returns its world, and the beetle tracks and release point in meters.
function simulate(init_trees)
    world = new_world(; seed=1, width=2000, height=2000, cell_size=10)

    trajectories = BeetleTrajectories()

    systems = (
        InitGrids(),
        init_trees,
        # The tree the beetles emerge from, at the release point.
        DamageTree(; x=100, y=100),
        UpdateTime(; ticks_per_year=52*steps_per_tick),
        # tick_of_year 0, so that both fields are calculated in the first tick, before any movement.
        TreeAttraction(;
            tick_of_year=0,
            damaged_trees=false,
            half_distance=50.0,
            density_radius=20,
            density_weight=1.0,
        ),
        TreeAttraction(; tick_of_year=0, damaged_trees=true, half_distance=50.0, density_radius=20, density_weight=1.0),
        # Life expectancy and maximum age are in ticks, i.e. movement steps here: 5 and 18 weeks.
        ReleaseBeetles(; x=100, y=100, count=10_000, life_expectancy=5.0 * steps_per_tick, max_age=max_age),
        BeetleMovement(;
            steps_per_tick=1,
            distance_per_step=2000.0,
            duration_feeding=duration_feeding,
            feeding_probability=0.5,
            leave_tree_probability=0.25,
            emergence_flight_distance=100.0,
        ),
        BeetleMortality(),
        trajectories,
    )

    # One more tick than steps, for BeetleMortality to remove beetles that reached the maximum age.
    run!(Scheduler(world, systems), total_steps + 1)

    cs = get_resource(world, WorldSize).cell_size
    tracks = [[Point2f(cell_center(p.x, p.y, cs)...) for p in trajectories.tracks[e]] for e in trajectories.entities]
    return (; world, tracks, release=first(first(tracks)))
end

results = [simulate(scenario.init_trees) for scenario in SCENARIOS]

# Statistics and distributions use all beetles, trajectory plots only the first ones, to keep them readable.
const N_TRAJECTORIES = 100
shown_tracks(result) = result.tracks[1:min(N_TRAJECTORIES, length(result.tracks))]

# ---------------------------------------------------------------------------
# Analysis and plots

# Tracks end early when beetles die. Part of a track within the given range of steps.
track_range(track, range) = track[first(range):min(last(range), length(track))]

# All tracks as a single line plot, separated by NaN points, to keep the SVG small.
function track_segments(tracks, range)
    points = Point2f[]
    for track in tracks
        append!(points, track_range(track, range))
        push!(points, Point2f(NaN, NaN))
    end
    return points
end

phases = (
    (
        title="Maturation feeding (attracted by healthy trees)",
        range=1:(duration_feeding+1),
        color=SERIES_COLORS[1],
    ),
    (
        title="Egg laying (attracted by damaged trees)",
        range=(duration_feeding+1):(total_steps+1),
        color=SERIES_COLORS[2],
    ),
)

# Maps show a fixed area around the release point, which is the origin of the ticks.
const MAP_RADIUS = 500.0
const MAP_TICK_STEP = 200
function map_ticks(origin)
    # Ticks at multiples of MAP_TICK_STEP, so that there is always one at the origin.
    n = floor(Int, MAP_RADIUS / MAP_TICK_STEP)
    offsets = ((-n):n) .* MAP_TICK_STEP
    return (origin .+ offsets, string.(offsets))
end

# Map area, tree bitmap and axis settings for a scenario's result.
function map_setup(result)
    release = result.release
    xlims = (release[1] - MAP_RADIUS, release[1] + MAP_RADIUS)
    ylims = (release[2] - MAP_RADIUS, release[2] + MAP_RADIUS)
    trees = tree_image(result.world; xlims=xlims, ylims=ylims)
    axis_kwargs = (; aspect=DataAspect(), xticks=map_ticks(release[1]), yticks=map_ticks(release[2]))
    return (; xlims, ylims, trees, axis_kwargs)
end

# Trajectories by phase: one column per scenario, one row per phase.
fig = Figure(; size=(1050, 1100))
for (col, (scenario, result)) in enumerate(zip(SCENARIOS, results))
    m = map_setup(result)
    for (row, phase) in enumerate(phases)
        col == 1 && Label(fig[row, 0], phase.title; rotation=pi / 2, font=:bold, tellheight=false)
        ax = Axis(
            fig[row, col];
            title=row == 1 ? scenario.title : "",
            xlabel=row == length(phases) ? "x from release point (m)" : "",
            ylabel=col == 1 ? "y from release point (m)" : "",
            m.axis_kwargs...,
        )
        image!(ax, m.trees...; interpolate=false, rasterize=2)
        lines!(ax, track_segments(shown_tracks(result), phase.range); color=(phase.color, 0.35), linewidth=1)
        # Positions at the end of the phase, or at death during the phase.
        scatter!(
            ax,
            [last(track_range(t, phase.range)) for t in shown_tracks(result) if length(t) > first(phase.range)];
            color=phase.color,
            markersize=6,
        )
        scatter!(ax, [result.release]; color=:black, marker=:star5, markersize=14)
        limits!(ax, m.xlims..., m.ylims...)
    end
end
save_figure(OUT_DIR, "trajectories", fig; png=true)

# Individual trajectories of the first beetles, both phases per panel. One figure per scenario.
const GRID_ROWS, GRID_COLS = 4, 5

for (scenario, result) in zip(SCENARIOS, results)
    m = map_setup(result)
    local fig = Figure(; size=(1300, 1150))
    for (k, track) in enumerate(result.tracks[1:min(GRID_ROWS*GRID_COLS, length(result.tracks))])
        row, col = fldmod1(k, GRID_COLS)
        died = length(track) < total_steps + 1
        title = died ? "Beetle $k (died week $(cld(length(track) - 1, steps_per_tick)))" : "Beetle $k"
        ax = Axis(fig[row, col]; title=title, m.axis_kwargs...)
        image!(ax, m.trees...; interpolate=false, rasterize=2)
        for phase in phases
            segment = track_range(track, phase.range)
            length(segment) > 1 && lines!(ax, segment; color=phase.color, linewidth=1.5)
        end
        scatter!(ax, [result.release]; color=:black, marker=:star5, markersize=10)
        died && scatter!(ax, [track[end]]; color=:black, marker=:xcross, markersize=10)
        limits!(ax, m.xlims..., m.ylims...)
        row == GRID_ROWS || hidexdecorations!(ax; grid=false)
        col == 1 || hideydecorations!(ax; grid=false)
    end
    Legend(
        fig[GRID_ROWS+1, :],
        [
            LineElement(; color=phases[1].color, linewidth=1.5),
            LineElement(; color=phases[2].color, linewidth=1.5),
            MarkerElement(; color=:black, marker=:star5, markersize=10),
            MarkerElement(; color=:black, marker=:xcross, markersize=10),
        ],
        ["Maturation feeding", "Egg laying", "Release point", "Death"];
        orientation=:horizontal, framevisible=false,
    )
    save_figure(OUT_DIR, "trajectories_individual_$(scenario.name)", fig; png=true)
end

# Net displacement from the release point over movement steps: one panel per scenario.
steps = 0:total_steps
alive_quantile(col, q) = (alive=filter(!isnan, col); isempty(alive) ? NaN : quantile(alive, q))

fig = Figure(; size=(1100, 470))
displacement_axes = Axis[]
# Upper y limit from the 90 % quantiles of both scenarios, as single beetles go much further.
displacement_ymax = 0.0
for (i, (scenario, result)) in enumerate(zip(SCENARIOS, results))
    # NaN after a beetle's death. Quantiles are over the beetles alive at each step.
    dist = [s + 1 <= length(t) ? hypot((t[s+1] - result.release)...) : NaN for t in result.tracks, s in steps]
    q10, q50, q90 = (map(c -> alive_quantile(c, q), eachcol(dist)) for q in (0.1, 0.5, 0.9))
    global displacement_ymax = max(displacement_ymax, maximum(filter(!isnan, q90)))

    ax = Axis(
        fig[1, i];
        xlabel="Movement step ($steps_per_tick per week)",
        ylabel=i == 1 ? "Distance from release point (m)" : "",
        title=scenario.title,
    )
    push!(displacement_axes, ax)
    for row in eachrow(dist[1:min(N_TRAJECTORIES, end), :])
        lines!(ax, steps, row; color=(:gray, 0.15), linewidth=1)
    end
    band!(ax, steps, q10, q90; color=(SERIES_COLORS[1], 0.2))
    lines!(ax, steps, q50; color=SERIES_COLORS[1], linewidth=2)
    vlines!(ax, [duration_feeding]; color=:black, linestyle=:dash, linewidth=1)
    # Phase names left and right of the phase boundary.
    text!(ax, duration_feeding, 0; text="feeding", align=(:right, :bottom), offset=(-4, 4))
    text!(ax, duration_feeding, 0; text="egg laying", align=(:left, :bottom), offset=(4, 4))

    damaged_set = Set(tree_points(result.world; damaged=true))
    egg_layers = [t for t in result.tracks if length(t) > duration_feeding + 1]
    println(scenario.title)
    println("  Beetles released:                   ", length(result.tracks))
    println("  Beetles alive after feeding:        ", length(egg_layers))
    println("  Median distance after feeding:      ", round(q50[duration_feeding+1]; digits=1), " m (beetles alive)")
    println(
        "  Median distance at death:           ",
        round(median(hypot((t[end] - result.release)...) for t in result.tracks); digits=1),
        " m",
    )
    isempty(egg_layers) || println(
        "  Egg layers dying on a damaged tree: ",
        round(mean(t[end] in damaged_set for t in egg_layers); digits=2),
    )
end
for ax in displacement_axes
    ylims!(ax, -0.03 * displacement_ymax, 1.05 * displacement_ymax)
end
Legend(
    fig[2, :],
    [
        LineElement(; color=(:gray, 0.5), linewidth=1),
        PolyElement(; color=(SERIES_COLORS[1], 0.2)),
        LineElement(; color=SERIES_COLORS[1], linewidth=2),
    ],
    ["Individual beetles (first $N_TRAJECTORIES)", "10–90 % quantiles", "Median"];
    orientation=:horizontal, framevisible=false,
)
save_figure(OUT_DIR, "displacement", fig; png=true)

# Distribution of distances from the release point after selected weeks, over the beetles alive then.
# One row per week, one column per scenario, with shared bins and axes.
const DISTANCE_WEEKS = [2, 4, 8, 12, 16]

# Distances of the beetles alive after `week` weeks.
distances_at(result, week) =
    [hypot((t[week*steps_per_tick+1] - result.release)...) for t in result.tracks if length(t) > week * steps_per_tick]

distances = [distances_at(result, week) for week in DISTANCE_WEEKS, result in results]
const DISTANCE_BIN_WIDTH = 50.0
distance_bins =
    0:DISTANCE_BIN_WIDTH:(ceil(maximum(maximum, filter(!isempty, distances))/DISTANCE_BIN_WIDTH)*DISTANCE_BIN_WIDTH)

fig = Figure(; size=(1100, 1100))
distance_axes = Axis[]
for (row, week) in enumerate(DISTANCE_WEEKS), (col, scenario) in enumerate(SCENARIOS)
    d = distances[row, col]
    ax = Axis(
        fig[row, col];
        title=row == 1 ? scenario.title : "",
        xlabel=row == length(DISTANCE_WEEKS) ? "Distance from release point (m)" : "",
        ylabel=col == 1 ? "Beetles" : "",
    )
    push!(distance_axes, ax)
    isempty(d) || hist!(ax, d; bins=distance_bins, color=SERIES_COLORS[1], strokecolor=:white, strokewidth=0.5)
    median_text = isempty(d) ? "" : ", median $(round(Int, median(d))) m"
    text!(
        ax, 1, 1;
        text="Week $week: $(length(d)) alive$median_text",
        space=:relative, align=(:right, :top), offset=(-6, -6),
    )
    row == length(DISTANCE_WEEKS) || hidexdecorations!(ax; grid=false)
end
linkaxes!(distance_axes...)
save_figure(OUT_DIR, "distance_distribution", fig; png=true)
