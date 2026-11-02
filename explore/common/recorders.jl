using Ark
using PWNModel

"""
    BeetleTrajectories()

System that records the position of every beetle, once at initialization
and once after every update. Must come after the systems that create and
move beetles.

Recorded positions are in `tracks`, a vector of positions per beetle entity.
A track ends early when its beetle is removed.
"""
struct BeetleTrajectories <: PWNModel.System
    tracks::Dict{Entity,Vector{BeetlePosition}}
end

BeetleTrajectories() = BeetleTrajectories(Dict{Entity,Vector{BeetlePosition}}())

PWNModel.initialize!(s::BeetleTrajectories, w::World) = record!(s, w)
PWNModel.update!(s::BeetleTrajectories, w::World) = record!(s, w)

function record!(s::BeetleTrajectories, w::World)
    for (entities, positions) in Query(w, (BeetlePosition,))
        for i in eachindex(entities)
            push!(get!(Vector{BeetlePosition}, s.tracks, entities[i]), positions[i])
        end
    end
end
