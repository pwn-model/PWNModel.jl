
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
