@testset "Test generated concrete generator functions" begin

    @testset "Type conversion for default type" begin
        def_T = Float64

        Types_changed = [Bool, Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128]
        Types_unchanged = [ComplexF32, ComplexF64, Complex{Int}, Float32, Float64]

        for T in Types_changed
            IndexFunArrays.default_type(T, Float64) = Float64
            for T2 in Types_changed
                @test IndexFunArrays.default_type(T, def_T) == def_T
            end
        end
        
        for T in Types_unchanged
            for T2 in Types_changed
                @test IndexFunArrays.default_type(T, T2) == T
            end
        end
    end

    @testset "Test rr method" begin
    
    
        @test rr((5,)) == [2.0, 1.0, 0.0, 1.0, 2.0]
        @test rr(Int, (5,)) == [2, 1, 0, 1, 2]
        @test rr((4, 4)) == [2.8284271247461903 2.23606797749979 2.0 2.23606797749979; 2.23606797749979 1.4142135623730951 1.0 1.4142135623730951; 2.0 1.0 0.0 1.0; 2.23606797749979 1.4142135623730951 1.0 1.4142135623730951]
    
        @test rr((2, 3), offset=(1, 1)) == [0.0 1.0 2.0; 1.0 1.4142135623730951 2.23606797749979]
    
        @test rr((2, 3), offset=(1, 1)) == [0.0 1.0 2.0; 1.0 1.4142135623730951 2.23606797749979]
    
        @test rr(Float64, (3, 5), offset = CtrCorner, scale = ScaUnit) == [0.0 1.0 2.0 3.0 4.0; 1.0 1.4142135623730951 2.23606797749979 3.1622776601683795 4.123105625617661; 2.0 2.23606797749979 2.8284271247461903 3.605551275463989 4.47213595499958]
    
        @test rr2(Int, (10, )) == [25; 16; 9; 4; 1; 0; 1; 4; 9; 16]
        @test rr2(Int, (10, 1)) == reshape([25; 16; 9; 4; 1; 0; 1; 4; 9; 16], (10, 1))
    end


    @testset "Test rr2 method for an array as input" begin
        x = rand((1:100), (10,))
        @test rr2(x) == [25; 16; 9; 4; 1; 0; 1; 4; 9; 16]
        x = rand((1:100), (10,1))
        @test rr2(x) == reshape([25; 16; 9; 4; 1; 0; 1; 4; 9; 16], (10, 1))

    end

    @testset "Test xx and yy method" begin
        a = xx(Float64, (3, 5), offset = CtrCorner, scale = ScaUnit)
        b = yy(Float64, (5, 3), offset = CtrCorner, scale = ScaUnit)'
        @test  a == [0.0 0.0 0.0 0.0 0.0; 1.0 1.0 1.0 1.0 1.0; 2.0 2.0 2.0 2.0 2.0]
        @test a == b

        @test xx(Int, (3, 5), offset = CtrCorner, scale = ScaUnit) == [0 0 0 0 0; 1 1 1 1 1; 2 2 2 2 2] 
    end


    @testset "Test different scalings" begin
        @test rr((10,), scale = ScaNorm) == [0.5555555555555556, 0.4444444444444444, 0.3333333333333333, 0.2222222222222222, 0.1111111111111111, 0.0, 0.1111111111111111, 0.2222222222222222, 0.3333333333333333, 0.4444444444444444]
        @test rr((10,), scale = ScaFT) == [0.5, 0.4, 0.30000000000000004, 0.2, 0.1, 0.0, 0.1, 0.2, 0.30000000000000004, 0.4]
    
        @test rr((11,), scale = ScaFTEdge) == [1.0, 0.8, 0.6000000000000001, 0.4, 0.2, 0.0, 0.2, 0.4, 0.6000000000000001, 0.8, 1.0]
        
        @test rr((10,), scale = ScaFTEdge) == [1.0, 0.8, 0.6000000000000001, 0.4, 0.2, 0.0, 0.2, 0.4, 0.6000000000000001, 0.8]


        @test rr((11,), scale = (5,)) == [25.0, 20.0, 15.0, 10.0, 5.0, 0.0, 5.0, 10.0, 15.0, 20.0, 25.0]

        @test rr((4,), scale = (5,)) == [10.0, 5.0, 0.0, 5.0]
    end

    @testset "Test rr for different offsets" begin
        @test rr2(Int, (5, 5), offset = CtrFFT) == [0 1 4 9 16; 1 2 5 10 17; 4 5 8 13 20; 9 10 13 18 25; 16 17 20 25 32]
        @test rr2(Int, (4, 4), offset = CtrFFT) == [0 1 4 9; 1 2 5 10; 4 5 8 13; 9 10 13 18]
        @test rr2((5, 5), offset = CtrMid) == [8.0 5.0 4.0 5.0 8.0; 5.0 2.0 1.0 2.0 5.0; 4.0 1.0 0.0 1.0 4.0; 5.0 2.0 1.0 2.0 5.0; 8.0 5.0 4.0 5.0 8.0]
        @test rr2((4, 4), offset = CtrMid) == [4.5 2.5 2.5 4.5; 2.5 0.5 0.5 2.5; 2.5 0.5 0.5 2.5; 4.5 2.5 2.5 4.5]
        
        @test rr2((4, 4), offset = CtrEnd) == [18.0 13.0 10.0 9.0; 13.0 8.0 5.0 4.0; 10.0 5.0 2.0 1.0; 9.0 4.0 1.0 0.0]
        @test rr2((5, 6), offset = CtrEnd) == [41.0 32.0 25.0 20.0 17.0 16.0; 34.0 25.0 18.0 13.0 10.0 9.0; 29.0 20.0 13.0 8.0 5.0 4.0; 26.0 17.0 10.0 5.0 2.0 1.0; 25.0 16.0 9.0 4.0 1.0 0.0]

    end
end


@testset "Test window functions" begin



    # simple window_hanning test
    @testset "window_hanning window test" begin
        window_hanning((10, ), border_in=0, border_out=1) ≈ sinpi.(range(0, 1, length=11)[1:end-1]).^2
        window_hanning((10, ), border_in=0.4, border_out=0.499) ≈ [0, 0, 0, 1, 1, 1, 1, 1, 0, 0]
        
        x = window_hanning(Int, (10, ), border_in=0.4, border_out=0.499) 
        @test x ≈ [0, 0, 0, 1, 1, 1, 1, 1, 0, 0]
        @test typeof(x) <: IndexFunArray{Int, 1, T} where T
        
        x = window_hanning(ComplexF32, (10, ), border_in=0.4, border_out=0.499) 
        @test x ≈ [0, 0, 0, 1, 1, 1, 1, 1, 0, 0]
        @test typeof(x) <: IndexFunArray{ComplexF32, 1, T} where T
        

        x = window_hanning(Float32.(randn((10, ))), border_in=0.4, border_out=0.499) 
        @test x ≈ [0, 0, 0, 1, 1, 1, 1, 1, 0, 0]
        @test typeof(x) <: IndexFunArray{Float32, 1, T} where T
        
    end

    @testset "window_linear and window_radial_linear" begin

        @test window_linear((4, 4), border_in = 0, border_out = 1) == [0.0 0.0 0.0 0.0; 0.0 0.25 0.5 0.25; 0.0 0.5 1.0 0.5; 0.0 0.25 0.5 0.25]
        @test window_linear((4, 4), border_in = 0, border_out = 1, offset = CtrCorner, scale = ScaNorm) == [1.0 0.6666666666666667 0.33333333333333337 0.0; 0.6666666666666667 0.44444444444444453 0.22222222222222227 0.0; 0.33333333333333337 0.22222222222222227 0.11111111111111113 0.0; 0.0 0.0 0.0 0.0]

        @test window_radial_linear((4, 4), border_in = 0, border_out = 1, offset = CtrCorner, scale = ScaNorm) == [1.0 0.6666666666666667 0.33333333333333337 0.0; 0.6666666666666667 0.5285954792089683 0.2546440075000701 0.0; 0.33333333333333337 0.2546440075000701 0.057190958417936644 0.0; 0.0 0.0 0.0 0.0]
    end

    



end



