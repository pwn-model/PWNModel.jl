# Plotting helpers for the archived octant attraction model. Include after
# ../../common/plotting.jl and Octants.jl.

"""
    octant_source_image(world; damaged, xlims, ylims) -> (xrange, yrange, image)

Like [`attraction_source_image`](@ref), but for the octant sources computed
by `TreeAttractionOctants`: each cell shows its most attractive octant
source, i.e. the tree a beetle there is most likely to select. Unlike
`TreeAttraction`'s sources, a tree's own cell is never its own source, so
tree cells show their most attractive other tree. Values are pseudo-random
in [0, 1) per source tree, the same as for `attraction_source_image`, `NaN`
where no octant has a source.
"""
function octant_source_image(world::World; damaged::Bool, xlims, ylims)
    res =
        damaged ? get_resource(world, DamagedTreeAttractionOctants) : get_resource(world, HealthyTreeAttractionOctants)
    sources = res.sources
    cs = sources.cell_size
    x1, x2, y1, y2 = cell_bounds(sources; xlims=xlims, ylims=ylims)

    image = fill(NaN, x2 - x1 + 1, y2 - y1 + 1)
    for x in x1:x2, y in y1:y2
        r = sources[x, y]
        a, k = findmax(r.attraction)
        a > 0 || continue
        ox, oy = r.offsets[k]
        image[x-x1+1, y-y1+1] = PWNModel._hash_to_unit(cell_index(sources, x + Int(ox), y + Int(oy)))
    end
    return ((x1 - 1) * cs, x2 * cs), ((y1 - 1) * cs, y2 * cs), image
end
