
struct TreeGrid
    trees::Array{Entity,2}
    width::Int
    height::Int

    function TreeGrid(sx::Int, sy::Int)
        new(Array{Entity}(undef, sy, sx), sx, sy)
    end
end
