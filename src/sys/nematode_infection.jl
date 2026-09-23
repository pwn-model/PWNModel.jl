
# NematodeInfection infects trees from feeding, infected beetles.
mutable struct NematodeInfection <: System
    const infection_probability::Float64

    _to_infect::Vector{Entity}
end

NematodeInfection(; infection_probability::Float64) = NematodeInfection(infection_probability, Entity[])

function update!(s::NematodeInfection, w::World)
    tick = get_resource(w, Time).tick
    feeding = get_resource(w, FeedingInfectedBeetles).grid
    rng = get_resource(w, Rng)
    non_inf_prob = 1.0 - s.infection_probability

    for (entities, positions) in Query(w, (Position,); without=(Damaged, Infected))
        for i in eachindex(entities)
            pos = positions[i]
            f = feeding[pos.x, pos.y]
            if f == 0
                continue
            end
            p = 1.0 - non_inf_prob^f
            if rand(rng) < p
                push!(s._to_infect, entities[i])
            end
        end
    end

    for e in s._to_infect
        add_components!(w, e, (Infected(tick),))
    end
    empty!(s._to_infect)
end
