"""
    Scheduler(world, systems; tps=0, fps=0)

  - `tps`: target update rate of the systems' [`update!`](@ref), in ticks
    per second. Values `<= 0` (the default) mean as fast as possible.
  - `fps`: target update rate of the systems' [`update_ui!`](@ref) (e.g.
    redrawing live plots), in frames per second, independent of `tps`.
    `0` (the default) means 30 FPS, values `< 0` sync it with `tps`, i.e. a
    UI update after every tick.

Both can also be changed later, by calling [`tps!`](@ref)/[`fps!`](@ref) or
by assigning `scheduler.tps`/`scheduler.fps` directly, and the run can be
paused via `scheduler.paused`. All three are stored in a
[`SchedulerControl`](@ref) resource the scheduler adds to the world, so that
systems (e.g. a UI) can change them, too.

Mirrors `app.Systems` from the sibling Go implementation's
`github.com/mlange-42/ark-tools/app` package, except that UI updates are a
second method of ordinary [`System`](@ref)s instead of a separate system type.
"""
mutable struct Scheduler{ST<:Tuple}
    const world::World
    const systems::ST
    const _control::SchedulerControl

    _is_initialized::Bool
    _next_update::Float64
    _next_draw::Float64
end

function Scheduler(world::World, systems::ST; tps::Real=0, fps::Real=0) where {ST<:Tuple}
    add_resource!(world, Tick())
    add_resource!(world, Termination())
    control = SchedulerControl(; tps=tps, fps=fps)
    add_resource!(world, control)
    return Scheduler{ST}(world, systems, control, false, 0.0, 0.0)
end

# `tps`, `fps` and `paused` are forwarded to the SchedulerControl resource.
const _CONTROL_PROPERTIES = (:tps, :fps, :paused)

function Base.getproperty(s::Scheduler, name::Symbol)
    name in _CONTROL_PROPERTIES && return getfield(getfield(s, :_control), name)
    return getfield(s, name)
end

function Base.setproperty!(s::Scheduler, name::Symbol, value)
    name in _CONTROL_PROPERTIES && return setproperty!(getfield(s, :_control), name, value)
    return setfield!(s, name, convert(fieldtype(typeof(s), name), value))
end

Base.propertynames(s::Scheduler) = (fieldnames(typeof(s))..., _CONTROL_PROPERTIES...)

"""
    tps!(s::Scheduler, value)

Sets the target update rate of `s`, in ticks per second. Values `<= 0` mean
as fast as possible. Equivalent to assigning `s.tps` directly.
"""
tps!(s::Scheduler, value::Real) = (s.tps = Float64(value))

"""
    fps!(s::Scheduler, value)

Sets the target UI update rate of `s`, in frames per second. `0` means 30 FPS,
values `< 0` sync it with the tick rate. Equivalent to assigning `s.fps` directly.
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

@inline _update_ui_systems!(::Tuple{}, ::World) = nothing
@inline function _update_ui_systems!(systems::Tuple, world::World)
    update_ui!(systems[1], world)
    _update_ui_systems!(Base.tail(systems), world)
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
    s._next_draw = 0.0
end

# Time of the next update at `rate` per second after one intended at `last`.
# Mirrors `nextTime` from ark-tools' `app` package: steps at a fixed `1/rate`
# cadence, but resyncs to the current time instead of bursting through a
# backlog of updates when it falls far behind.
function _next_time(last::Float64, rate::Float64)
    if rate <= 0
        return last
    end
    now = time()
    if now > last + 0.2
        return now - 0.01
    end
    return last + 1.0 / rate
end

# Effective UI frame rate. While paused, it is capped to 30 FPS and never
# synced with the (then absent) ticks, like `limitedFps` in ark-tools' `app`.
function _effective_fps(s::Scheduler)
    fps = s.fps
    if s.paused
        return (fps <= 0 || fps > 30) ? 30.0 : fps
    end
    return fps == 0 ? 30.0 : fps
end

# Updates the systems if a tick is due and not paused. Returns whether it was.
function _update_systems_timed!(s::Scheduler)
    s.paused && return false
    if s.tps > 0
        time() < s._next_update && return false
        s._next_update = _next_time(s._next_update, s.tps)
    end
    _update_systems!(s.systems, s.world)
    return true
end

# Updates the UI of the systems if a frame is due, i.e. after every tick when
# syncing with the tick rate.
function _update_ui_timed!(s::Scheduler, updated::Bool)
    fps = _effective_fps(s)
    if fps < 0
        updated || return
    else
        time() < s._next_draw && return
        s._next_draw = _next_time(s._next_draw, fps)
    end
    _update_ui_systems!(s.systems, s.world)
    # Let other tasks run, in particular GLMakie's render loops, so they draw
    # the UI updates. Without this, they would never get to run at unlimited
    # tick rates, as the model's loop would then never sleep. Processing
    # pending events first also wakes up tasks whose sleep timers expired.
    Base.process_events()
    yield()
end

# Sleeps until the next tick or UI update is due. While paused, only UI
# updates are due.
function _wait(s::Scheduler)
    next = s.paused ? s._next_draw : s._next_update
    if _effective_fps(s) > 0 && s._next_draw < next
        next = s._next_draw
    end
    wait = next - time()
    if wait > 0
        sleep(wait)
    end
end

"""
    step!(s::Scheduler)

Updates all systems of `s` and advances its [`Tick`](@ref), waiting until the
tick is due according to `s.tps` and updating the UI of all systems in between
according to `s.fps`.

While `s.paused`, only updates the UI, until unpaused (or terminated).

Returns whether the run should continue, i.e. whether a system has set the
[`Termination`](@ref) resource's `terminate` field to `true` (e.g. via
[`FixedTermination`](@ref)). A UI update setting it returns before the tick.
"""
function step!(s::Scheduler)
    while true
        updated = _update_systems_timed!(s)
        _update_ui_timed!(s, updated)
        if updated
            get_resource(s.world, Tick).value += 1
            return !get_resource(s.world, Termination).terminate
        end
        # A UI update may also terminate, e.g. when a plot window is closed.
        get_resource(s.world, Termination).terminate && return false
        _wait(s)
    end
end

function finalize!(s::Scheduler)
    _finalize_systems!(s.systems, s.world)
end

function run!(s::Scheduler, steps::Int)
    # initialize all systems
    initialize!(s)

    # update loop
    for _ in 1:steps
        # update all systems, stopping early on termination
        step!(s) || break
    end

    # finalize all systems
    finalize!(s)
end

"""
    run!(s::Scheduler)

Runs `s` until a system sets the [`Termination`](@ref) resource, e.g. via
[`FixedTermination`](@ref).

Mirrors `App.Run` from the sibling Go implementation's
`github.com/mlange-42/ark-tools/app` package.
"""
function run!(s::Scheduler)
    # initialize all systems
    initialize!(s)

    # update loop
    while step!(s)
    end

    # finalize all systems
    finalize!(s)
end
