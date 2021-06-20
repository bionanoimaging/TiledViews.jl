using Test
using Random
using TiledViews

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

@testset "Test tile_centers" begin
    q = rand(100,101);
    a=TiledView(q, (80,91), (0,0));
    @test [[(-60, -54), (20,-54)] [(-60, 37), (20,37)]] == tile_centers(a)
end

@testset "similar" begin
    function compare_sizes(a)
        b=similar(a);
        print(size(a));print(size(b));size(b.parent)
        @test all(size(a) .== size(b))
        @test all(size(a.parent) .<= size(b.parent))
        c=similar(a,Int64,size(b).+1)
        @test all(size(c) .== size(a) .+1)
        @test all(size(c.parent) .> size(a.parent))
    end
    for n in 1:40
        dims = rand(1:5)
        sz = Tuple(rand(3:7,dims))
        ts = Tuple(rand(1:4,dims))
        overlap = Tuple(rand(0:2,dims))
        overlap = Tuple(((overlap[n] >= ts[n]) ? ts[n]-1 : overlap[n] for n in 1:length(ts)))
        keep_ctr = rand(Bool)
        a = TiledView(ones(sz...), ts, overlap, keep_center=keep_ctr);
        compare_sizes(a)
    end
end

return
