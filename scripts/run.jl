using Ark
using PWNModel

include("plot/time_series.jl")

world = World(Position, GridCoords, Damaged, Infected, Relation{InCell})

# Resources
add_resource!(world, WorldSize(200, 200, 50))
add_resource!(world, Rng(1))

tree_pop_plot = TimeSeries(
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
        UpdateTime(ticks_per_year=52),
        DiseaseCourse(ticks_to_damage=8),
        RandomInfection(tick_of_infection=0, num_trees=100, cell_x=5, cell_y=3),
        DamageTrees(tick_of_year=35, damage_probability=0.01, removal_probability=0.333),

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
