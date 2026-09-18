module PWNModel

using Ark
using Random

include("util/timer.jl")
include("util/shuffle.jl")

include("ecs/tick.jl")
include("ecs/observers.jl")
include("ecs/scheduler.jl")
include("ecs/system.jl")
include("ecs/reporter/csv_reporter.jl")

include("comps/tree.jl")
include("comps/cell.jl")
include("res/entity_grid.jl")
include("res/space_grid.jl")
include("res/world_size.jl")
include("res/rng.jl")
include("res/time.jl")

include("sys/init_grids.jl")
include("sys/init_trees.jl")
include("sys/update_time.jl")
include("sys/disease_course.jl")
include("sys/random_infection.jl")
include("sys/damage_trees.jl")

include("obs/tree_population.jl")
include("obs/tree_damage.jl")
include("obs/tree_colonization.jl")

include("util/print.jl")

function __init__()
    _init_timer()
end

export Scheduler, fps!, initialize!, step!, finalize!, run!

export RowObserver, header, row, CSV
export Rng, Tick, Time
export EntityGrid, SpaceGrid, WorldSize
export Position, InCell, Damaged, Infected, Colonized
export GridCoords
export InitGrids, InitTrees
export UpdateTime, DiseaseCourse, RandomInfection, DamageTrees
export TreePopulationObserver, TreeDamageObserver, TreeColonizationObserver
export trees_to_string

end
