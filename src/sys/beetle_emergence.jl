
# BeetleEmergence of beetles from nematode-infected trees.
#
# Beetle life expectancy is drawn from an exponential distribution via
# randexp(rng.xoshiro) -- the raw Xoshiro256++ source directly, not Rng's
# usual low-53-bit rand override -- so that it stays bit-identical with the
# sibling Go implementation's util.ExpFloat64 (see res/rng.jl and
# pwn/util/random.go for why exponential draws need this separate path).
Base.@kwdef struct BeetleEmergence <: System
    tick_of_year::Int
    beetles_per_tree::Int
    life_expectancy::Float64

    _source_trees::Vector{Position} = Position[]
end

function update!(s::BeetleEmergence, w::World)
    time = get_resource(w, Time)

    if time.tick_of_year != s.tick_of_year
        return
    end

    rng = get_resource(w, Rng)

    for (_, positions) in Query(w, (Position,); with=(Damaged, Infected))
        append!(s._source_trees, positions)
    end

    n = length(s._source_trees) * s.beetles_per_tree
    new_entities!(w, n, (BeetlePosition, LifeExpectancy)) do (entities, beetle_positions, life_expectancies)
        for i in eachindex(entities)
            pos = s._source_trees[(i - 1) ÷ s.beetles_per_tree + 1]
            beetle_positions[i] = BeetlePosition(pos.x, pos.y)
            life_expectancies[i] = LifeExpectancy(time.tick + floor(Int, randexp(rng.xoshiro) * s.life_expectancy))
        end
    end

    empty!(s._source_trees)
end
