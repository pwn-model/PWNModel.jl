
# BeetleMortality removes beetles that have reached their life expectancy.
Base.@kwdef struct BeetleMortality <: System
    _to_remove::Vector{Entity} = Entity[]
end

function update!(s::BeetleMortality, w::World)
    tick = get_resource(w, Time).tick

    for (entities, life_expectancies) in Query(w, (LifeExpectancy,))
        for i in eachindex(entities)
            if tick >= life_expectancies[i].tick_of_death
                push!(s._to_remove, entities[i])
            end
        end
    end

    for e in s._to_remove
        remove_entity!(w, e)
    end
    empty!(s._to_remove)
end
