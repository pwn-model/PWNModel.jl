abstract type System end

function initialize!(::System, ::World) end
function update!(::System, ::World) end
function finalize!(::System, ::World) end

mutable struct Scheduler{ST<:Tuple}
    const world::World
    const systems::ST
    _is_initialized::Bool
end

Scheduler(world::World, systems::ST) where {ST<:Tuple} = Scheduler{ST}(world, systems, false)

function initialize!(s::Scheduler)
    if s._is_initialized
        return
    end
    for sys in s.systems
        initialize!(sys, s.world)
    end
    s._is_initialized = true
end

function step!(s::Scheduler)
    for sys in s.systems
        update!(sys, s.world)
    end
end

function finalize!(s::Scheduler)
    for sys in s.systems
        finalize!(sys, s.world)
    end
end

function run!(s::Scheduler, steps::Int)
    # initialize all systems
    initialize!(s)

    # update loop
    for _ in 1:steps
        # update all systems
        step!(s)
    end
    
    # finalize all systems
    finalize!(s)
end
