"""
Reports the proportion of colonized trees per tick.
"""
struct TreeColonization <: RowObserver
    _result::Vector{Float64}
end

TreeColonization() = TreeColonization([0.0])

header(::TreeColonization) = ["colonized"]

function data(o::TreeColonization, w::World)
    o._result[1] = count_entities(Filter(w, (Colonized,))) / count_entities(Filter(w, (Position,)))

    return o._result
end
