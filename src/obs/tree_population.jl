"""
Reports total and damaged tree counts per model tick.
"""
struct TreePopulationObserver <: RowObserver
    _result::Vector{Float64}
end

TreePopulationObserver() = TreePopulationObserver([0.0, 0.0, 0.0, 0.0])

header(::TreePopulationObserver) = ["total", "damaged", "infected", "damaged_infected"]

function row(o::TreePopulationObserver, w::World)
    o._result[1] = count_entities(Filter(w, (Position,)))
    o._result[2] = count_entities(Filter(w, (Damaged,), without=(Infected,)))
    o._result[3] = count_entities(Filter(w, (Infected,), without=(Damaged,)))
    o._result[4] = count_entities(Filter(w, (Damaged, Infected)))

    return o._result
end
