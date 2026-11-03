# NEIGHBOR_OFFSETS are the (dx, dy) offsets of the 8 Moore-neighborhood
# cells around a beetle's current cell, in the same order as the sibling Go
# implementation's `neighborOffsets` (pwn/sys/beetle_movement_by_field.go)
# -- so that random_neighbor and max_field_neighbor draw/break ties
# identically in both implementations from the same seed.
const NEIGHBOR_OFFSETS = (
    (-1, -1), (0, -1), (1, -1),
    (-1, 0), (1, 0),
    (-1, 1), (0, 1), (1, 1),
)

# BeetleMovement system. Moves beetles straight towards the attraction
# source of their current cell (see TreeAttraction), by up to
# distance_per_step meters per step. Mirrors the sibling Go implementation's
# `sys.BeetleMovement`.
mutable struct BeetleMovement <: System
    const steps_per_tick::Int
    const distance_per_step::Float64
    const duration_feeding::Int
    const duration_egg_laying::Int
    const leave_tree_probability::Float64
    const random_walk_probability::Float64

    _feeding_infected::Grid{UInt32}

    _distance_in_cells::Float64
    _width::Int
    _height::Int

    function BeetleMovement(
        steps_per_tick::Int, distance_per_step::Float64, duration_feeding::Int, duration_egg_laying::Int,
        leave_tree_probability::Float64, random_walk_probability::Float64,
    )
        return new(
            steps_per_tick, distance_per_step, duration_feeding, duration_egg_laying,
            leave_tree_probability, random_walk_probability,
            Grid(0, 0, 1, UInt32(0)),
            0.0, 0, 0,
        )
    end
end

BeetleMovement(;
    steps_per_tick::Int, distance_per_step::Float64, duration_feeding::Int, duration_egg_laying::Int,
    leave_tree_probability::Float64, random_walk_probability::Float64,
) = BeetleMovement(
    steps_per_tick,
    distance_per_step,
    duration_feeding,
    duration_egg_laying,
    leave_tree_probability,
    random_walk_probability,
)

function initialize!(s::BeetleMovement, w::World)
    ws = get_resource(w, WorldSize)
    s._feeding_infected = Grid(ws.width, ws.height, ws.cell_size, UInt32(0))
    s._width, s._height = ws.width, ws.height

    add_resource!(w, FeedingInfectedBeetles(s._feeding_infected))

    s._distance_in_cells = s.distance_per_step / ws.cell_size
end

function update!(s::BeetleMovement, w::World)
    time = get_resource(w, Time)
    tick = time.tick
    rng = get_resource(w, Rng)

    healthy = get_resource(w, HealthyTreeAttraction)
    damaged = get_resource(w, DamagedTreeAttraction)

    fill!(s._feeding_infected, UInt32(0))

    for (entities, beetle_positions, emergence_ticks) in Query(w, (BeetlePosition, EmergenceTick))
        for i in eachindex(entities)
            et = emergence_ticks[i]

            if tick < et.tick_of_emergence + s.duration_feeding
                nearest = healthy.source
                presence = healthy.presence
            elseif tick < et.tick_of_emergence + s.duration_feeding + s.duration_egg_laying
                nearest = damaged.source
                presence = damaged.presence
            else
                continue # TODO: remove beetle?
            end

            pos = beetle_positions[i]
            x, y = pos.x, pos.y

            for _ in 1:(s.steps_per_tick)
                max_step = s._distance_in_cells
                if presence[x, y] && rand(rng) < s.leave_tree_probability
                    last_tree = nearest[x, y]
                    offset = random_offset(rng)
                    while nearest[x, y] == last_tree && max_step >= 1
                        x += offset[1]
                        y += offset[2]
                        max_step -= 1 # TODO: exact cost for diagonal steps?
                        if !checkbounds(Bool, presence, x, y)
                            x -= offset[1]
                            y -= offset[2]
                            offset = random_offset(rng)
                            continue
                        end
                    end
                end

                if presence[x, y]
                    s._feeding_infected[x, y] += UInt32(1)
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
                end
            end

            beetle_positions[i] = BeetlePosition(x, y)
        end
    end
end

function random_offset(rng::Rng)
    return NEIGHBOR_OFFSETS[frozen_rand_range(rng.xoshiro, UInt64(length(NEIGHBOR_OFFSETS)))+1]
end
