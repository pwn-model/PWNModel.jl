module PWNModel

using Ark
using Random

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

include("sys/init_grids.jl")
include("sys/init_trees.jl")

export Scheduler, initialize!, step!, finalize!, run!
export RowObserver, header, row, CSV

export EntityGrid
export SpaceGrid
export WorldSize
export Position
export InCell
export Damaged
export NematodeInfected
export GridCoords
export Rng
export InitGrids
export InitTrees

end
