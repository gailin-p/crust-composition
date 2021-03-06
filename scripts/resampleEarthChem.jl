"""
Resample earthchem data set (original in igncn1.mat) to a perplex-ready ignmajors.csv
After resampling, apply a random geotherm/crust layer combination to each sample
TODO: also resample geotherm/crust values, but separately
      (they should not be connected to a specific composition)

Advantages of this over using perplex directly on EarthChem samples:
- most EarthChem samples are missing H2O data
- some EarthChem samples behave badly at high pressure (0 vp) because Perplex
  predicts liquid, but discarding these samples
  at depth might bias the compositions we allow in the inversion for deeper layers.
  If all samples are resampled, we can discard at depth those that behave unphysically

Use:
Run from base folder (runPerplexBatchVp)
Places resampled file at data/<data_prefix>/ignmajors.csv

"""

using ArgParse
using StatGeochem
using MAT
using DelimitedFiles
using Logging
using Statistics
using Random
using ProgressMeter: @showprogress
include("../src/config.jl") # constants defined here
include("../src/utilities.jl")
include("../src/crustDistribution.jl")

s = ArgParseSettings()
@add_arg_table! s begin
    "--data_prefix", "-o"
        help = "Folder for output data files"
        arg_type= String
        required = true
    "--data", "-d"
        help = "Path to EarthChem mat file"
        arg_type = String
        default = "resources/igncn1.mat"
    "--dabie"
        help = "If provided, use Dabie data file as source composition when resampling"
        arg_type = String
        default = ""
    "--huang"
        help = "If provided, use Huang data file as source composition when resampling"
        arg_type = String
        default = ""
    "--num_samples", "-n"
        help = "How many samples to produce"
        arg_type = Int
        default = 100000
    "--weight", "-w"
        help = "Weight during resampling? Allowed: silica, latlongage"
        arg_type = String
        range_tester = x -> (x in ["","silica","latlongage", "RG"])
        default = ""
    "--bin_geotherms", "-b"
        help = "Bin geotherms? (1 for no binning.) Provides b output files, one for each bin"
        arg_type = Int
        default = 1
    "--exhume"
        help = "Km of exhumation. Reasonable values 0 - 10 km"
        arg_type = Float64
        default = 5.0
    "--formation_temp"
        help = "Formation temperature (degrees C). At hottest geotherm, middle of lower crust is ~550 C. Reasonable values range up to 600 C"
        arg_type = Float64
        default = 550.0
end
parsed_args = parse_args(ARGS, s)
dir = parsed_args["data_prefix"]
mkpath("data/"*dir) # make if does not exist
writeOptions("data/"*dir*"/resampleEarthChem_options.csv", parsed_args)

# Read in mat file
ign = matread(parsed_args["data"])


if (parsed_args["dabie"] == "") & (parsed_args["huang"] == "")
    # Calculate H2O_Total if not present or all NaN
    if (! ( "H2O_Total" in keys(ign))) || (sum(isnan.(ign["H2O_Total"])) == length(ign["H2O_Total"]))
        println("Calculating H2O_Total from H2O, H2O_Plus, H2O_Minus, and Loi")
        ign["H2O_Total"] = fill(NaN, (length(ign["H2O"]),1))
        println(size(ign["H2O"]))
        println(size(ign["H2O_Total"]))

        # If H2O exists, use that
        h2Ogood = .~(isnan.(ign["H2O"]))
        println("Using $(sum(h2Ogood)) H2O values")
        ign["H2O_Total"][h2Ogood] .= ign["H2O"][h2Ogood]

        # Otherwise, if H2O_Plus and H2O_Minus, use sum of those
        plusminus = (.~h2Ogood) .& (.~(isnan.(ign["H2O_Plus"]))) .& (.~(isnan.(ign["H2O_Minus"])))
        println("Using $(sum(plusminus)) H2O_Plus and H2O_Minus values")
        ign["H2O_Total"][plusminus] .= ign["H2O_Minus"][plusminus] .+ ign["H2O_Plus"][plusminus]

        # Otherwise, partition Loi into CO2 and H2O based on ratio in rest of data set
        ratio = nanmean(ign["H2O"][h2Ogood] ./ (ign["CO2"][h2Ogood] + ign["H2O"][h2Ogood])) # h2O out of total volatiles
        loi = (.~plusminus) .& (.~h2Ogood) .& (.~(isnan.(ign["Loi"])))
        println("Using $(sum(loi)) Loi values, partitioning $(ratio) of volatiles into H2O")
        ign["H2O_Total"][loi] = ign["Loi"][loi] .* ratio
        ign["CO2"][loi] .= ign["Loi"][loi] .* (1-ratio)

        println("$(sum(.~(isnan.(ign["H2O_Total"])))) not-nan H2O_Total values from $(sum(h2Ogood) + sum(plusminus) + sum(loi)) other data vals")
    end

    # List of elements we want to resample export (primarily element oxides)
    # Lat, long and age are unused, but export for visualization or reference.

    # Set uncertainties
    for e in RESAMPLED_ELEMENTS
        ign["err"][e] = ign[e] .* (ign["err2srel"][e] / 2) # default
        ign["err"][e][isnan.(ign[e])] .= nanstd(ign[e]) # missing data gets std, which is a much larger uncertainty
    end

    # Special cases: Latitude & Longitude
    ign["err"]["Latitude"] = ign["Loc_Prec"]
    ign["err"]["Longitude"] = ign["Loc_Prec"]

    # Special cases: Age
    ign["err"]["Age"] = (ign["Age_Max"]-ign["Age_Min"])/2;
    # Find points with < 50 Ma absolute uncertainty
    t = (ign["err"]["Age"] .< 50) .| isnan.(ign["err"]["Age"])
    # Set 50 Ma minimum age uncertainty (1-sigma)
    ign["err"]["Age"][t] .= 50

    # Clean up data before resampling
    # Start with all Fe as FeO TODO before or after resample? TODO what error to use for binned FeO?
    ign["FeO"] = feoconversion.(ign["FeO"], ign["Fe2O3"], ign["FeOT"], ign["Fe2O3T"])

    # Reject samples with suspicious anhydrous normalizations
    anhydrousnorm = fill(false, length(ign[RESAMPLED_ELEMENTS[1]]))
    for i in 1:length(ign[RESAMPLED_ELEMENTS[1]]) # for every sample
        elts = [ign[elt][i] for elt in COMPOSITION_ELEMENTS[1:8]] # sum of percents for every sample
        total = sum(elts)
        anhydrousnorm[i] = (total < 101) & (total > 90) # is this sample reasonable? (all NaNs will return false)
    end
    println("Throwing away $(length(ign[RESAMPLED_ELEMENTS[1]]) - sum(anhydrousnorm)) samples because of suspicious anhydrous normalizations or all NaN values")

    for elt in RESAMPLED_ELEMENTS
        ign[elt] = ign[elt][anhydrousnorm]
        ign["err"][elt] = ign["err"][elt][anhydrousnorm]
    end
elseif parsed_args["huang"] != "" # Huang
    dat, h = readdlm(parsed_args["huang"], ',', header=true)
    n = size(dat, 1)
    dat[dat .== -1] .= NaN
    # Standard format
    ign_new = Dict{String,Any}()
    for re in RESAMPLED_ELEMENTS # standard list of elts
        ign_new[re] = fill(NaN, n)
    end
    for (i, ce) in enumerate(h) # elts we have
        ign_new[ce] = dat[:,i]
    end

    ign_new["elements"] = RESAMPLED_ELEMENTS

    # Set uncertainties
    ign_new["err"] = Dict()
    for e in RESAMPLED_ELEMENTS
        ign_new["err"][e] = ign_new[e] .* (ign["err2srel"][e] / 2) # default
        ign_new["err"][e][isnan.(ign_new[e])] .= nanstd(ign_new[e]) # missing data gets std, which is a much larger uncertainty
    end

    # make this the usual ign
    ign = ign_new
else # Dabie
    comp_compat, _ = convert_dabie(parsed_args["dabie"])
    n = size(comp_compat)[1]
    ign_new = Dict{String,Any}()
    for re in RESAMPLED_ELEMENTS
        ign_new[re] = fill(NaN, n)
    end
    for (i, ce) in enumerate(COMPOSITION_ELEMENTS)
        ign_new[ce] = comp_compat[:,i]
    end

    ign_new["elements"] = RESAMPLED_ELEMENTS

    # Set uncertainties
    ign_new["err"] = Dict()
    for e in RESAMPLED_ELEMENTS
        ign_new["err"][e] = ign_new[e] .* (ign["err2srel"][e] / 2) # default
        ign_new["err"][e][isnan.(ign_new[e])] .= nanstd(ign_new[e]) # missing data gets std, which is a much larger uncertainty
    end

    # make this the usual ign
    ign = ign_new

    data = unelementify(ign, ign["elements"], floatout=true)
end

# Set undefined elements for bulk elts to average, so they don't go NaN in resample.
for e in COMPOSITION_ELEMENTS
    ign[e][isnan.(ign[e])] .= nanmean(ign[e])
end

# Resample
if (parsed_args["weight"] == "silica") # weight according to silica content
    #throw(AssertionError("Hey, we decided weighting by silica is bad because we want representative
    #    proportions of compositions!"))

    k = invweight(ign["SiO2"],2) # 2 is resampling scale #, (nanmaximum(ign["SiO2"])-nanminimum(ign["SiO2"]))/100)
#println("Am i nan? $(sum(k))")

    # Probability of keeping a given data point when sampling:
    # We want to select roughly one-fith of the full dataset in each re-sample,
    # which means an average resampling probability <p> of about 0.2
    p = 1.0 ./ ((k .* median(5.0 ./ k)) .+ 1.0)
#println("Am i nan? $(sum(p))")
    resampled = bsresample(ign, parsed_args["num_samples"], RESAMPLED_ELEMENTS, p)
elseif (parsed_args["weight"] == "latlongage")
    println("Weighting by lat, long, age.")

    k = invweight(ign["Latitude"], ign["Longitude"], ign["Age"])
    p = 1.0 ./ ((k .* median(5.0 ./ k)) .+ 1.0)

    resampled = bsresample(ign, parsed_args["num_samples"], RESAMPLED_ELEMENTS, p)
#elseif (parsed_args["weight"] == "RG")

else
    resampled = bsresample(ign, parsed_args["num_samples"], RESAMPLED_ELEMENTS)
end

println("Num resampled $(length(keys(resampled)))")

# Write ignmajors

# Create 2d array of out element data to export
outtable = Array{Float64,2}(undef, (length(resampled["SiO2"]), length(PERPLEX_ELEMENTS)))
println("Size outtable $(size(outtable))")
for i = 1:length(RESAMPLED_ELEMENTS)
    outtable[:,i+1] = resampled[RESAMPLED_ELEMENTS[i]]
end

# Fix any resampled below 0 (only for elements, not for lat/long/age)
outtable[:,2:length(COMPOSITION_ELEMENTS)+1] = map(x->max(0.0, x), outtable[:,2:length(COMPOSITION_ELEMENTS)+1])

# Renormalize because we'll use these as % comp later
normalizeComp!(view(outtable, :, 2:length(COMPOSITION_ELEMENTS)+1))

outtable[:,1] = Array(1:size(outtable,1)) # Set indices

# Apply geotherms.
bins = parsed_args["bin_geotherms"]
bin_boundaries = crustDistribution.binBoundaries(bins)

for (i, bin_bottom) in enumerate(bin_boundaries[1:end-1])
    bin_top = bin_boundaries[i+1]

    crustparam = crustDistribution.getCrustParams(bin_bottom, bin_top)
    for i in 1:size(outtable, 1)
        outtable[i,length(RESAMPLED_ELEMENTS)+2:end-2] .= crustparam
    end

    outtable[:,findfirst(isequal("exhumed"), PERPLEX_ELEMENTS)] .= parsed_args["exhume"]
    outtable[:,findfirst(isequal("formation_temp"), PERPLEX_ELEMENTS)] .= parsed_args["formation_temp"]



    # Write this outtable before doing the next
    dir = parsed_args["data_prefix"]
    mkpath("data/"*dir) # make if does not exist

    path = "data/"*dir*"/bsr_ignmajors_$(i).csv"
    header = reshape(PERPLEX_ELEMENTS, (1, length(PERPLEX_ELEMENTS)))
    writedlm(path, vcat(header, round.(outtable, digits=5)), ",")
end
