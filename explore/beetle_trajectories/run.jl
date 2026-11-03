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
const duration_egg_laying = 8 * steps_per_tick
const total_steps = duration_feeding + duration_egg_laying

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
        # Life expectancy is in ticks, i.e. movement steps here: 5 weeks.
        ReleaseBeetles(; x=100, y=100, count=100, life_expectancy=5.0 * steps_per_tick),
        BeetleMovement(;
            steps_per_tick=1,
            distance_per_step=2000.0,
            duration_feeding=duration_feeding,
            feeding_probability=0.5,
            leave_tree_probability=0.25,
        ),
        BeetleMortality(),
        trajectories,
    )

    run!(Scheduler(world, systems), total_steps)

    cs = get_resource(world, WorldSize).cell_size
    tracks = [[Point2f(cell_center(p.x, p.y, cs)...) for p in trajectories.tracks[e]] for e in trajectories.entities]
    return (; world, tracks, release=first(first(tracks)))
end

results = [simulate(scenario.init_trees) for scenario in SCENARIOS]

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

# Trajectories by phase: one row per scenario, one column per phase.
fig = Figure(; size=(1100, 1050))
for (row, (scenario, result)) in enumerate(zip(SCENARIOS, results))
    m = map_setup(result)
    Label(fig[row, 0], scenario.title; rotation=pi / 2, font=:bold, fontsize=18, tellheight=false)
    for (col, phase) in enumerate(phases)
        ax = Axis(
            fig[row, col];
            title=row == 1 ? phase.title : "",
            xlabel=row == length(SCENARIOS) ? "x from release point (m)" : "",
            ylabel="y from release point (m)",
            m.axis_kwargs...,
        )
        image!(ax, m.trees...; interpolate=false, rasterize=2)
        lines!(ax, track_segments(result.tracks, phase.range); color=(phase.color, 0.35), linewidth=1)
        # Positions at the end of the phase, of beetles still alive then.
        scatter!(
            ax,
            [t[last(phase.range)] for t in result.tracks if length(t) >= last(phase.range)];
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

fig = Figure(; size=(1100, 420))
displacement_axes = Axis[]
for (i, (scenario, result)) in enumerate(zip(SCENARIOS, results))
    # NaN after a beetle's death. Quantiles are over the beetles alive at each step.
    dist = [s + 1 <= length(t) ? hypot((t[s+1] - result.release)...) : NaN for t in result.tracks, s in steps]
    q10, q50, q90 = (map(c -> alive_quantile(c, q), eachcol(dist)) for q in (0.1, 0.5, 0.9))

    ax = Axis(
        fig[1, i];
        xlabel="Movement step ($steps_per_tick per week)",
        ylabel=i == 1 ? "Distance from release point (m)" : "",
        title=scenario.title,
    )
    push!(displacement_axes, ax)
    for row in eachrow(dist)
        lines!(ax, steps, row; color=(:gray, 0.15), linewidth=1)
    end
    band!(ax, steps, q10, q90; color=(SERIES_COLORS[1], 0.2), label="10–90 % quantiles")
    lines!(ax, steps, q50; color=SERIES_COLORS[1], linewidth=2, label="Median")
    vlines!(ax, [duration_feeding]; color=:black, linestyle=:dash, linewidth=1)
    text!(ax, duration_feeding, 0; text=" feeding | egg laying", align=(:center, :bottom), offset=(0, 4))
    i == 1 && axislegend(ax; position=:lt)

    damaged_set = Set(tree_points(result.world; damaged=true))
    survivors = [t for t in result.tracks if length(t) == total_steps + 1]
    println(scenario.title)
    println("  Beetles released:                   ", length(result.tracks))
    println("  Beetles alive at the end:           ", length(survivors))
    println("  Median distance after feeding:      ", round(q50[duration_feeding+1]; digits=1), " m (beetles alive)")
    println("  Median distance after egg laying:   ", round(q50[end]; digits=1), " m (beetles alive)")
    isempty(survivors) || println(
        "  Survivors ending on a damaged tree: ",
        round(mean(t[end] in damaged_set for t in survivors); digits=2),
    )
end
linkyaxes!(displacement_axes...)
save_figure(OUT_DIR, "displacement", fig; png=true)
