# Attraction field: how does the attraction field of TreeAttraction look
# around a single tree and a small forest, and where do their fields meet?
# See README.md.
#
# Run from the PWNModel.jl/ directory:
#   julia --project=explore explore/attraction_field/run.jl

using Ark
using CairoMakie
using PWNModel

include("../common/world.jl")
include("../common/plotting.jl")

const OUT_DIR = joinpath(@__DIR__, "out")

# Landscape: a single tree and a round, fully stocked forest, both centered
# on the transect row. Positions are in cells of 10 m.
const WIDTH, HEIGHT, CELL_SIZE = 1000, 400, 10
const TRANSECT_Y = 20
const TREE = Position(30, TRANSECT_Y)
const FOREST_CENTER = Position(70, TRANSECT_Y)
const FOREST_RADIUS = 6

const FOREST = [
    Position(x, y) for x in 1:(WIDTH÷CELL_SIZE), y in 1:(HEIGHT÷CELL_SIZE) if
    (x - FOREST_CENTER.x)^2 + (y - FOREST_CENTER.y)^2 <= FOREST_RADIUS^2
]

# Values of density_weight to compare.
const DENSITY_WEIGHTS = [0.0, 1.0, 2.0]

# Computes the healthy-tree attraction field for the given trees. Returns the world.
function attraction(trees, density_weight)
    world = new_world(; seed=1, width=WIDTH, height=HEIGHT, cell_size=CELL_SIZE)
    systems = (
        InitGrids(),
        PlaceTrees(; positions=trees),
        UpdateTime(; ticks_per_year=52),
        TreeAttraction(;
            tick_of_year=0, damaged_trees=false, half_distance=50.0, density_radius=20,
            density_weight=density_weight,
        ),
    )
    run!(Scheduler(world, systems), 1)
    return world
end

field(world) = get_resource(world, HealthyTreeAttraction).grid

# For each density weight: the field of the whole landscape, and of the tree and the forest alone.
results = [
    (;
        density_weight=w,
        world=attraction([TREE; FOREST], w),
        tree=field(attraction([TREE], w)),
        forest=field(attraction(FOREST, w)),
    ) for w in DENSITY_WEIGHTS
]

# ---------------------------------------------------------------------------
# Plots

transect(grid) = [grid[x, TRANSECT_Y] for x in 1:grid.width]
xs = ((1:(WIDTH÷CELL_SIZE)) .- 0.5) .* CELL_SIZE
transect_y = (TRANSECT_Y - 0.5) * CELL_SIZE
tree_x = (TREE.x - 0.5) * CELL_SIZE
forest_x = ((FOREST_CENTER.x - FOREST_RADIUS - 1) * CELL_SIZE, (FOREST_CENTER.x + FOREST_RADIUS) * CELL_SIZE)

# Position along the transect where the forest's field takes over from the tree's.
# NaN if the forest's field dominates even at the tree.
function meeting_point(r)
    t, f = transect(r.tree), transect(r.forest)
    f[TREE.x] >= t[TREE.x] && return NaN
    x = findfirst(x -> f[x] >= t[x], TREE.x:FOREST_CENTER.x)
    return xs[TREE.x+x-1]
end

# Maps of the field, one per density weight, with the transect.
fig = Figure(; size=(1000, 1000))
for (i, r) in enumerate(results)
    ax = Axis(
        fig[i, 1];
        title="density_weight = $(r.density_weight)",
        ylabel="y (m)", xlabel=i == length(results) ? "x (m)" : "", aspect=DataAspect(),
    )
    grid = field(r.world)
    hm = heatmap!(
        ax, grid_axes(grid)..., log10.(grid_matrix(grid));
        colormap=:viridis, colorrange=(-4, 0), rasterize=2,
    )
    image!(ax, tree_image(r.world; xlims=(0, WIDTH), ylims=(0, HEIGHT))...; interpolate=false, rasterize=2)
    hlines!(ax, [transect_y]; color=:black, linestyle=:dash, linewidth=1)
    # Where the fields of the tree and the forest meet: equal values.
    ratio = log10.(grid_matrix(r.tree)) .- log10.(grid_matrix(r.forest))
    contour!(ax, grid_axes(grid)..., ratio; levels=[0.0], color=SERIES_COLORS[2], linewidth=1.5)
    limits!(ax, 0, WIDTH, 0, HEIGHT)
    i == 1 && Colorbar(fig[1:length(results), 2], hm; label="log₁₀ attraction")
end
save_figure(OUT_DIR, "field_maps", fig; png=true)

# Cross-sections along the transect, one panel per density weight.
fig = Figure(; size=(1000, 900))
for (i, r) in enumerate(results)
    ax = Axis(
        fig[i, 1];
        title="density_weight = $(r.density_weight)",
        xlabel=i == length(results) ? "x (m)" : "", ylabel="Attraction",
        yscale=log10,
    )
    vspan!(ax, [forest_x[1]], [forest_x[2]]; color=(HEALTHY_TREE_COLOR, 0.6))
    vlines!(ax, [tree_x]; color=HEALTHY_TREE_COLOR, linewidth=4)
    lines!(ax, xs, transect(r.tree); color=SERIES_COLORS[1], linestyle=:dash, linewidth=1.5)
    lines!(ax, xs, transect(r.forest); color=SERIES_COLORS[3], linestyle=:dash, linewidth=1.5)
    lines!(ax, xs, transect(field(r.world)); color=:black, linewidth=2)
    isnan(meeting_point(r)) || vlines!(ax, [meeting_point(r)]; color=SERIES_COLORS[2], linewidth=1.5)
    xlims!(ax, 0, WIDTH)
    ylims!(ax, 1e-7, 2)
    i == length(results) || hidexdecorations!(ax; grid=false)
end
Legend(
    fig[length(results)+1, 1],
    [
        LineElement(; color=:black, linewidth=2),
        LineElement(; color=SERIES_COLORS[1], linestyle=:dash, linewidth=1.5),
        LineElement(; color=SERIES_COLORS[3], linestyle=:dash, linewidth=1.5),
        LineElement(; color=SERIES_COLORS[2], linewidth=1.5),
        PolyElement(; color=HEALTHY_TREE_COLOR),
    ],
    ["Tree and forest", "Single tree only", "Forest only", "Fields meet", "Trees"];
    orientation=:horizontal, framevisible=false,
)
save_figure(OUT_DIR, "cross_sections", fig; png=true)

for r in results
    x = meeting_point(r)
    println(
        "density_weight = ", r.density_weight, ": ",
        isnan(x) ? "the forest's field dominates everywhere" : "fields meet at x = $x m",
    )
end
