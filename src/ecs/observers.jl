"""
Row observer interface for the [`CSV`](@ref) reporter.

A row observer supplies column names once via [`header`](@ref), and one
row of `Float64` values per model tick via [`row`](@ref). Concrete
observers should subtype `RowObserver` and implement both; `initialize!`
and `update!` default to no-ops and only need to be specialized when the
observer keeps its own state.

Mirrors `observer.Row` from the sibling Go implementation's
`github.com/mlange-42/ark-tools/observer` package.
"""
abstract type RowObserver end

initialize!(::RowObserver, ::World) = nothing
update!(::RowObserver, ::World) = nothing

"""
Column names for a [`RowObserver`](@ref), in the same order as [`row`](@ref).
"""
function header end

"""
Values for a [`RowObserver`](@ref) at the current model tick, in the order given by [`header`](@ref).
"""
function row end
