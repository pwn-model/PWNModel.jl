mutable struct RecordingSystem <: PWNModel.System
    initialized::Int
    updated::Int
    finalized::Int
end

RecordingSystem() = RecordingSystem(0, 0, 0)

PWNModel.initialize!(sys::RecordingSystem, ::World) = (sys.initialized += 1)
PWNModel.update!(sys::RecordingSystem, ::World) = (sys.updated += 1)
PWNModel.finalize!(sys::RecordingSystem, ::World) = (sys.finalized += 1)

@testset "Scheduler" begin
    sys1 = RecordingSystem()
    sys2 = RecordingSystem()
    scheduler = PWNModel.Scheduler(
        World(),
        (sys1, sys2),
    )

    PWNModel.run!(scheduler, 5)

    for sys in (sys1, sys2)
        @test sys.initialized == 1
        @test sys.updated == 5
        @test sys.finalized == 1
    end
end

@testset "Scheduler constructor" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,))

    @test scheduler._is_initialized == false
    @test scheduler.systems == (sys1,)
end

@testset "Scheduler adds and increments a Tick resource" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,))

    @test get_resource(scheduler.world, PWNModel.Tick).value == 0

    PWNModel.step!(scheduler)
    @test get_resource(scheduler.world, PWNModel.Tick).value == 1

    PWNModel.step!(scheduler)
    PWNModel.step!(scheduler)
    @test get_resource(scheduler.world, PWNModel.Tick).value == 3
end

@testset "Scheduler initialize! is idempotent" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,))

    PWNModel.initialize!(scheduler)
    PWNModel.initialize!(scheduler)

    @test scheduler._is_initialized == true
    @test sys1.initialized == 1
end

@testset "Scheduler step!" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,))

    PWNModel.step!(scheduler)
    PWNModel.step!(scheduler)

    @test sys1.updated == 2
    @test sys1.initialized == 0
    @test sys1.finalized == 0
end

@testset "Scheduler finalize!" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,))

    PWNModel.finalize!(scheduler)

    @test sys1.finalized == 1
end

@testset "Scheduler fps defaults to unlimited" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,))

    @test scheduler.fps == 0.0

    elapsed = @elapsed PWNModel.run!(scheduler, 1000)
    @test elapsed < 1.0
end

@testset "Scheduler fps limits the update rate" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,); fps=100)

    @test scheduler.fps == 100.0

    elapsed = @elapsed PWNModel.run!(scheduler, 5)
    @test elapsed >= 0.04
end

@testset "Scheduler fps! and direct field assignment are equivalent" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,))

    PWNModel.fps!(scheduler, 50)
    @test scheduler.fps == 50.0

    scheduler.fps = 0
    @test scheduler.fps == 0.0
end
