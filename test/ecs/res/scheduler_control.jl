@testset "SchedulerControl" begin
    control = PWNModel.SchedulerControl()
    @test control.tps == 0.0
    @test control.fps == 0.0
    @test control.paused == false

    control2 = PWNModel.SchedulerControl(; tps=30, fps=-1, paused=true)
    @test control2.tps == 30.0
    @test control2.fps == -1.0
    @test control2.paused == true
end

@testset "next_tps" begin
    @test PWNModel.next_tps(0, true) == 1.0
    @test PWNModel.next_tps(30, true) == 40.0
    @test PWNModel.next_tps(33, true) == 40.0
    @test PWNModel.next_tps(10000, true) == 10000.0

    @test PWNModel.next_tps(30, false) == 20.0
    @test PWNModel.next_tps(33, false) == 30.0
    @test PWNModel.next_tps(1, false) == 0.0
    @test PWNModel.next_tps(0, false) == 0.0
    @test PWNModel.next_tps(20000, false) == 10000.0
end
