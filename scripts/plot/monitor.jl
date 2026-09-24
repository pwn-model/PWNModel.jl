using Ark
using PWNModel
using GLMakie

"""
Live world and performance statistics monitor. Shows a summary line, time
series plots of entity counts, memory and ticks per second, and one bar per
archetype with its used and reserved entity capacity, in its own GLMakie
window.

Mirrors `monitor.Monitor` from the sibling Go implementation's
`github.com/mlange-42/ark-pixel/monitor` package. Ark.jl has no equivalent
of Go Ark's `World.Stats`, so its statistics come from
[`world_stats`](@ref) instead, which reads them from Ark.jl's internals and
only estimates memory (see [`WorldStats`](@ref)). The summary line also
shows the number of archetype graph nodes ("Nodes"), which the Go original
omits.

Symbology of the archetype bars, like the Go original:

  - Green: archetypes without entity relations
  - Cyan: archetypes with entity relations, labeled with their number of
    used/total tables
  - Light: used capacity, dark: reserved capacity

Unless `hide_controls` is set, it also has controls for the run, like the Go
`monitor.Controls` drawer (which `monitor.NewMonitorWindow` adds there): a
button or SPACE pauses/resumes the run, and buttons or the UP/DOWN keys step
its tick rate through a list of preferred rates (see [`next_tps`](@ref)).
They act on the [`SchedulerControl`](@ref) resource.

Not part of the `PWNModel` package: GLMakie pulls in a full OpenGL stack, so
this file lives in `scripts/` (a dependency of the `scripts/` environment
only, see `scripts/Project.toml`) and is `include`d directly by run scripts
rather than exported from the package.
"""
mutable struct Monitor <: PWNModel.System
    const title::String
    const plot_capacity::Int
    const sample_interval::Float64
    const hide_plots::Bool
    const hide_archetypes::Bool
    const hide_controls::Bool

    _control::Union{SchedulerControl,Nothing}
    _tps_text::Union{Observable{String},Nothing}
    _pause_text::Union{Observable{String},Nothing}
    _summary::Union{Observable{String},Nothing}
    _series::Vector{Observable{Vector{Point2f}}}
    _plot_axes::Vector{Axis}
    _arch_ax::Union{Axis,Nothing}
    _arch_sizes::Union{Observable{Vector{Float64}},Nothing}
    _arch_caps::Union{Observable{Vector{Float64}},Nothing}
    _arch_counts::Union{Observable{Vector{String}},Nothing}
    _arch_tables::Union{Observable{Vector{String}},Nothing}
    _num_archetypes::Int
    _screen::Any

    _start_time::Float64
    _last_sample::Float64
    _num_samples::Int
    _timer_tick::Int
    _timer_time::Float64
    _tick_time::Float64
end

"""
    Monitor(; title="Monitor", plot_capacity=300, sample_interval=1.0,
              hide_plots=false, hide_archetypes=false, hide_controls=false)

  - `plot_capacity`: number of values kept in the time series plots.
  - `sample_interval`: approx. time between samples for the time series
    plots, in seconds (Go's `SampleInterval`, a `time.Duration` there).
  - `hide_plots`: hides the time series plots.
  - `hide_archetypes`: hides the archetype bars.
  - `hide_controls`: hides the pause/speed controls and disables their keys.
"""
function Monitor(;
    title::AbstractString="Monitor",
    plot_capacity::Int=300,
    sample_interval::Real=1.0,
    hide_plots::Bool=false,
    hide_archetypes::Bool=false,
    hide_controls::Bool=false,
)
    return Monitor(
        String(title),
        plot_capacity > 0 ? plot_capacity : 300,
        sample_interval > 0 ? Float64(sample_interval) : 1.0,
        hide_plots,
        hide_archetypes,
        hide_controls,
        nothing,
        nothing,
        nothing,
        nothing,
        Observable{Vector{Point2f}}[],
        Axis[],
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        -1,
        nothing,
        0.0,
        0.0,
        0,
        0,
        0.0,
        0.0,
    )
end

"""
GLMakie screen the monitor was displayed on, e.g. to `wait` on it so the
window stays open after a script's `run!` call returns.
"""
screen(m::Monitor) = m._screen

const _MONITOR_GREEN = RGBAf(0 / 255, 130 / 255, 40 / 255, 1)
const _MONITOR_DARK_GREEN = RGBAf(20 / 255, 80 / 255, 25 / 255, 1)
const _MONITOR_CYAN = RGBAf(0 / 255, 100 / 255, 120 / 255, 1)
const _MONITOR_DARK_CYAN = RGBAf(20 / 255, 50 / 255, 70 / 255, 1)

# Time series plots and their lines. The lines' flattened order must match
# the values appended in `_append_samples!`.
const _MONITOR_SERIES_PLOTS = (
    (ylabel="Entities", labels=("Used", "Total")),
    (ylabel="Memory [kB]", labels=("Reserved", "Used")),
    (ylabel="TPS", labels=("TPS",)),
)

function PWNModel.initialize!(m::Monitor, w::World)
    GLMakie.activate!()

    fig = Figure(size=(1200, 700))

    m._summary = Observable("")
    Label(fig[1, 1:2], m._summary, font=:regular, halign=:left, tellwidth=false)

    if !m.hide_plots
        plots = GridLayout(m.hide_archetypes ? fig[2, 1:2] : fig[2, 1])
        for (i, spec) in enumerate(_MONITOR_SERIES_PLOTS)
            ax = Axis(plots[i, 1], ylabel=spec.ylabel, xticklabelsvisible=false)
            for label in spec.labels
                series = Observable(Point2f[])
                lines!(ax, series, label=label)
                push!(m._series, series)
            end
            length(spec.labels) > 1 && axislegend(ax, position=:lt, framevisible=false)
            push!(m._plot_axes, ax)
        end
    end

    if !m.hide_archetypes
        m._arch_ax = Axis(
            m.hide_plots ? fig[2, 1:2] : fig[2, 2], title="Archetypes", xlabel="Entities",
            yticksvisible=false, yticklabelsvisible=false,
            ygridvisible=false,
        )
        if !m.hide_plots
            # Like the Go original: plots take a quarter of the width.
            colsize!(fig.layout, 1, Relative(0.25))
        end
    end

    m.hide_controls || _add_controls!(m, fig, get_resource(w, SchedulerControl))

    m._num_archetypes = -1
    now = time()
    m._start_time = now
    m._last_sample = now - m.sample_interval
    m._num_samples = 0
    m._timer_tick = get_resource(w, Tick).value
    m._timer_time = now
    m._tick_time = 0.0

    m._screen = plot_window(m.title, fig)
end

function PWNModel.update_ui!(m::Monitor, w::World)
    window_closed!(m._screen, w) && return

    now = time()
    tick = get_resource(w, Tick).value
    _update_timer!(m, tick, now)

    stats = world_stats(w)
    tps = m._tick_time > 0 ? 1.0 / m._tick_time : 0.0

    m._summary[] = _monitor_summary(m, stats, tick, tps, now)

    if !m.hide_plots && now - m._last_sample >= m.sample_interval
        _append_samples!(m, stats, tps)
        m._last_sample = now
    end

    m.hide_archetypes || _update_archetypes!(m, stats)
    m.hide_controls || _update_controls!(m)
end

# Adds pause and speed buttons below the plots, and their keyboard shortcuts.
function _add_controls!(m::Monitor, fig::Figure, control::SchedulerControl)
    m._control = control
    m._tps_text = Observable("")
    m._pause_text = Observable("")

    controls = GridLayout(fig[3, 1:2], halign=:right, tellwidth=false)
    Label(controls[1, 1], m._tps_text, width=110, halign=:right)
    slower = Button(controls[1, 2], label="-", width=30)
    faster = Button(controls[1, 3], label="+", width=30)
    pause = Button(controls[1, 4], label=m._pause_text, width=80)

    on(_ -> _toggle_pause!(m), pause.clicks)
    on(_ -> _step_tps!(m, false), slower.clicks)
    on(_ -> _step_tps!(m, true), faster.clicks)

    on(events(fig).keyboardbutton) do event
        event.action == Keyboard.press || return
        if event.key == Keyboard.space
            _toggle_pause!(m)
        elseif event.key == Keyboard.up
            _step_tps!(m, true)
        elseif event.key == Keyboard.down
            _step_tps!(m, false)
        end
    end

    _update_controls!(m)
end

# Controls are also changed in the (render loop) callbacks above, so their
# labels are refreshed there, too, to not wait for the next UI update while
# paused at a low frame rate.
function _toggle_pause!(m::Monitor)
    m._control.paused = !m._control.paused
    _update_controls!(m)
end

function _step_tps!(m::Monitor, increase::Bool)
    m._control.tps = next_tps(m._control.tps, increase)
    _update_controls!(m)
end

function _update_controls!(m::Monitor)
    tps = m._control.tps
    tps_text = tps > 0 ? "$(round(Int, tps)) TPS" : "Max. TPS"
    pause_text = m._control.paused ? "Resume" : "Pause"
    m._tps_text[] == tps_text || (m._tps_text[] = tps_text)
    m._pause_text[] == pause_text || (m._pause_text[] = pause_text)
end

# Updates the time per tick about once per second, like Go's frameTimer.
function _update_timer!(m::Monitor, tick::Int, now::Float64)
    delta = now - m._timer_time
    delta < 1.0 && return

    # Unlike Go's frameTimer, no ticks (e.g. while paused) show as 0 TPS
    # instead of keeping the last rate.
    ticks = tick - m._timer_tick
    m._tick_time = ticks > 0 ? delta / ticks : 0.0
    m._timer_tick = tick
    m._timer_time = now
end

function _monitor_summary(m::Monitor, stats::WorldStats, tick::Int, tps::Float64, now::Float64)
    mem, units = _mem_text(stats.memory)
    tpt = m._tick_time * 1000
    elapsed = round(Int, now - m._start_time)
    return "Tick: $tick  |  Ent.: $(stats.entities.used)  |  " *
           "Archetypes: $(length(stats.archetypes))  |  Nodes: $(stats.nodes)  |  " *
           "Comp: $(length(stats.component_types))  |  Cache: $(stats.cached_filters)  |  " *
           "Mem: $(round(mem; digits=1)) $units  |  TPS: $(round(tps; digits=1))  |  " *
           "TPT: $(round(tpt; digits=2)) ms  |  Time: $(elapsed)s"
end

_mem_text(bytes::Int) = bytes <= 10 * 1_024_000 ? (bytes / 1024, "kB") : (bytes / 1_024_000, "MB")

function _append_samples!(m::Monitor, stats::WorldStats, tps::Float64)
    values = (
        stats.entities.used, stats.entities.total,
        stats.memory / 1024, stats.memory_used / 1024,
        tps,
    )
    x = Float32(m._num_samples)
    for (series, v) in zip(m._series, values)
        points = series[]
        push!(points, Point2f(x, v))
        if length(points) > m.plot_capacity
            deleteat!(points, 1)
        end
        notify(series)
    end
    m._num_samples += 1

    for ax in m._plot_axes
        autolimits!(ax)
    end
end

function _update_archetypes!(m::Monitor, stats::WorldStats)
    archetypes = stats.archetypes
    if length(archetypes) != m._num_archetypes
        _rebuild_archetypes!(m, stats)
    end

    m._arch_sizes[] = [Float64(a.size) for a in archetypes]
    m._arch_caps[] = [Float64(a.capacity) for a in archetypes]
    m._arch_counts[] = [string(a.size) for a in archetypes]
    m._arch_tables[] = [
        a.num_relations > 0 ? "$(length(a.tables)) / $(length(a.tables) + a.free_tables)" : ""
        for a in archetypes
    ]

    max_cap = maximum(a -> a.capacity, archetypes; init=0)
    xlims!(m._arch_ax, 0, max(max_cap, 1))
end

# Redraws the archetype bars from scratch, as their number (and with it the
# length of all their per-bar Observables) changed. Rare after model setup.
function _rebuild_archetypes!(m::Monitor, stats::WorldStats)
    ax = m._arch_ax
    empty!(ax)

    archetypes = stats.archetypes
    n = length(archetypes)
    ys = collect(1:n)
    has_rel = [a.num_relations > 0 for a in archetypes]

    m._arch_caps = Observable(zeros(n))
    m._arch_sizes = Observable(zeros(n))
    m._arch_counts = Observable(fill("", n))
    m._arch_tables = Observable(fill("", n))

    barplot!(
        ax, ys, m._arch_caps, direction=:x, gap=0.1,
        color=[r ? _MONITOR_DARK_CYAN : _MONITOR_DARK_GREEN for r in has_rel],
    )
    barplot!(
        ax, ys, m._arch_sizes, direction=:x, gap=0.1,
        color=[r ? _MONITOR_CYAN : _MONITOR_GREEN for r in has_rel],
    )

    labels = [
        "$(lpad(a.memory_per_entity, 4)) B  " * join((string(nameof(t)) for t in a.component_types), " ")
        for a in archetypes
    ]
    label_pos = [Point2f(0, y) for y in ys]
    text!(ax, label_pos, text=labels, align=(:left, :center), offset=(90, 0), space=:data, fontsize=12)
    text!(ax, label_pos, text=m._arch_tables, align=(:left, :center), offset=(5, 0), fontsize=12)

    # Entity counts, right-aligned to the axis' right edge.
    right = lift(ax.finallimits, m._arch_caps) do lims, _
        x = lims.origin[1] + lims.widths[1]
        [Point2f(x, y) for y in ys]
    end
    text!(ax, right, text=m._arch_counts, align=(:right, :center), offset=(-5, 0), fontsize=12)

    # Reversed limits also reverse the axis: first archetype (no components) on top.
    ylims!(ax, n + 0.5, 0.5)
    m._num_archetypes = n
end
