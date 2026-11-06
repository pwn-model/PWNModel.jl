# Attraction half distance: how does `half_distance` of the attraction
# kernel affect the dominance of tree clusters over scattered trees, for
# radial attraction (TreeAttraction) and for the octant selection
# probabilities of octant attraction (TreeAttractionOctants)? See README.md.
#
# Run from the PWNModel.jl/ directory:
#   julia --project=explore explore/attraction_half_distance/run.jl

using Ark
using CairoMakie
using PWNModel
using Random
using Statistics

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

# Distance in meters from cell (x, y) to the edge of the nearest cluster.
cluster_distance(x, y) =
    minimum(c -> (hypot(x - c.center[1], y - c.center[2]) - c.radius) * CELL_SIZE, CLUSTERS)

# Distance in meters from cell (x, y) to the world's border.
border_distance(x, y) = (min(x, y, NX - x + 1, NY - y + 1) - 0.5) * CELL_SIZE

# Trees closer than this to the world's border are excluded from the
# summaries of octant selection, as they lack sources in some directions.
const SUMMARY_BORDER = 200.0

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

# Selection probabilities of the 8 octants of an OctantSources record, and
# whether each octant's source is a cluster tree. Empty octants have
# probability 0. All probabilities are NaN if no octant has a source.
function octant_probabilities(r::OctantSources, x, y)
    a = Float64.(collect(r.attraction))
    p = a ./ sum(a)
    cluster = [a[k] > 0 && IS_CLUSTER[x+Int(r.offsets[k][1]), y+Int(r.offsets[k][2])] for k in 1:8]
    return p, cluster
end

# Effective number of octants: exp of the entropy of the selection probabilities, from 1 to 8.
effective_octants(p) = exp(-sum(q * log(q) for q in p if q > 0; init=0.0))

# Octant attraction: for each cell, the probability of selecting an octant
# whose source is a cluster tree, and the effective number of octants.
function octants(h)
    world = attraction(TreeAttractionOctants(; attraction_kwargs(h)...))
    sources = get_resource(world, HealthyTreeAttractionOctants).sources

    cluster_probability = fill(NaN, NX, NY)
    effective = fill(NaN, NX, NY)
    for x in 1:NX, y in 1:NY
        p, cluster = octant_probabilities(sources[x, y], x, y)
        any(isnan, p) && continue
        cluster_probability[x, y] = sum(p[cluster]; init=0.0)
        effective[x, y] = effective_octants(p)
    end

    # Means over the trees of each category, away from the world's border.
    inner(trees) = [p for p in trees if border_distance(p.x, p.y) >= SUMMARY_BORDER]
    mean_over(grid, trees) = mean(grid[p.x, p.y] for p in inner(trees))
    return (;
        half_distance=h,
        sources,
        cluster_probability,
        effective,
        scattered_cluster_probability=mean_over(cluster_probability, SCATTERED_TREES),
        cluster_cluster_probability=mean_over(cluster_probability, CLUSTER_TREES),
        scattered_effective=mean_over(effective, SCATTERED_TREES),
        cluster_effective=mean_over(effective, CLUSTER_TREES),
    )
end

radial_results = [radial(h) for h in HALF_DISTANCES]
octant_results = [octants(h) for h in HALF_DISTANCES]

# ---------------------------------------------------------------------------
# Example trees for the octant roses

# A scattered tree is lone if there is no other tree within density_radius,
# i.e. its occupancy is minimal.
const TREE_SET = Set((p.x, p.y) for p in [CLUSTER_TREES; SCATTERED_TREES])
const R_CELLS = DENSITY_RADIUS ÷ CELL_SIZE
is_lone(p) = count(
    (p.x + dx, p.y + dy) in TREE_SET for dx in (-R_CELLS):R_CELLS, dy in (-R_CELLS):R_CELLS
) == 1

const ROSE_BORDER = 400.0
const LONE_CANDIDATES =
    [p for p in SCATTERED_TREES if is_lone(p) && border_distance(p.x, p.y) >= ROSE_BORDER]

const EXAMPLES = let
    far = argmax(p -> cluster_distance(p.x, p.y), LONE_CANDIDATES)
    near = argmin(p -> abs(cluster_distance(p.x, p.y) - 100.0), LONE_CANDIDATES)
    c = CLUSTERS[2]
    edge = Position(c.center[1] - c.radius, c.center[2])
    [
        (title="Lone tree far from clusters", position=far),
        (title="Lone tree near a cluster", position=near),
        (title="Tree at a cluster edge", position=edge),
    ]
end

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

# Draws cluster outlines and scattered trees over a map.
function draw_trees!(ax; untargeted=nothing)
    lines!(ax, cluster_outlines(); color=:black, linewidth=1)
    if untargeted === nothing
        scatter!(ax, points(SCATTERED_TREES); color=:black, markersize=2.5)
    else
        set = Set(untargeted)
        targeted = [p for p in SCATTERED_TREES if !(p in set)]
        scatter!(ax, points(targeted); color=:black, markersize=3)
        scatter!(ax, points(untargeted); color=:transparent, strokecolor=:black, strokewidth=0.8, markersize=6)
    end
end

# Grid of map panels, one per half distance, in 2 rows x 3 columns. The
# last slot is passed to `extra` (e.g. for a legend or colorbar).
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

# Octant maps: probability of selecting a cluster tree, and effective number of octants.
const PROBABILITY_COLORMAP = cgrad(["#ffffff", CLUSTER_COLOR, "#0d3366"])
const EFFECTIVE_COLORMAP = cgrad(["#ffffff", "#8a6fc4", "#3b1f73"])

function plot_octant_maps()
    for (name, field, colormap, colorrange, label) in (
        (
            "octant_cluster_probability",
            :cluster_probability,
            PROBABILITY_COLORMAP,
            (0, 1),
            "Probability of selecting a cluster tree",
        ),
        ("octant_effective_number", :effective, EFFECTIVE_COLORMAP, (1, 8), "Effective number of octants"),
    )
        hm = nothing
        map_panels(
            (ax, i) -> begin
                hm = heatmap!(
                    ax, grid_axes(octant_results[i].sources)..., getfield(octant_results[i], field);
                    colormap=colormap, colorrange=colorrange, rasterize=2,
                )
                draw_trees!(ax)
            end,
            pos -> Colorbar(pos[1, 1], hm; label=label, vertical=false, width=Relative(0.8), tellheight=false),
            name,
        )
    end
end
plot_octant_maps()

# Octant roses: per example tree, a local map and the 8 octant selection
# probabilities for each half distance, colored by the category of the
# octant's source. Wedge areas are proportional to probabilities, i.e. the
# radius is the square root of the probability.
const ROSE_MAP_RADIUS = 300.0

function draw_rose!(ax, p, cluster)
    for r in sqrt.((0.1, 0.25, 0.5, 1.0))
        lines!(ax, [Point2f(r * cos(t), r * sin(t)) for t in range(0, 2pi; length=97)]; color=:gray80, linewidth=0.75)
    end
    for k in 0:3
        t = k * pi / 4
        lines!(ax, [Point2f(-cos(t), -sin(t)), Point2f(cos(t), sin(t))]; color=:gray80, linewidth=0.75)
    end
    for k in 1:8
        p[k] > 0 || continue
        ts = range((k - 1) * pi / 4, k * pi / 4; length=16)
        r = sqrt(p[k])
        wedge = [[Point2f(0, 0)]; [Point2f(r * cos(t), r * sin(t)) for t in ts]]
        poly!(ax, wedge; color=cluster[k] ? CLUSTER_COLOR : SCATTERED_COLOR, strokecolor=:white, strokewidth=1)
    end
    limits!(ax, -1.05, 1.05, -1.05, 1.05)
    hidedecorations!(ax)
    hidespines!(ax)
end

function plot_roses()
    fig = Figure(; size=(1500, 820))
    map_world = attraction(TreeAttraction(; attraction_kwargs(DEFAULT_HALF_DISTANCE)...))
    for (row, ex) in enumerate(EXAMPLES)
        p = ex.position
        cx, cy = cell_center(p.x, p.y, CELL_SIZE)
        xlims, ylims = (cx - ROSE_MAP_RADIUS, cx + ROSE_MAP_RADIUS), (cy - ROSE_MAP_RADIUS, cy + ROSE_MAP_RADIUS)
        ax = Axis(fig[row, 1]; title=ex.title, aspect=DataAspect())
        hidedecorations!(ax)
        image!(ax, tree_image(map_world; xlims=xlims, ylims=ylims)...; interpolate=false, rasterize=2)
        for k in 0:3
            t = k * pi / 4
            d = 2 * ROSE_MAP_RADIUS
            lines!(ax, [Point2f(cx - d * cos(t), cy - d * sin(t)), Point2f(cx + d * cos(t), cy + d * sin(t))];
                color=:gray60, linewidth=0.75, linestyle=:dash)
        end
        lines!(ax, cluster_outlines(); color=:black, linewidth=1)
        scatter!(ax, [Point2f(cx, cy)]; color=:black, marker=:star5, markersize=14)
        limits!(ax, xlims..., ylims...)

        for (col, r) in enumerate(octant_results)
            probs, cluster = octant_probabilities(r.sources[p.x, p.y], p.x, p.y)
            ax = Axis(
                fig[row, col+1];
                title=row == 1 ? h_label(r.half_distance) : "",
                subtitle="effective octants: $(round(effective_octants(probs); digits=1))",
                aspect=DataAspect(),
            )
            draw_rose!(ax, probs, cluster)
        end
    end
    Legend(
        fig[length(EXAMPLES)+1, :],
        [
            PolyElement(; color=CLUSTER_COLOR),
            PolyElement(; color=SCATTERED_COLOR),
            PolyElement(; color=HEALTHY_TREE_COLOR),
            MarkerElement(; marker=:star5, color=:black, markersize=12),
        ],
        ["Octant source is a cluster tree", "Octant source is a scattered tree", "Trees", "Example tree"];
        orientation=:horizontal, framevisible=false,
    )
    save_figure(OUT_DIR, "octant_roses", fig; png=true)
end
plot_roses()

# Octant summary: means over scattered trees and over cluster trees, in two panels.
fig = Figure(; size=(1100, 500))
ax1 = summary_axis(fig[1, 1]; ylabel="Probability", title="Probability of selecting a cluster tree")
summary_lines!(
    ax1,
    [r.scattered_cluster_probability for r in octant_results],
    SCATTERED_COLOR;
    label="From scattered trees",
)
summary_lines!(ax1, [r.cluster_cluster_probability for r in octant_results], CLUSTER_COLOR; label="From cluster trees")
ylims!(ax1, 0, 1)
ax2 = summary_axis(fig[1, 2]; ylabel="Effective number of octants", title="Spread of octant selection")
summary_lines!(ax2, [r.scattered_effective for r in octant_results], SCATTERED_COLOR; label="From scattered trees")
summary_lines!(ax2, [r.cluster_effective for r in octant_results], CLUSTER_COLOR; label="From cluster trees")
ylims!(ax2, 1, 8)
Legend(fig[2, 1:2], ax1; orientation=:horizontal, framevisible=false)
save_figure(OUT_DIR, "octant_summary", fig; png=true)

# ---------------------------------------------------------------------------
# Console summary

println("Cluster trees: ", length(CLUSTER_TREES), ", scattered trees: ", length(SCATTERED_TREES))
for ex in EXAMPLES
    p = ex.position
    println(
        ex.title,
        ": cell ",
        (p.x, p.y),
        ", ",
        round(cluster_distance(p.x, p.y)),
        " m from the nearest cluster edge",
    )
end
for (r, o) in zip(radial_results, octant_results)
    println(
        h_label(r.half_distance), ": ",
        "cluster reach over a lone tree ", round(r.half_distance * log2(25); digits=0), " m, ",
        "cluster area ", round(100 * r.cluster_area; digits=1), " %, ",
        "untargeted scattered trees ", round(100 * r.untargeted_share; digits=1), " %, ",
        "P(cluster) from scattered trees ", round(o.scattered_cluster_probability; digits=2), ", ",
        "effective octants from scattered trees ", round(o.scattered_effective; digits=1),
        " / from cluster trees ", round(o.cluster_effective; digits=1),
    )
end
