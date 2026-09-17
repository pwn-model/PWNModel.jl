
# DiseaseCourse system.
Base.@kwdef struct DiseaseCourse <: System
    ticks_to_damage::Int

    _to_damage::Vector{Entity} = Entity[]
end

function update!(s::DiseaseCourse, w::World)
    tick = get_resource(w, Time).tick

    for (entities, infected) in Query(w, (Infected,); without=(Damaged,))
        for i in eachindex(entities)
            if infected[i].infection_tick + s.ticks_to_damage <= tick
                push!(s._to_damage, entities[i])
            end
        end
    end

    for e in s._to_damage
        add_components!(w, e, (Damaged(),))
    end

    empty!(s._to_damage)
end
