using Ark
using PWNModel

world = World()
add_resource!(world, TreeGrid(100, 50))

scheduler = Scheduler(
    world,
    (
        InitTrees(0.1),
    ),
)

run!(scheduler, 100)
