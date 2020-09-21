""" 
Inversion for binned geotherm (works for not binned too; treats like nbins=1)

Main entry script for inversions. 
"""

using DelimitedFiles
using HDF5
using StatGeochem
using StatsBase
using ProgressMeter: @showprogress
using ArgParse
using Plots; gr();

include("../src/inversionModel.jl")
include("../src/invertData.jl")
include("../src/vpOnlyModel.jl")
include("../src/vpRhoModel.jl")
include("../src/bin.jl")
include("../src/config.jl")

s = ArgParseSettings()
@add_arg_table! s begin
    "--data_prefix", "-d"
        help = "Folder for data files"
        arg_type= String
        default="remote/latlong_weighted"
    "--name"
    	help = "Name of inversion run / folder to output results"
    	arg_type = String 
    	default = "default"
    "--model", "-m"
        help = "Type of model to use. Allowed: inversion (PCA), range (range of nearby samples)"
        arg_type = String
        range_tester = x -> (x in ["inversion","range", "vprange", "vprhorange"])
        default = "range"
    "--num_invert", "-n" 
    	help = "How many resampled Crust1.0 samples to invert?"
    	arg_type = Int
    	default = 50000
    "--age_model"
    	help = "How to apply ages to samples to invert. Allowed: tc1, earthchem"
        arg_type = String
        range_tester = x -> (x in ["tc1","earthchem"])
        default = "earthchem"
    "--data_source"
    	help = "Source for seismic data"
        arg_type = String
        range_tester = x -> (x in ["Shen","Crust1.0"])
        default = "Crust1.0"
    "--bin_size", "-b"  
    	help = "% of each sizemic parameter in bin for range model (in decimal form)"
    	arg_type = Float64
    	default = .05
    "--mean"  
    	help = "for range model, use the mean of all matching compsoitions? if not, choose random."
    	arg_type = Bool
    	default = false
    "--crack"
    	help = "Mean of upper crust crack porosity. -1 means no cracking."
    	arg_type = Float64  
    	default = -1.0
    "--allow_spheres"
    	help = "Allow shapes other than cracks (aspect ratio < .05) in upper crust"
    	arg_type = Bool  
    	default = false
end
parsed_args = parse_args(ARGS, s)
outputPath = "data/"*parsed_args["data_prefix"]*"/"*parsed_args["name"]*"/"
if ispath(outputPath)
	error("Output path $(outputPath) exists, delete or use a different --name option.")
end
mkpath(outputPath) # make output dir 
writeOptions(outputPath*"/inversion_options.csv", parsed_args)

function run(parsed_args, outputPath)
	if parsed_args["crack"] <= 0 
		crackFile = "" 
	else
		crackFile = outputPath*"crack_profile.csv"
		if !isfile(crackFile)
			println("Building new random cracking profiles...")
			ignFile = "data/"*parsed_args["data_prefix"]*"/bsr_ignmajors_1.csv"
			ign, header = readdlm(ignFile, ',', header=true)
			n = size(ign, 1)
			profiles = Array{Crack,1}([random_cracking(parsed_args["crack"], [0.0, 0.5, 0.0, 0.5], 
				parsed_args["allow_spheres"] ? [1/3, 1/3, 1/3] : [1.0, 0.0, 0.0]) for i in 1:n])
			write_profiles(profiles, crackFile)
		end 
	end 

	### TODO: combine all these models, this is absurd -- most code is shared.
	if parsed_args["model"] == "range"
		models = makeModels(parsed_args["data_prefix"], modelType=RangeModel, crackFile=crackFile) # see inversionModel.jl. returns a ModelCollection 
		setError(models, parsed_args["bin_size"])
		if parsed_args["mean"]
			setMean(models, parsed_args["mean"])
		end 
	elseif parsed_args["model"] == "vprange"
		models = makeModels(parsed_args["data_prefix"], modelType=VpModel, crackFile=crackFile)  
		setError(models, parsed_args["bin_size"])
	elseif parsed_args["model"] == "vprhorange"
		models = makeModels(parsed_args["data_prefix"], modelType=VpRhoModel, crackFile=crackFile)  
		setError(models, parsed_args["bin_size"])
		if parsed_args["mean"]
			setMean(models, parsed_args["mean"])
		end 
	elseif parsed_args["model"] == "inversion"
		models = makeModels(parsed_args["data_prefix"], modelType=InversionModel, crackFile=crackFile)
	end 

	# Get data to invert (resampled Crust1.0 data)
	# What age model to use? 
	if parsed_args["age_model"] == "tc1"
		age_model = Tc1Age()
	elseif parsed_args["age_model"] == "earthchem"
		age_model = EarthChemAge(10, 3)
	end

	upperDat, (upperCrustbase, upperAge, upperLat, upperLong) = getAllSeismic(
		6, n=parsed_args["num_invert"], ageModel=age_model, latlong=true, dataSrc=parsed_args["data_source"]) # returns rho, vp, vpvs, tc1, age
	middleDat, (middleCrustbase, middleAge, middleLat, middleLong) = getAllSeismic(
		7, n=parsed_args["num_invert"], ageModel=age_model, latlong=true, dataSrc=parsed_args["data_source"])
	lowerDat, (lowerCrustbase, lowerAge, lowerLat, lowerLong) = getAllSeismic(
		8, n=parsed_args["num_invert"], ageModel=age_model, latlong=true, dataSrc=parsed_args["data_source"])
	sampleDat = [upperDat, middleDat, lowerDat]
	sampleAges = [upperAge, middleAge, lowerAge]
	sampleBases = [upperCrustbase, middleCrustbase, lowerCrustbase]
	sampleLats = [upperLat, middleLat, lowerLat]
	sampleLongs = [upperLong, middleLong, lowerLong]

	# Result data per geotherm bin 
	results_upper, errors_upper = estimateComposition(models, UPPER, upperDat...)
	results_middle, errors_middle  = estimateComposition(models, MIDDLE, middleDat...)
	results_lower, errors_lower = estimateComposition(models, LOWER, lowerDat...)
	results = [results_upper, results_middle, results_lower]
	errors = [errors_upper, errors_middle, errors_lower]

	SI_index = findfirst(isequal("SiO2"), PERPLEX_ELEMENTS)
	println("Mean of upper results $(nanmean(results[1][:,SI_index]))")
	println("Mean of middle results $(nanmean(results[2][:,SI_index]))")
	println("Mean of lower results $(nanmean(results[3][:,SI_index]))")

	# Oversampling ratio 
	n_original = length(crustDistribution.all_lats) # number of 1x1 grid cells w data at 
	n_resampled = parsed_args["num_invert"]

	# Write to output files (one per layer)
	for (l, layer) in enumerate(LAYER_NAMES)
		#println("shapes $(size(sampleAges[l])), $(size(sampleBases[l])), $(size(results[l])), $(size(errors[l])),")
		output = hcat(sampleDat[l]..., 
			sampleAges[l], sampleBases[l], sampleLats[l], sampleLongs[l], results[l], errors[l])
		nelts = size(results[l],2) - 1 # last is geotherm bin info 
		header = hcat(["sample_rho" "sample_vp" "sample_vpvs" "sample_geotherm"], # inverted data 
			["sample_age" "sample_depth" "sample_lat" "sample_long"], # supplemental sample data 
			reshape(PERPLEX_ELEMENTS, (1,nelts)), # inverted data (results)
			["bin"], 
			reshape(PERPLEX_ELEMENTS, (1,nelts)).*" error") # errors on inverted data 

		if parsed_args["crack"] > 0
			(cracks, crack_header) = readdlm(crackFile, ',', header=true)
			out_cracks = Array{Any,2}(undef, (size(results[l],1), size(cracks,2)))
			for j in 1:size(out_cracks,1)
				idx = results[l][j,1]
				if isnan(idx)
					out_cracks[j,:] .= NaN
				else
					out_cracks[j,:] = cracks[Int(idx),:]
				end
			end
			output = hcat(output, out_cracks)
			header = hcat(header, reshape(crack_header, (1, length(crack_header))))
		end 

		output = vcat(header, output)
		filename = outputPath*"results-$layer.csv"
		writedlm(filename, output, ',')
	end 

end 

run(parsed_args, outputPath)


























