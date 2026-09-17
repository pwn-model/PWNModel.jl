
# UpdateTime adds and updates the Time resource.
Base.@kwdef struct UpdateTime <: System
    weeks_per_year::Int
end

function initialize!(::UpdateTime, w::World)
    add_resource!(w, Time())
end

function update!(s::UpdateTime, w::World)
    tick = get_resource(w, Tick).value
    time = get_resource(w, Time)
    time.tick = tick
    time.tick_of_year = tick % s.weeks_per_year
    time.year = tick ÷ s.weeks_per_year
end
