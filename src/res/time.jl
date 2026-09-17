
# Time resource
mutable struct Time
    tick::Int
    tick_of_year::Int
    year::Int
end

Time() = Time(0, 0, 0)
