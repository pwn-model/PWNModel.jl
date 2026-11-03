
# BeetleEmergence of beetles from nematode-infected trees.
#
# Beetle life expectancy is drawn from an exponential distribution via
# randexp(rng.xoshiro) -- the raw Xoshiro256++ source directly, not Rng's
# usual low-53-bit rand override -- so that it stays bit-identical with the
# sibling Go implementation's util.ExpFloat64 (see res/rng.jl and
# pwn/util/random.go for why exponential draws need this separate path).
# The drawn life span is capped at max_age ticks.
Base.@kwdef struct BeetleEmergence <: System
    tick_of_year::Int
    beetles_per_tree::Int
    life_expectancy::Float64
    max_age::Int

    _source_trees::Vector{Position} = Position[]
end

function update!(s::BeetleEmergence, w::World)
    time = get_resource(w, Time)
    tick = time.tick

    if time.tick_of_year != s.tick_of_year
        return
    end

    rng = get_resource(w, Rng)

    for (_, positions) in Query(w, (Position,); with=(Colonized, Infected))
        append!(s._source_trees, positions)
    end

    n = length(s._source_trees) * s.beetles_per_tree
    new_entities!(w, n,
        (BeetlePosition, EmergenceTick, LifeExpectancy, LastTree),
    ) do (entities, beetle_positions, emergence_ticks, life_expectancies, last_trees)
        for i in eachindex(entities)
            pos = s._source_trees[(i-1)÷s.beetles_per_tree+1]
            beetle_positions[i] = BeetlePosition(pos.x, pos.y)
            emergence_ticks[i] = EmergenceTick(tick)
            life_expectancies[i] =
                LifeExpectancy(tick + min(floor(Int, randexp(rng.xoshiro) * s.life_expectancy), s.max_age))
            last_trees[i] = LastTree(NO_CELL)
        end
    end

    empty!(s._source_trees)
end
