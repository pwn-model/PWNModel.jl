
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
WalkDirection component of beetles.

Movement state that a beetle keeps between movement steps (see
`BeetleMovement`) while it is on the way, i.e. when it ran out of distance
budget before arriving:

  - `(dx, dy)`: the direction of its walk away from a tree it left, if the
    walk ended before the beetle left the area attracted by that tree. A unit
    vector, or `(0, 0)` if the beetle is not walking away from a tree. The
    beetle continues the walk in the next step.
  - `feeding`: the beetle's mode (feeding, or egg laying), kept in the next
    step instead of drawing it anew.
  - `on_the_way`: whether the beetle is walking away from a tree, or flying
    towards a target tree it has not reached yet.

All beetles have this component. `WalkDirection()` is the state of a beetle
that is not on the way.

The direction is stored as `Float32` to save memory, and converted back to
`Float64` for all calculations. Both conversions are exact or round to
nearest, the same in the sibling Go implementation.
"""
struct WalkDirection
    dx::Float32
    dy::Float32
    feeding::Bool
    on_the_way::Bool
end

WalkDirection() = WalkDirection(0.0f0, 0.0f0, false, false)
