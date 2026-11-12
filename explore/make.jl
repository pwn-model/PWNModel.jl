# Builds the experiments web page from the landing page `index.md` (for
# domain experts; this folder's README.md is for developers), the README of
# each experiment, and the experiments' figures in their `out/` folders.
# Archived experiments (in `archive/`) are listed in a separate section.
# Run the experiments first.
#
# A README line `<!-- include out/<file>.md -->` is replaced by the content of
# that file, relative to the experiment folder, e.g. a table of results written
# by the experiment. On GitHub, the line is an invisible comment.
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
    "forest_density" => "Forest density",
    "forest_gap" => "Forest gap",
    "attraction_half_distance" => "Attraction half distance",
]

# Archived experiments, as paths below this folder, and their page titles, in page order.
const ARCHIVE = [
    "archive/attraction_half_distance_octants" => "Attraction half distance (octants)",
    "archive/beetle_trajectories_octants" => "Beetle trajectories (octants)",
]

const INCLUDE = r"<!-- include (\S+) -->"

# The README of the experiment in `dir`, with include lines replaced by the files' content.
expand_includes(dir) =
    replace(read(joinpath(dir, "README.md"), String), INCLUDE => m -> read(joinpath(dir, match(INCLUDE, m)[1]), String))

src = mktempdir()
cp(joinpath(@__DIR__, "index.md"), joinpath(src, "index.md"))
for (dir, _) in [EXPERIMENTS; ARCHIVE]
    mkpath(joinpath(src, dir))
    write(joinpath(src, dir, "index.md"), expand_includes(joinpath(@__DIR__, dir)))
    cp(joinpath(@__DIR__, dir, "out"), joinpath(src, dir, "out"))
    # Included Markdown files are not pages of their own.
    for file in readdir(joinpath(src, dir, "out"); join=true)
        endswith(file, ".md") && rm(file)
    end
end

makedocs(;
    sitename="PWN model experiments",
    root=@__DIR__,
    source=src,
    build="site",
    pages=[
        "Home" => "index.md",
        ("$title" => "$dir/index.md" for (dir, title) in EXPERIMENTS)...,
        "Archive" => ["$title" => "$dir/index.md" for (dir, title) in ARCHIVE],
    ],
    format=Documenter.HTML(; prettyurls=false, edit_link=nothing, repolink=nothing),
    remotes=nothing,
)
