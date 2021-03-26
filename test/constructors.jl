

@testset "Check constructors" begin 
    float_types_to_test = [Float16, Float32, Float64, ComplexF32, ComplexF64]
    int_types_to_test = [Int16, Int32, Int64]
    
    
    function test_arr(arr, f, T, s)
        @test typeof(arr[s...]) == T
        @test last(arr) ≈ sqrt(sum(abs2.((s))))
        @test arr.size == s
        @test first(arr) ≈ sqrt(sum(abs2.((ntuple(x -> 1, length(s))))))
        @test typeof(arr) <: IndexFunArray{T, length(s), F} where F
    end
    
    
    @testset "Check IndexFunArray initializer for types and boundaries" begin
    
        sizes = [(10, 10), (2,2,2), (3,3,3,3)]
        for s in sizes
            for T in float_types_to_test 
                f(ind) = T(sqrt(sum(abs2.(ind))))
                arr = IndexFunArray(f, s)
                test_arr(arr, f, T, s)
                arr = IndexFunArray(T, f, s)
                test_arr(arr, f, T, s)
            end
        end
    end    
    

#    @testset "Certain special cases" begin
#        @test IndexFunArray(x -> x, (1,0), (1,1), (3, 3)) == [(0, 1) (0, 2) (0, 3); (1, 1) (1, 2) (1, 3); (2, 1) (2, 2) (2, 3)]
#
#    end
end
