for i in {0..500}
do
#  echo $i >> test_output.txt  
    rm -rf data/remote/base/perplex_test_many
    julia scripts/inversion_binned_geotherm.jl -d remote/base --name perplex_test_many --data_source TestRG --cracked_samples 0 -n 100
    julia visualization/all_comps.jl -p data/remote/base/perplex_test_many >> data/output_many_tests_n100.csv
done

    
