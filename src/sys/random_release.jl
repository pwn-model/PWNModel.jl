
# RandomRelease infects the given number of trees in the given grid cell.
#
# Selection uses frozen_shuffle! (see src/util/shuffle.jl) rather than
# Random.shuffle!, so that tree selection is bit-identical with the sibling
# Go implementation's util.Shuffle for the same seed.
Base.@kwdef struct RandomRelease <: System
    # tick_of_infection is the model tick at which trees are infected.
    tick_of_infection::Int
    # num_trees is the number of trees to infect. Capped at the number of
    # undamaged, uninfected trees in the cell.
    num_trees::Int
    # cell_x and cell_y are the 0-based column and row of the release cell
    # in the coarse SpaceGrid (cells of WorldSize's grid_cell_size meters),
    # counted from the world origin. E.g. with grid_cell_size 500, cell
    # (2, 1) covers x in [1000, 1500) and y in [500, 1000) meters.
    #
    # Unlike Julia's own 1-based array indexing (space.grid is indexed at
    # [cell_x+1, cell_y+1]), this matches the sibling Go implementation, so
    # that the same config file selects the same cell in both.
    cell_x::Int
    cell_y::Int
end

function update!(s::RandomRelease, w::World)
    tick = get_resource(w, Time).tick

    if tick != s.tick_of_infection
        return
    end

    space = get_resource(w, SpaceGrid)
    cell = space.grid[s.cell_x+1, s.cell_y+1]
    rng = get_resource(w, Rng)

    to_infect = Entity[]
    for (entities, _) in Query(w, (Position, InCell => cell); without=(Damaged, Infected))
        append!(to_infect, entities)
    end

    frozen_shuffle!(rng.xoshiro, to_infect)

    n = min(length(to_infect), s.num_trees)
    for e in view(to_infect, 1:n)
        add_components!(w, e, (Infected(tick),))
    end
end
