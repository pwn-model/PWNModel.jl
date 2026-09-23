using Ark
using PWNModel
using GLMakie

"""
Live matrix-image plot reporter system. Draws the values of a
[`MatrixObserver`](@ref) as a color-mapped image in its own GLMakie window,
copying each tick's matrix into a reused backing buffer and re-uploading it
to the GPU via `notify`.

Mirrors `plot.Image` from the sibling Go implementation's
`github.com/mlange-42/ark-pixel/plot` package, adapted to Makie's built-in
`colormap`/`colorrange` value-to-color mapping (done on the GPU) instead of
a `colorgrad` gradient and a manually maintained RGBA pixel buffer. Makie's
`Axis` also takes care of scaling the image to the window while preserving
its aspect ratio, so there is no equivalent of the Go type's `Scale` field.
A `Colorbar` legend for the color scale is added alongside the image, which
the Go original (drawing directly onto a `pixel.Window` canvas) has no
equivalent of.

Not part of the `PWNModel` package: GLMakie pulls in a full OpenGL stack, so
this file lives in `scripts/` (a dependency of the `scripts/` environment
only, see `scripts/Project.toml`) and is `include`d directly by run scripts
rather than exported from the package.
"""
mutable struct Image <: PWNModel.System
    const observer::PWNModel.MatrixObserver
    const title::String
    const colormap::Symbol
    const colorrange::Tuple{Float64,Float64}

    _values::Union{Observable{Matrix{Float64}},Nothing}
    _screen::Any
end

"""
    Image(; observer, title="", colormap=:viridis, colorrange=(0.0, 1.0))

  - `observer`: the [`MatrixObserver`](@ref) supplying the 2D value matrix.
  - `colormap`: Makie colormap used to map values to colors. A `Symbol` (e.g.
    `:viridis`) or a `String` (e.g. from a config file, which has no `Symbol`
    literal syntax).
  - `colorrange`: `(min, max)` value range for the color mapping. Defaults to
    `(0.0, 1.0)`, matching the Go original's default when neither bound is
    given. A `Tuple` or, e.g. from a config file's YAML sequence, any other
    2-element `AbstractVector`.
"""
function Image(;
    observer::PWNModel.MatrixObserver,
    title::AbstractString="",
    colormap::Union{Symbol,AbstractString}=:viridis,
    colorrange::Union{Tuple{<:Real,<:Real},AbstractVector{<:Real}}=(0.0, 1.0),
)
    return Image(
        observer,
        String(title),
        Symbol(colormap),
        (Float64(colorrange[1]), Float64(colorrange[2])),
        nothing,
        nothing,
    )
end

"""
GLMakie screen the plot was displayed on, e.g. to `wait` on it so the window
stays open after a script's `run!` call returns.
"""
screen(p::Image) = p._screen

function PWNModel.initialize!(s::Image, w::World)
    PWNModel.initialize!(s.observer, w)

    GLMakie.activate!()

    fig = Figure()
    ax = Axis(fig[1, 1], title=s.title, aspect=DataAspect())
    hidedecorations!(ax)

    s._values = Observable(PWNModel.data(s.observer, w))
    image!(ax, s._values, colormap=s.colormap, colorrange=s.colorrange, interpolate=false)
    Colorbar(fig[1, 2], colormap=s.colormap, colorrange=s.colorrange)

    # display(fig) alone would draw into GLMakie's shared singleton screen,
    # which other plots (e.g. TimeSeries, TreesMap) also default to -- stealing
    # their window instead of opening a separate one. An explicit Screen avoids that.
    s._screen = GLMakie.Screen(title=isempty(s.title) ? "Makie" : s.title)
    display(s._screen, fig)
end

function PWNModel.update!(s::Image, w::World)
    PWNModel.update!(s.observer, w)

    values = s._values[]
    values .= PWNModel.data(s.observer, w)
    notify(s._values)
end
