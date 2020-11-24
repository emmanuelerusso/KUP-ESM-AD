#!/bin/sh

#-- Libraries Upload
module unload cray-netcdf-hdf5parallel
module load CDO
module load NCL
module load NCO

set -ex

export CESM_PATH="/project/s906/jbuzan/archive/F.LGM.pr.m.01_0_CN.x1.122"  #set path to the folder of CESM input
export FILE_CAM="F.LGM.pr.m.01_0_CN.x1.122.cam.h1."                        #set first part of filename for CAM
export FILE_CLM="F.LGM.pr.m.01_0_CN.x1.122.clm2.h1."                       #set first part of filename for CLM
export scratchdir=$SCRATCH"/CESM-input"
# To do:
#pull pressure interpolation ncl scripts from github to $scratchdir
#adjust ncl files

# adjust the arguments according to your needs
#$1 = start_year
#$2 = end_year
#$3 = off_set needed to transform unrealistic years into regular years, e.g., 1990
#$4 = exp_name used to create the folder for the corresponding experiment

./run_cesm_preprocessing.sh 0001 0010 1990 LGM_1x1
