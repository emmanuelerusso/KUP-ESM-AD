#################################################
#  WRF Tables, Registry files, plotting scripts #
#################################################

E. Russo and M. Messmer, 24th Nov 2020

# GEOGRID.TBL
# METGRID.TBL
# REGISTRY.EM_COMM
# Vtable
# scripts/

#### GEOGRID.TBL ####

Adjusting the smoothing of the topography in case of using a domain over complex terrain.
The uploaded version corresponds to the WPS version 3.8.1

search for "HGT_M"
smooth_option = smth-desmth_special; smooth_passes=1 (is the default)
smooth_option = 1-2-1; smooth_passes=1 (uploaded here)

the smooth_passes indicates how often the smoothing is applied. In case of instability in the model 
(e.g., vertical velocity, hurting of CFL criterion, etc.) this number can be increased, so that
several rounds of smooting are applied.

#### METGRID.TBL ####

Adjusting the interpolation of the SSTs. Due to differences in the land-sea mask some of the grid
points optain unrealistic values (boiling sea, i.e, 70-80 degrees celsius) or wrong coast lines.
To avoid this, the SST part of the MetGRID.TBL must be adapted. Please note that there are two 
different methods, depending if you are using ECMWF reanalysis or global model (CESM) as input.

!! Make sure to check your SSTs in the met_em.d0* files, to be sure that this is correct before 
   running real and wrf. Check other than the first time step !!
   

# Default:

name=SST
  interp_option=sixteen_pt+four_pt
  fill_missing=0.
  missing_value=-1.E30
  flag_in_output=FLAG_SST
  
# Adjusted here for usage with ERA-Interim or ERA-5 (METGRID.TBL_ecmwf)
  The possible interpolations are extended and the inclusion of an interp_mask
  allow a smoother coastline.

name=SST
  interp_option=sixteen_pt+four_pt+wt_average_4pt+wt_average_16pt+search
  fill_missing=0.
  missing_value=-1.E30
  flag_in_output=FLAG_SST
  masked=land
  interp_mask=LANDSEA(1)
  
# Adjusted here for usage with CESM (METGRID.TBL_cesm)
When running WRF with CESM as initial and boundary conditions make sure to
change the land grid points from NANs to 0. Check the detailed documentation
on this in docs/SST_int_metgrid_WRF.pdf.

name=SST
  interp_option=sixteen_pt+wt_average_16pt+search masked=land
  interp_mask=LANDMASK(1)
  fill_missing=-1.E30
  flag_in_output=FLAG_SST missing_value=-1.E30
  
  
#### REGISTRY FILE ####
The Registry file controls the variables that are written to the outfile. As
I/O processes are slowing down the simulation it is wise to adjust this file
to remove some constant variables and variables that are not used for the
analysis.
!! Make sure to recompile the whole model again after applying changes to the
   Registry files with a ./clean -a command first. !!
   
# REGISTRY.EM_COMM_slim


#### DIAGNOSTIC SCRIPTS ####
!! To be done ... !!
The idea is to produce plots after each model run of some specific variables to
check that the model is working properly.


#### PLOTTING SCRIPTS ####
some useful scripts are uploaded in the "scripts/" folder to faciliate plotting
of, e.g., the domains and the topography.

# plot_domains.ncl
It can be used to plot the nested domains including WRF topography. You have to
uncomment or comment some of the nests depending on your domain configuration.
