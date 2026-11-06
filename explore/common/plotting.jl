using Ark
using CairoMakie
using PWNModel

# Categorical colors, in fixed order. Use them in this order for series.
const SERIES_COLORS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300"]

const HEALTHY_TREE_COLOR = "#b3dab3"
const DAMAGED_TREE_COLOR = "#d9b48f"

# Light gray ramp for background fields, so that colored marks on top stay readable.
const FIELD_COLORMAP = cgrad(["#ffffff", "#7a7a7a"])

# Many distinct colors in random-looking order, for maps of categories like attraction sources.
const SOURCE_COLORMAP = :glasbey_hv_n256

"""
    save_figure(dir, name, fig; png=false)

Saves `fig` as `<dir>/<name>.svg`, and also as a PNG if `png` is true.
Creates `dir` if missing. Heavy plot layers (e.g. maps with many cells or
points) should be drawn with `rasterize=true` to keep the SVG small.
"""
function save_figure(dir::AbstractString, name::AbstractString, fig; png::Bool=false)
    mkpath(dir)
    save(joinpath(dir, "$name.svg"), fig)
    png && save(joinpath(dir, "$name.png"), fig; px_per_unit=2)
    return nothing
end

"""
    grid_axes(grid) -> (xs, ys)

Cell center coordinates in meters along both axes of `grid`, for `heatmap!`.
"""
function grid_axes(grid::Grid)
    xs = ((1:grid.width) .- 0.5) .* grid.cell_size
    ys = ((1:grid.height) .- 0.5) .* grid.cell_size
    return xs, ys
end

"""
    grid_matrix(grid) -> Matrix

Values of `grid` as a matrix indexed `[x, y]`, as `heatmap!` expects them.
"""
grid_matrix(grid::Grid) = permutedims(grid._values)

"""
    tree_points(world; damaged) -> Vector{Point2f}

Cell centers in meters of all healthy (`damaged=false`) resp. damaged trees.
"""
function tree_points(world::World; damaged::Bool)
    cs = get_resource(world, WorldSize).cell_size
    points = Point2f[]
    query = damaged ? Query(world, (Position,); with=(Damaged,)) : Query(world, (Position,); without=(Damaged,))
    for (_, positions) in query
        for p in positions
            push!(points, Point2f(cell_center(p.x, p.y, cs)...))
        end
    end
    return points
end

"""
    cell_bounds(grid; xlims, ylims) -> (x1, x2, y1, y2)

Range of cells `x1:x2`, `y1:y2` of `grid` covering `xlims`/`ylims` (in
meters), clipped to the grid. The covered area in meters is
`((x1 - 1) * cs, x2 * cs)` resp. `((y1 - 1) * cs, y2 * cs)`, with `cs` the
grid's cell size.
"""
function cell_bounds(grid::Grid; xlims, ylims)
    cs = grid.cell_size
    x1, x2 = max(1, floor(Int, xlims[1] / cs) + 1), min(grid.width, ceil(Int, xlims[2] / cs))
    y1, y2 = max(1, floor(Int, ylims[1] / cs) + 1), min(grid.height, ceil(Int, ylims[2] / cs))
    return x1, x2, y1, y2
end

"""
    attraction_source_image(world; damaged, xlims, ylims) -> (xrange, yrange, image)

Map of the attraction sources (see `TreeAttractionSourceMap`) of healthy
(`damaged=false`) resp. damaged trees within `xlims`/`ylims` (in meters),
with one pixel per grid cell. Values are pseudo-random in [0, 1) per source
tree, `NaN` where there is no source. Draw it with
`image!(ax, xrange, yrange, image; colormap=SOURCE_COLORMAP, colorrange=(0, 1), interpolate=false)`.
"""
function attraction_source_image(world::World; damaged::Bool, xlims, ylims)
    observer = TreeAttractionSourceMap(; damaged_trees=damaged)
    PWNModel.initialize!(observer, world)
    values = PWNModel.data(observer, world)

    grid = get_resource(world, TreeGrid).grid
    cs = grid.cell_size
    x1, x2, y1, y2 = cell_bounds(grid; xlims=xlims, ylims=ylims)
    return ((x1 - 1) * cs, x2 * cs), ((y1 - 1) * cs, y2 * cs), values[x1:x2, y1:y2]
end

"""
    octant_source_image(world; damaged, xlims, ylims) -> (xrange, yrange, image)

Like [`attraction_source_image`](@ref), but for the octant sources computed
by `TreeAttractionOctants`: each cell shows its most attractive octant
source, i.e. the tree a beetle there is most likely to select. Unlike
`TreeAttraction`'s sources, a tree's own cell is never its own source, so
tree cells show their most attractive other tree. Values are pseudo-random
in [0, 1) per source tree, the same as for `attraction_source_image`, `NaN`
where no octant has a source.
"""
function octant_source_image(world::World; damaged::Bool, xlims, ylims)
    res =
        damaged ? get_resource(world, DamagedTreeAttractionOctants) : get_resource(world, HealthyTreeAttractionOctants)
    sources = res.sources
    cs = sources.cell_size
    x1, x2, y1, y2 = cell_bounds(sources; xlims=xlims, ylims=ylims)

    image = fill(NaN, x2 - x1 + 1, y2 - y1 + 1)
    for x in x1:x2, y in y1:y2
        r = sources[x, y]
        a, k = findmax(r.attraction)
        a > 0 || continue
        ox, oy = r.offsets[k]
        image[x-x1+1, y-y1+1] = PWNModel._hash_to_unit(cell_index(sources, x + Int(ox), y + Int(oy)))
    end
    return ((x1 - 1) * cs, x2 * cs), ((y1 - 1) * cs, y2 * cs), image
end

"""
    tree_image(world; xlims, ylims) -> (xrange, yrange, image)

Bitmap of the trees within `xlims`/`ylims` (in meters), with one pixel per
grid cell: healthy and damaged trees in their colors, empty cells
transparent. The covered area is extended to whole cells, given by `xrange`
and `yrange` in meters. Draw it with
`image!(ax, xrange, yrange, image; interpolate=false)`.
"""
function tree_image(world::World; xlims, ylims)
    grid = get_resource(world, TreeGrid).grid
    cs = grid.cell_size
    x1, x2, y1, y2 = cell_bounds(grid; xlims=xlims, ylims=ylims)

    image = fill(RGBAf(0, 0, 0, 0), x2 - x1 + 1, y2 - y1 + 1)
    for (damaged, color) in ((false, HEALTHY_TREE_COLOR), (true, DAMAGED_TREE_COLOR))
        query = damaged ? Query(world, (Position,); with=(Damaged,)) : Query(world, (Position,); without=(Damaged,))
        c = to_color(color)
        for (_, positions) in query
            for p in positions
                if x1 <= p.x <= x2 && y1 <= p.y <= y2
                    image[p.x-x1+1, p.y-y1+1] = c
                end
            end
        end
    end
    return ((x1 - 1) * cs, x2 * cs), ((y1 - 1) * cs, y2 * cs), image
end
