/******************************************************************************
 * FILE: runPerplexBatchVp.c
 * COMPILATION: mpicc -std=c99 -o runPerplexBatchVp runPerplexBatchVp.c
 * USAGE: mpiexec -np N ./runPerplexBatchVp ignmajors.csv
 *
 * DESCRIPTION:
 *   Configures and runs PerpleX  seismic velocity calculations on N
 *   processors for each bulk composition in ignmajors.csv, along a specified
 *   geothermal gradient.
 *
 * PREREQUISITES:
 *   PerpleX (http://www.perplex.ethz.ch/)
 *
 * NOTES:
 * 	This program uses the system() function and unix-like command-line
 *   arguments. Consequently, it will likely only run as-is on Linux/Unix/BSD/Mac.
 *
 *   To use as-is, make sure the perplex executables build, vertex, and werami
 *   are on your $PATH, and place the three required .dat files (hp02ver.dat,
 *   perplex_option.dat, and solution_model.dat are in the current directory.
 *   Else, you can specify explicit paths to these files in the "simulation
 *   parameters section of the code below.
 *
 *   In order to run different types of perplex calculations (i.e., to
 *   calculate something other than seismic velocites for the compositions
 *   in ignmajors.csv) you can edit the batch strings that are written to
 *   build.txt and werami.txt. For more infomation on how this works,
 *   see http://www.perplex.ethz.ch/perplex_66_seismic_velocity.html
 *   and http://www.perplex.ethz.ch/faq/scripting.txt
******************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <mpi.h>
#include <strings.h>
#include <string.h>
#include <math.h>
#include "arrays.h"

#define ROOT 0 // Set identiy of root node

int main(int argc, char **argv){
	uint32_t datarows, datacolumns, resultrows, resultcolumns;
	uint32_t i, j, k, r, c;
	int world_size, world_rank, rc;
	FILE *fp;


	//Check input arguments
	if (argc != 2) {
		fprintf(stderr,"USAGE: %s <input_filename>\n", argv[0]);
		exit(1);
	}

	// Start MPI
	rc = MPI_Init(&argc,&argv);
	if (rc != MPI_SUCCESS) {
		printf ("Error starting MPI program. Terminating.\n"); MPI_Abort(MPI_COMM_WORLD, rc);
	}

	// Get world size (number of MPI processes) and world rank (# of this process)
	MPI_Comm_size(MPI_COMM_WORLD,&world_size);
	MPI_Comm_rank(MPI_COMM_WORLD,&world_rank);


	if (world_rank==ROOT){
		// Declare variables used only on the root node
		int buf[world_size-1], nextReady;
		MPI_Request reqs[world_size-1];
		MPI_Status stats[world_size-1];
		double* results = malloc(100000 * sizeof(double));
		double stop[15] = {-1};

		// Open output file
//		fp=fopen("PerplexResults.csv","w");
		// Print format of output
		fprintf(stdout,"index\tP(bar)\tT(K)\trho\tVp\tVp/Vs\n");

		// Import 2-d source data array as a flat double array. Format:
		// #, SiO2, TiO2, Al2O3, FeO, MgO, CaO, Na2O, K2O, H2O, CO2, tc1Crust, upper Crust1.0, middle, lower
		double** const data = csvparse(argv[1],',', &datarows, &datacolumns);

		// Listen for task requests from the worker nodes
		for (i=1; i<world_size; i++){
			//        *buf, count, datatype, dest, tag, comm, *request
			MPI_Irecv(&buf[i-1], 1, MPI_INT, i, 0, MPI_COMM_WORLD, &reqs[i-1]);
		}

		// Once any worker asks for a new task, send next task to that worker and keep listening
		for (i=0; i<datarows; i++){
			//	    count, MPI_Request, *index, MPI_Status
			MPI_Waitany(world_size-1, reqs, &nextReady, stats); // Listen for task request
			if (buf[nextReady] > 0){
				// Get results from last calculation (if any)
				//       *buf, count, datatype, source, tag, comm, *status
				MPI_Recv(&resultrows, 2, MPI_INT, nextReady+1, 2, MPI_COMM_WORLD, &stats[nextReady]);
				MPI_Recv(&resultcolumns, 2, MPI_INT, nextReady+1, 3, MPI_COMM_WORLD, &stats[nextReady]);
				MPI_Recv(results, resultrows*resultcolumns, MPI_DOUBLE, nextReady+1, 4, MPI_COMM_WORLD, &stats[nextReady]);

				// Print results to file
				fprintfflatindex(stdout, results, buf[nextReady], '\t', resultrows, resultcolumns);
//				fflush(fp);
			}

			//       *buf, count, datatype, dest, tag, comm
//			printf("0: Send data: Rank: %i\n", nextReady+1);
			MPI_Send(data[i], 15, MPI_DOUBLE, nextReady+1, 1, MPI_COMM_WORLD); // Send next problem to work on
			//        *buf, count, datatype, source, tag, comm, *request
			MPI_Irecv(&buf[nextReady], 1, MPI_INT, nextReady+1, 0, MPI_COMM_WORLD, &reqs[nextReady]); // Keep waiting
		}

		// Once all tasks have been sent, wait for workers to complete and send the stop signal
		for (i=1; i<world_size; i++){
			// Listen for task request
			//	    count, MPI_Request, *index, MPI_Status
			MPI_Waitany(world_size-1, reqs, &nextReady, stats);
			// Get results from last calculation (if any)
			if (buf[nextReady] > 0){
				//       *buf, count, datatype, source, tag, comm, *status
				MPI_Recv(&resultrows, 2, MPI_INT, nextReady+1, 2, MPI_COMM_WORLD, &stats[nextReady]);
				MPI_Recv(&resultcolumns, 2, MPI_INT, nextReady+1, 3, MPI_COMM_WORLD, &stats[nextReady]);
				MPI_Recv(results, resultrows*resultcolumns, MPI_DOUBLE, nextReady+1, 4, MPI_COMM_WORLD, &stats[nextReady]);

				// Print results to file
				fprintfflatindex(stdout, results, buf[nextReady], '\t', resultrows, resultcolumns);
//				fflush(fp);
			}

			// Send stop signal
//			printf("0: Stop: Rank: %i\n", nextReady+1);
			MPI_Send(&stop, 15, MPI_DOUBLE, nextReady+1, 1, MPI_COMM_WORLD);
		}


//		fclose(fp);
	}

	else {
		// Declare variables used only on the worker nodes
		MPI_Request sReq;
		MPI_Status sStat;
		double ic[15], *results;
		char* prefix = malloc(500*sizeof(char));
		char* cmd_string = malloc(1000*sizeof(char));
		char* path_string = malloc(500*sizeof(char));
		// Initialize index with negative value tell root node we don't have results yet
		int index = -1.0;

		/************************************************************************
 		 * Simulation Parameters:
 		 *
 		 * Location of scratch directory (ideally local scratch for each node)
 		 * This location may vary on your system - contact your sysadmin if
 		 * unsure								*/
		const char scratchdir[]="/scratch/gailin/"; // /scratch/gailin is local, /dartfs-hpc/scratch/gailin is shared
//		const char scratchdir[]="./";	// Local directory

		/* Path to PerpleX executables and data files:				*/
		const char pathtobuild[]="build";
		const char pathtovertex[]="vertex";
		const char pathtowerami[]="werami";
		const char pathtodatafiles[]="/dartfs-hpc/rc/home/9/f0043n9/perple_x/*.dat";
		//const char pathtodatafiles[]="./*.dat"; // Local directory
//		const char pathtodatafiles[]="/scratch/gpfs/cbkeller/*.dat";
		/************************************************************************/


		double dpdz = 2900. * 9.8 / 1E5 * 1E3; // Pressure gradient (bar/km)


		while (1) {
			// Ask root node for task to work on
			//       *buf, count, datatype, dest, tag, comm, *request
//			printf("%i: Asking root for new task\n", world_rank);
			MPI_Isend(&index, 1, MPI_INT, ROOT, 0, MPI_COMM_WORLD, &sReq);

			// Send results of last task (if any) back to root node and free result array
			if (index>0){
//				printf("%i: Sending results back to root\n", world_rank);
				//       *buf, count, datatype, dest, tag, command
				MPI_Send(&resultrows, 1, MPI_INT, ROOT, 2, MPI_COMM_WORLD);
				MPI_Send(&resultcolumns, 1, MPI_INT, ROOT, 3, MPI_COMM_WORLD);
				MPI_Send(results, resultrows*resultcolumns, MPI_DOUBLE, ROOT, 4, MPI_COMM_WORLD);
//				printf("%i: Results sent to root\n", world_rank);
				free(results);
			}

			// Get next task from root node
			//       *buf, count, datatype, source, tag, comm, *status
			MPI_Recv(&ic, 15, MPI_DOUBLE, ROOT, 1, MPI_COMM_WORLD, &sStat);

			// If composition is unreadable, move on to next simulation
			if (isnan(ic[0])){
				fprintf(stderr, "%i: Sumulation input contains NaN, moving on.\n", world_rank);
				index = -1;
				continue;
			}

			// Get calculation index from ic (round by casting to int)
			index = (int) round(ic[0]);

//			printf("%i: index: %i\n",world_rank,index);

			// Exit loop if stop signal recieved
			if (index == -1) {
//				printf("%i: done!\n", world_rank);
				break;
			}

//			//Override water
//			ic[9]=2.0;
//			//Override CO2
//			ic[10]=0.1;

//			// Print current whole-rock composition
//			for (i=0; i<12; i++){
//				printf("%g\t", ic[i]);
//			}
//			printf("\n");


			//Configure working directory
			sprintf(prefix,"%sout%i_%i/", scratchdir, world_rank, index);
			sprintf(cmd_string,"rm -rf %s; mkdir -p %s", prefix, prefix);
			system(cmd_string);

			// Place required data files
			sprintf(cmd_string,"cp %s %s", pathtodatafiles, prefix);
			system(cmd_string);


			// Create build batch file
			sprintf(path_string, "%sbuild.txt", prefix);
			fp=fopen(path_string,"w");
			// Name, components, and basic options. Holland and Powell (2002) thermodynamic dataset and (1998) fluid equation state.
			fprintf(fp,"%i\nhpha02ver.dat\nperplex_option.dat\nn\n3\nn\nn\nn\nSIO2\nTIO2\nAL2O3\nFEO\nMGO\nCAO\nNA2O\nK2O\nH2O\nCO2\n\n5\n", index);
			// Pressure gradient details
			fprintf(fp,"n\ny\n2\n1\n273.15\n%g\n1\n20000\ny\n", 550.0/ic[11]/dpdz);
			// Whole-rock composition
			for(i=1; i<11; i++){
				fprintf(fp,"%g ",ic[i]);
			}
			//Solution model
			fprintf(fp,"\nn\nn\ny\nsolution_model.dat\nO(HP)\nOpx(HP)\nOmph(GHP)\nGt(HP)\noAmph(DP)\nGlTrTsPg\nT\nAnth\nChl(HP)\nBio(TCC)\nMica(CF)\nCtd(HP)\nIlHm(A)\nSp(HP)\nSapp(HP)\nSt(HP)\nfeldspar\nDo(HP)\n\nClosed System");
			fclose(fp);

			// build PerpleX problem definition
			sprintf(cmd_string,"cd %s; %s < build.txt >> buildoutput.txt", prefix, pathtobuild);
			system(cmd_string);

			// Run PerpleX vertex calculations
			sprintf(cmd_string,"cd %s; echo %i | %s >> vertextoutput.txt", prefix, index, pathtovertex);
			system(cmd_string);


			// Create werami batch file
			sprintf(path_string, "%swerami.txt", prefix);
			fp=fopen(path_string,"w");
			//			fprintf(fp,"%i\n3\n1\n1\n20000\n40\n2\nn\nn\n13\nn\nn\n15\nn\nn\n0\n0\n", index);
			fprintf(fp,"%i\n3\n2\nn\nn\n13\nn\nn\n15\nn\nn\n0\n0\n", index);
			fclose(fp);

			// Extract Perplex results with werami
			sprintf(cmd_string,"cd %s; %s < werami.txt >> weramioutput.txt", prefix, pathtowerami);
			system(cmd_string);


			// If results can't be found, clean up scratch directory and move on to next simulation
			sprintf(cmd_string,"%s%i_1.tab", prefix, index);
			if ((fp = fopen(cmd_string, "r")) == NULL) {
				fprintf(stderr, "%i: %s : Simulation output could not be found.\n", world_rank, prefix);
				sprintf(cmd_string,"rm -r %s", prefix);
				system(cmd_string);
				index = -1;
				continue;
			}

			// Use sed to convert the .tab output file into a plain csv
			sprintf(cmd_string, "cd %s; sed -e '1,/T(K)/d' -e 's/      /,/g' -e 's/,,*/,/g' %i_1.tab > %i.csv", prefix, index, index);
			system(cmd_string);

			// Import results, if they exist. Format:
			// P(bar) T(K) rho Vp(km/s) Vp/Vs
			sprintf(path_string, "%s%i.csv", prefix, index);
			results = csvparseflat(path_string,',', &resultrows, &resultcolumns);

			// Can delete temp files after we've read them
			sprintf(cmd_string,"rm -r %s", prefix);
			system(cmd_string);

		}
	}
	MPI_Finalize();
	return 0;
}
