mutable struct Scheduler{ST<:Tuple}
    const world::World
    const systems::ST
    _is_initialized::Bool
end

function Scheduler(world::World, systems::ST) where {ST<:Tuple}
    add_resource!(world, Tick())
    return Scheduler{ST}(world, systems, false)
end

@inline _initialize_systems!(::Tuple{}, ::World) = nothing
@inline function _initialize_systems!(systems::Tuple, world::World)
    initialize!(systems[1], world)
    _initialize_systems!(Base.tail(systems), world)
end

@inline _update_systems!(::Tuple{}, ::World) = nothing
@inline function _update_systems!(systems::Tuple, world::World)
    update!(systems[1], world)
    _update_systems!(Base.tail(systems), world)
end

@inline _finalize_systems!(::Tuple{}, ::World) = nothing
@inline function _finalize_systems!(systems::Tuple, world::World)
    finalize!(systems[1], world)
    _finalize_systems!(Base.tail(systems), world)
end

function initialize!(s::Scheduler)
    if s._is_initialized
        return
    end
    _initialize_systems!(s.systems, s.world)
    s._is_initialized = true
end

function step!(s::Scheduler)
    _update_systems!(s.systems, s.world)
    get_resource(s.world, Tick).value += 1
end

function finalize!(s::Scheduler)
    _finalize_systems!(s.systems, s.world)
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
