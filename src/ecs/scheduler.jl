"""
    Scheduler(world, systems; fps=0)

  - `fps`: target update rate in ticks per second. Values `<= 0` (the
    default) mean as fast as possible. Can also be changed later, either by
    calling [`fps!`](@ref) or by assigning `scheduler.fps` directly.
"""
mutable struct Scheduler{ST<:Tuple}
    const world::World
    const systems::ST
    fps::Float64

    _is_initialized::Bool
    _next_update::Float64
end

function Scheduler(world::World, systems::ST; fps::Real=0) where {ST<:Tuple}
    add_resource!(world, Tick())
    return Scheduler{ST}(world, systems, Float64(fps), false, 0.0)
end

"""
    fps!(s::Scheduler, value)

Sets the target update rate of `s`, in ticks per second. Values `<= 0` mean
as fast as possible. Equivalent to assigning `s.fps` directly.
"""
fps!(s::Scheduler, value::Real) = (s.fps = Float64(value))

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
    s._next_update = 0.0
end

# Sleeps as needed to cap the update rate to `s.fps` ticks per second.
# Mirrors `nextTime`/`Systems.wait` from the sibling Go implementation's
# `github.com/mlange-42/ark-tools/app` package (there, driving `App.TPS`):
# steps at a fixed `1/fps` cadence, but resyncs to the current time instead
# of bursting through a backlog of ticks when it falls far behind.
function _limit_fps!(s::Scheduler)
    if s.fps <= 0
        return
    end

    dt = 1.0 / s.fps
    now = time()
    if now > s._next_update + 0.2
        s._next_update = now - 0.01
    end

    wait = s._next_update - now
    if wait > 0
        sleep(wait)
    end
    s._next_update += dt
end

function step!(s::Scheduler)
    _limit_fps!(s)
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
