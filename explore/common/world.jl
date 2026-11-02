using Ark
using PWNModel
using Random

"""
    new_world(; seed, width, height, cell_size) -> World

Creates a `World` with the model's full component set (like `run_model`),
an [`Rng`](@ref) resource seeded with `seed`, and a `WorldSize` resource
(`width`, `height` and `cell_size` in meters).
"""
function new_world(; seed::Integer, width::Int, height::Int, cell_size::Int)
    world = World(
        Position, Damaged, Infected, Colonized,
        BeetlePosition, EmergenceTick, LifeExpectancy,
    )
    add_resource!(world, Rng(seed))
    add_resource!(world, WorldSize(; width=width, height=height, cell_size=cell_size))
    return world
end

"""
    cell_center(x, y, cell_size) -> (x_m, y_m)

Center of grid cell `(x, y)` in meters, for 1-based cell coordinates.
"""
cell_center(x::Int, y::Int, cell_size::Int) = ((x - 0.5) * cell_size, (y - 0.5) * cell_size)

"""
    ReleaseBeetles(; x, y, count, life_expectancy)

Initialization system that creates `count` beetles in cell `(x, y)`, all
emerging at the current tick. Life expectancy in ticks is drawn from an
exponential distribution with mean `life_expectancy`, like in
`BeetleEmergence`. It only matters if `BeetleMortality` is used.
"""
Base.@kwdef struct ReleaseBeetles <: PWNModel.System
    x::Int
    y::Int
    count::Int
    life_expectancy::Float64
end

function PWNModel.initialize!(s::ReleaseBeetles, w::World)
    tick = get_resource(w, Time).tick
    rng = get_resource(w, Rng)

    new_entities!(
        w, s.count, (BeetlePosition, EmergenceTick, LifeExpectancy),
    ) do (entities, positions, emergence_ticks, life_expectancies)
        for i in eachindex(entities)
            positions[i] = BeetlePosition(s.x, s.y)
            emergence_ticks[i] = EmergenceTick(tick)
            life_expectancies[i] = LifeExpectancy(tick + floor(Int, randexp(rng.xoshiro) * s.life_expectancy))
        end
    end
end

"""
    PlaceTrees(; positions, damaged=false)

Initialization system that creates a tree in each of the given cells
(`positions`, a vector of `Position`), healthy or damaged. Requires
`InitGrids` to run before it. Can be used several times, e.g. once for
healthy and once for damaged trees, as long as cells don't overlap.
"""
Base.@kwdef struct PlaceTrees <: PWNModel.System
    positions::Vector{Position}
    damaged::Bool = false
end

function PWNModel.initialize!(s::PlaceTrees, w::World)
    trees = get_resource(w, TreeGrid).grid
    comps = s.damaged ? (Position, Damaged) : (Position,)
    new_entities!(w, length(s.positions), comps) do (entities, positions, _...)
        for i in eachindex(entities)
            positions[i] = s.positions[i]
            trees[s.positions[i].x, s.positions[i].y] = entities[i]
        end
    end
end
