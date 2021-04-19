using TiledViews
using BenchmarkTools

function tv_test(s)
    @btime 
    return 
end


function xx_test(s)
    x = ones(s)
    y = xx(x) .+ sqrt.(1.2 .* abs.(xx(x)));
    @btime $y .= xx($x) .+ sqrt.(1.2 .* abs.(xx($x)));
    @btime $y .= xx($x) .+ sqrt.(1.2 .* abs.(xx($x)));
    return 
end

function compare_to_CartesianIndices()
    x = ones(1000,1000);
    qq2(index) = sum(Tuple(index));
    ww2 = qq2.(CartesianIndices(x));
    y = rr2(x) .+ sqrt.(1.2.*rr2(x).*rr2(x));

    @info "rr2 based"
    @btime $y .= rr2($x) .+ sqrt.(1.2.*rr2($x).*rr2($x));
    @btime $y .= rr2($x) .+ sqrt.(1.2.*rr2($x).*rr2($x));
    @info "CartesianIndices based"
    @btime $y .= ($qq2).(CartesianIndices($x)) .+ sqrt.(1.2.*($qq2).(CartesianIndices($x)).*($qq2).(CartesianIndices($x)));
    @btime $y .= ($qq2).(CartesianIndices($x)) .+ sqrt.(1.2.*($qq2).(CartesianIndices($x)).*($qq2).(CartesianIndices($x)));
    @info "CartesianIndices based with initialized function"
    @btime $y .= $ww2 .+ sqrt.(1.2.*$ww2.*$ww2);
    @btime $y .= $ww2 .+ sqrt.(1.2.*$ww2.*$ww2);
end 

