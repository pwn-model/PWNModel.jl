# TreeAttraction computes four attraction fields -- healthy/damaged trees,
# each at near/far range -- meant to bias where dispersing beetles fly.
# Mirrors the sibling Go implementation's `sys.TreeAttraction`.
mutable struct TreeAttraction <: System
    # tick_of_year when tree attraction is calculated.
    const tick_of_year::Int
    # radius_near is the radius of the near attraction field around each
    # source tree, in meters. Must be a multiple of the world's base cell size.
    const radius_near::Int
    # radius_far is the radius of the far attraction field around each
    # source tree, in meters. Must be a multiple of radius_near.
    const radius_far::Int

    # _units_per_cell is the number of tree-grid units per far-field
    # dispersal-grid cell, i.e. radius_near expressed in the world's base
    # cell-size units.
    _units_per_cell::Int

    _healthy_near::Grid{Float64}
    _damaged_near::Grid{Float64}
    _healthy_far::Grid{Float64}
    _damaged_far::Grid{Float64}

    _filter_healthy::Filter
    _filter_damaged::Filter

    function TreeAttraction(tick_of_year::Int, radius_near::Int, radius_far::Int)
        return new(
            tick_of_year, radius_near, radius_far, 1,
            Grid(0, 0, 1, 0.0), Grid(0, 0, 1, 0.0), Grid(0, 0, 1, 0.0), Grid(0, 0, 1, 0.0),
        )
    end
end

TreeAttraction(; tick_of_year::Int, radius_near::Int, radius_far::Int) =
    TreeAttraction(tick_of_year, radius_near, radius_far)

function initialize!(s::TreeAttraction, w::World)
    ws = get_resource(w, WorldSize)
    if s.radius_near % ws.cell_size != 0
        throw(ArgumentError("radius_near of the dispersal submodel must be a multiple of the world's base cell size."))
    end
    if s.radius_far % s.radius_near != 0
        throw(ArgumentError("radius_far of the dispersal submodel must be a multiple of radius_near."))
    end

    s._healthy_near = Grid(ws.width, ws.height, ws.cell_size, 0.0)
    s._damaged_near = Grid(ws.width, ws.height, ws.cell_size, 0.0)
    add_resource!(w, HealthyTreeAttractionNear(s._healthy_near))
    add_resource!(w, DamagedTreeAttractionNear(s._damaged_near))

    s._units_per_cell = s.radius_near ÷ ws.cell_size
    width, height = cld(ws.width, s._units_per_cell), cld(ws.height, s._units_per_cell)
    s._healthy_far = Grid(width, height, s.radius_near, 0.0)
    s._damaged_far = Grid(width, height, s.radius_near, 0.0)
    add_resource!(w, HealthyTreeAttractionFar(s._healthy_far))
    add_resource!(w, DamagedTreeAttractionFar(s._damaged_far))

    s._filter_healthy = Filter(w, (Position,); without=(Damaged,))
    s._filter_damaged = Filter(w, (Position,); with=(Damaged,))
end

function update!(s::TreeAttraction, w::World)
    toy = get_resource(w, Time).tick_of_year

    if toy != s.tick_of_year
        return
    end

    calc_attraction!(s)
end

function calc_attraction!(s::TreeAttraction)
    fill_from_query!(s, s._healthy_near, s._filter_healthy, 1, Float64(s.radius_near ÷ s._healthy_near.cell_size))
    fill_from_query!(s, s._damaged_near, s._filter_damaged, 1, Float64(s.radius_near ÷ s._damaged_near.cell_size))

    fill_grid!(s._healthy_near)
    fill_grid!(s._damaged_near)

    fill_from_query!(
        s, s._healthy_far, s._filter_healthy, s._units_per_cell, Float64(s.radius_far ÷ s._healthy_far.cell_size),
    )
    fill_from_query!(
        s, s._damaged_far, s._filter_damaged, s._units_per_cell, Float64(s.radius_far ÷ s._damaged_far.cell_size),
    )

    fill_grid!(s._healthy_far)
    fill_grid!(s._damaged_far)
end

# fill_from_query! seeds the attraction grid: every cell containing a
# matching tree is set to the field's peak value (the radius, in grid
# cells), everything else to 0. fill_grid! then propagates these peaks
# outward.
#
# Takes a pre-built Filter (see the field docstring on TreeAttraction)
# rather than `with`/`without` tuples, so that Query(filt) below hits Ark's
# fast, specialized path instead of re-deriving a filter from tuples whose
# element types aren't compile-time constants here.
function fill_from_query!(s::TreeAttraction, grid::Grid{Float64}, filt::Filter, units_per_cell::Int, peak::Float64)
    fill!(grid, 0.0)
    for (_, positions) in Query(filt)
        for pos in positions
            x, y = to_coords(s, pos.x, pos.y, units_per_cell)
            grid[x, y] = peak
        end
    end
end

# fill_grid! turns the seeded peaks into a smooth attraction field by
# propagating each source's value outward, decreasing by 1 per orthogonal
# step and sqrt(2) per diagonal step, floored at 0. This is an in-place,
# single-grid Gauss-Seidel relaxation (a discrete fast-sweeping method):
# two passes in opposite raster directions suffice, because the grid has
# no obstacles, so any shortest path from a source can be split into one
# forward-monotone and one backward-monotone segment, each fully resolved
# by one of the two passes.
function fill_grid!(grid::Grid{Float64})
    w, h = grid.width, grid.height

    # Offsets of the already-updated neighbours seen by a sweep moving in
    # increasing (forward) resp. decreasing (backward) x/y, paired with
    # their step cost.
    forward = ((-1, -1), (-1, 0), (-1, 1), (0, -1))
    backward = ((1, 1), (1, 0), (1, -1), (0, 1))
    costs = (sqrt(2.0), 1.0, sqrt(2.0), 1.0)

    function relax!(x, y, offsets)
        best = grid[x, y]
        for i in eachindex(offsets)
            dx, dy = offsets[i]
            nx, ny = x + dx, y + dy
            if nx < 1 || nx > w || ny < 1 || ny > h
                continue
            end
            v = grid[nx, ny] - costs[i]
            if v > best
                best = v
            end
        end
        grid[x, y] = max(best, 0.0)
    end

    for x in 1:w, y in 1:h
        relax!(x, y, forward)
    end
    for x in w:-1:1, y in h:-1:1
        relax!(x, y, backward)
    end
end

# to_coords calculates (1-based) attraction-grid coords from (1-based) tree grid coords.
to_coords(::TreeAttraction, x::Int, y::Int, upc::Int) = (fld(x - 1, upc) + 1, fld(y - 1, upc) + 1)
