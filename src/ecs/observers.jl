"""
Row observer interface.

A row observer supplies column names once via [`header`](@ref),
and one row of `Float64` values per model tick via [`data`](@ref).
Concrete observers should subtype `RowObserver` and implement both;
`initialize!` and `update!` default to no-ops and only need
to be specialized when the observer keeps its own state.

Mirrors `observer.Row` from the sibling Go implementation's
`github.com/mlange-42/ark-tools/observer` package.
"""
abstract type RowObserver end

initialize!(::RowObserver, ::World) = nothing
update!(::RowObserver, ::World) = nothing

"""
Column names for a [`RowObserver`](@ref), in the same order as [`row`](@ref).
"""
header(o::RowObserver) = error("header not implemented for $(typeof(o))")

"""
Values for a [`RowObserver`](@ref) at the current model tick, in the order given by [`header`](@ref).
"""
data(o::RowObserver, ::World)::AbstractVector{Float64} = error("data not implemented for $(typeof(o))")

"""
Matrix observer interface.

A matrix observer supplies a 2D array of `Float64`
values per model tick via [`data`](@ref).
Concrete observers should subtype `RowObserver` and implement both;
`initialize!` and `update!` default to no-ops and only need
to be specialized when the observer keeps its own state.
"""
abstract type MatrixObserver end

initialize!(::MatrixObserver, ::World) = nothing
update!(::MatrixObserver, ::World) = nothing

"""
Values for a [`MatrixObserver`](@ref) at the current model tick.
"""
data(o::MatrixObserver, ::World)::Matrix{Float64} = error("data not implemented for $(typeof(o))")
