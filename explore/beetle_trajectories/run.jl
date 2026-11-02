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

world = new_world(; seed=1, width=2000, height=2000, cell_size=10)

trajectories = BeetleTrajectories()

systems = (
    InitGrids(),
    InitTrees(; km2_probability=1.0, tree_probability=0.9, damage_prevalence=0.03, beetle_prevalence=0.0),
    UpdateTime(; ticks_per_year=52*steps_per_tick),
    # tick_of_year 0, so that both fields are calculated in the first tick, before any movement.
    TreeAttraction(; tick_of_year=0, damaged_trees=false, half_distance=50.0, density_radius=20, density_weight=1.0),
    TreeAttraction(; tick_of_year=0, damaged_trees=true, half_distance=50.0, density_radius=20, density_weight=1.0),
    # Life expectancy is in ticks, i.e. movement steps here: 5 weeks.
    ReleaseBeetles(; x=100, y=100, count=100, life_expectancy=5.0 * steps_per_tick),
    BeetleMovement(;
        steps_per_tick=1,
        duration_feeding=duration_feeding,
        duration_egg_laying=duration_egg_laying,
        leave_tree_probability=0.25,
        random_walk_probability=0.6,
    ),
    BeetleMortality(),
    trajectories,
)

run!(Scheduler(world, systems), total_steps)

# ---------------------------------------------------------------------------
# Analysis and plots

cs = get_resource(world, WorldSize).cell_size
tracks = [[Point2f(cell_center(p.x, p.y, cs)...) for p in track] for track in values(trajectories.tracks)]
release = first(first(tracks))

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

healthy_trees = tree_points(world; damaged=false)
damaged_trees = tree_points(world; damaged=true)

phases = (
    (
        title="Maturation feeding (attracted by healthy trees)",
        field=get_resource(world, HealthyTreeAttraction).grid,
        range=1:(duration_feeding+1),
        color=SERIES_COLORS[1],
    ),
    (
        title="Egg laying (attracted by damaged trees)",
        field=get_resource(world, DamagedTreeAttraction).grid,
        range=(duration_feeding+1):(total_steps+1),
        color=SERIES_COLORS[2],
    ),
)

# Zoom the maps to the area visited by beetles, plus a margin.
const MAP_MARGIN = 100.0
visited = reduce(vcat, tracks)
xlims = (max(0, minimum(first, visited) - MAP_MARGIN), maximum(first, visited) + MAP_MARGIN)
ylims = (max(0, minimum(last, visited) - MAP_MARGIN), maximum(last, visited) + MAP_MARGIN)

fig = Figure(; size=(1200, 520))
for (i, phase) in enumerate(phases)
    ax = Axis(fig[1, i]; title=phase.title, aspect=DataAspect(), xlabel="x (m)", ylabel="y (m)")
    xs, ys = grid_axes(phase.field)
    hm = heatmap!(
        ax, xs, ys, log10.(max.(grid_matrix(phase.field), 1e-8));
        colormap=FIELD_COLORMAP, colorrange=(-8, 0), rasterize=2,
    )
    scatter!(ax, healthy_trees; color=HEALTHY_TREE_COLOR, markersize=3, rasterize=2)
    scatter!(ax, damaged_trees; color=DAMAGED_TREE_COLOR, markersize=5, rasterize=2)
    lines!(ax, track_segments(tracks, phase.range); color=(phase.color, 0.35), linewidth=1)
    # Positions at the end of the phase, of beetles still alive then.
    scatter!(ax, [t[last(phase.range)] for t in tracks if length(t) >= last(phase.range)]; color=phase.color, markersize=6)
    scatter!(ax, [release]; color=:black, marker=:star5, markersize=14)
    limits!(ax, xlims..., ylims...)
    i == length(phases) && Colorbar(fig[1, i+1], hm; label="log₁₀ attraction")
end
save_figure(OUT_DIR, "trajectories", fig; png=true)

# Net displacement from the release point over movement steps.
steps = 0:total_steps
# NaN after a beetle's death. Quantiles are over the beetles alive at each step.
dist = [s + 1 <= length(t) ? hypot((t[s+1] - release)...) : NaN for t in tracks, s in steps]
alive_quantile(col, q) = (alive = filter(!isnan, col); isempty(alive) ? NaN : quantile(alive, q))
q10, q50, q90 = (map(c -> alive_quantile(c, q), eachcol(dist)) for q in (0.1, 0.5, 0.9))

fig = Figure(; size=(800, 420))
ax = Axis(
    fig[1, 1];
    xlabel="Movement step ($steps_per_tick per week)", ylabel="Distance from release point (m)",
    title="Net displacement of $(length(tracks)) beetles",
)
for row in eachrow(dist)
    lines!(ax, steps, row; color=(:gray, 0.15), linewidth=1)
end
band!(ax, steps, q10, q90; color=(SERIES_COLORS[1], 0.2), label="10–90 % quantiles")
lines!(ax, steps, q50; color=SERIES_COLORS[1], linewidth=2, label="Median")
vlines!(ax, [duration_feeding]; color=:black, linestyle=:dash, linewidth=1)
text!(ax, duration_feeding, 0; text=" feeding | egg laying", align=(:center, :bottom), offset=(0, 4))
axislegend(ax; position=:lt)
save_figure(OUT_DIR, "displacement", fig; png=true)

damaged_set = Set(damaged_trees)
survivors = [t for t in tracks if length(t) == total_steps + 1]
println("Beetles released:                  ", length(tracks))
println("Beetles alive at the end:          ", length(survivors))
println("Median distance after feeding:     ", round(q50[duration_feeding+1]; digits=1), " m (beetles alive)")
println("Median distance after egg laying:  ", round(q50[end]; digits=1), " m (beetles alive)")
isempty(survivors) || println(
    "Survivors ending on a damaged tree: ",
    round(mean(t[end] in damaged_set for t in survivors); digits=2),
)
