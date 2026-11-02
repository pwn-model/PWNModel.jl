using Ark
using CairoMakie
using PWNModel

# Categorical colors, in fixed order. Use them in this order for series.
const SERIES_COLORS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300"]

const HEALTHY_TREE_COLOR = "#b3dab3"
const DAMAGED_TREE_COLOR = "#d9b48f"

# Light gray ramp for background fields, so that colored marks on top stay readable.
const FIELD_COLORMAP = cgrad(["#ffffff", "#7a7a7a"])

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
    x1, x2 = max(1, floor(Int, xlims[1] / cs) + 1), min(grid.width, ceil(Int, xlims[2] / cs))
    y1, y2 = max(1, floor(Int, ylims[1] / cs) + 1), min(grid.height, ceil(Int, ylims[2] / cs))

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
