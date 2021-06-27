using TiledViews, TestImages, Images, Statistics
# lets normalize each tile to a mean and standard deviation of 0.5 and stitch them back together
data = Float32.(testimage("cameraman"));
Gray.(data)

tile_size = (50, 50)
tile_overlap = (20,20)
myview = TiledView(data, tile_size, tile_overlap);
size(myview)

# make a new view to copy into
dest = TiledViews.zeros_like(myview);
typeof(dest)

# Define a function that does the work
do_normalize(tile) = 0.5 .+ 0.5.*(tile .- mean(tile))./ std(tile) ;

for (src, dst) in zip(get_tile_iterator(myview), get_tile_iterator(dest))
    dst .= do_normalize(src)
end
Gray.(dest.parent)

# now lets do this with smoother transitions using a window
my_window = get_window(myview);
Gray.(my_window)
typeof(my_window)   # This is actually an IndexFunArray (~ no memory needed)

dest2 = TiledViews.zeros_like(myview); # just to make a new view to copy into
for (src, dst) in zip(get_tile_iterator(myview), get_tile_iterator(dest2))
    dst .+= my_window .* do_normalize(src);
end
Gray.(dest.parent)
Gray.(dest2.parent)

# A more convenient way:
myview, matching_window = TiledWindowView(data, (50, 50);verbose=true);

# Evan more convenient:
res = tiled_processing(myview, do_normalize; verbose=true);
Gray.(res.parent)
