struct NoopObserver <: PWNModel.RowObserver end

mutable struct RecordingObserver <: PWNModel.RowObserver
    initialized::Int
    updated::Int
end

RecordingObserver() = RecordingObserver(0, 0)

PWNModel.initialize!(o::RecordingObserver, ::World) = (o.initialized += 1)
PWNModel.update!(o::RecordingObserver, ::World) = (o.updated += 1)
PWNModel.header(::RecordingObserver) = ["a", "b"]
PWNModel.row(o::RecordingObserver, ::World) = [Float64(o.updated), Float64(o.updated) * 2]

@testset "RowObserver initialize!/update! default to no-ops" begin
    o = NoopObserver()
    world = World()

    @test PWNModel.initialize!(o, world) === nothing
    @test PWNModel.update!(o, world) === nothing
end

@testset "RowObserver header/row are unimplemented by default" begin
    o = NoopObserver()

    @test_throws MethodError PWNModel.header(o)
    @test_throws MethodError PWNModel.row(o, World())
end

@testset "RowObserver dispatch" begin
    o = RecordingObserver()
    world = World()

    PWNModel.initialize!(o, world)
    PWNModel.update!(o, world)
    PWNModel.update!(o, world)

    @test o.initialized == 1
    @test o.updated == 2
    @test PWNModel.header(o) == ["a", "b"]
    @test PWNModel.row(o, world) == [2.0, 4.0]
end
