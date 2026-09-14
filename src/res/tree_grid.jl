
struct TreeGrid
    _trees::Array{Entity,2}
    width::Int
    height::Int

    function TreeGrid(sx::Int, sy::Int)
        new(fill(zero_entity, sy, sx), sx, sy)
    end
end

Base.getindex(grid::TreeGrid, x::Int, y::Int) = grid._trees[y, x]
Base.setindex!(grid::TreeGrid, entity::Entity, x::Int, y::Int) = (grid._trees[y, x] = entity)
