using Statistics
using DelimitedFiles
using StatGeochem
using HDF5

"""
Keep a running mean
m mean so far
n number of samples so far
"""
mutable struct RunningMean
	m::Float64
	n::Int
end

function RunningMean()
	return RunningMean(0., 0)
end

"""
Add a new number to a running mean
"""
function mean!(running::RunningMean, new::Number)
	running.m = (running.n*running.m + new)/(running.n + 1)
	running.n += 1
end

"""
Stored info for normalizing samples. Used in some inversion models (PCA and linear)
"""
struct Norm
	std::Float64
	mean::Float64
end

function normalize(norm::Norm, arr::Array)
	return (arr .- norm.mean) ./ norm.std
end

"""
Normalize each row of input matrix (in place)
"""
function normalizeComp!(a::AbstractArray{Float64, 2})
	sums = sum(a,dims=2)
	for row in 1:size(a,1)
		a[row,:] .= (a[row,:] ./ sums[row]) .* 100
	end
end

function inverseMean(a::AbstractArray{Float64})
	return 1/(nanmean(1 ./ a))
end

"""
Convert Dabie compositions to Perplex / Ign
"""
function convert_dabie(f::String)
	comps, h = readdlm(f, ',', header=true)
	h = h[:]
	sample_names = comps[:,1][:]
	comp_compat = zeros((size(comps,1),length(COMPOSITION_ELEMENTS)))
	for (j, name) in enumerate(COMPOSITION_ELEMENTS)
	    if name == "H2O_Total"
	        name = "H2OC"
	    end
	    if name == "FeO"
	        feoi = findfirst(isequal("FeO"),h)
	        fe2o3i = findfirst(isequal("Fe2O3"), h)
	        feo = [feoconversion(comps[i, feoi], comps[i, fe2o3i]) for i in 1:size(comps,1)]
	        comp_compat[:,j] .= feo
	    else
	        comp_compat[:, j] .= comps[:,findfirst(isequal(name), h)]
	    end
	end
	return comp_compat, sample_names
end

# Return list of means where each mean averages over n values of dat
function runs_means(dat, n)
	print("Fraction nan: ", sum(isnan.(dat))/length(dat))
    means = []
    for i in 1:floor(Int,length(dat)/n)
        append!(means, nanmean(dat[(i-1)*n+1:i*n]))
    end
    return means
end

"""
Write options to option file
"""
function writeOptions(filename, options)
	out = fill("", (length(keys(options)), 2))
	for (k, key) in enumerate(keys(options))
		out[k, 1] = key
		out[k, 2] = string(options[key])
	end
	writedlm(filename, out, ",")
end

"""
For values at each location in latitide/longitude, find average value per lat/long grid square.
Return lat, long, ave value for each square, with val=NaN for squares with no values.
size combines that size^2 lat/long squares into each returned square.
If var, also return variance
"""
function areaAverage(latitude::Array{Float64,1}, longitude::Array{Float64,1}, vals::Array{Float64,1}; size::Int=1, return_std::Bool=false)
	good = .!(isnan.(latitude) .| isnan.(longitude) .| isnan.(vals))

	m = Dict{Tuple, Array}() # map from lat/long to list of values
	# Want full globe for visualization, even where no values
	# for lat in range(floor(minimum(latitude[good])/size), stop=floor(maximum(latitude[good])/size))
	# 	for long in range(floor(minimum(longitude[good])/size), stop=floor(maximum(longitude[good])/size))
	# 		m[(floor(lat), floor(long))] = []
	# 	end
	# end

	# now put in those values
	latitude = latitude[good] ./ size
	longitude = longitude[good] ./ size
	vals = vals[good]
	for i in 1:length(latitude)
		a = get!(m, (floor(latitude[i]), floor(longitude[i])), [])
		append!(a, vals[i])
	end
	# for k in keys(m)
	# 	m[k] = [nanmean(Array{Float64}(m[k]))]
	# end

	ks = keys(m)
	vs = [m[k] for k in ks] # make sure no reordering
	lats = [k[1] for k in ks]
	longs = [k[2] for k in ks]
	val = [mean(v) for v in vs]
	if return_std
		variance = [std(v) for v in vs]
	end

	#good = .!(isnan.(lats) .| isnan.(longs) .| isnan.(val))

	#return lats[good].*size, longs[good].*size, val[good]
	if return_std
		return lats.*size, longs.*size, val, variance
	end
	return lats.*size, longs.*size, val
end

"""
For plotting latitude and longitude data.
Assumes lat/long pairs are unique (run after areaAverage)
Returns grid with NaN at any missing values
"""
function globe(lats, longs, vals)
	slats = sort(unique(lats))
	slongs = sort(unique(longs))
    g = fill(NaN, (length(slats), length(slongs)))
	#println(size(g))
    for i in 1:length(lats)
        y = searchsortedfirst(slats, lats[i])
        x = searchsortedfirst(slongs, longs[i])
        #println("$x, $y")
        g[y,x] = vals[i]
    end
    return g
end

function plotglobe(k::String, dat, header)
    return globe( areaAverage(
    	dat[:, findfirst(isequal("sample_lat"), header)],
    	dat[:, findfirst(isequal("sample_long"), header)],
    	dat[:, findfirst(isequal(k), header)])...)
end

"""
Take area averages of composition samples and corresponding Perple_X samples.
"""
function areaAverage(inputDataDir::String, outputDataDir::String)
	# use file from first geotherm bin to collect indices by lat/long
	file = "data/" * inputDataDir * "/bsr_ignmajors_1.csv"
	dat = readdlm(file, ',')
	mkdir("data/$outputDataDir")

	# Create mapping from unique lat/longs to sample indices
	lat_i = findfirst(isequal("Latitude"), PERPLEX_ELEMENTS)
	long_i = findfirst(isequal("Longitude"), PERPLEX_ELEMENTS)
	dat[:,lat_i] = floor.(dat[:,lat_i])
	dat[:,long_i] = floor.(dat[:,long_i])
	m = Dict{Tuple, Array}()
	for j in 1:size(dat,1)
		a = get!(m, (dat[j, lat_i], dat[j, long_i]), [])
		append!(a, j)
	end

	# Average data by lat/long bin for every (geotherm bin)/layer combo
	fileNames = filter(x->contains(x,"perplex_out_"), readdir("data/$inputDataDir"))
	nBins = length(fileNames)
	for file_i in 1:nBins
		ign = readdlm("data/$inputDataDir/bsr_ignmajors_$file_i.csv", ',')
		perplex = h5read("data/$inputDataDir/perplex_out_$file_i.h5", "results")
		new_perplex = fill(NaN, (4,3,length(m)))
		new_ign = fill(NaN, (length(m), size(dat,2)))
		for (new_i, k) in enumerate(keys(m))
			new_ign[new_i, :] = mean(dat[m[k],:], dims=1)
			new_ign[new_i, 1] = new_i
			for j in 1:size(perplex, 1)
				for l in 1:size(perplex, 2)
					new_perplex[j, l, new_i] = inverseMean(perplex[j, l, m[k]])
				end
			end
			new_perplex[1, :, new_i] .= new_i # index is not average index
		end
		writedlm("data/$outputDataDir/bsr_ignmajors_$file_i.csv", new_ign, ',')
		h5write("data/$outputDataDir/perplex_out_$file_i.h5", "results", new_perplex)
	end

	# Write options file
	writeOptions("data/$outputDataDir/areaAverage_options.csv", Dict([("inputDir", inputDataDir)]))
end
