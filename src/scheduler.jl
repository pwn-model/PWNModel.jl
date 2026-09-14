abstract type System end

function initialize!(::System, ::World) end
function update!(::System, ::World) end
function finalize!(::System, ::World) end

struct Scheduler{ST<:Tuple}
    world::World
    systems::ST
end

function run!(s::Scheduler, steps::Int)
    # initialize all systems
    for sys in s.systems
        initialize!(sys, s.world)
    end

    # update loop
    for _ in 1:steps
        # update all systems
        for sys in s.systems
            update!(sys, s.world)
        end
    end
    
    # finalize all systems
    for sys in s.systems
        finalize!(sys, s.world)
    end
end
