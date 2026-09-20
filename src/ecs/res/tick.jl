"""
Tick resource holding the model's current time step.

Managed by the [`Scheduler`](@ref), which adds it and increments it once per
[`step!`](@ref); it should not be modified by user code.
"""
mutable struct Tick
    value::Int
end

Tick() = Tick(0)
