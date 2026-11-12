# BeetleMovement system. Moves beetles straight towards the attraction
# source of their current cell (see TreeAttraction), by up to
# distance_per_step meters per step. Mirrors the sibling Go implementation's
# `sys.BeetleMovement`.
mutable struct BeetleMovement <: System
    const steps_per_tick::Int
    const distance_per_step::Float64
    # emergence_flight_distance is the maximum distance, in meters, of the
    # undirected flight that beetles make in their first movement step after
    # emergence, before flying towards a target. The actual distance is
    # drawn uniformly between 0 and this value. Spreads out the beetles
    # emerging from the same tree, which would otherwise all fly to the same
    # first target.
    const emergence_flight_distance::Float64
    const duration_feeding::Int
    # feeding_probability is the probability that a beetle past
    # duration_feeding feeds (targets healthy trees) instead of laying eggs
    # (targets damaged trees), drawn anew each movement step.
    const feeding_probability::Float64
    const leave_tree_probability::Float64

    _feeding_infected::Grid{UInt32}

    # _to_remove is a reused buffer for beetles that left the world.
    _to_remove::Vector{Entity}

    _distance_in_cells::Float64
    _emergence_flight_in_cells::Float64
    _width::Int
    _height::Int

    function BeetleMovement(
        steps_per_tick::Int, distance_per_step::Float64, emergence_flight_distance::Float64, duration_feeding::Int,
        feeding_probability::Float64, leave_tree_probability::Float64,
    )
        return new(
            steps_per_tick, distance_per_step, emergence_flight_distance, duration_feeding,
            feeding_probability, leave_tree_probability,
            Grid(0, 0, 1, UInt32(0)), Entity[],
            0.0, 0.0, 0, 0,
        )
    end
end

BeetleMovement(;
    steps_per_tick::Int, distance_per_step::Float64, emergence_flight_distance::Float64, duration_feeding::Int,
    feeding_probability::Float64, leave_tree_probability::Float64,
) = BeetleMovement(
    steps_per_tick,
    distance_per_step,
    emergence_flight_distance,
    duration_feeding,
    feeding_probability,
    leave_tree_probability,
)

function initialize!(s::BeetleMovement, w::World)
    ws = get_resource(w, WorldSize)
    s._feeding_infected = Grid(ws.width, ws.height, ws.cell_size, UInt32(0))
    s._width, s._height = ws.width, ws.height

    add_resource!(w, FeedingInfectedBeetles(s._feeding_infected))

    s._distance_in_cells = s.distance_per_step / ws.cell_size
    s._emergence_flight_in_cells = s.emergence_flight_distance / ws.cell_size
end

function update!(s::BeetleMovement, w::World)
    time = get_resource(w, Time)
    tick = time.tick
    rng = get_resource(w, Rng)

    healthy = get_resource(w, HealthyTreeAttraction)
    damaged = get_resource(w, DamagedTreeAttraction)

    fill!(s._feeding_infected, UInt32(0))

    for (entities, beetle_positions, emergence_ticks, walk_directions) in
        Query(w, (BeetlePosition, EmergenceTick, WalkDirection))
        for i in eachindex(entities)
            et = emergence_ticks[i]

            pos = beetle_positions[i]
            x, y = pos.x, pos.y
            wd = walk_directions[i]

            for step in 1:(s.steps_per_tick)
                # A beetle still on the way keeps its mode.
                walking = wd.dx != 0 || wd.dy != 0
                if wd.on_the_way
                    is_feeding = wd.feeding
                else
                    is_feeding = true
                    if tick >= et.tick_of_emergence + s.duration_feeding
                        is_feeding = rand(rng) < s.feeding_probability
                    end
                end

                if is_feeding
                    nearest = healthy.source
                    presence = healthy.presence
                else
                    nearest = damaged.source
                    presence = damaged.presence
                end

                max_step = s._distance_in_cells
                inside = true
                if step == 1 && tick == et.tick_of_emergence
                    # Undirected flight away from the tree the beetle emerged
                    # from, in one go, in a uniformly random direction. Without
                    # any emergence flight, no random numbers are drawn for it.
                    if s._emergence_flight_in_cells > 0
                        flight = min(rand(rng) * s._emergence_flight_in_cells, max_step)
                        dx, dy = random_direction(rng)
                        x += round(Int, dx * flight, RoundNearestTiesAway)
                        y += round(Int, dy * flight, RoundNearestTiesAway)
                        max_step -= flight
                        inside = checkbounds(Bool, nearest, x, y)
                    end
                elseif walking || (presence[x, y] && rand(rng) < s.leave_tree_probability)
                    # Walk out of the area attracted by the tree the beetle leaves,
                    # in a new random direction, or in the stored one if the beetle
                    # is still walking away from a tree it left in an earlier step.
                    dx, dy = walking ? (Float64(wd.dx), Float64(wd.dy)) : random_direction(rng)
                    x, y, max_step, inside, left_area = walk(nearest, x, y, max_step, dx, dy)
                    if inside && !left_area
                        # Out of budget before leaving the area. Continue in the next step.
                        wd = WalkDirection(Float32(dx), Float32(dy), is_feeding, true)
                        continue
                    end
                    wd = WalkDirection()
                end

                if !inside
                    # The beetle left the world and dies.
                    push!(s._to_remove, entities[i])
                    break
                end

                if presence[x, y]
                    s._feeding_infected[x, y] += UInt32(1)
                    wd = WalkDirection()
                    continue
                end

                max_step_sq = max_step * max_step

                tx, ty = cell_coords(nearest, nearest[x, y])
                dx, dy = Float64(tx - x), Float64(ty - y)
                dist_sq = dx * dx + dy * dy
                if dist_sq <= max_step_sq
                    x, y = tx, ty
                else
                    # Go's math.Round rounds halves away from zero,
                    # Julia's default round to even.
                    frac = max_step / sqrt(dist_sq)
                    x += round(Int, dx * frac, RoundNearestTiesAway)
                    y += round(Int, dy * frac, RoundNearestTiesAway)
                end

                if presence[x, y]
                    s._feeding_infected[x, y] += UInt32(1)
                    wd = WalkDirection()
                else
                    # Out of budget before reaching the target. Continue in the next step.
                    wd = WalkDirection(0.0f0, 0.0f0, is_feeding, true)
                end
            end

            beetle_positions[i] = BeetlePosition(x, y)
            walk_directions[i] = wd
        end
    end

    for e in s._to_remove
        remove_entity!(w, e)
    end
    empty!(s._to_remove)
end

# walk moves (x, y) along a straight line in direction (dx, dy), a unit
# vector, out of the area of the source the beetle is in. It advances in
# steps of one cell size of distance, each costing 1 of the budget, and stops
# as soon as the cell's source differs, or the remaining budget (in cells) is
# below 1. Returns the new position, the remaining budget, false if the
# beetle left the grid (the position is then outside of it), and whether it
# left the source's area. Mirrors the sibling Go implementation's walk.
function walk(source::Grid{UInt32}, x::Int, y::Int, budget::Float64, dx::Float64, dy::Float64)
    leaving = source[x, y]
    x0, y0 = x, y
    k = 1
    while budget >= 1 && source[x, y] == leaving
        x = x0 + round(Int, k * dx, RoundNearestTiesAway)
        y = y0 + round(Int, k * dy, RoundNearestTiesAway)
        budget -= 1
        if !checkbounds(Bool, source, x, y)
            return x, y, budget, false, true
        end
        k += 1
    end
    return x, y, budget, true, source[x, y] != leaving
end
