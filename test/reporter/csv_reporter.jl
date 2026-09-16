mutable struct CountObserver <: PWNModel.RowObserver
    initialized::Int
    n::Int
end

CountObserver() = CountObserver(0, 0)

PWNModel.initialize!(o::CountObserver, ::World) = (o.initialized += 1)
PWNModel.update!(o::CountObserver, ::World) = (o.n += 1)
PWNModel.header(::CountObserver) = ["a", "b"]
PWNModel.row(o::CountObserver, ::World) = [Float64(o.n), Float64(o.n) * 2]

@testset "CSV writes header and one row per tick" begin
    dir = mktempdir()
    file = joinpath(dir, "out.csv")

    rep = PWNModel.CSV(observer=CountObserver(), file=file)
    scheduler = PWNModel.Scheduler(World(), (rep,))
    PWNModel.run!(scheduler, 3)

    @test readlines(file) == ["t,a,b", "0,1.0,2.0", "1,2.0,4.0", "2,3.0,6.0"]
end

@testset "CSV calls observer initialize! and update!" begin
    dir = mktempdir()
    file = joinpath(dir, "out.csv")

    observer = CountObserver()
    rep = PWNModel.CSV(observer=observer, file=file)
    scheduler = PWNModel.Scheduler(World(), (rep,))
    PWNModel.run!(scheduler, 4)

    @test observer.initialized == 1
    @test observer.n == 4
end

@testset "CSV respects sep" begin
    dir = mktempdir()
    file = joinpath(dir, "out.csv")

    rep = PWNModel.CSV(observer=CountObserver(), file=file, sep=";")
    scheduler = PWNModel.Scheduler(World(), (rep,))
    PWNModel.run!(scheduler, 1)

    @test readlines(file) == ["t;a;b", "0;1.0;2.0"]
end

@testset "CSV respects update_interval" begin
    dir = mktempdir()
    file = joinpath(dir, "out.csv")

    rep = PWNModel.CSV(observer=CountObserver(), file=file, update_interval=2)
    scheduler = PWNModel.Scheduler(World(), (rep,))
    PWNModel.run!(scheduler, 4)

    @test readlines(file) == ["t,a,b", "0,1.0,2.0", "2,3.0,6.0"]
end

@testset "CSV with final only writes on finalize!" begin
    dir = mktempdir()
    file = joinpath(dir, "out.csv")

    rep = PWNModel.CSV(observer=CountObserver(), file=file, final=true)
    scheduler = PWNModel.Scheduler(World(), (rep,))
    PWNModel.run!(scheduler, 5)

    @test readlines(file) == ["t,a,b", "5,5.0,10.0"]
end

@testset "CSV creates missing parent directories" begin
    dir = mktempdir()
    file = joinpath(dir, "nested", "out.csv")

    rep = PWNModel.CSV(observer=CountObserver(), file=file)
    scheduler = PWNModel.Scheduler(World(), (rep,))
    PWNModel.run!(scheduler, 1)

    @test isfile(file)
end
