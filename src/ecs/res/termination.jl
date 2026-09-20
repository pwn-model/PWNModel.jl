"""
Termination resource holding whether the simulation should terminate after the current step.

Added by the [`Scheduler`](@ref). Can be set by systems, e.g. [`FixedTermination`](@ref),
and is checked by [`step!`](@ref)/[`run!`](@ref) to decide whether to continue the run.

Mirrors `resource.Termination` from the sibling Go implementation's
`github.com/mlange-42/ark-tools/resource` package.
"""
mutable struct Termination
    terminate::Bool
end

Termination() = Termination(false)
