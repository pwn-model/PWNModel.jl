using Ark
using PWNModel

"""
    BeetleTrajectories()

System that records the position of every beetle, once at initialization
and once after every update. Must come after the systems that create and
move beetles.

Recorded positions are in `tracks`, a vector of positions per beetle entity.
A track ends early when its beetle is removed. `entities` holds the beetle
entities in the order they were first recorded.
"""
struct BeetleTrajectories <: PWNModel.System
    tracks::Dict{Entity,Vector{BeetlePosition}}
    entities::Vector{Entity}
end

BeetleTrajectories() = BeetleTrajectories(Dict{Entity,Vector{BeetlePosition}}(), Entity[])

PWNModel.initialize!(s::BeetleTrajectories, w::World) = record!(s, w)
PWNModel.update!(s::BeetleTrajectories, w::World) = record!(s, w)

function record!(s::BeetleTrajectories, w::World)
    for (entities, positions) in Query(w, (BeetlePosition,))
        for i in eachindex(entities)
            track = get!(s.tracks, entities[i]) do
                push!(s.entities, entities[i])
                BeetlePosition[]
            end
            push!(track, positions[i])
        end
    end
end

"""
    TreeVisits()

System that sums up, per cell, the beetles feeding on healthy trees and
laying eggs on damaged trees, over all ticks. Must come after the movement
system, which counts these events in the `FeedingInfectedBeetles` grid
anew each tick: one event per movement step a beetle ends on a tree of the
type it targets, so a beetle staying on a tree counts once per step there.

Cells are assigned to feeding or egg laying by the presence grid of the
`DamagedTreeAttraction` resource, which is what the movement uses.
Summed counts are in `healthy` (feeding) and `damaged` (egg laying), as
grids of the world's size.
"""
mutable struct TreeVisits <: PWNModel.System
    healthy::Grid{Int}
    damaged::Grid{Int}
end

TreeVisits() = TreeVisits(Grid(0, 0, 1, 0), Grid(0, 0, 1, 0))

function PWNModel.initialize!(s::TreeVisits, w::World)
    ws = get_resource(w, WorldSize)
    s.healthy = Grid(ws.width, ws.height, ws.cell_size, 0)
    s.damaged = Grid(ws.width, ws.height, ws.cell_size, 0)
end

function PWNModel.update!(s::TreeVisits, w::World)
    events = get_resource(w, FeedingInfectedBeetles).grid
    damaged = get_resource(w, DamagedTreeAttraction).presence
    for x in 1:events.width, y in 1:events.height
        n = Int(events[x, y])
        n == 0 && continue
        target = damaged[x, y] ? s.damaged : s.healthy
        target[x, y] += n
    end
end
