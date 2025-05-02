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
    @test [(-80, -91)  (-80, 0)  (-80, 91);  (0, -91)    (0, 0)    (0, 91); (80, -91)   (80, 0)   (80, 91)] == tile_centers(a)
end

#=
@testset "similar" begin
    function compare_sizes(a)
        b=similar(a);
        #print(size(a));print(size(b));size(b.parent)
        @test all(size(a) .== size(b))
        @test all(size(a.parent) .<= size(b.parent))
        c=similar(a,Int64,size(b).+1)
        @test all(size(c) .== size(a) .+1)
        @test all(size(c.parent) .> size(a.parent))
    end
    for n in 1:40
        dims = rand(1:5);
        sz = Tuple(rand(3:7,dims));
        ts = Tuple(rand(1:4,dims));
        overlap = Tuple(rand(0:2,dims));
        overlap = Tuple(((overlap[n] >= ts[n]) ? ts[n]-1 : overlap[n] for n in 1:length(ts)));
        keep_ctr = rand(Bool);
        a = TiledView(ones(sz...), ts, overlap, keep_center=keep_ctr);
        compare_sizes(a);
    end
end
=#
@testset "zeros_like" begin
    q = rand(100,101);
    a=TiledView(q, (80,91), (0,0), keep_center=false);
    w = TiledViews.zeros_like(a)
    @test size(w) == size(a)
end

@testset "similar" begin
    q = rand(100,101);
    a=TiledView(q, (80,91), (0,0));
    @test size(similar(a)) == size(a)
    @test eltype(similar(a,Int32)) == Int32
    @test size(similar(a,Int32,(30,40,1))) == (30,40,1)
end

@testset "TiledWindowView" begin
    dest = ones(512,512)
    tile_size = (65,65)
    tiles, win = TiledWindowView(dest, tile_size, rel_overlap=(1.0,1.0));
    to_write = 0.2 .* win .* collect(tiles[:,:,:,:]);
    #tiles[:,:,:,:] .+= to_write[:,:,:,:] ;  # why can one NOT use [:,:,:,:]? 
    tiles .+= to_write ;  # why can one NOT use [:,:,:,:]? 
    @test sum(abs.(dest[50:end-50,50:end-50] .- 1.2)) < 1e-10
    win2, mynorm = get_window(tiles, get_norm=true, verbose=true);
    @test all(win .== win2)
    tiles, win = TiledWindowView(dest, tile_size, rel_overlap=(1.0,1.0), get_norm=true);
    @test all(win .== win2)

    arr = [i*10 + j for i=0:8, j=0:9]
    q = TiledView(arr, (4,4), (0,0), keep_center=true);
    @test q[3,3,2,2] == 45 # see if the center really aligns with the center
    arr = [i*10 + j for i=0:8, j=0:9]
    q = TiledView(arr, (5,5), (0,0), keep_center=true);
    @test q[3,3,2,2] == 45 # see if the center really aligns with the center
end

@testset "sub-indexing" begin
    q = rand(100,101);
    a=TiledView(q, (80,91), (0,0));
    @test size(a[:,3:14,1:2,1]) == (80,12,2)
end

@testset "eachtile" begin
    q = zeros(100,101);
    a=TiledView(q, (80,91), (0,0));
    for (t,tn,tc,tc2) in zip(eachtile(a),eachtilenumber(a),eachtilerelpos(a),eachtilerelpos(a,2.0))
        t[:] .+= tn[1];
    end
    @test q[end,end] == 3
end

@testset "tiled_processing" begin
    q = ones(10,10,10);
    a = TiledView(q, (4,4,4), (2,2,2));
    @test get_num_tiles(a) == (6,6,6)
    res = tiled_processing(a, (v)->sin.(v); verbose=false);

    res2 = tiled_processing(q, (v)->sin.(v), (4,4,4), (2,2,2); verbose=false);
    @test maximum(res2.parent) ≈ sin(1)
    @test res != res2
    a = TiledView(q, (4,4,4), (2,2,2); keep_center=false);
    @test get_num_tiles(a) == (5,5,5)
    res3 = tiled_processing(a, (v)->sin.(v); verbose=false);
    @test res2 == res3

    # test for incomplete tile sizes to be expanded
    @test all(tiled_processing(ones(10,20), (a)->3 .*a, (2,), window_function = TiledViews.IndexFunArrays.window_hanning, verbose=false).parent .== 3)
    # test for functions that reduce dimensions and also test for a bug in the window function
    @test all(tiled_processing(ones(10,20), (a)->sum(a, dims=2), (2,),  window_function = TiledViews.IndexFunArrays.window_hanning, verbose=false).parent .== 20)
    fct2 = (a)->[3 .*a, sum(a, dims=2), "result: $(sum(a))"]; # a function that returns a tuple of three values of very different types
    res = tiled_processing(ones(5,6), fct2, (2,), verbose=true)
    @test all(res[1].parent .== 3)
    @test all(res[2].parent .== 6)
    @test all(res[3][1:2] .== "result: 12.0") # this is a random number, so it should be the same for all tiles
    @test all(res[3][3] .== "result: 6.0") # this is a random number, so it should be the same for all tiles
    res = tiled_processing(ones(10,10), (a)->rand(4,5), (5,5), (0,0), verbose=false);
    @test typeof(res) == Matrix{Matrix{Float64}}
    @test size(res) == (2,2)
end

return
