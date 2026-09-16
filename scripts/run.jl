using Ark
using PWNModel

world = World(Position, GridCoords, Damaged, NematodeInfected, Relation{InCell})
add_resource!(world, WorldSize(100, 50, 10))
add_resource!(world, Rng(rand(UInt64)))

scheduler = Scheduler(
    world,
    (
        InitGrids(),
        InitTrees(
            tree_probability=0.9,
            damage_prevalence=0.03,
        ),
        DiseaseCourse(ticks_to_damage=8),
        RandomInfection(tick_of_infection=0, num_trees=100, cell_x=5, cell_y=3),
        CSV(
            observer=TreePopulationObserver(),
            file="out/tree_pop.csv",
        ),
    ),
)

run!(scheduler, 100)
