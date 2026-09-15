
struct EntityGrid
    _entities::Array{Entity,2}
    width::Int
    height::Int

    function EntityGrid(sx::Int, sy::Int)
        new(fill(zero_entity, sy, sx), sx, sy)
    end
end

Base.getindex(grid::EntityGrid, x::Int, y::Int) = grid._entities[y, x]
Base.setindex!(grid::EntityGrid, entity::Entity, x::Int, y::Int) = (grid._entities[y, x] = entity)
