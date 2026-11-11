# Attraction half distance: how does `half_distance` of the attraction
# kernel affect the dominance of tree clusters over scattered trees, with
# radial attraction (TreeAttraction)? See README.md.
#
# Run from the PWNModel.jl/ directory:
#   julia --project=explore explore/attraction_half_distance/run.jl

using Ark
using CairoMakie
using PWNModel
using Random

include("../common/world.jl")
include("../common/plotting.jl")

const OUT_DIR = joinpath(@__DIR__, "out")

# Values of half_distance to compare, in meters. 50 m is the default.
const HALF_DISTANCES = [12.5, 25.0, 50.0, 100.0, 200.0]
const DEFAULT_HALF_DISTANCE = 50.0
const DENSITY_RADIUS = 20
const DENSITY_WEIGHT = 1.0

# Landscape: scattered trees, plus round, fully stocked clusters of different
# sizes. Positions and radii are in cells of 10 m.
const WIDTH, HEIGHT, CELL_SIZE = 2000, 2000, 10
const NX, NY = WIDTH ÷ CELL_SIZE, HEIGHT ÷ CELL_SIZE
const CLUSTERS = [
    (center=(50, 145), radius=3),
    (center=(145, 150), radius=6),
    (center=(95, 60), radius=12),
]
const SCATTERED_PROBABILITY = 0.025

in_cluster(c, x, y) = (x - c.center[1])^2 + (y - c.center[2])^2 <= c.radius^2
in_any_cluster(x, y) = any(c -> in_cluster(c, x, y), CLUSTERS)

# Cluster trees fill their clusters completely. Scattered trees are placed
# at random in all other cells, with a fixed seed.
const CLUSTER_TREES = [Position(x, y) for x in 1:NX, y in 1:NY if in_any_cluster(x, y)]
const SCATTERED_TREES = let rng = Xoshiro(1)
    [Position(x, y) for x in 1:NX, y in 1:NY if !in_any_cluster(x, y) && rand(rng) < SCATTERED_PROBABILITY]
end

# Category of each cell, indexed [x, y]: whether it holds a cluster tree.
const IS_CLUSTER = [in_any_cluster(x, y) for x in 1:NX, y in 1:NY]
# Cluster of each cell, 0 for cells outside clusters.
const CLUSTER_ID = [something(findfirst(c -> in_cluster(c, x, y), CLUSTERS), 0) for x in 1:NX, y in 1:NY]

# ---------------------------------------------------------------------------
# Simulation

# Runs a single attraction system for one tick on the landscape. Returns the world.
function attraction(system)
    world = new_world(; seed=1, width=WIDTH, height=HEIGHT, cell_size=CELL_SIZE)
    systems = (
        InitGrids(),
        PlaceTrees(; positions=[CLUSTER_TREES; SCATTERED_TREES]),
        UpdateTime(; ticks_per_year=52),
        system,
    )
    run!(Scheduler(world, systems), 1)
    return world
end

attraction_kwargs(h) = (;
    tick_of_year=0, damaged_trees=false, half_distance=h,
    density_radius=DENSITY_RADIUS, density_weight=DENSITY_WEIGHT,
)

# Radial attraction: for each cell, whether its source is a cluster tree
# (missing if no source), and the catchment size of each tree, i.e. the
# number of cells other than its own that have it as source.
function radial(h)
    world = attraction(TreeAttraction(; attraction_kwargs(h)...))
    source = get_resource(world, HealthyTreeAttraction).source

    source_cluster = Matrix{Union{Missing,Bool}}(missing, NX, NY)
    # Catchment per cell, to find catchment boundaries: the source's cell
    # index for scattered trees, a single negative id per cluster for cluster
    # trees, so that a cluster's catchment is shown as a whole.
    catchment_id = zeros(Int, NX, NY)
    catchment = zeros(Int, NX, NY)
    for x in 1:NX, y in 1:NY
        idx = source[x, y]
        idx == NO_CELL && continue
        sx, sy = cell_coords(source, idx)
        source_cluster[x, y] = IS_CLUSTER[sx, sy]
        catchment_id[x, y] = IS_CLUSTER[sx, sy] ? -CLUSTER_ID[sx, sy] : Int(idx)
        (sx, sy) == (x, y) || (catchment[sx, sy] += 1)
    end

    untargeted = [p for p in SCATTERED_TREES if catchment[p.x, p.y] == 0]
    return (;
        half_distance=h,
        source_cluster,
        catchment_id,
        untargeted,
        cluster_area=count(isequal(true), source_cluster) / count(!ismissing, source_cluster),
        untargeted_share=length(untargeted) / length(SCATTERED_TREES),
    )
end

radial_results = [radial(h) for h in HALF_DISTANCES]

# ---------------------------------------------------------------------------
# Plots

const CLUSTER_COLOR = SERIES_COLORS[1]
const SCATTERED_COLOR = SERIES_COLORS[2]

format_h(h) = h == round(h) ? string(Int(h)) : string(h)
h_label(h) = "half_distance = $(format_h(h)) m"

# Points in meters of the given tree cells.
points(trees) = [Point2f(cell_center(p.x, p.y, CELL_SIZE)...) for p in trees]

# Outline of each cluster, at the outer edge of its cells.
function cluster_outlines()
    out = Point2f[]
    for c in CLUSTERS
        cx, cy = cell_center(c.center..., CELL_SIZE)
        r = (c.radius + 0.5) * CELL_SIZE
        append!(out, [Point2f(cx + r * cos(t), cy + r * sin(t)) for t in range(0, 2pi; length=97)])
        push!(out, Point2f(NaN, NaN))
    end
    return out
end

# Draws cluster outlines and scattered trees over a map, with untargeted
# scattered trees hollow.
function draw_trees!(ax; untargeted)
    lines!(ax, cluster_outlines(); color=:black, linewidth=1)
    set = Set(untargeted)
    targeted = [p for p in SCATTERED_TREES if !(p in set)]
    scatter!(ax, points(targeted); color=:black, markersize=3)
    scatter!(ax, points(untargeted); color=:transparent, strokecolor=:black, strokewidth=0.8, markersize=6)
end

# Grid of map panels, one per half distance, in 2 rows x 3 columns. The
# last slot is passed to `extra` (e.g. for a legend).
function map_panels(draw!, extra, name)
    fig = Figure(; size=(1400, 1000))
    for (i, h) in enumerate(HALF_DISTANCES)
        row, col = fldmod1(i, 3)
        ax = Axis(
            fig[row, col];
            title=h_label(h), aspect=DataAspect(),
            xlabel=row == 2 ? "x (m)" : "", ylabel=col == 1 ? "y (m)" : "",
        )
        draw!(ax, i)
        limits!(ax, 0, WIDTH, 0, HEIGHT)
    end
    extra(fig[2, 3])
    save_figure(OUT_DIR, name, fig; png=true)
end

# Image of the radial catchments, colored by the category of their source
# tree, with darker catchment boundaries. A cluster's catchment is shown as
# a whole, without the boundaries between its trees.
function catchment_image(r)
    image = fill(RGBAf(1, 1, 1, 1), NX, NY)
    blend(color, alpha) =
        (c=to_color(color); RGBAf(1 - alpha * (1 - c.r), 1 - alpha * (1 - c.g), 1 - alpha * (1 - c.b), 1))
    for x in 1:NX, y in 1:NY
        ismissing(r.source_cluster[x, y]) && continue
        id = r.catchment_id[x, y]
        boundary = (x < NX && r.catchment_id[x+1, y] != id) || (y < NY && r.catchment_id[x, y+1] != id)
        color = r.source_cluster[x, y] ? CLUSTER_COLOR : SCATTERED_COLOR
        image[x, y] = blend(color, boundary ? 0.7 : 0.3)
    end
    return image
end

# Radial catchment maps.
map_panels(
    (ax, i) -> begin
        image!(ax, (0, WIDTH), (0, HEIGHT), catchment_image(radial_results[i]); interpolate=false, rasterize=2)
        draw_trees!(ax; untargeted=radial_results[i].untargeted)
    end,
    pos -> Legend(
        pos,
        [
            PolyElement(; color=(CLUSTER_COLOR, 0.3)),
            PolyElement(; color=(SCATTERED_COLOR, 0.3)),
            LineElement(; color=:black, linewidth=1),
            MarkerElement(; marker=:circle, color=:black, markersize=5),
            MarkerElement(; marker=:circle, color=:transparent, strokecolor=:black, strokewidth=0.8, markersize=8),
        ],
        [
            "Source is a cluster tree",
            "Source is a scattered tree",
            "Cluster",
            "Scattered tree, targeted",
            "Scattered tree, not targeted\n(source of no other cell)",
        ];
        framevisible=false, tellwidth=false, tellheight=false,
    ),
    "radial_catchments",
)

# Axis for a summary over half distances, with the default value marked.
function summary_axis(pos; kwargs...)
    ax = Axis(
        pos;
        xscale=log2,
        xticks=(HALF_DISTANCES, format_h.(HALF_DISTANCES)),
        xlabel="half_distance (m)",
        kwargs...,
    )
    vlines!(ax, [DEFAULT_HALF_DISTANCE]; color=:gray60, linestyle=:dash, linewidth=1)
    return ax
end

function summary_lines!(ax, values, color; label)
    scatterlines!(ax, HALF_DISTANCES, values; color=color, linewidth=2, markersize=8, label=label)
end

# Radial summary.
fig = Figure(; size=(700, 450))
ax = summary_axis(fig[1, 1]; ylabel="Share (%)", title="Radial attraction")
summary_lines!(
    ax,
    100 .* [r.cluster_area for r in radial_results],
    CLUSTER_COLOR;
    label="Area with a cluster tree as source",
)
summary_lines!(
    ax, 100 .* [r.untargeted_share for r in radial_results], SCATTERED_COLOR;
    label="Scattered trees not targeted (source of no other cell)",
)
ylims!(ax, 0, 100)
axislegend(ax; position=:lt, framevisible=false)
save_figure(OUT_DIR, "radial_summary", fig; png=true)

# ---------------------------------------------------------------------------
# Console summary

println("Cluster trees: ", length(CLUSTER_TREES), ", scattered trees: ", length(SCATTERED_TREES))
for r in radial_results
    println(
        h_label(r.half_distance), ": ",
        "cluster reach over a lone tree ", round(r.half_distance * log2(25); digits=0), " m, ",
        "cluster area ", round(100 * r.cluster_area; digits=1), " %, ",
        "untargeted scattered trees ", round(100 * r.untargeted_share; digits=1), " %",
    )
end
