abstract type System end

function initialize!(::System, ::World) end
function update!(::System, ::World) end

"""
    update_ui!(sys::System, world::World)

Updates the UI of `sys`, e.g. redraws a live plot. Called by the
[`Scheduler`](@ref) at its `fps` rate, independent of the ticks that call
[`update!`](@ref). No-op by default.

Mirrors `UISystem.UpdateUI` from the sibling Go implementation's
`github.com/mlange-42/ark-tools/app` package.
"""
function update_ui!(::System, ::World) end
function finalize!(::System, ::World) end
