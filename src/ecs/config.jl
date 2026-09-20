# Assembles a World's resources and a set of Systems from a YAML config
# file, so that models can be composed without recompiling.
#
# Mirrors the sibling Go implementation's `config` package
# (github.com/pwn-model/pwn/config), adapted to Julia: types are resolved
# by name via reflection instead of an explicit per-type registry, since
# Julia types are already first-class values reachable by name. The one
# thing that *does* need an explicit, one-time step is opting in an
# external module's types (see `allow_external_module`); everything
# PWNModel itself defines needs no registration at all.

const _OWN_MODULE = @__MODULE__

# Modules whose own system/resource types may be referenced from config
# files, as "ModuleName.TypeName", keyed by module name. PWNModel's own
# types need no entry here: an unqualified name resolves against PWNModel
# directly.
const _EXTERNAL_MODULES = Dict{String,Module}()

"""
    allow_external_module(mod::Module)

Makes `mod`'s own system/resource types usable from config files, as
`"\$(nameof(mod)).TypeName"`, e.g. `"ArkTools.XyTermination"`.

Call this once per external module that defines systems or resources you
want to use from a config file, typically right where the module is
already `using`'d. Without this, a config file can only reference types
PWNModel itself defines; that's what keeps it from also reaching whatever
else happens to be visible in PWNModel's own namespace (e.g. via its own
`using Ark`) -- see `resolve_type`.
"""
function allow_external_module(mod::Module)
    _EXTERNAL_MODULES[String(nameof(mod))] = mod
    return nothing
end

# _resolve_module splits a config type-name into its owning module and
# unqualified type name: "InitTrees" -> (PWNModel, :InitTrees),
# "ArkTools.XyTermination" -> (ArkTools, :XyTermination), the latter only
# if ArkTools was previously passed to `allow_external_module`.
function _resolve_module(name::AbstractString)
    dot = findfirst('.', name)
    if dot === nothing
        return _OWN_MODULE, Symbol(name)
    end

    prefix = SubString(name, 1, dot - 1)
    mod = get(_EXTERNAL_MODULES, prefix, nothing)
    if mod === nothing
        throw(
            ArgumentError(
                "unknown or disallowed module prefix \"$prefix\" in type name \"$name\"" *
                " (call allow_external_module(YourModule) first)",
            ),
        )
    end
    return mod, Symbol(SubString(name, dot + 1))
end

"""
    resolve_type(name::AbstractString, supertype_::Type) -> Type

Resolves a config type-name to a concrete type that is both a subtype of
`supertype_` and actually *defined by* (not just visible in) its owning
module.

The latter check is what excludes a type that a module merely imports via
`using`: e.g. PWNModel's own `using Ark` makes `Ark.World` reachable as a
plain name inside PWNModel, but `parentmodule(Ark.World)` is `Ark`, not
`PWNModel`, so it is not resolvable here as `"World"`.
"""
function resolve_type(name::AbstractString, supertype_::Type)
    mod, type_name = _resolve_module(name)

    if !isdefined(mod, type_name)
        throw(ArgumentError("unknown type \"$name\""))
    end
    T = getfield(mod, type_name)

    if !(T isa Type)
        throw(ArgumentError("\"$name\" is not a type"))
    end
    if parentmodule(T) !== mod
        throw(ArgumentError("\"$name\" is not defined in $mod"))
    end
    if !(T <: supertype_)
        throw(ArgumentError("\"$name\" is not a $supertype_"))
    end
    return T
end

# _construct builds a T from a config entry's remaining fields (everything
# but "type"), via its usual keyword constructor: the same one every
# System/resource in this codebase already has.
function _construct(::Type{T}, entry::AbstractDict) where {T}
    kwargs = (Symbol(k) => v for (k, v) in entry if k != "type")
    return T(; kwargs...)
end

function _build_entry(entry::AbstractDict, supertype_::Type)
    haskey(entry, "type") || throw(ArgumentError("config entry is missing a 'type' field"))
    T = resolve_type(entry["type"], supertype_)
    return _construct(T, entry)
end

"""
Config is the top-level, deserialized shape of a model config file.
"""
struct Config
    # Seed for the model's PRNG. The PRNG implementation itself is fixed
    # (not configurable), to keep it bit-identical with the sibling Go
    # implementation.
    seed::UInt64
    # Ticks per second cap for the Scheduler (see `Scheduler`'s `fps`).
    # Values <= 0 mean as fast as possible.
    tps::Float64
    # Resources to add to the world. Each entry's "type" selects the
    # resource type (see `resolve_type`); its other fields are passed as
    # keyword arguments to that type's constructor.
    resources::Vector{Any}
    # Systems to run, in order. Each entry's "type" selects the system
    # type; its other fields are passed as keyword arguments to that
    # type's constructor.
    systems::Vector{System}
end

function _config_from_data(data)
    if data === nothing
        data = Dict{String,Any}()
    end

    seed = UInt64(get(data, "seed", 0))
    tps = Float64(get(data, "tps", 0))

    resources = Any[_build_entry(entry, Any) for entry in get(data, "resources", [])]
    systems = System[_build_entry(entry, System) for entry in get(data, "systems", [])]

    return Config(seed, tps, resources, systems)
end

"""
    parse_config(text::AbstractString) -> Config

Parses a model config file's contents.
"""
parse_config(text::AbstractString) = _config_from_data(YAML.load(text; dicttype=Dict{String,Any}))

"""
    load_config(path::AbstractString) -> Config

Reads and parses a model config file.
"""
load_config(path::AbstractString) = _config_from_data(YAML.load_file(path; dicttype=Dict{String,Any}))

"""
    apply!(cfg::Config, world::World)

Adds all of `cfg`'s resources to `world`.

Does not touch systems: a [`Scheduler`](@ref)'s systems tuple is fixed at
construction (for dispatch performance), so callers build it themselves
from `cfg.systems`, e.g. `Scheduler(world, Tuple(cfg.systems); fps=cfg.tps)`.
Nor does it touch the PRNG seed, which is hard-coded to [`Rng`](@ref)
using only `cfg.seed` (see `scripts/run.jl`).
"""
function apply!(cfg::Config, world::World)
    for res in cfg.resources
        add_resource!(world, res)
    end
    return nothing
end
