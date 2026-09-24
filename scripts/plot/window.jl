using Ark
using PWNModel
using GLMakie

# Window handling shared by the live plot systems (Image, TimeSeries, TreesMap).

"""
    plot_window(title::AbstractString, fig::Figure) -> GLMakie.Screen

Displays `fig` in a new GLMakie window titled `title` (or "Makie" if empty).

`display(fig)` alone would draw into GLMakie's shared singleton screen, which
all plots default to -- each stealing the previous one's window instead of
opening a separate one. An explicit Screen avoids that.

The window's render loop polls at 120 FPS, so that it is ready to draw
whenever the model's [`Scheduler`](@ref) briefly yields to it after a UI
update, even at unlimited tick rates. It only actually renders after updates.

The window's render loop runs with Ctrl+C deferred. Otherwise, a Ctrl+C
pressed while the render loop task happens to be running (e.g. while the model
sleeps to cap its tick rate) is thrown into that task instead of the model's,
breaking the window's OpenGL state and requiring a second Ctrl+C to actually
stop the run. Deferred, it is delivered to the model's task instead.
"""
function plot_window(title::AbstractString, fig::Figure)
    screen = GLMakie.Screen(
        title=isempty(title) ? "Makie" : title,
        renderloop=_sigint_deferred_renderloop,
        framerate=120.0,
    )
    display(screen, fig)
    return screen
end

_sigint_deferred_renderloop(screen::GLMakie.Screen) = disable_sigint(() -> GLMakie.renderloop(screen))

"""
    window_closed!(screen, w::World) -> Bool

Checks whether the user closed `screen`'s window (e.g. via its X button). If
so, closes all other plot windows along with it, requests termination of the
run via the [`Termination`](@ref) resource, and returns `true`.
"""
function window_closed!(screen::GLMakie.Screen, w::World)
    isopen(screen) && return false

    GLMakie.closeall()
    get_resource(w, Termination).terminate = true
    return true
end
