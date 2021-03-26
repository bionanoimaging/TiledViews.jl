using Test
using Random

using TiledView

@testset "testing array access" begin
    a = TiledView(reshape(1:49,(7,7)), (4, 4),(0, 0));
    @test size(a) == (4,4,3,3)
    @test a[1,1,1,1] == 1    
end


@testset "Check errors" begin
    a = TiledView(reshape(1:49,(7,7)), (4, 4),(0, 0));
    @test_throws BoundsError a[0,1,1,1]
    @test_throws BoundsError a[5,1,1,1]
    @test_throws BoundsError a[4,0,1,1]
    @test_throws BoundsError a[4,5,1,1]
    @test_throws BoundsError a[4,1,0,1]
    @test_throws BoundsError a[4,1,5,1]
    @test_throws BoundsError a[4,1,1,0]
    @test_throws BoundsError a[4,1,1,5]
end

@testset "Test own size method" begin
    x = ones((2,4,6,8, 10));
    @test selectsizes(x, (2, 3, 4)) == (1, 4, 6, 8, 1)
    @test selectsizes(x, (4, 3, 2), keep_dims = false) == (8, 6, 4)
    
    x = ones((10));
    @test selectsizes(x, (1,), keep_dims=false) == (10,)
    @test selectsizes(x, (1,), keep_dims=true) == (10,)
    

    x = ones((10, 10));
    @test selectsizes(x, (1, 2), keep_dims=false) == (10, 10)
    @test selectsizes(x, (1, 2), keep_dims=true) == (10, 10)
   
    x = ones((1,1,3));
    @test selectsizes(x, (1,2), keep_dims=false) == (1,1)
    @test selectsizes(x, (3,3), keep_dims=false) == (3,3)
    @test selectsizes(x, (3,3), keep_dims=true) == (1, 1, 3)

end



include("constructors.jl")

include("concrete_generators.jl")

return
