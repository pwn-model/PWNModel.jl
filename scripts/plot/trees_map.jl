using Ark
using PWNModel
using GLMakie

"""
Live grid-map plot system. Draws the tree grid as a color image in its own
GLMakie window, mutating a pixel-buffer matrix in place each tick and
re-uploading it to the GPU via `notify`, instead of drawing one mark per
tree entity.

Mirrors `maps.Trees` from the sibling Go implementation's
`github.com/pwn-model/pwn/obs/maps` package, adapted to GLMakie's
`image!`/`Observable` update model instead of a `pixel` canvas blit.

Not part of the `PWNModel` package: GLMakie pulls in a full OpenGL stack, so
this file lives in `scripts/` (a dependency of the `scripts/` environment
only, see `scripts/Project.toml`) and is `include`d directly by run scripts
rather than exported from the package.
"""
mutable struct TreesMap <: PWNModel.System
    const title::String

    _pixels::Union{Observable{Matrix{RGBAf}},Nothing}
    _screen::Any
end

"""
    TreesMap(; title="")
"""
function TreesMap(; title::AbstractString="")
    return TreesMap(String(title), nothing, nothing)
end

"""
GLMakie screen the map was displayed on, e.g. to `wait` on it so the window
stays open after a script's `run!` call returns.
"""
screen(m::TreesMap) = m._screen

const _BACKGROUND_COLOR = RGBAf(0, 0, 0, 1)
const _TREE_COLOR = RGBAf(0 / 255, 200 / 255, 0 / 255, 1)
const _DAMAGED_COLOR = RGBAf(0 / 255, 0 / 255, 160 / 255, 1)
const _COLONIZED_COLOR = RGBAf(200 / 255, 0 / 255, 200 / 255, 1)
const _INFECTED_COLOR = RGBAf(255 / 255, 0 / 255, 0 / 255, 160 / 255)

function PWNModel.initialize!(s::TreesMap, w::World)
    ws = get_resource(w, WorldSize)

    GLMakie.activate!()

    fig = Figure()
    ax = Axis(fig[1, 1], title=s.title, aspect=DataAspect())
    hidedecorations!(ax)

    s._pixels = Observable(fill(_BACKGROUND_COLOR, ws.width, ws.height))
    image!(ax, s._pixels, interpolate=false)

    # display(fig) alone would draw into GLMakie's shared singleton screen,
    # which other plots (e.g. TimeSeries) also default to -- stealing their
    # window instead of opening a separate one. An explicit Screen avoids that.
    s._screen = GLMakie.Screen()
    display(s._screen, fig)
end

function PWNModel.update!(s::TreesMap, w::World)
    pixels = s._pixels[]
    fill!(pixels, _BACKGROUND_COLOR)

    for (_, positions) in Query(w, (Position,); without=(Damaged,))
        for pos in positions
            pixels[pos.x, pos.y] = _TREE_COLOR
        end
    end

    for (_, positions) in Query(w, (Position,); with=(Damaged,), without=(Colonized,))
        for pos in positions
            pixels[pos.x, pos.y] = _DAMAGED_COLOR
        end
    end

    for (_, positions) in Query(w, (Position,); with=(Colonized,))
        for pos in positions
            pixels[pos.x, pos.y] = _COLONIZED_COLOR
        end
    end

    for (_, positions) in Query(w, (Position,); with=(Infected,))
        for pos in positions
            pixels[pos.x, pos.y] = _INFECTED_COLOR
        end
    end

    notify(s._pixels)
end
