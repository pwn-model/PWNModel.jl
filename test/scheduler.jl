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
