using Ark
using PWNModel

world = World(Position, GridCoords, Relation{InCell})
add_resource!(world, WorldSize(100, 50, 10))
add_resource!(world, Rng(rand(UInt64)))

scheduler = Scheduler(
    world,
    (
        InitGrids(),
        InitTrees(0.1),
    ),
)

run!(scheduler, 100)
