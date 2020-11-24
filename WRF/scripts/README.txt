###########################################################
# 
#
###########################################################

E. Russo and M. Messmer, 24th Nov 2020

#### Preprocessing and WPS ####

## for leap years, i.e., reanalysis data (ERA-5)


## for no-leap years, i.e. climate model simulations (CESM)

# setenv_create_wps_input.sh
Can be run to initiate all the environmental variables and to run 
run_cesm_preprocessing.sh

# run_cesm_preprocessing.sh 
This script prepares the CESM output to be digested by the WPS program
of WRF. Only needed in combination with a climate model output.

# WPS, WRF and postporcessing are still missing
