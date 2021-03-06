#!/bin/bash
set -e # Fail if any command fails 

# Run dabie test 
# 

# Resample composition files 
julia scripts/resampleEarthChem.jl -o dabie_local -b 10 -n 1000 --dabie "data/kern_dabie_comp.csv"

# Perplex for each geotherm bin 
for b in {1..10}
do
mpiexec -np 3 --oversubscribe julia scripts/runPerplex.jl -d dabie_local -b $b --scratch "/Users/gailin/dartmouth/crustal_structure/perplexed_pasta/scratch" --perplex "/Users/gailin/resources/perplex-stable/" --perplex_dataset hpha11ver.dat 
done

# Invert 
julia scripts/inversion_binned_geotherm.jl -d dabie_local -n 3000 --name dabierg --data_source DabieRG --data_source_uncertainty 0
julia visualization/age_comp.jl -p data/dabie_local/dabierg
julia visualization/visualize_range_model.jl -d dabie_local --name dabie_rg 
