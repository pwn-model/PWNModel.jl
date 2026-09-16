
# RandomInfection infects the given number of trees in the given grid cell.
#
# Selection uses Julia's default `Random.shuffle!` on a plain `Vector{Entity}`
# collected from the query. This deliberately does not attempt to reproduce
# the exact same shuffle algorithm as the sibling Go implementation (which
# uses `math/rand/v2`'s `Rand.Shuffle`, based on Lemire's method): the two
# languages' bounded-integer sampling from a raw RNG stream differ, so a
# from-scratch reimplementation would be needed for bit-identical selection.
# Given the same seed, both implementations infect the same *number* of
# trees in the same cell, but not necessarily the same trees.
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

    Random.shuffle!(rng.xoshiro, to_infect)

    n = min(length(to_infect), s.num_trees)
    for e in view(to_infect, 1:n)
        add_components!(w, e, (NematodeInfected(tick),))
    end
end
