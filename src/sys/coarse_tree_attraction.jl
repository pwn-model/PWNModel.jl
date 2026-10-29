# CoarseTreeAttraction computes one attraction field like TreeAttraction,
# but on a coarse grid of cell_size meters instead of the world's base tree
# grid. It computes healthy- or damaged-tree attraction, never both: add it
# to the scheduler twice, once with damaged_trees=false and once true, to
# get both fields. Mirrors the sibling Go implementation's
# `sys.CoarseTreeAttraction`.
#
# Instead of TreeAttraction's per-source sliding-window density, each coarse
# cell is seeded with its own occupancy fraction -- the number of matching
# trees in it, divided by the number of base grid cells in a coarse cell --
# raised to density_weight. Cells without a matching tree are seeded with 0.
# The seeds are then propagated outward by propagate_attraction!, exactly as
# in TreeAttraction.
#
# If the world size is not a multiple of cell_size, the coarse grid is
# rounded up. The partial cells along the right/bottom edge are normalized
# like all others, so they can't reach an occupancy of 1 -- just as
# TreeAttraction normalizes by its full density window, even where that
# window is clipped by the world's edge.
mutable struct CoarseTreeAttraction <: System
    # tick_of_year when tree attraction is calculated.
    const tick_of_year::Int

    # damaged_trees selects which trees this instance computes attraction
    # from and which resource it publishes to: false uses healthy trees and
    # publishes HealthyTreeAttractionCoarse, true uses damaged trees and
    # publishes DamagedTreeAttractionCoarse.
    const damaged_trees::Bool

    # cell_size is the coarse grid's cell size, in meters. Must be a
    # multiple of the world's base cell size.
    const cell_size::Int

    # half_distance is the distance, in meters, at which a source's
    # contribution has decayed to half its value at the source cell. See
    # TreeAttraction's half_distance; here, a step is one coarse cell.
    const half_distance::Float64

    # density_weight is the exponent applied to a coarse cell's occupancy
    # fraction (always in (0, 1] for cells with at least one matching tree)
    # to get its seed: 0 seeds every occupied cell at 1, 1 makes the seed
    # scale linearly with occupancy, and >1 favours dense cells
    # disproportionately. As with TreeAttraction, the whole resulting field
    # stays within [0, 1].
    const density_weight::Float64

    # _factor is the number of base grid cells per coarse cell along each
    # axis, i.e. cell_size divided by the world's base cell size.
    _factor::Int

    _attraction::Grid{Float64}

    _filter::Filter

    function CoarseTreeAttraction(
        tick_of_year::Int, damaged_trees::Bool, cell_size::Int, half_distance::Float64, density_weight::Float64,
    )
        return new(tick_of_year, damaged_trees, cell_size, half_distance, density_weight, 0, Grid(0, 0, 1, 0.0))
    end
end

CoarseTreeAttraction(;
    tick_of_year::Int, damaged_trees::Bool, cell_size::Int, half_distance::Float64, density_weight::Float64,
) = CoarseTreeAttraction(tick_of_year, damaged_trees, cell_size, half_distance, density_weight)

function initialize!(s::CoarseTreeAttraction, w::World)
    ws = get_resource(w, WorldSize)
    if s.cell_size <= 0 || s.cell_size % ws.cell_size != 0
        throw(
            ArgumentError(
                "cell_size of CoarseTreeAttraction must be a positive multiple of the world's base cell size.",
            ),
        )
    end
    s._factor = s.cell_size ÷ ws.cell_size

    width = cld(ws.width, s._factor)
    height = cld(ws.height, s._factor)
    s._attraction = Grid(width, height, s.cell_size, 0.0)
    if s.damaged_trees
        add_resource!(w, DamagedTreeAttractionCoarse(s._attraction))
    else
        add_resource!(w, HealthyTreeAttractionCoarse(s._attraction))
    end

    s._filter = if s.damaged_trees
        Filter(w, (Position,); with=(Damaged,))
    else
        Filter(w, (Position,); without=(Damaged,))
    end
end

function update!(s::CoarseTreeAttraction, w::World)
    toy = get_resource(w, Time).tick_of_year

    if toy != s.tick_of_year
        return
    end

    calc_attraction!(s)
end

function calc_attraction!(s::CoarseTreeAttraction)
    fill_from_query!(s, s._attraction, s._filter)
    propagate_attraction!(s._attraction, s.half_distance)
end

# fill_from_query! seeds the coarse attraction grid: every coarse cell is
# set to its occupancy fraction (matching tree count divided by max_count)
# raised to density_weight, or to 0 if it holds no matching tree.
# propagate_attraction! then propagates these seeds outward.
function fill_from_query!(s::CoarseTreeAttraction, grid::Grid{Float64}, filt::Filter)
    fill!(grid, 0.0)

    f = s._factor
    max_count = Float64(f * f)

    for (_, positions) in Query(filt)
        for pos in positions
            cx, cy = fld(pos.x - 1, f) + 1, fld(pos.y - 1, f) + 1
            grid[cx, cy] += 1.0
        end
    end

    for x in 1:(grid.width), y in 1:(grid.height)
        count = grid[x, y]
        if count == 0
            continue
        end
        grid[x, y] = (count / max_count)^s.density_weight
    end
end
