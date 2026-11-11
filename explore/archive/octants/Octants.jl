"""
    Octants

Archived octant attraction model, removed from `PWNModel`: `TreeAttractionOctants`
computes the most attractive tree in each of 8 directions (octants) around every
cell, and `BeetleMovementOctants` moves beetles towards one of them, selected by
roulette selection weighted by attraction. See `../README.md`.

The code is kept as it was in `PWNModel`, extending its systems interface
(`initialize!`, `update!`) and using some of its internals.
"""
module Octants

using Ark
using PWNModel
using PWNModel: System, DensitySeeding, seed_density!, random_direction
import PWNModel: initialize!, update!

include("src/octant_sources.jl")
include("src/resources.jl")
include("src/attraction_octants.jl")
include("src/tree_attraction_octants.jl")
include("src/beetle_movement_octants.jl")

export OctantSources, HealthyTreeAttractionOctants, DamagedTreeAttractionOctants
export TreeAttractionOctants, BeetleMovementOctants

end
