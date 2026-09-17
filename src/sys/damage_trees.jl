
# DamageTrees damages trees, and removes damaged trees.
Base.@kwdef struct DamageTrees <: System
    tick_of_year::Int
    damage_probability::Float64
    removal_probability::Float64

    _to_remove::Vector{Entity} = Entity[]
    _to_damage::Vector{Entity} = Entity[]
end

function update!(s::DamageTrees, w::World)
    toy = get_resource(w, Time).tick_of_year

    if toy != s.tick_of_year
        return
    end

    rng = get_resource(w, Rng)

    for (entities,) in Query(w, (); with=(Damaged,))
        for e in entities
            if rand(rng) < s.removal_probability
                push!(s._to_remove, e)
            end
        end
    end

    for e in s._to_remove
        remove_entity!(w, e)
    end
    empty!(s._to_remove)

    for (entities,) in Query(w, (); with=(Position,), without=(Damaged,))
        for e in entities
            if rand(rng) < s.damage_probability
                push!(s._to_damage, e)
            end
        end
    end

    for e in s._to_damage
        add_components!(w, e, (Damaged(),))
    end
    empty!(s._to_damage)
end
