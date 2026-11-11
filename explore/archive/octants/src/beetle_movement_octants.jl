# BeetleMovementOctants system. Like BeetleMovement, but instead of flying
# towards the single attraction source of their current cell, beetles
# select one of the 8 octants around their cell by roulette selection,
# weighted by the attraction values of the octants' sources (see
# TreeAttractionOctants), and fly straight towards that octant's source, by
# up to distance_per_step meters per step.
#
# The selection is memoryless: a beetle that does not reach its target
# within a step selects anew, from the octants of the cell it got to, in its
# next step.
#
# A beetle leaving a tree selects among the octants of the tree's cell right
# away, without first walking out of the tree's area as in BeetleMovement:
# a cell's own tree is never one of its octant sources, so the other trees
# around it are available directly.
#
# A beetle whose cell has no source in any octant (no tree of the wanted
# type visible) stays where it is, without drawing a random number.
mutable struct BeetleMovementOctants <: System
    const steps_per_tick::Int
    const distance_per_step::Float64
    # emergence_flight_distance is the maximum distance, in meters, of the
    # undirected flight that beetles make in their first movement step after
    # emergence, before flying towards a target. The actual distance is
    # drawn uniformly between 0 and this value. See BeetleMovement.
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

    function BeetleMovementOctants(
        steps_per_tick::Int, distance_per_step::Float64, emergence_flight_distance::Float64, duration_feeding::Int,
        feeding_probability::Float64, leave_tree_probability::Float64,
    )
        return new(
            steps_per_tick, distance_per_step, emergence_flight_distance, duration_feeding,
            feeding_probability, leave_tree_probability,
            Grid(0, 0, 1, UInt32(0)), Entity[],
            0.0, 0.0,
        )
    end
end

BeetleMovementOctants(;
    steps_per_tick::Int, distance_per_step::Float64, emergence_flight_distance::Float64, duration_feeding::Int,
    feeding_probability::Float64, leave_tree_probability::Float64,
) = BeetleMovementOctants(
    steps_per_tick,
    distance_per_step,
    emergence_flight_distance,
    duration_feeding,
    feeding_probability,
    leave_tree_probability,
)

function initialize!(s::BeetleMovementOctants, w::World)
    ws = get_resource(w, WorldSize)
    s._feeding_infected = Grid(ws.width, ws.height, ws.cell_size, UInt32(0))

    add_resource!(w, FeedingInfectedBeetles(s._feeding_infected))

    s._distance_in_cells = s.distance_per_step / ws.cell_size
    s._emergence_flight_in_cells = s.emergence_flight_distance / ws.cell_size
end

function update!(s::BeetleMovementOctants, w::World)
    time = get_resource(w, Time)
    tick = time.tick
    rng = get_resource(w, Rng)

    healthy = get_resource(w, HealthyTreeAttractionOctants)
    damaged = get_resource(w, DamagedTreeAttractionOctants)

    fill!(s._feeding_infected, UInt32(0))

    for (entities, beetle_positions, emergence_ticks) in Query(w, (BeetlePosition, EmergenceTick))
        for i in eachindex(entities)
            et = emergence_ticks[i]

            pos = beetle_positions[i]
            x, y = pos.x, pos.y

            for step in 1:(s.steps_per_tick)
                is_feeding = true
                if tick >= et.tick_of_emergence + s.duration_feeding
                    is_feeding = rand(rng) < s.feeding_probability
                end

                octants = is_feeding ? healthy : damaged
                sources = octants.sources
                presence = octants.presence

                max_step = s._distance_in_cells
                inside = true
                leaving = false
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
                        inside = checkbounds(Bool, presence, x, y)
                    end
                elseif presence[x, y] && rand(rng) < s.leave_tree_probability
                    leaving = true
                end

                if !inside
                    # The beetle left the world and dies.
                    push!(s._to_remove, entities[i])
                    break
                end

                if presence[x, y] && !leaving
                    s._feeding_infected[x, y] += UInt32(1)
                    continue
                end

                k = select_octant(rng, sources[x, y])
                if k == 0
                    # No tree visible: stay in place.
                    if presence[x, y]
                        s._feeding_infected[x, y] += UInt32(1)
                    end
                    continue
                end

                ox, oy = sources[x, y].offsets[k]
                dx, dy = Float64(ox), Float64(oy)
                dist_sq = dx * dx + dy * dy
                if dist_sq <= max_step * max_step
                    x += Int(ox)
                    y += Int(oy)
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

    for e in s._to_remove
        remove_entity!(w, e)
    end
    empty!(s._to_remove)
end

# select_octant selects one of the octants of r by roulette selection,
# with probabilities proportional to the octants' attraction values. Returns
# the selected octant, or 0 without drawing a random number if all octants
# are empty.
#
# The attraction values are summed as Float64, in octant order, both for
# the total and the running sum the draw is compared against, so the final
# running sum equals the total exactly. A draw that rounds up to the total
# selects the last non-empty octant.
function select_octant(rng::Rng, r::OctantSources)
    total = 0.0
    for a in r.attraction
        total += Float64(a)
    end
    if total <= 0
        return 0
    end

    u = rand(rng) * total
    acc = 0.0
    last = 0
    for k in 1:8
        a = Float64(r.attraction[k])
        if a > 0
            acc += a
            if u < acc
                return k
            end
            last = k
        end
    end
    return last
end
