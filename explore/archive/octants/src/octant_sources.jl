# OctantSources holds, for one cell, the most attractive source tree in each
# of the 8 octants around that cell, as computed by propagate_octants!.
#
# Octant k (1-based) covers the directions from 45°*(k-1) (included) to
# 45°*k (excluded), measured from +x towards +y (half-open octants), so the
# octant of a direction at angle a is floor(a / 45°) + 1. With (dx, dy) the
# offset from the cell to a source:
#
#   1: 0 <=  dy <   dx      5: 0 <= -dy <  -dx
#   2: 0 <   dx <=  dy      6: 0 <  -dx <= -dy
#   3: 0 <= -dx <   dy      7: 0 <=  dx <  -dy
#   4: 0 <   dy <= -dx      8: 0 <  -dy <=  dx
#
# Every cell other than the cell itself is in exactly one octant. The cell
# itself is in none: a tree's own cell is excluded, so that a beetle on a
# tree "sees" only other trees.
#
# The layout is 64 bytes, i.e. one cache line, so that a consumer selecting
# among a cell's octants reads them all with a single memory access.
struct OctantSources
    # offsets are the (dx, dy) offsets, in cells, from the cell to the source
    # of each octant. (0, 0) for an octant without any source: since the
    # cell itself is never a source, (0, 0) is never a valid offset.
    offsets::NTuple{8,NTuple{2,Int16}}
    # attraction is the attraction value of each octant's source as seen
    # from the cell, i.e. its seed decayed over the distance to the cell. 0
    # for an octant without any source.
    attraction::NTuple{8,Float32}
end

# OctantSources() returns a record with all 8 octants empty.
OctantSources() = OctantSources(ntuple(_ -> (Int16(0), Int16(0)), Val(8)), ntuple(_ -> 0.0f0, Val(8)))
