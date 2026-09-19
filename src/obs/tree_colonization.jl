"""
Reports the proportion of colonized trees per tick.
"""
struct TreeColonizationObserver <: RowObserver
    _result::Vector{Float64}
end

TreeColonizationObserver() = TreeColonizationObserver([0.0])

header(::TreeColonizationObserver) = ["damaged"]

function data(o::TreeColonizationObserver, w::World)
    o._result[1] = count_entities(Filter(w, (Colonized,))) / count_entities(Filter(w, (Position,)))

    return o._result
end
