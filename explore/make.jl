# Builds the experiments web page from the landing page `index.md` (for
# domain experts; this folder's README.md is for developers), the README of
# each experiment, and the experiments' figures in their `out/` folders.
# Run the experiments first.
#
# Run from the PWNModel.jl/ directory:
#   julia --project=explore explore/make.jl
#
# The page is written to explore/site/.

using Documenter

# Experiment folders and their page titles, in page order.
const EXPERIMENTS = [
    "attraction_field" => "Attraction field",
    "beetle_trajectories" => "Beetle trajectories",
    "attraction_half_distance" => "Attraction half distance",
]

src = mktempdir()
cp(joinpath(@__DIR__, "index.md"), joinpath(src, "index.md"))
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
