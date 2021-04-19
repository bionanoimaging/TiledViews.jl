using CUDA
using TiledViews

function testCUDA_TV(s=(1024,1024), Niter=100)
    @time arr .= Mandelbrot;
    
    return arr
end
