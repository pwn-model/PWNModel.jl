using Ark
using PWNModel
using GLMakie

"""
Live line-plot reporter system. Draws one line per selected column of a
[`RowObserver`](@ref) in its own GLMakie window, appending one point per
column per tick (or every `update_interval` ticks).

Mirrors `plot.Lines` from the sibling Go implementation's
`github.com/mlange-42/ark-pixel/plot` package, adapted to GLMakie's
`Observable`/`notify` update model instead of a per-frame full redraw.

Not part of the `PWNModel` package: GLMakie pulls in a full OpenGL stack, so
this file lives in `scripts/` (a dependency of the `scripts/` environment
only, see `scripts/Project.toml`) and is `include`d directly by run scripts
rather than exported from the package.
"""
mutable struct LinePlot <: PWNModel.System
    const observer::PWNModel.RowObserver
    const x::Union{String,Nothing}
    const y::Union{Vector{String},Nothing}
    const xlim::Union{Tuple{Float64,Float64},Nothing}
    const ylim::Union{Tuple{Float64,Float64},Nothing}
    const title::String
    const xlabel::String
    const ylabel::String
    const update_interval::Int
    const max_values::Union{Int,Nothing}

    _x_index::Int
    _y_indices::Vector{Int}
    _series::Vector{Observable{Vector{Point2f}}}
    _ax::Union{Axis,Nothing}
    _screen::Any
    _step::Int
end

"""
    LinePlot(; observer, x=nothing, y=nothing, xlim=nothing, ylim=nothing,
               title="", xlabel="", ylabel="", update_interval=1, max_values=nothing)

  - `observer`: the [`RowObserver`](@ref) supplying column headers and rows.
  - `x`: column name for the x axis. Defaults to the tick count.
  - `y`: column names to plot as separate lines. Defaults to all columns but `x`.
  - `xlim`/`ylim`: fixed axis limits as `(low, high)`. Default to auto-scaling;
    giving only one of the two still triggers auto-scaling on both, since a
    single Makie `autolimits!` call recomputes both axes at once.
  - `update_interval`: sample and redraw every this many ticks, like [`CSV`](@ref).
  - `max_values`: if given, keep only the most recent `max_values` points per
    line (rolling window) instead of the full unbounded history.
"""
function LinePlot(;
    observer::PWNModel.RowObserver,
    x::Union{AbstractString,Nothing}=nothing,
    y::Union{AbstractVector{<:AbstractString},Nothing}=nothing,
    xlim::Union{Tuple{<:Real,<:Real},Nothing}=nothing,
    ylim::Union{Tuple{<:Real,<:Real},Nothing}=nothing,
    title::AbstractString="",
    xlabel::AbstractString="",
    ylabel::AbstractString="",
    update_interval::Int=1,
    max_values::Union{Int,Nothing}=nothing,
)
    return LinePlot(
        observer,
        isnothing(x) ? nothing : String(x),
        isnothing(y) ? nothing : String.(y),
        isnothing(xlim) ? nothing : Float64.(xlim),
        isnothing(ylim) ? nothing : Float64.(ylim),
        String(title),
        String(xlabel),
        String(ylabel),
        update_interval,
        max_values,
        -1,
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
screen(p::LinePlot) = p._screen

function PWNModel.initialize!(s::LinePlot, w::World)
    PWNModel.initialize!(s.observer, w)
    headers = PWNModel.header(s.observer)

    s._x_index = isnothing(s.x) ? -1 : _find_column(headers, s.x)
    if isnothing(s.y)
        s._y_indices = [i for i in eachindex(headers) if i != s._x_index]
    else
        s._y_indices = [_find_column(headers, name) for name in s.y]
    end

    GLMakie.activate!()

    fig = Figure()
    ax = Axis(fig[1, 1], title=s.title, xlabel=s.xlabel, ylabel=s.ylabel)
    if !isnothing(s.xlim)
        xlims!(ax, s.xlim[1], s.xlim[2])
    end
    if !isnothing(s.ylim)
        ylims!(ax, s.ylim[1], s.ylim[2])
    end

    s._series = [Observable(Point2f[]) for _ in s._y_indices]
    for (i, idx) in enumerate(s._y_indices)
        lines!(ax, s._series[i], label=headers[idx])
    end
    if length(s._series) > 1
        axislegend(ax)
    end

    s._ax = ax
    s._screen = display(fig)
    s._step = 0
end

function PWNModel.update!(s::LinePlot, w::World)
    PWNModel.update!(s.observer, w)

    if s._step % s.update_interval == 0
        vals = PWNModel.row(s.observer, w)
        x = s._x_index >= 0 ? vals[s._x_index] : Float64(s._step)

        for (i, idx) in enumerate(s._y_indices)
            v = vals[idx]
            if !isnan(v)
                points = s._series[i][]
                push!(points, Point2f(x, v))
                if !isnothing(s.max_values) && length(points) > s.max_values
                    deleteat!(points, 1)
                end
                notify(s._series[i])
            end
        end

        if isnothing(s.xlim) || isnothing(s.ylim)
            autolimits!(s._ax)
        end
    end

    s._step += 1
end

function _find_column(headers::Vector{String}, name::AbstractString)
    idx = findfirst(==(name), headers)
    isnothing(idx) && error("column '$name' not found")
    return idx
end
