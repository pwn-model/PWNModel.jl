module PWNModel

using Ark
using Random
using YAML

include("util/timer.jl")
include("util/shuffle.jl")

include("ecs/res/tick.jl")
include("ecs/res/termination.jl")
include("ecs/system.jl")
include("ecs/config.jl")
include("ecs/sys/fixed_termination.jl")
include("ecs/observers.jl")
include("ecs/scheduler.jl")
include("ecs/reporter/csv_reporter.jl")

include("comps/tree.jl")
include("comps/cell.jl")
include("comps/beetle.jl")
include("res/grid.jl")
include("res/grids.jl")
include("res/world_size.jl")
include("res/rng.jl")
include("res/time.jl")

include("sys/init_grids.jl")
include("sys/init_trees.jl")
include("sys/update_time.jl")
include("sys/disease_course.jl")
include("sys/random_infection.jl")
include("sys/damage_trees.jl")
include("sys/beetle_emergence.jl")
include("sys/beetle_mortality.jl")
include("sys/colonization.jl")
include("sys/tree_attraction.jl")

include("obs/tree_population.jl")
include("obs/tree_damage.jl")
include("obs/tree_colonization.jl")
include("obs/maps/tree_colonization.jl")
include("obs/maps/beetles.jl")
include("obs/maps/tree_attraction.jl")

include("util/print.jl")

include("app.jl")

function __init__()
    _init_timer()
end

export Scheduler, fps!, initialize!, step!, finalize!, run!
export run_model, julia_main

export Config, load_config, parse_config, apply!, allow_external_module

export RowObserver, header, row, CSV
export Rng, Tick, Time
export Termination, FixedTermination
export Grid, TreeGrid, SpaceGrid, WorldSize
export HealthyTreeAttraction, DamagedTreeAttraction
export Position, InCell, Damaged, Infected, Colonized
export BeetlePosition, LifeExpectancy
export GridCoords
export InitGrids, InitTrees
export UpdateTime, DiseaseCourse, RandomInfection, DamageTrees, Colonization
export BeetleEmergence, EmergenceTick, BeetleMortality
export TreeAttraction
export TreePopulationObserver, TreeDamageObserver, TreeColonizationObserver
export TreeColonizationMapObserver, BeetlesMapObserver, TreeAttractionMapObserver
export trees_to_string

end
