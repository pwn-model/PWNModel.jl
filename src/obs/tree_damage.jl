"""
Reports the proportion of damaged trees per tick.
"""
struct TreeDamageObserver <: RowObserver
    _result::Vector{Float64}
end

TreeDamageObserver() = TreeDamageObserver([0.0])

header(::TreeDamageObserver) = ["damaged"]

function row(o::TreeDamageObserver, w::World)
    o._result[1] = count_entities(Filter(w, (Damaged,))) / count_entities(Filter(w, (Position,)))

    return o._result
end
