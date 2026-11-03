@testset "Grid" begin
    grid = PWNModel.TreeGrid(4, 3, 1)
    @test grid.grid.width == 4
    @test grid.grid.height == 3
    @test grid.grid.cell_size == 1

    world = World()
    e = new_entity!(world, ())
    grid.grid[2, 1] = e
    @test grid.grid[2, 1] == e
    @test is_zero(grid.grid[1, 1]) == true
end

@testset "Grid cell index and coords" begin
    grid = Grid(20, 10, 1, UInt32(0))

    for x in 1:(grid.width), y in 1:(grid.height)
        idx = PWNModel.cell_index(grid, x, y)
        @test 1 <= idx < PWNModel.NO_CELL
        @test PWNModel.cell_coords(grid, idx) == (x, y)
    end

    # The index is the position in the grid's own storage.
    grid[4, 8] = 42
    @test grid._values[PWNModel.cell_index(grid, 4, 8)] == 42
end

@testset "Grid checkbounds" begin
    grid = Grid(20, 10, 1, false)

    @test checkbounds(Bool, grid, 1, 1)
    @test checkbounds(Bool, grid, 20, 10)
    @test checkbounds(Bool, grid, 5, 5)

    @test !checkbounds(Bool, grid, 0, 1)
    @test !checkbounds(Bool, grid, 1, 0)
    @test !checkbounds(Bool, grid, 21, 1)
    @test !checkbounds(Bool, grid, 1, 11)

    @test checkbounds(grid, 20, 10) === nothing
    @test_throws BoundsError checkbounds(grid, 21, 1)
end
