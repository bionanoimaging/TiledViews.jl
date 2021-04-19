using TiledViews

function reading_writing()
    flat = collect(reshape(1:49,(7,7)))
    tiled = TiledView(flat, (4, 4),(0, 0));
    tileW, matching_window = TiledWindowView(flat, (5, 5);verbose=true);
    @show size(tileW)
    windowed = collect(tileW .* matching_window);
    tileW[:,:,:,:] .= 0  # cleares the original array
    @show tileW.parent
    tileW .+= windowed  # writes the windowed data back into the array
    @show flat
end 



data = ones(10,10).+0.0;
myview, matching_window = TiledWindowView(data, (5, 5);verbose=true);
size(myview)
windowed = collect(myview .* matching_window);
myview[:,:,:,:].=0  # cleares the original array
