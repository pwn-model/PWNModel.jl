# Builds the experiments web page from the README of this folder and of
# each experiment, together with the experiments' figures in their `out/`
# folders. Run the experiments first.
#
# Run from the PWNModel.jl/ directory:
#   julia --project=explore explore/make.jl
#
# The page is written to explore/site/.

using Documenter

# Experiment folders and their page titles, in page order.
const EXPERIMENTS = [
    "beetle_trajectories" => "Beetle trajectories",
]

src = mktempdir()
cp(joinpath(@__DIR__, "README.md"), joinpath(src, "index.md"))
for (dir, _) in EXPERIMENTS
    mkpath(joinpath(src, dir))
    cp(joinpath(@__DIR__, dir, "README.md"), joinpath(src, dir, "index.md"))
    cp(joinpath(@__DIR__, dir, "out"), joinpath(src, dir, "out"))
end

makedocs(;
    sitename="PWN model experiments",
    root=@__DIR__,
    source=src,
    build="site",
    pages=["Home" => "index.md", ("$title" => "$dir/index.md" for (dir, title) in EXPERIMENTS)...],
    format=Documenter.HTML(; prettyurls=false, edit_link=nothing, repolink=nothing),
    remotes=nothing,
)
