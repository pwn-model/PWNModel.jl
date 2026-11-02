using Ark
using PWNModel

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
    ReleaseBeetles(; x, y, count)

Initialization system that creates `count` beetles in cell `(x, y)`, all
emerging at tick 0 and never dying (as long as `BeetleMortality` is not
used, their life expectancy is irrelevant anyway).
"""
Base.@kwdef struct ReleaseBeetles <: PWNModel.System
    x::Int
    y::Int
    count::Int
end

function PWNModel.initialize!(s::ReleaseBeetles, w::World)
    new_entities!(
        w, s.count, (BeetlePosition, EmergenceTick, LifeExpectancy),
    ) do (entities, positions, emergence_ticks, life_expectancies)
        for i in eachindex(entities)
            positions[i] = BeetlePosition(s.x, s.y)
            emergence_ticks[i] = EmergenceTick(0)
            life_expectancies[i] = LifeExpectancy(typemax(Int))
        end
    end
end
