using Ark
using PWNModel

include("plot/line_plot.jl")

world = World(Position, GridCoords, Damaged, Infected, Relation{InCell})

# Resources
add_resource!(world, WorldSize(100, 50, 10))
add_resource!(world, Rng(rand(UInt64)))

tree_pop_plot = LinePlot(
            observer=TreePopulationObserver(),
            title="Tree population",
            xlabel="Tick",
            ylabel="Trees",
        )

scheduler = Scheduler(
    world,
    (
        # Initialization
        InitGrids(),
        InitTrees(
            tree_probability=0.9,
            damage_prevalence=0.03,
        ),

        # Systems
        DiseaseCourse(ticks_to_damage=8),
        RandomInfection(tick_of_infection=0, num_trees=100, cell_x=5, cell_y=3),

        # Observers
        CSV(
            observer=TreePopulationObserver(),
            file="out/tree_pop.csv",
        ),
        tree_pop_plot,
    ),
)

run!(scheduler, 100)

wait(screen(tree_pop_plot))
