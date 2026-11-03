
"""
BeetlePosition component.
"""
struct BeetlePosition
    x::Int
    y::Int
end

"""
EmergenceTick component of beetles.
"""
struct EmergenceTick
    tick_of_emergence::Int
end

"""
LifeExpectancy component of beetles.
"""
struct LifeExpectancy
    tick_of_death::Int
end

"""
LastTree component of beetles, storing the last tree visited, as a cell
index (see `cell_index`), or `NO_CELL` if none.
"""
struct LastTree
    index::UInt32
end
