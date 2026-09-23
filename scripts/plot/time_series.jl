using Ark
using PWNModel
using GLMakie

"""
Live time-series plot reporter system. Draws one line per selected column of
a [`RowObserver`](@ref) in its own GLMakie window, appending one row of data
per tick (or every `update_interval` ticks).

Mirrors `plot.TimeSeries` from the sibling Go implementation's
`github.com/mlange-42/ark-pixel/plot` package, adapted to GLMakie's
`Observable`/`notify` update model instead of a per-frame full redraw.

Not part of the `PWNModel` package: GLMakie pulls in a full OpenGL stack, so
this file lives in `scripts/` (a dependency of the `scripts/` environment
only, see `scripts/Project.toml`) and is `include`d directly by run scripts
rather than exported from the package.
"""
mutable struct TimeSeries <: PWNModel.System
    const observer::PWNModel.RowObserver
    const columns::Union{Vector{String},Nothing}
    const title::String
    const xlabel::String
    const ylabel::String
    const update_interval::Int
    const max_rows::Union{Int,Nothing}

    _indices::Vector{Int}
    _series::Vector{Observable{Vector{Point2f}}}
    _ax::Union{Axis,Nothing}
    _screen::Any
    _step::Int
end

"""
    TimeSeries(; observer, columns=nothing, title="", xlabel="", ylabel="",
                 update_interval=1, max_rows=nothing)

  - `observer`: the [`RowObserver`](@ref) supplying column headers and rows.
  - `columns`: column names to plot as separate lines. Defaults to all columns.
  - `update_interval`: sample and redraw every this many ticks, like [`CSV`](@ref).
  - `max_rows`: if given, keep only the most recent `max_rows` points per line
    (rolling window) instead of the full unbounded history.
"""
function TimeSeries(;
    observer::PWNModel.RowObserver,
    columns::Union{AbstractVector{<:AbstractString},Nothing}=nothing,
    title::AbstractString="",
    xlabel::AbstractString="",
    ylabel::AbstractString="",
    update_interval::Int=1,
    max_rows::Union{Int,Nothing}=nothing,
)
    return TimeSeries(
        observer,
        isnothing(columns) ? nothing : String.(columns),
        String(title),
        String(xlabel),
        String(ylabel),
        update_interval,
        max_rows,
        Int[],
        Observable{Vector{Point2f}}[],
        nothing,
        nothing,
        0,
    )
end

"""
GLMakie screen the plot was displayed on, e.g. to `wait` on it so the window
stays open after a script's `run!` call returns.
"""
screen(p::TimeSeries) = p._screen

function PWNModel.initialize!(s::TimeSeries, w::World)
    PWNModel.initialize!(s.observer, w)
    headers = PWNModel.header(s.observer)

    s._indices =
        isnothing(s.columns) ? collect(eachindex(headers)) :
        [_find_column(headers, name) for name in s.columns]

    GLMakie.activate!()

    fig = Figure()
    ax = Axis(fig[1, 1], title=s.title, xlabel=s.xlabel, ylabel=s.ylabel)

    s._series = [Observable(Point2f[]) for _ in s._indices]
    for (i, idx) in enumerate(s._indices)
        lines!(ax, s._series[i], label=headers[idx])
    end
    if length(s._series) > 1
        axislegend(ax)
    end

    s._ax = ax

    # display(fig) alone would draw into GLMakie's shared singleton screen,
    # which other plots (e.g. TreesMap) also default to -- stealing their
    # window instead of opening a separate one. An explicit Screen avoids that.
    s._screen = GLMakie.Screen(title=isempty(s.title) ? "Makie" : s.title)
    display(s._screen, fig)
    s._step = 0
end

function PWNModel.update!(s::TimeSeries, w::World)
    PWNModel.update!(s.observer, w)

    if s._step % s.update_interval == 0
        vals = PWNModel.data(s.observer, w)
        x = Float64(s._step)

        for (i, idx) in enumerate(s._indices)
            points = s._series[i][]
            push!(points, Point2f(x, vals[idx]))
            if !isnothing(s.max_rows) && length(points) > s.max_rows
                deleteat!(points, 1)
            end
            notify(s._series[i])
        end

        autolimits!(s._ax)
    end

    s._step += 1
end

function _find_column(headers::Vector{String}, name::AbstractString)
    idx = findfirst(==(name), headers)
    isnothing(idx) && error("column '$name' not found")
    return idx
end
