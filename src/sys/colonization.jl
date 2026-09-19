
# KernelOffset is one pre-computed weighted offset of a dispersal kernel,
# relative to its source cell.
struct KernelOffset
    dx::Int
    dy::Int
    weight::Float64
end

# build_kernel pre-computes a truncated, radially symmetric dispersal kernel
# as a flat list of (offset, weight) pairs, so that per-tick spread only
# needs cheap integer offset lookups instead of a distance calculation per
# cell pair.
#
# Weights are normalized to sum to 1, so the kernel is a proper dispersal
# probability distribution: splatting a fixed number of emerging beetles
# through it conserves beetle count (up to grid-edge losses) instead of
# scaling with the kernel's arbitrary peak.
#
# The negative-exponential decay below is a placeholder for a "simple"
# dispersal kernel; swap the weight formula for whatever shape the model
# needs (Gaussian, power-law, ...) without touching the convolution logic
# in calc_arrivals!.
function build_kernel(radius::Int, scale::Float64)
    offsets = KernelOffset[]
    sizehint!(offsets, (2radius + 1)^2)
    total = 0.0
    for dy in (-radius):radius, dx in (-radius):radius
        d = hypot(dx, dy)
        if d > radius
            continue
        end
        w = exp(-d / scale)
        push!(offsets, KernelOffset(dx, dy, w))
        total += w
    end
    return [KernelOffset(o.dx, o.dy, o.weight / total) for o in offsets]
end

# Colonization is the background beetle spread process.
mutable struct Colonization <: System
    const tick_of_year::Int

    # kernel_radius is the dispersal kernel's cutoff radius, in space-grid cells.
    const kernel_radius::Int
    # kernel_scale is the dispersal kernel's decay length, in space-grid cells.
    const kernel_scale::Float64
    # beetles_per_tree is the fixed number of beetles emerging from each
    # colonized tree per year.
    const beetles_per_tree::Float64
    # trees_per_beetle is the mean number of distinct (uniformly random)
    # damaged trees within a cell that a single arriving beetle attempts
    # to colonize.
    const trees_per_beetle::Float64

    _density::Grid{Int}
    _susceptible::Grid{Int}
    _arrivals::Grid{Float64}
    _probability::Grid{Float64}

    _kernel::Vector{KernelOffset}

    _to_colonize::Vector{Entity}
end

function Colonization(;
    tick_of_year::Int,
    kernel_radius::Int,
    kernel_scale::Float64,
    beetles_per_tree::Float64,
    trees_per_beetle::Float64,
)
    return Colonization(
        tick_of_year, kernel_radius, kernel_scale, beetles_per_tree, trees_per_beetle,
        Grid(0, 0, 1, 0), Grid(0, 0, 1, 0), Grid(0, 0, 1, 0.0), Grid(0, 0, 1, 0.0),
        KernelOffset[], Entity[],
    )
end

function initialize!(s::Colonization, w::World)
    space = get_resource(w, SpaceGrid)

    s._density = Grid(space.grid.width, space.grid.height, space.grid.cell_size, 0)
    s._susceptible = Grid(space.grid.width, space.grid.height, space.grid.cell_size, 0)
    s._arrivals = Grid(space.grid.width, space.grid.height, space.grid.cell_size, 0.0)
    s._probability = Grid(space.grid.width, space.grid.height, space.grid.cell_size, 0.0)

    s._kernel = build_kernel(s.kernel_radius, s.kernel_scale)
end

function update!(s::Colonization, w::World)
    toy = get_resource(w, Time).tick_of_year

    if toy != s.tick_of_year
        return
    end

    ws = get_resource(w, WorldSize)
    rng = get_resource(w, Rng)

    fill!(s._density, 0)
    fill!(s._susceptible, 0)
    fill!(s._arrivals, 0.0)
    # s._probability is intentionally *not* reset here: every cell that
    # still has >=1 susceptible tree gets a fresh value from
    # calc_probability! below before it is read again this same tick, and
    # a cell with none is never read, so stale values from a previous
    # tick can never matter.

    for (_, positions) in Query(w, (Position,); with=(Colonized,))
        for pos in positions
            x, y = to_coords(ws, pos.x, pos.y)
            s._density[x, y] += 1
        end
    end

    # The beetles that emerged from a source tree have flown out to lay
    # their eggs elsewhere, so the source tree empties out and becomes
    # available for colonization again.
    remove_components!(w, Filter(w, (Colonized,)), (Colonized,))

    for (_, positions) in Query(w, (Position,); with=(Damaged,), without=(Colonized,))
        for pos in positions
            x, y = to_coords(ws, pos.x, pos.y)
            s._susceptible[x, y] += 1
        end
    end

    calc_arrivals!(s)
    calc_probability!(s)

    for (entities, positions) in Query(w, (Position,); with=(Damaged,), without=(Colonized,))
        for i in eachindex(entities)
            x, y = to_coords(ws, positions[i].x, positions[i].y)
            p = s._probability[x, y]
            if rand(rng) < p
                push!(s._to_colonize, entities[i])
            end
        end
    end

    for e in s._to_colonize
        add_components!(w, e, (Colonized(),))
    end
    empty!(s._to_colonize)
end

# calc_arrivals! applies the pre-normalized dispersal kernel to the density
# grid, computing the deterministic expected number of arriving beetles per
# cell (a fractional value, not a stochastic draw): each colonized tree
# emits a fixed beetles_per_tree, split across its neighborhood according
# to the kernel's (normalized) weights.
#
# Rather than looping over every target cell and gathering contributions
# from the whole kernel window (O(cells * kernel_area)), this "splats" each
# occupied source cell's contribution onto its neighborhood
# (O(colonized_cells * kernel_area)). That is far cheaper whenever
# colonized cells are a small fraction of the grid, which is the usual case
# for a spreading infestation, and never worse than the gather approach.
function calc_arrivals!(s::Colonization)
    w, h = s._density.width, s._density.height

    for x in 1:w, y in 1:h
        v = s._density[x, y]
        if v == 0
            continue
        end
        emitted = v * s.beetles_per_tree
        for k in s._kernel
            nx, ny = x + k.dx, y + k.dy
            if nx < 1 || nx > w || ny < 1 || ny > h
                continue
            end
            s._arrivals[nx, ny] += emitted * k.weight
        end
    end
end

# calc_probability! converts expected beetle arrivals into a per-tree
# colonization probability for each cell, capping colonization by the
# finite supply of arriving beetles competing for the cell's susceptible
# trees, rather than treating each susceptible tree as an independent,
# unbounded Bernoulli trial.
#
# Each arriving beetle is assumed to make trees_per_beetle independent,
# uniformly random attempts among the damaged trees within its own landing
# cell (approximating multi-tree oviposition without resolving which
# individual trees within the cell are closer together). Attempts are not
# exclusive -- several can land on the same tree, matching the lack of any
# competition/exclusion mechanism between beetles. This is the classic
# occupancy ("balls into bins") problem: the probability that a given tree
# receives at least one attempt out of n independent draws among m equally
# likely trees is 1 - (1 - 1/m)^n. It's computed here via log1p/expm1 for
# numerical stability at large m or n.
function calc_probability!(s::Colonization)
    w, h = s._arrivals.width, s._arrivals.height

    for x in 1:w, y in 1:h
        m = s._susceptible[x, y]
        if m == 0
            continue
        end
        n = s._arrivals[x, y] * s.trees_per_beetle
        p = -expm1(n * log1p(-1 / m))
        s._probability[x, y] = p
    end
end
