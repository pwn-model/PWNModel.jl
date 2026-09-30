@testset "run_model out_dir" begin
    mktempdir() do tmp
        config_path = joinpath(tmp, "config.yaml")
        write(
            config_path,
            """
            seed: 1
            resources:
              - type: WorldSize
                width: 200
                height: 100
                cell_size: 10
                grid_cell_size: 50
            systems:
              - type: InitGrids
              - type: FixedTermination
                steps: 3
              - type: CSV
                observer:
                  type: TreePopulation
                file: out/tree_pop.csv
            """,
        )

        prev = pwd()
        out_dir = joinpath(tmp, "a", "b")
        run_model(config_path; out_dir=out_dir)
        @test pwd() == prev
        @test isfile(joinpath(out_dir, "out", "tree_pop.csv"))
    end
end

@testset "_parse_app_args" begin
    parse = PWNModel._parse_app_args
    @test parse(String[]) == ("config.yaml", nothing)
    @test parse(["c.yaml"]) == ("c.yaml", nothing)
    @test parse(["c.yaml", "-o", "out"]) == ("c.yaml", "out")
    @test parse(["--out-dir", "out", "c.yaml"]) == ("c.yaml", "out")
    @test parse(["--out-dir=out"]) == ("config.yaml", "out")
    @test_throws ErrorException parse(["-o"])
    @test_throws ErrorException parse(["--bogus"])
    @test_throws ErrorException parse(["a.yaml", "b.yaml"])
end
