using CUDA
using IndexFunArrays

function f(arr, x)
    arr .= arr.^2 .+ arr.^3 .+ sqrt.(x)
    return arr
end

function f2(arr)
    arr .= arr.^2 .+ arr.^3 .+ sqrt.(arr .^2) 
    return arr
end

function f3(arr)
    arr = arr.^2 .+ arr.^3 .+ sqrt.(arr .^2) 
    return arr
end

function test(s)
    arr = randn(Float32, s)
    arr_c = CuArray(arr)
    x = rr2(Float32, s)
    x_c = CuArray(rr(Float32, s))

    @info "f on CPU"
    @time f(arr, x);
    @time f(arr, x);
    @info "f2 on CPU"
    @time f2(arr);
    @time f2(arr);
    @info "f on GPU"
    CUDA.@time f(arr_c, x);
    CUDA.@time f(arr_c, x);
    @info "f2 on GPU"
    CUDA.@time f2(arr_c);
    CUDA.@time f2(arr_c);
    @info "f3 on GPU"
    CUDA.@time f3(arr_c);
    CUDA.@time f3(arr_c);

    return 
end 

function MandelbrotIterations(c, Niter=500)
    x = c
    res = 0
    for n in 1:Niter
        x = x.^2 .+ c
        #if abs(x) > 4.0 && (res == 0)
        #    res = n
        #end
        res += (res == 0)*(abs(x)> 4.0)*n  # ensure that only the first breakage counts but avoid if
    end
    return (res % 127)
end

function MandelbrotIterations(idx,start,scale, Niter=100)
    c = Complex(start[1].+idx[1].*scale[1],start[2].+idx[2].*scale[2])
    return MandelbrotIterations(c..., Niter)
end

function testMandelbrotArray(s=(1024,1024), Niter=100)
    arr = zeros(Int64, s)
    scale = (3.0,3.0)./s;
    start=(-2.3,-1.5);
    @info "Test MandelBrot Array CPU"
    @time arr .= MandelbrotIterations.(CartesianIndices(arr), [scale], [start])
    @time arr .= MandelbrotIterations.(CartesianIndices(arr), [scale], [start])
end

function testMandelbrotIFA(s=(1024,1024), Niter=100)
    arr = zeros(Int64, s)
    scale = (3.0,3.0)./s;
    start=(-2.3,-1.5);
    Mandelbrot = IndexFunArray(x -> MandelbrotIterations(x,start, scale,Niter), size(arr));
    @info "Test MandelBrot IndexFunArray CPU"
    @time arr .= Mandelbrot;
    @time arr .= Mandelbrot;
    
    #arr_c = CuArray(arr)
    #CUDA.@time arr_c .= Mandelbrot
    #CUDA.@time arr_c .= Mandelbrot
    #CUDA.@time arr_c .= MandelbrotIterations.(arr_c,start,scale,Niter)
    return arr
end

#using Napari
#napari.view_image(testMandelbrotIFA())

