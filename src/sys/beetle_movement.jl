
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

    _feeding_infected::Grid{UInt32}

    # _candidates is a reused buffer for max_field_neighbor's tied
    # candidates, as indices into NEIGHBOR_OFFSETS.
    _candidates::Vector{UInt8}

    _width::Int
    _height::Int

    function BeetleMovement(
        steps_per_tick::Int, duration_feeding::Int, duration_egg_laying::Int,
        leave_tree_probability::Float64, random_walk_probability::Float64,
    )
        return new(
            steps_per_tick, duration_feeding, duration_egg_laying,
            leave_tree_probability, random_walk_probability,
            Grid(0, 0, 1, UInt32(0)),
            Vector{UInt8}(undef, length(NEIGHBOR_OFFSETS)), 0, 0,
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
    s._feeding_infected = Grid(ws.width, ws.height, ws.cell_size, UInt32(0))
    s._width, s._height = ws.width, ws.height

    add_resource!(w, FeedingInfectedBeetles(s._feeding_infected))
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
                field = healthy.attraction
                presence = healthy.presence
            elseif tick < et.tick_of_emergence + s.duration_feeding + s.duration_egg_laying
                field = damaged.attraction
                presence = damaged.presence
            else
                continue # TODO: remove beetle?
            end

            pos = beetle_positions[i]
            x, y = pos.x, pos.y

            for _ in 1:(s.steps_per_tick)
                tree_here = presence[x, y]
                if !tree_here || rand(rng) < s.leave_tree_probability
                    if rand(rng) < s.random_walk_probability
                        x, y = random_neighbor(s, rng, x, y)
                    else
                        x, y = max_field_neighbor(s, rng, field, x, y)
                    end
                    tree_here = presence[x, y]
                end

                if !tree_here
                    continue
                end

                s._feeding_infected[x, y] += UInt32(1)
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
# with the highest value in field. Ties are broken uniformly at random, so
# that a flat field doesn't bias movement towards the first NEIGHBOR_OFFSETS.
# Draws a random number only if there is a tie, via frozen_rand_range (see
# random_neighbor). Mirrors the sibling Go implementation's maxFieldNeighbor,
# which uses a stack array instead of the reused _candidates buffer.
function max_field_neighbor(s::BeetleMovement, rng::Rng, field::Grid{Float64}, x::Int, y::Int)
    candidates = s._candidates
    n = 0
    best_v = 0.0
    for (i, o) in enumerate(NEIGHBOR_OFFSETS)
        nx, ny = x + o[1], y + o[2]
        if nx < 1 || nx > s._width || ny < 1 || ny > s._height
            continue
        end
        v = field[nx, ny]
        if n == 0 || v > best_v
            best_v = v
            candidates[1] = UInt8(i)
            n = 1
        elseif v == best_v
            n += 1
            candidates[n] = UInt8(i)
        end
    end

    if n == 0
        return x, y
    elseif n == 1
        o = NEIGHBOR_OFFSETS[candidates[1]]
        return x + o[1], y + o[2]
    else
        o = NEIGHBOR_OFFSETS[candidates[frozen_rand_range(rng.xoshiro, UInt64(n))+1]]
        return x + o[1], y + o[2]
    end
end
