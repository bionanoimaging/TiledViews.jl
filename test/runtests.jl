using Test
using Random

using TiledView

@testset "testing array access" begin
    a = TiledView(reshape(1:49,(7,7)), (4, 4),(0, 0));
    @test size(a) == (4,4,3,3)
    @test a[1,1,1,1] == 0   
    @test a[4,4,1,1] == 1
end


@testset "Check errors" begin
    a = TiledView(reshape(1:49,(7,7)), (4, 4),(0, 0));
    @test_throws BoundsError a[0,1,1,1]
    @test_throws BoundsError a[5,1,1,1]
    @test_throws BoundsError a[4,0,1,1]
    @test_throws BoundsError a[4,5,1,1]
    @test_throws BoundsError a[4,1,0,1]
    @test_throws BoundsError a[4,1,4,1]
    @test_throws BoundsError a[4,1,1,0]
    @test_throws BoundsError a[4,1,1,4]
end

@testset "Test own size method" begin
    q = ones(7,7) .+ 0.0
    a = TiledView(q, (5, 4),(3, 2));
    a[:,:,:,:] .= 77;
    @test !any(q .!= 77.0)
end

return
