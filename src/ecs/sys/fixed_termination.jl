"""
    FixedTermination(; steps)

System that terminates the run after a fixed number of ticks.

Mirrors `system.FixedTermination` from the sibling Go implementation's
`github.com/mlange-42/ark-tools/system` package.
"""
Base.@kwdef struct FixedTermination <: System
    steps::Int
end

function update!(s::FixedTermination, world::World)
    tick = get_resource(world, Tick).value
    if tick + 1 >= s.steps
        get_resource(world, Termination).terminate = true
    end
end
