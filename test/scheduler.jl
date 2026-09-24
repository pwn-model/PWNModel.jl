mutable struct RecordingSystem <: PWNModel.System
    initialized::Int
    updated::Int
    finalized::Int
    ui_updated::Int
end

RecordingSystem() = RecordingSystem(0, 0, 0, 0)

PWNModel.initialize!(sys::RecordingSystem, ::World) = (sys.initialized += 1)
PWNModel.update!(sys::RecordingSystem, ::World) = (sys.updated += 1)
PWNModel.finalize!(sys::RecordingSystem, ::World) = (sys.finalized += 1)
PWNModel.update_ui!(sys::RecordingSystem, ::World) = (sys.ui_updated += 1)

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

@testset "Scheduler tps defaults to unlimited" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,))

    @test scheduler.tps == 0.0

    elapsed = @elapsed PWNModel.run!(scheduler, 1000)
    @test elapsed < 1.0
end

@testset "Scheduler tps limits the update rate" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,); tps=50)

    @test scheduler.tps == 50.0

    # The first two ticks fire without waiting (the resync in `_next_time`
    # treats the initial, far-in-the-past `_next_update` as stale), so only
    # `steps - 2` of the `dt = 1/tps` waits actually happen. Assert well
    # below that theoretical minimum to stay robust to CI timer jitter.
    dt = 1 / scheduler.tps
    elapsed = @elapsed PWNModel.run!(scheduler, 10)
    @test elapsed >= 0.6 * (10 - 2) * dt
end

@testset "Scheduler tps!/fps! and direct field assignment are equivalent" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,))

    PWNModel.tps!(scheduler, 50)
    @test scheduler.tps == 50.0
    scheduler.tps = 0
    @test scheduler.tps == 0.0

    PWNModel.fps!(scheduler, 20)
    @test scheduler.fps == 20.0
    scheduler.fps = 0
    @test scheduler.fps == 0.0
end

@testset "Scheduler updates the UI independently of ticks" begin
    # Unlimited ticks, 30 FPS default: far fewer UI updates than ticks.
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,))
    PWNModel.run!(scheduler, 1000)
    @test sys1.updated == 1000
    @test 1 <= sys1.ui_updated < 100

    # Slow ticks, fast UI: several UI updates per tick.
    sys2 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys2,); tps=10, fps=100)
    PWNModel.run!(scheduler, 5)
    @test sys2.updated == 5
    @test sys2.ui_updated > 10
end

@testset "Scheduler fps < 0 syncs UI updates with ticks" begin
    sys1 = RecordingSystem()
    scheduler = PWNModel.Scheduler(World(), (sys1,); fps=-1)
    PWNModel.run!(scheduler, 100)
    @test sys1.updated == 100
    @test sys1.ui_updated == 100
end

@testset "Scheduler shares tps/fps/paused with its SchedulerControl resource" begin
    world = World()
    scheduler = PWNModel.Scheduler(world, (RecordingSystem(),); tps=50, fps=20)
    control = get_resource(world, PWNModel.SchedulerControl)
    @test control.tps == 50.0
    @test control.fps == 20.0
    @test control.paused == false

    control.tps = 10
    @test scheduler.tps == 10.0
    scheduler.paused = true
    @test control.paused == true
end

# Pauses the run on its `pause_at`-th tick; resumes it on the
# `resume_after`-th UI update after that, recording what happened meanwhile.
mutable struct PausingSystem <: PWNModel.System
    const pause_at::Int
    const resume_after::Int
    updated::Int
    paused_ui_updates::Int
end

PausingSystem(pause_at, resume_after) = PausingSystem(pause_at, resume_after, 0, 0)

function PWNModel.update!(sys::PausingSystem, w::World)
    sys.updated += 1
    if sys.updated == sys.pause_at
        get_resource(w, PWNModel.SchedulerControl).paused = true
    end
end

function PWNModel.update_ui!(sys::PausingSystem, w::World)
    control = get_resource(w, PWNModel.SchedulerControl)
    control.paused || return
    sys.paused_ui_updates += 1
    if sys.paused_ui_updates >= sys.resume_after
        control.paused = false
    end
end

@testset "Scheduler pause stops ticks but not UI updates" begin
    world = World()
    sys = PausingSystem(3, 5)
    # Unlimited ticks and synced UI: while paused, UI updates must still happen,
    # at a limited frame rate instead of spinning.
    scheduler = PWNModel.Scheduler(world, (sys,); fps=-1)

    elapsed = @elapsed PWNModel.run!(scheduler, 10)
    @test sys.updated == 10
    @test sys.paused_ui_updates == 5
    @test get_resource(world, Tick).value == 10
    # 5 UI updates at <= 30 FPS while paused.
    @test elapsed >= 0.6 * 4 / 30
end
