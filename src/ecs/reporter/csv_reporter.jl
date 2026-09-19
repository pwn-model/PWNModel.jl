"""
CSV reporter system. Writes one row per model tick to a CSV file.

Wraps a [`RowObserver`](@ref) that supplies the column headers and, per
tick, one row of `Float64` values. Mirrors `reporter.CSV` from the
sibling Go implementation's `github.com/mlange-42/ark-tools/reporter`
package.
"""
mutable struct CSV <: System
    const observer::RowObserver
    const file::String
    const sep::String
    const update_interval::Int
    const final::Bool
    _io::Union{IO,Nothing}
    _step::Int
end

function CSV(;
    observer::RowObserver,
    file::AbstractString,
    sep::AbstractString=",",
    update_interval::Int=1,
    final::Bool=false,
)
    return CSV(observer, String(file), String(sep), update_interval, final, nothing, 0)
end

function initialize!(s::CSV, w::World)
    initialize!(s.observer, w)

    dir = dirname(s.file)
    if !isempty(dir)
        mkpath(dir)
    end

    s._io = open(s.file, "w")
    println(s._io, "t", s.sep, join(header(s.observer), s.sep))

    s._step = 0
end

function update!(s::CSV, w::World)
    update!(s.observer, w)
    if !s.final && s._step % s.update_interval == 0
        _write_row!(s, w)
    end
    s._step += 1
end

function finalize!(s::CSV, w::World)
    if s.final
        _write_row!(s, w)
    end
    close(s._io)
end

function _write_row!(s::CSV, w::World)
    print(s._io, s._step)
    for v in data(s.observer, w)
        print(s._io, s.sep, v)
    end
    print(s._io, "\n")
end
