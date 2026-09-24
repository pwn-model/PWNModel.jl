"""
SchedulerControl resource holding the [`Scheduler`](@ref)'s run-time
controllable parameters: its tick rate, UI frame rate, and whether it is
paused.

Added by the [`Scheduler`](@ref), which reads it on every step. Systems can
modify it to control the run, e.g. a UI to pause/resume it or change its
speed. The scheduler's own `tps`/`fps` properties and [`tps!`](@ref)/
[`fps!`](@ref) read and write this same resource.

Mirrors the `TPS`, `FPS` and `Paused` fields of `app.Systems` from the
sibling Go implementation's `github.com/mlange-42/ark-tools/app` package,
which is itself a resource there.
"""
mutable struct SchedulerControl
    # Target tick rate, in ticks per second. Values <= 0 mean as fast as possible.
    tps::Float64
    # Target UI frame rate. 0 means 30 FPS, values < 0 sync it with `tps`.
    fps::Float64
    # Whether ticks are paused. UI updates continue, at up to 30 FPS.
    paused::Bool
end

SchedulerControl(; tps::Real=0, fps::Real=0, paused::Bool=false) =
    SchedulerControl(Float64(tps), Float64(fps), paused)

# Preferred tick rates to step through when speeding up or slowing down a
# run, like `preferredTps` from ark-pixel's `monitor` package. 0 means as
# fast as possible.
const _PREFERRED_TPS = (
    0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 7.0, 10.0, 15.0, 20.0, 30.0, 40.0, 50.0, 60.0, 80.0, 100.0,
    120.0, 150.0, 200.0, 250.0, 500.0, 750.0, 1000.0, 2000.0, 5000.0, 10000.0,
)

"""
    next_tps(curr::Real, increase::Bool) -> Float64

The next preferred tick rate above (`increase=true`) or below `curr`, for
stepping a run's speed up or down, e.g. via [`SchedulerControl`](@ref).
Stays at `curr` if it's the highest preferred rate or above; returns `0`
(as fast as possible) when decreasing from the lowest one.

Mirrors `calcTps` from the sibling Go implementation's
`github.com/mlange-42/ark-pixel/monitor` package, except that decreasing
from above the highest preferred rate returns that rate instead of `0`.
"""
function next_tps(curr::Real, increase::Bool)
    if increase
        for tps in _PREFERRED_TPS
            tps > curr && return tps
        end
        return Float64(curr)
    end
    for i in 2:length(_PREFERRED_TPS)
        _PREFERRED_TPS[i] >= curr && return _PREFERRED_TPS[i-1]
    end
    return last(_PREFERRED_TPS)
end
