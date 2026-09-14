using Ark
using PWNModel

world = World(Position)
add_resource!(world, TreeGrid(100, 50))
add_resource!(world, Rng(rand(UInt64)))

scheduler = Scheduler(
    world,
    (
        InitTrees(0.1),
    ),
)

run!(scheduler, 100)
