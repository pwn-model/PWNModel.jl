using Ark
using PWNModel

include("plot/time_series.jl")
include("plot/trees_map.jl")

world = World(Position, GridCoords, Damaged, Infected, Colonized, Relation{InCell})

# Resources
add_resource!(world, WorldSize(
    width=4000,
    height=3000,
    cell_size=10,
    grid_cell_size=500,
))
add_resource!(world, Rng(1))

tree_pop_plot = TimeSeries(
    observer=TreeColonizationObserver(),
    title="Tree colonization",
    xlabel="Tick",
    ylabel="Proportion",
)

tree_map_plot = TreesMap(title="Trees")

scheduler = Scheduler(
    world,
    (
        # Initialization
        InitGrids(),
        InitTrees(
            tree_probability=0.9,
            damage_prevalence=0.03,
            beetle_prevalence=0.2,
        ),

        # Systems
        UpdateTime(
            ticks_per_year=52,
        ),
        DiseaseCourse(
            ticks_to_damage=8,
        ),
        RandomInfection(
            tick_of_infection=0,
            num_trees=100,
            cell_x=3, cell_y=3,
        ),
        DamageTrees(
            tick_of_year=35,
            damage_probability=0.01,
            removal_probability=0.333,
        ),
        Colonization(
            tick_of_year=20,
            cell_size=100,
            kernel_scale=100.0,
            kernel_radius=400,
            beetles_per_tree=2.2,
            trees_per_beetle=1.0,
        ),

        # Observers
        CSV(
            observer=TreePopulationObserver(),
            file="out/tree_pop.csv",
        ),
        tree_pop_plot,
        tree_map_plot,
    ),
)

fps!(scheduler, 30)
run!(scheduler, 5200)

wait(screen(tree_pop_plot))
wait(screen(tree_map_plot))

#println(trees_to_string(world))
