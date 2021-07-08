"""
Create main figure (composition of upper, middle, and lower crust over time)

"""

using ArgParse
using DelimitedFiles 
using Plots; gr();
using Statistics

include("../src/bin.jl")
include("../src/config.jl")
include("../src/crustDistribution.jl")
include("../src/invertData.jl")

s = ArgParseSettings()
@add_arg_table s begin
    "--data_path", "-p"
        help = "Path to model output"
        arg_type= String
        required=true
    "--compare_to", "-c"
    	help = "Other results to compare to this one. Full paths to result dirs."
    	arg_type= String
    	nargs = '*'
    "--titles", "-t"
    	help = "Title for each of compare to datasets. Base first, then each of comapre_to in order."
    	arg_type = String
    	nargs = '*'
end 

parsed_args = parse_args(ARGS, s)
## Defaults for compare variables: default to corresponding main result variable. 
if length(parsed_args["titles"]) < (length(parsed_args["compare_to"]) + 1)
	append!(parsed_args["titles"], fill("no title provided", (length(parsed_args["compare_to"]) + 1)-length(parsed_args["titles"])))
end 

build_args = readdlm("$(parsed_args["data_path"])/inversion_options.csv", ',', header=false)
N = build_args[findfirst(isequal("num_invert"), build_args[:,1]),2]
M = build_args[findfirst(isequal("num_runs"), build_args[:,1]),2]

# By age! 
function find_age_aves(files, N, M)
	age_model = EarthChemAge(10, 3) # Default in inversion_binned_geotherm 
	ages = ageBins(age_model) 

	age_results = Array{Float64, 2}(undef, 3, length(ages)-1) # (layer, age)
	age_1std = Array{Float64, 2}(undef, 3, length(ages)-1) # (layer, age)


	for (l, file) in enumerate(files)	
		layer = LAYER_NAMES[l]

		(result, header) = readdlm(file, ',', header=true)
		header = header[:] # make 1d 

		si_index = findfirst(isequal("SiO2"), header) # result 
		age_index = findfirst(isequal("sample_age"), header) # Age 
		#good = ((.~isnan.(result[:,si_index])) .& (.~isnan.(result[:,age_index])))

		age_median = []
		age_low = []
		age_high = [] # 95 percentile

		# Oversampling ratio -- IS THIS RIGHT???
		#n_original = length(crustDistribution.all_lats) # number of 1x1 grid cells w data 
		#n_resampled = size(result, 1) 

		for (i, age) in enumerate(ages[1:end-1])
			mc_avgs = fill(NaN, M)
			for m in 1:M
				# only this run 
				istart = (m-1)*N + 1
				iend = m*N
				dat = result[istart:iend]

				test = ((dat[:,age_index] .>= age) .& (dat[:,age_index] .< ages[i+1]) .& good)
				age_results[l,i] = nanmean(result[test,si_index])
				
		end 
	end
	return ages, age_results, age_1std
end 

files = ["$(parsed_args["data_path"])/results-$layer.csv" for layer in LAYER_NAMES]
ages, age_results, age_1std = find_age_aves(files, N, M)


p1 = plot(legend=false, ylabel="% SiO2", ylims=(52, 70), title="Upper", titlefontsize=11) 
p2 = plot(legend=:bottomright, legendfontsize=7, fg_legend = :transparent, ylabel="% SiO2", ylims=(52, 70), title="Middle", titlefontsize=11)
p3 = plot(legend=false, xlabel="Age", ylabel="% SiO2", ylims=(52, 70), title="Lower", titlefontsize=11)
ps = [p1, p2, p3]

p = plot(size=(500,450), legend=:bottomright, fg_legend = :transparent, framestyle=:box, xlabel="Age", ylabel="SiO2 (weight %)");

for i in 1:3 # layers 
	color = [:blue, :orange, :green][i]
	plot!(ps[i], ages[1:end-1], age_results[i,:], yerror=age_1std[i,:], label=parsed_args["titles"][1], markerstrokecolor=color, 
		linecolor=color, markercolor=color)
	plot!(p, ages[1:end-1], age_results[i,:], yerror=age_1std[i,:], label=LAYER_NAMES[i], markerstrokecolor=color, 
		linecolor=color, markercolor=color)
end 

# Upper, middle, and lower from Rudnick and Fountain 

# for i in 1:3 
# 	plot!(ps[i], [200], [66.0], seriestype=:scatter, marker=8,markershape=:star5, markercolor=:blue, label="")
# 	plot!(ps[i], [200], [60.6], seriestype=:scatter, marker=8,markershape=:star5, markercolor=:orange, label="")
# 	plot!(ps[i], [200], [52.3], seriestype=:scatter, marker=8,markershape=:star5, markercolor=:green, label="")
# end 

# plot!(p, [200], [66.0], seriestype=:scatter, marker=8,markershape=:star5, markercolor=:blue, label="")
# plot!(p, [200], [60.6], seriestype=:scatter, marker=8,markershape=:star5, markercolor=:orange, label="")
# plot!(p, [200], [52.3], seriestype=:scatter, marker=8,markershape=:star5, markercolor=:green, label="")


# Plot exposed. Always use base so have same comparison... 
# TODO this will need to change when re-do base w new elts
tmin = 0
tmax = 4000
nbins = 4
samplePath = "data/remote/base_nobin/bsr_ignmajors_1.csv"
ign, h = readdlm(samplePath, ',', header=true)
age_i = findfirst(isequal("Age"),PERPLEX_ELEMENTS)
si_i = findfirst(isequal("SiO2"),PERPLEX_ELEMENTS)
original = matread(IGN_FILE)
age_centers, elt_means, elt_errors = bin(ign[:,age_i], ign[:,si_i],
        tmin, tmax, length(ign[si_i])/length(original["SiO2"]), nbins)

plot!(ps[1], age_centers, elt_means, color=:pink, 
	yerror=elt_errors, label="exposed", markerstrokecolor=:auto);
plot!(p, age_centers, elt_means, color=:pink, 
	yerror=elt_errors, label="exposed", markerstrokecolor=:auto);


# Compare to pre-resampled ign 
# ign = matread(IGN_FILE)
# age_centers, elt_means, elt_errors = bin(ign["Age"], ign["SiO2"],
#         tmin, tmax, nbins)
# plot!(p, age_centers, elt_means, yerror=elt_errors, label="exposed", markerstrokecolor=:auto);

# If some to compare to, compare to them. 
if length(parsed_args["compare_to"]) > 0
	for (d, datum) in enumerate(parsed_args["compare_to"])
		files = ["$datum/results-$layer.csv" for layer in LAYER_NAMES]
		ages, age_results, age_1std = find_age_aves(files)

		for i in 1:3 # layers 
			color = [:blue, :orange, :green][i]
			linestyle = [:dash, :dot, :dashdot, :dashdotdot, :dash][d]
			plot!(ps[i], ages[1:end-1], age_results[i,:], yerror=age_1std[i,:], label=parsed_args["titles"][d+1], markerstrokecolor=color, 
				linecolor=color, markercolor=color, linestyle=linestyle)
			plot!(p, ages[1:end-1], age_results[i,:], yerror=age_1std[i,:], label=LAYER_NAMES[i], markerstrokecolor=color, 
				linecolor=color, markercolor=color, linestyle=linestyle)
		end 

	end 
end


outputPath = "$(parsed_args["data_path"])/output"
mkpath(outputPath) # make if does not exist
if length(parsed_args["compare_to"]) == 0
	savefig(p, outputPath*"/composition-ages.pdf");
else 
	savefig(p, outputPath*"/composition-ages-compare.pdf");
	p2 = plot(ps..., size=(400,700), layout=(3,1))
	savefig(p2, outputPath*"/composition-ages-compare-split.pdf");
end