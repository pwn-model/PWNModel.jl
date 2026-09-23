
# NEIGHBOR_OFFSETS are the (dx, dy) offsets of the 8 Moore-neighborhood
# cells around a beetle's current cell, in the same order as the sibling Go
# implementation's `neighborOffsets` (pwn/sys/beetle_movement.go) -- so that
# random_neighbor and max_field_neighbor draw/break ties identically in
# both implementations from the same seed.
const NEIGHBOR_OFFSETS = (
    (-1, -1), (0, -1), (1, -1),
    (-1, 0), (1, 0),
    (-1, 1), (0, 1), (1, 1),
)

# BeetleMovement system. Mirrors the sibling Go implementation's
# `sys.BeetleMovement`.
mutable struct BeetleMovement <: System
    const steps_per_tick::Int
    const duration_feeding::Int
    const duration_egg_laying::Int
    const leave_tree_probability::Float64
    const random_walk_probability::Float64

    _healthy_presence::Grid{Bool}
    _damaged_presence::Grid{Bool}

    _width::Int
    _height::Int

    _filter::Filter
    _filter_healthy::Filter
    _filter_damaged::Filter

    function BeetleMovement(
        steps_per_tick::Int, duration_feeding::Int, duration_egg_laying::Int,
        leave_tree_probability::Float64, random_walk_probability::Float64,
    )
        return new(
            steps_per_tick, duration_feeding, duration_egg_laying,
            leave_tree_probability, random_walk_probability,
            Grid(0, 0, 1, false), Grid(0, 0, 1, false), 0, 0,
        )
    end
end

BeetleMovement(;
    steps_per_tick::Int, duration_feeding::Int, duration_egg_laying::Int,
    leave_tree_probability::Float64, random_walk_probability::Float64,
) = BeetleMovement(
    steps_per_tick,
    duration_feeding,
    duration_egg_laying,
    leave_tree_probability,
    random_walk_probability,
)

function initialize!(s::BeetleMovement, w::World)
    ws = get_resource(w, WorldSize)
    s._healthy_presence = Grid(ws.width, ws.height, ws.cell_size, false)
    s._damaged_presence = Grid(ws.width, ws.height, ws.cell_size, false)
    s._width, s._height = ws.width, ws.height

    s._filter = Filter(w, (BeetlePosition, EmergenceTick))
    s._filter_healthy = Filter(w, (Position,); without=(Damaged,))
    s._filter_damaged = Filter(w, (Position,); with=(Damaged,))
end

function update!(s::BeetleMovement, w::World)
    time = get_resource(w, Time)
    tick = time.tick
    rng = get_resource(w, Rng)
    healthy_field = get_resource(w, HealthyTreeAttraction).grid
    damaged_field = get_resource(w, DamagedTreeAttraction).grid

    presence_calculated = false

    for (entities, beetle_positions, emergence_ticks) in Query(s._filter)
        if !presence_calculated
            calc_presence!(s)
            presence_calculated = true
        end

        for i in eachindex(entities)
            et = emergence_ticks[i]

            if tick < et.tick_of_emergence + s.duration_feeding
                field = healthy_field
                presence = s._healthy_presence
            elseif tick < et.tick_of_emergence + s.duration_feeding + s.duration_egg_laying
                field = damaged_field
                presence = s._damaged_presence
            else
                continue # TODO: remove beetle?
            end

            pos = beetle_positions[i]
            x, y = pos.x, pos.y

            for _ in 1:(s.steps_per_tick)
                tree_here = presence[x, y]
                if !tree_here || rand(rng) >= s.leave_tree_probability
                    if rand(rng) < s.random_walk_probability
                        x, y = random_neighbor(s, rng, x, y)
                    else
                        x, y = max_field_neighbor(s, field, x, y)
                    end
                    tree_here = presence[x, y]
                end

                if !tree_here
                    continue
                end

                # TODO: something with the tree...
            end

            beetle_positions[i] = BeetlePosition(x, y)
        end
    end
end

# random_neighbor picks a uniformly random in-bounds Moore-neighborhood cell
# of (x, y), by rejection sampling: interior cells (the common case)
# resolve in a single draw, and only edge/corner cells ever redraw.
#
# Draws the offset index via frozen_rand_range (src/util/shuffle.jl) rather
# than `rand(rng.xoshiro, 1:8)`: Julia's own range sampler is not a stable
# target (see frozen_shuffle!'s docstring), and this keeps the draw
# bit-identical with the sibling Go implementation's util.RandRange (see
# pwn/util/random.go and pwn/sys/beetle_movement.go's randomNeighbor).
function random_neighbor(s::BeetleMovement, rng::Rng, x::Int, y::Int)
    while true
        o = NEIGHBOR_OFFSETS[frozen_rand_range(rng.xoshiro, UInt64(length(NEIGHBOR_OFFSETS)))+1]
        nx, ny = x + o[1], y + o[2]
        if nx >= 1 && nx <= s._width && ny >= 1 && ny <= s._height
            return nx, ny
        end
    end
end

# max_field_neighbor picks the in-bounds Moore-neighborhood cell of (x, y)
# with the highest value in field, breaking ties by NEIGHBOR_OFFSETS order.
function max_field_neighbor(s::BeetleMovement, field::Grid{Float64}, x::Int, y::Int)
    best_x, best_y = x, y
    has_best = false
    best_v = 0.0
    for o in NEIGHBOR_OFFSETS
        nx, ny = x + o[1], y + o[2]
        if nx < 1 || nx > s._width || ny < 1 || ny > s._height
            continue
        end
        v = field[nx, ny]
        if !has_best || v > best_v
            best_v = v
            best_x, best_y = nx, ny
            has_best = true
        end
    end
    return best_x, best_y
end

function calc_presence!(s::BeetleMovement)
    fill!(s._healthy_presence, false)
    fill!(s._damaged_presence, false)

    for (_, positions) in Query(s._filter_healthy)
        for pos in positions
            s._healthy_presence[pos.x, pos.y] = true
        end
    end

    for (_, positions) in Query(s._filter_damaged)
        for pos in positions
            s._damaged_presence[pos.x, pos.y] = true
        end
    end
end
