# Octant attraction (archived code)

Code of the octant attraction model, which was not adopted and has been removed from the `PWNModel` package.
It is kept here for the archived experiments that use it:
[`attraction_half_distance_octants`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/archive/attraction_half_distance_octants)
and [`beetle_trajectories_octants`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/archive/beetle_trajectories_octants).

- `TreeAttractionOctants` computes, for every cell, the most attractive tree in each of the 8 octants around it
  (resources `HealthyTreeAttractionOctants`, `DamagedTreeAttractionOctants`).
- `BeetleMovementOctants` moves beetles towards the source of one of these octants,
  selected by roulette selection weighted by attraction.

The code is unchanged from the package, wrapped in the module `Octants` (`Octants.jl`),
which extends `PWNModel`'s system interface and uses some of its internals.
Use it from an experiment like this:

```julia
include("../octants/Octants.jl")
using .Octants
include("../octants/plotting.jl")  # optional, after ../../common/plotting.jl
```

The unit tests and benchmarks of this code, and its Go implementation, were removed.
They can be found in the git history of `PWNModel.jl` and `pwn`.
