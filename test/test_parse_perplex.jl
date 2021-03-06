using Test 

include("../src/parsePerplex.jl")

# Test point. real perplex output. 
point = "
----------------------------------------

Stable phases at:
                             P(bar)   =  5216.49    
                             T(K)     =  532.003    

Phase Compositions (molar  proportions):
                   wt %      vol %     mol %     mol        H2O      CO2      AL2O3    FEO      MGO      CAO      NA2O     K2O      SIO2     TIO2 
 Bio(TCC)          22.49     21.65     11.29    0.480E-01  1.00000  0.00000  0.53211  1.44490  1.52299  0.00000  0.00000  0.50000  2.96789  0.00000
 Mica(CF)           4.71      4.78      2.82    0.120E-01  1.00000  0.00000  1.25351  0.07898  0.16752  0.00000  0.37675  0.12325  3.24649  0.00000
 Do(HP)             0.24      0.22      0.27    0.114E-02  0.00000  2.00000  0.00000  0.77087  0.22913  1.00000  0.00000  0.00000  0.00000  0.00000
 IlHm(A)            1.73      1.07      2.65    0.113E-01  0.00000  0.00000  0.00000  0.99479  0.00521  0.00000  0.00000  0.00000  0.00000  1.00000
 Gt(HP)             3.37      2.52      1.65    0.702E-02  0.00000  0.00000  1.00000  1.55494  0.01823  1.42683  0.00000  0.00000  3.00000  0.00000
 cz                20.01     17.70     10.23    0.435E-01  0.50000  0.00000  1.50000  0.00000  0.00000  2.00000  0.00000  0.00000  3.00000  0.00000
 ab                30.14     33.87     26.71    0.114      0.00000  0.00000  0.50000  0.00000  0.00000  0.00000  0.50000  0.00000  3.00000  0.00000
 q                 11.05     12.36     42.73    0.182      0.00000  0.00000  0.00000  0.00000  0.00000  0.00000  0.00000  0.00000  1.00000  0.00000
 acti               6.26      5.83      1.66    0.707E-02  1.00000  0.00000  0.00000  2.00000  3.00000  2.00000  0.00000  0.00000  8.00000  0.00000

Phase speciation (molar proportions):

 Bio(TCC)          east: 0.03211, ann: 0.27644, phl: 0.07588, obi: 0.61557
 Mica(CF)          cel: 0.16752, fcel: 0.07898, mu: 0.00000, pa: 0.75351
 Do(HP)            dol: 0.22913, ank: 0.77087
 IlHm(A)           ilm: 0.99479, geik: 0.00521
 Gt(HP)            alm: 0.51831, py: 0.00608, gr: 0.47561

Molar Properties and Density:
                    N(g)          G(J)     S(J/K)     V(J/bar)      Cp(J/K)       Alpha(1/K)  Beta(1/bar)    Cp/Cv    Density(kg/m3)
 Bio(TCC)          462.88       -5388794   624.41       15.129       472.05      0.31003E-04  0.19385E-05   1.0085       3059.6    
 Mica(CF)          388.27       -5542088   514.39       13.396       433.41      0.39502E-04  0.17160E-05   1.0152       2898.4    
 Do(HP)            208.71       -1920905   291.96       6.5795       209.75      0.35169E-04  0.11258E-05   1.0187       3172.2    
 IlHm(A)           151.55       -1173314   172.42       3.1829       118.56      0.28055E-04  0.58105E-06   1.0197       4761.3    
 Gt(HP)            474.67       -5628955   543.14       12.015       438.34      0.21959E-04  0.60715E-06   1.0117       3950.7    
 cz                454.35       -6531082   528.80       13.639       438.20      0.25180E-04  0.90779E-06   1.0117       3331.4    
 ab                262.22       -3725950   349.72       10.001       274.78      0.29440E-04  0.17188E-05   1.0099       2621.9    
 q                  60.08        -857962   72.150       2.2816       61.018      0.24446E-04  0.16691E-05   1.0072       2633.4    
 acti              875.44      -10957163   1058.6       27.650       866.32      0.28987E-04  0.13237E-05   1.0109       3166.2    
 System             98.82       -1320890   125.56       3.3542       100.00      0.28672E-04  0.15521E-05   1.0095       2946.1    

Seismic Properties:
                 Gruneisen_T      Ks(bar)      Mu(bar)    V0(km/s)     Vp(km/s)     Vs(km/s)   Poisson ratio
 Bio(TCC)          0.51695      0.50850E+06  0.25810E+06   4.0768       5.2790       2.9044      0.28294    
 Mica(CF)          0.72231      0.60815E+06  0.36301E+06   4.5807       6.1386       3.5390      0.25107    
 Do(HP)            0.99820      0.90483E+06  0.42796E+06   5.3408       6.8200       3.6730      0.29572    
 IlHm(A)            1.3218      0.17550E+07  0.73579E+06   6.0712       7.5805       3.9311      0.31607    
 Gt(HP)             1.0030      0.16497E+07  0.99911E+06   6.4620       8.6877       5.0288      0.24805    
 cz                0.87340      0.11975E+07  0.69897E+06   5.9954       7.9950       4.5805      0.25568    
 ab                0.62958      0.60522E+06  0.35639E+06   4.8045       6.4192       3.6868      0.25388    
 q                 0.55160      0.38093E+06  0.45301E+06   3.8034       6.1157       4.1476      0.74186E-01
 acti              0.70655      0.76369E+06  0.60080E+06   4.9113       7.0300       4.3561      0.18837    
 System            0.66525      0.66053E+06  0.41443E+06   4.7350       6.4169       3.7506      0.24055    

Isochemical Seismic Derivatives:
                Ks_T(bar/K)  Ks_P  Mu_T(bar/K)  Mu_P  Vphi_T(km/s/K) Vphi_P(km/s/bar) Vp_T(km/s/K)  Vp_P(km/s/bar)  Vs_T(km/s/K)  Vs_P(km/s/bar)
 Mica(CF)           -73.86   4.3495    -51.79   0.9810  -0.21105E-03    0.13856E-04   -0.31706E-03    0.12118E-04   -0.20790E-03    0.22582E-05
 Do(HP)            -139.68   3.7428   -143.88   0.8829  -0.30481E-03    0.80571E-05   -0.63687E-03    0.76587E-05   -0.55873E-03    0.18345E-05
 IlHm(A)           -303.10   8.1858   -170.00   1.7000  -0.45118E-03    0.12693E-04   -0.60697E-03    0.11825E-04   -0.35211E-03    0.28312E-05
 oAmph(DP)         -115.13   5.3676    -81.62   1.3174  -0.30963E-03    0.14436E-04   -0.46174E-03    0.13294E-04   -0.30065E-03    0.32128E-05
 GlTrTsPg           -98.44   3.9725    -72.28   0.9769  -0.22876E-03    0.91175E-05   -0.35279E-03    0.79622E-05   -0.23741E-03    0.14596E-05
 ky                -198.50   5.5539   -131.47   0.8975  -0.33618E-03    0.96010E-05   -0.49485E-03    0.81521E-05   -0.31958E-03    0.10871E-05
 ab                 -62.71   3.9665   -112.09   4.2410  -0.17988E-03    0.11350E-04   -0.53872E-03    0.22753E-04   -0.52839E-03    0.18636E-04
 mic                -45.69   3.9668    -25.18   0.7879  -0.14008E-03    0.12001E-04   -0.19432E-03    0.10751E-04   -0.11789E-03    0.18736E-05
 q                 -140.80   8.1692    -17.55   1.6453  -0.61889E-03    0.36085E-04   -0.37719E-03    0.24754E-04    0.84956E-05    0.25583E-05
 ru                -140.14   4.2357    -21.00   0.7800  -0.13356E-03    0.52190E-05   -0.90052E-04    0.44919E-05    0.18333E-04    0.61580E-06
 System             -94.58   5.1148    -52.57   1.4830  -0.27752E-03    0.15100E-04   -0.34699E-03    0.13956E-04   -0.18283E-03    0.36883E-05

Bulk Composition:

              mol        g        wt %     mol/kg
    H2O       0.089     1.600     1.619     0.899
    CO2       0.002     0.100     0.101     0.023
    AL2O3     0.170    17.300    17.507     1.717
    FEO       0.107     7.719     7.812     1.087
    MGO       0.097     3.900     3.947     0.979
    CAO       0.112     6.300     6.375     1.137
    NA2O      0.061     3.800     3.845     0.620
    K2O       0.025     2.400     2.429     0.258
    SIO2      0.912    54.800    55.455     9.230
    TIO2      0.011     0.900     0.911     0.114

Other Bulk Properties:

 Enthalpy (J/kg) = -.126907E+08
 Specific Enthalpy (J/m3) = -.373887E+11
 Entropy (J/K/kg) =  1270.61    
 Specific Entropy (J/K/m3) = 0.374340E+07
 Heat Capacity (J/K/kg) =  1011.98    
 Specific Heat Capacity (J/K/m3) = 0.298142E+07


Chemical Potentials (J/mol):

      H2O           CO2           AL2O3         FEO           MGO           CAO           NA2O          K2O           SIO2          TIO2 
    -268527.      -426519.     -0.159585E+07  -275525.      -614911.      -714577.      -708275.      -780299.      -857963.      -896022.    

Variance (c-p+2) =  3


----------------------------------------

"

@testset "parse perplex" begin 
#dat = parsePerplexData("/users/gailin/resources/perplex_stable/hpha11ver.dat")

@testset "single item" begin
	item = "teph     EoS = 8 | H= -1733960.                             
SIO2(1)MNO(2)
G0 = -1780442 S0 = 155.9 V0 = 4.899  
c1 = 219.6 c2 = .36442E+1 c3 = -1292700 c5 = -1308.3  
b1 = .286E-4 b5 = 370.4448 b6 = 1256000 b7 = -.37d-5 b8 = 4.68  
m0 = 510000 m1 = .62 m2 = -108  "
	parsed = parsePerplexItem(item)
	@test length(keys(parsed)) == 18
	## Test end of line, middle of line, beginning of line, negative sign, decimal 
	@test parsed["EoS"] == 8 
	@test parsed["G0"] == -1780442
	@test parsed["c5"] == -1308.3
	@test parsed["name"] == "teph"
	@test parsed["c2"] == 3.6442
end

@testset "parse perplex point" begin 
	parsed = parse_perplex_point(point)
	# Endmembers should add to 100% 
	@test abs(sum(values(parsed)) - 100) < .001
	ks = ["cz", "ab", "q", "acti", "east", "ann", "phl", "obi", "cel", "fcel", "mu", "pa", "dol", 
		"ank", "ilm", "geik", "alm", "py", "gr"]
	@testset "keys" for k in ks
		@test k in keys(parsed)
	end
	@test parsed["q"] == 12.36
	@test parsed["gr"] == 2.52*.47561
end 

@testset "parse perplex system properties" begin 
	parsed = get_system_props(point)
	targets = ["Alpha(1/K)", "Beta(1/bar)", "Density(kg/m3)", "P(bar)", "T(K)", 
		"Ks(bar)", "Mu(bar)", "Vp(km/s)", "Vs(km/s)"]
	@testset "keys" for t in targets
		@test t in keys(parsed)
	end 
	@test parsed["T(K)"] == 532.003 
	@test parsed["Density(kg/m3)"] == 2946.1
	@test parsed["Alpha(1/K)"] == 0.28672E-04
	@test parsed["Vp(km/s)"] == 6.4169
end 






end 