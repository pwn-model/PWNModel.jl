"""
Reports the proportion of damaged trees per tick.
"""
struct TreeDamage <: RowObserver
    _result::Vector{Float64}
end

TreeDamage() = TreeDamage([0.0])

header(::TreeDamage) = ["damaged"]

function data(o::TreeDamage, w::World)
    o._result[1] = count_entities(Filter(w, (Damaged,))) / count_entities(Filter(w, (Position,)))

    return o._result
end
