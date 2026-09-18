"""
    trees_to_string(w::World)

Renders the tree grid as a string.
"""
function trees_to_string(w::World)
    grid = get_resource(w, TreeGrid)

    io = IOBuffer()
    for x in 1:grid.grid.width
        for y in 1:grid.grid.height
            e = grid.grid[x, y]
            if is_zero(e)
                print(io, ' ')
                continue
            end

            if has_components(w, e, (Infected,))
                print(io, 'x')
                continue
            end

            if has_components(w, e, (Damaged,))
                print(io, '+')
                continue
            end

            print(io, '.')
        end
        print(io, '\n')
    end

    return String(take!(io))
end
