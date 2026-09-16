
# RandomInfection infects the given number of trees in the given grid cell.
#
# Selection uses frozen_shuffle! (see src/util/shuffle.jl) rather than
# Random.shuffle!, so that tree selection is bit-identical with the sibling
# Go implementation's util.Shuffle for the same seed.
Base.@kwdef struct RandomInfection <: System
    tick_of_infection::Int
    num_trees::Int
    cell_x::Int
    cell_y::Int
end

function update!(s::RandomInfection, w::World)
    tick = get_resource(w, Tick).value

    if tick != s.tick_of_infection
        return
    end

    space = get_resource(w, SpaceGrid)
    cell = space.grid[s.cell_x, s.cell_y]
    rng = get_resource(w, Rng)

    to_infect = Entity[]
    for (entities, _) in Query(w, (Position, InCell => cell); without=(Damaged, NematodeInfected))
        append!(to_infect, entities)
    end

    frozen_shuffle!(rng.xoshiro, to_infect)

    n = min(length(to_infect), s.num_trees)
    for e in view(to_infect, 1:n)
        add_components!(w, e, (NematodeInfected(tick),))
    end
end
