"""
Reports total and damaged tree counts per model tick.
"""
struct TreePopulationObserver <: RowObserver
    _result::Vector{Float64}
end

TreePopulationObserver() = TreePopulationObserver([0.0, 0.0])

header(::TreePopulationObserver) = ["total", "damaged"]

function row(o::TreePopulationObserver, w::World)
    o._result[1] = count_entities(Filter(w, (Position,)))
    o._result[2] = count_entities(Filter(w, (Damaged,)))
    return o._result
end
