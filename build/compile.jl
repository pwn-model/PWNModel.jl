# Builds a standalone executable via PackageCompiler.jl's `create_app`,
# bundling the PWNModel package (Ark, Random, YAML -- no plotting deps) into
# an app directory with its own Julia runtime, so the result runs without a
# separate Julia install.
#
# Run from the repository root:
#   julia --project=build build/compile.jl [app_dir]
#
# The resulting app is invoked as:
#   <app_dir>/bin/PWNModel[.exe] [config.yaml]

using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using PackageCompiler

app_dir = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "PWNModelApp")

create_app(joinpath(@__DIR__, ".."), app_dir; force=true)

exe = joinpath(app_dir, "bin", "PWNModel" * (Sys.iswindows() ? ".exe" : ""))
println("Built app: $exe")
