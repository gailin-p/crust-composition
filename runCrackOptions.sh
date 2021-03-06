# Usage: runCrackOptions.sh <model/dataset>
set -e # Fail if any command fails 

#for c in .05 .01 .005 .001 .0005 .0001
for p in .15 .1 .05 .01 .005 
do
julia scripts/inversion_binned_geotherm.jl -d $1 --name percent_crack_$p --crack .05 -n 5000 --cracked_samples 1 --fraction_crack $p
julia visualization/age_comp.jl	-p data/$1/percent_crack_$p/
julia visualization/visualize_range_model.jl -d $1/ --name percent_crack_$p

done 
