
# RandomRelease infects the given number of trees,
# randomly selected from all over the simulation area.
#
# Selection uses frozen_shuffle! (see src/util/shuffle.jl) rather than
# Random.shuffle!, so that tree selection is bit-identical with the sibling
# Go implementation's util.Shuffle for the same seed.
Base.@kwdef struct RandomRelease <: System
    # tick_of_infection is the model tick at which trees are infected.
    tick_of_infection::Int
    # num_trees is the number of trees to infect. Capped at the number of
    # undamaged, uninfected trees.
    num_trees::Int
end

function update!(s::RandomRelease, w::World)
    tick = get_resource(w, Time).tick

    if tick != s.tick_of_infection
        return
    end

    rng = get_resource(w, Rng)

    query = Query(w, (Position,); without=(Damaged, Infected))
    to_infect = Entity[]
    sizehint!(to_infect, count_entities(query))
    for (entities, _) in query
        append!(to_infect, entities)
    end

    frozen_shuffle!(rng.xoshiro, to_infect)

    n = min(length(to_infect), s.num_trees)
    for e in view(to_infect, 1:n)
        add_components!(w, e, (Infected(tick),))
    end
end
