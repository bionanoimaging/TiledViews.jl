using Test
using Random

using IndexFunArrays



@testset "Test defined array operation" begin
    f(ind) = ind[1]
    arr = IndexFunArray(Int, f, (10, 10))
    @test arr[2] == arr[12] == arr[2, 2] == 2
    
    arr2 = similar(arr, (11, 11))
    @test arr2[2] == arr2[13] == arr2[2, 2] == 2

    for s in [(10,), (10,1,2), (100, 100), (20,2,2,2,2)]
        @test s == size(IndexFunArray(ComplexF32, x -> zero(ComplexF32), s))
    end

end


@testset "Check errors" begin
    f() = try IndexFunArray(Int, x -> zero(Float32), (10, 10))
        return false
    catch Error
        return true
    end
    a = IndexFunArray(Int, x -> zero(Int), (10, 10))
   
    g() = try a[1] = 1
        return false
    catch Error
        return true
    end

    @test f()
    @test g()
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
