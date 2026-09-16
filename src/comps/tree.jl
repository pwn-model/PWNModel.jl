
struct Position
    x::Int
    y::Int
end

# InCell relation for trees to their containing spatial grid cell.
struct InCell end

# Damaged marks a tree as damaged in the perception of the vector.
struct Damaged end

# NematodeInfected marks a tree as infested with PWN.
struct NematodeInfected end
