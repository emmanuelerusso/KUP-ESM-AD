#!/bin/sh

# Created by J.J. Gomez-Navarro
# Adapted by M. Messmer

# Comments were almost entirely added by Emmanuele Russo, University of Bern.
# The initial script was corrected and modified by Emmanuele Russo (ERUSSO), University of Bern
# Bern, 01.05.2019


# The Script is used for interpolating CESM inputs stored at OCCR (Oeschger Center for Climate Change Research) 
# to the format and resolution required for WRF pre-processing.
# For soil variables, the script for each WRF soil layer takes the corresponding depth of each CESM layer falling in the considered layer
# Then it weights the values of soil water of each cesm layer according to the depth they cover in each WRF layer
# For example, if the first WRF layer is 1m deep, and the first two CESM layers go respectively from 0 to 0.9 m and from 0.9 to 1.5 m, we get:
# SOIL_WATER_WRF_LEVEL_1= (0.9XSOIL_WATER_CESM_LEVEL_1 + 0.1XSOIL_WATER_CESM_LEVEL_2)/ 1m   
# Values are pre-processed from monthly CESM files. In our case (ERUSSO- paleo simulation of glacial interglacial periods over the alps) time resolution of the CESM data is 6-hour for the atmospheric variables and 1-month for the soil variables. WRF requires 6-hour inputs. 


set -ex
#-- Variables Definition 
 
if [[ $# -ne 4 ]]; then
  echo "./run_cesm_preprocessing.sh start_year end_year off_set experiment_name, e.g., ./run_cesm_preprocessing.sh 0001 0010 1990 LGM"
  exit
fi

start_year=$1
end_year=$2
off_set=$3
exp_name=$4

year=$start_year

while [[ $year -le $end_year ]]; do

  new_year=$((year + off_set))
  scratchdir=$scratchdir

  mkdir -p $scratchdir/${exp_name}
  mkdir -p $scratchdir/${exp_name}/grib-$new_year

  outdir=$scratchdir/${exp_name}/grib-$new_year

  cd $scratchdir/${exp_name}/grib-$new_year


# take environmental variable set in the script setenv_create_wps_input.sh 

  inputdir=$CESM_PATH

# Link cesm files to scratch: these are 6-hourly data. We do not have these data for paleosimulations (ERUSSO).

  cam_name=$FILE_CAM
  clm_name=$FILE_CLM

  ln -sf $inputdir'/lnd/hist/${clm_name}'$year'-01-01-00000.nc' soil.nc
  ln -sf $inputdir'/atm/hist/${cam_name}'$year'-01-01-00000.nc' input.nc

# Select Variables from each monthly file of soil: SOILLIQ= Soil Liquid Water
#                                                 SOILICE= Soil Ice

 cdo selvar,SOILLIQ soil.nc  soilliq.nc
 cdo selvar,SOILICE soil.nc  soilice.nc
 cdo selvar,TSOI    soil.nc  soiltem.nc 

 if [[ $start_year -eq $year ]]; then
   ncks -v P0,hyam,hybm input $scratchdir/P0.hyam.hybm.nc
 fi

##-------------3D VARIABLES-------------

# Interpolate Atmospheric 3D variables onto pressure levels

 for var in RH T U V Z; do 
   echo "$var"
   export F$var=${outdir}/${var}.nc
   export inFile=${outdir}/input.nc
   export p0_path=$scratchdir
   ncl ${scratchdir}/Interpolation_${var}_hsigma_ps_ECMWF.ncl
 done


# Set code and time of Atmospheric 3D Variables
  for var in RH T U V Z; do
    OUTPUT="$(pwd)"
    echo "${OUTPUT}"
    rm -rf tmp ${var}.grb
    cdo -f grb copy ${var}.nc tmp
    case $var in
      T)  code=10;;
      U)  code=11;;
      V)  code=12;;         
      Z)  code=13;;
      RH) code=14;;
      Q)  code=15;;
    esac
    cdo -setreftime,"$new_year"-01-01,00:00:00,h -setcode,$code tmp ${var}.grb
  done

##-------------2D VARIABLES-------------

##Set reference time and variable codes of 2D Atmospheric/Surface Variables
  rm -rf tmp
  cdo -f grb -selvar,PS input.nc tmp
  cdo -setreftime,$new_year-01-01,00:00:00,h -setcode,17 tmp PS.grb
  cdo -f grb -selvar,PSL input.nc tmp
  cdo -setreftime,$new_year-01-01,00:00:00,h -setcode,18 tmp PSL.grb
  cdo -f grb -selvar,TREFHT input.nc tmp
  cdo -setreftime,$new_year-01-01,00:00:00,h -setcode,19 tmp T2.grb
  cdo -f grb -selvar,RHREFHT input.nc tmp
  cdo -setreftime,$new_year-01-01,00:00:00,h -setcode,20 tmp RH2.grb
  cdo -f grb -selvar,UBOT input.nc tmp
  cdo -setreftime,$new_year-01-01,00:00:00,h -setcode,21 tmp U10.grb
  cdo -f grb -selvar,VBOT input.nc tmp
  cdo -setreftime,$new_year-01-01,00:00:00,h -setcode,22 tmp V10.grb
  cdo -f grb -selvar,TS input.nc tmp
  cdo -setreftime,$new_year-01-01,00:00:00,h -setcode,23 tmp TS.grb
  cdo -f grb -selvar,SST input.nc tmp
  cdo -setreftime,$new_year-01-01,00:00:00,h -setcode,24 tmp SST.grb

#set land points of SSTs to missingvalues. By default they are equal to 0
  cdo setctomiss,0 SST.grb tmp
  mv tmp SST.grb    

##-----------------SOIL-----------------

#Describe WRF Soil Layers
cat>lev1<<EOF2
   zaxistype = depth_below_land
   size      = 1
   name      = depth
   longname  = depth_below_land
   units     = cm
   levels    =   5
   lbounds   =   0
   ubounds   =  10
EOF2

cat>lev2<<EOF2
   zaxistype = depth_below_land
   size      = 1
   name      = depth
   longname  = depth_below_land
   units     = cm
   levels    =  25
   lbounds   =  10
   ubounds   =  40
EOF2

cat>lev3<<EOF2
   zaxistype = depth_below_land
   size      = 1
   name      = depth
   longname  = depth_below_land
   units     = cm
   levels    =  70
   lbounds   =  40
   ubounds   = 100
EOF2

cat>lev4<<EOF2
   zaxistype = depth_below_land
   size      = 1
   name      = depth
   longname  = depth_below_land
   units     = cm
   levels    = 150
   lbounds   = 100
   ubounds   = 200
EOF2

# layer defines the lowest point of each CESM soil layer that we use (units are meters (m))
  layer=(0.00 0.01420127 0.04164873 0.08286843 0.1548618 0.269525 0.4626066 0.7769104 1.299144 2.156126) # Modified Values
                                                                                                       # ind<-1; layer=0; for (i in level[2:9])
                                                                                                       # {ind<-ind+1; layer=(i-layer)+i}
# level defines the midpoint of the levels and it corresponds to the naming of the CESM levels
  level=(0.00 0.007100635 0.027925 0.06225858 0.1188651 0.2121934 0.3660658 0.6197585 1.038027 1.727635)

# layer1-4 define the WRF layers
  layer1=0.1 #m
  layer2=0.4 #m 
  layer3=1.0 #m 
  layer4=2.0 #m
    
#tbd delete soiltem.nc
  mv soiltem.nc TSOIL.nc

  rho_water=1000 #kg m-3
  rho_ice=917    #kg m-3

#Cycle over different soil layers    
  for k in {1..9}; do  # Consider that total levels are 10, but first level is 0 and has no tickness 
     a=${layer[$k]} 
     b=${layer[$((k-1))]}
     d=`echo "$a - $b" | bc -l` #Length of Considered layer k
  
     # CESM values of ice and liquid water in the soil are in kg/m^2. Here we transform them in 
     # non-dimensional values
     cdo -sellevel,${level[ $k ]} -divc,$rho_water -divc,$d soilliq.nc SOILLIQ$k.nc
     cdo -sellevel,${level[ $k ]} -divc,$rho_ice   -divc,$d soilice.nc SOILICE$k.nc
     # Areal Density (kg/m^2) of Liquid Water for a given level
     tt=`echo "$rho_water. * $d" | bc -l`
  done

  cdo merge SOILLIQ*.nc SOILLIQ.nc
  cdo merge SOILICE*.nc SOILICE.nc
  rm -rf SOILICE[123456789].nc SOILLIQ[123456789].nc

# Add liquid water and ice in each level to get the total quantity of moisture for each month
  for mon in 01 02 03 04 05 06 07 08 09 10 11 12; do
     cdo selmon,$mon SOILLIQ.nc SOILLIQ_${mon}.nc
     cdo selmon,$mon SOILICE.nc SOILICE_${mon}.nc
     cdo add SOILLIQ_${mon}.nc SOILICE_${mon}.nc soil_mois_${mon}.nc
  done  

#merge values soil moisture for different months of a year in a single file
  cdo mergetime soil_mois_*.nc soil_mois.nc
  rm -rf soil_mois_*.nc
  rm -rf SOILLIQ_*.nc SOILICE_*.nc
  mv soil_mois.nc MSOIL.nc

# soil moisture in meters for first layer (Depth of 0.0175128175 m: 0 is not considered). For both variables 
# first the ratio of each cesm layer into each of WRF layer is calculated, and then averaged values are obtained
# using these weight ratios
  cdo -sellevel,${level[1]} -mulc,${layer[1]} MSOIL.nc MS1.nc
  cdo -sellevel,${level[1]} -mulc,${layer[1]} TSOIL.nc TS1.nc
# 
   
  z=0.0
  j=1
  # We have to incorporate the soil moisture and temperature values from CESM multiple layers
  # to WRF only 4 layers. We use as basis the values of MS1 
  #### tbd cycle over the 4 layers instead of haveing 4 times a for-loop

  for i in {2..9}; do
    TF=`echo "${layer[ $i ]} > $layer1" | bc` #LAYER1 is the first WRF layer 
    if [ $TF -eq 1 ]; then
       u=$layer1             # depth WRF Layer
       v=${layer[$((i-1))]}  # depth of CESM level prior to the considered one deeper 
       w=`echo "$u - $v" | bc -l` # difference depth WRF layer 1 and the one of considered CESM layer: this is
                                  # basically the remaining of layer[i]
       cdo -sellevel,${level[$i]} -mulc,$w MSOIL.nc mtmp.nc  
       cdo -sellevel,${level[$i]} -mulc,$w TSOIL.nc ttmp.nc
       cdo add mtmp.nc MS1.nc mkk.nc
       cdo add ttmp.nc TS1.nc tkk.nc
       mv mkk.nc MS1.nc
       mv tkk.nc TS1.nc
       rm mtmp.nc
       rm ttmp.nc
       j=$i
       z=`echo "$z + $w" | bc -l`
       break                         # So basically the cycle breaks as soon as the first layer deeper
                                     # than the considered WRF layer is reached
    else
       #upper layers than the considered layer
       u=${layer[$i]} # depth considered layer
       v=${layer[$((i-1))]} # depth upper layer
       w=`echo "$u - $v" | bc -l` # basically this is the length of the considered layer
       cdo -sellevel,${level[$i]} -mulc,$w MSOIL.nc mtmp.nc
       cdo -sellevel,${level[$i]} -mulc,$w TSOIL.nc ttmp.nc
       cdo add mtmp.nc MS1.nc mkk.nc
       cdo add ttmp.nc TS1.nc tkk.nc
       mv mkk.nc MS1.nc
       mv tkk.nc TS1.nc
       rm mtmp.nc
       rm ttmp.nc
       z=`echo "$z + $w" | bc -l`
    fi
  done

  TF=0
  z=0
  for i in `seq $j 9`; do
    TF=`echo "${layer[$i]} > $layer2" | bc -l`
    if [ $i -eq $j ] ;then
       u=${layer[$i]}
       v=$layer1
       w=`echo "$u - $v" | bc -l`
       cdo -sellevel,${level[$i]} -mulc,$w MSOIL.nc mtmp.nc
       cdo -sellevel,${level[$i]} -mulc,$w TSOIL.nc ttmp.nc
       mv mtmp.nc MS2.nc
       mv ttmp.nc TS2.nc
       z=`echo "$z + $w" | bc -l`
    elif [ $TF -eq 1 ]; then
       u=$layer2
       v=${layer[$((i-1))]}
       w=`echo "$u - $v" | bc -l`
       cdo -sellevel,${level[$i]} -mulc,$w MSOIL.nc mtmp.nc
       cdo -sellevel,${level[$i]} -mulc,$w TSOIL.nc ttmp.nc
       cdo add mtmp.nc MS2.nc mkk.nc
       cdo add ttmp.nc TS2.nc tkk.nc
       mv mkk.nc MS2.nc
       mv tkk.nc TS2.nc
       rm mtmp.nc
       rm ttmp.nc
       j=$i
       z=`echo "$z + $w" | bc -l`
       break
    else
       u=${layer[$i]}
       v=${layer[$((i-1))]}
       w=`echo "$u - $v" | bc -l`
       cdo -sellevel,${level[$i]} -mulc,$w MSOIL.nc mtmp.nc
       cdo -sellevel,${level[$i]} -mulc,$w TSOIL.nc ttmp.nc
       cdo add mtmp.nc MS2.nc mkk.nc
       cdo add ttmp.nc TS2.nc tkk.nc
       mv mkk.nc MS2.nc
       mv tkk.nc TS2.nc
       rm mtmp.nc
       rm ttmp.nc
       z=`echo "$z + $w" | bc -l`
    fi
  done

  TF=0
  z=0
  for i in `seq $j 9`; do
    TF=`echo "${layer[$i]} > $layer3" | bc -l`
    if [ $i -eq $j ] ;then
       u=${layer[$i]}
       v=$layer2
       w=`echo "$u - $v" | bc -l`
       cdo -sellevel,${level[$i]} -mulc,$w MSOIL.nc mtmp.nc
       cdo -sellevel,${level[$i]} -mulc,$w TSOIL.nc ttmp.nc
       mv mtmp.nc MS3.nc
       mv ttmp.nc TS3.nc
       z=`echo "$z + $w" | bc -l`
    elif [ $TF -eq 1 ]; then
       u=$layer3
       v=${layer[$((i-1))]}
       w=`echo "$u - $v" | bc -l`
       cdo -sellevel,${level[$i]} -mulc,$w MSOIL.nc mtmp.nc
       cdo -sellevel,${level[$i]} -mulc,$w TSOIL.nc ttmp.nc
       cdo add mtmp.nc MS3.nc mkk.nc
       cdo add ttmp.nc TS3.nc tkk.nc
       mv mkk.nc MS3.nc
       mv tkk.nc TS3.nc
       rm mtmp.nc
       rm ttmp.nc
       j=$i
       z=`echo "$z + $w" | bc -l`
       break
    else
       u=${layer[$i]}
       v=${layer[$((i-1))]}
       w=`echo "$u - $v" | bc -l`
       cdo -sellevel,${level[$i]} -mulc,$w MSOIL.nc mtmp.nc
       cdo -sellevel,${level[$i]} -mulc,$w TSOIL.nc ttmp.nc
       cdo add mtmp.nc MS3.nc mkk.nc
       cdo add ttmp.nc TS3.nc tkk.nc
       mv mkk.nc MS3.nc
       mv tkk.nc TS3.nc
       rm mtmp.nc
       rm ttmp.nc
       z=`echo "$z + $w" | bc -l`
    fi
  done

  TF=0
  z=0
  for i in `seq $j 9`; do
    TF=`echo "${layer[$i]} > $layer4" | bc -l`
    if [ $i -eq $j ] ;then
       u=${layer[$i]}
       v=$layer3
       w=`echo "$u - $v" | bc -l`
       cdo -sellevel,${level[$i]} -mulc,$w MSOIL.nc mtmp.nc
       cdo -sellevel,${level[$i]} -mulc,$w TSOIL.nc ttmp.nc
       mv mtmp.nc MS4.nc
       mv ttmp.nc TS4.nc
       z=`echo "$z + $w" | bc -l`
    elif [ $TF -eq 1 ]; then
       u=$layer4
       v=${layer[$((i-1))]}
       w=`echo "$u - $v" | bc -l`
       cdo -sellevel,${level[$i]} -mulc,$w MSOIL.nc mtmp.nc
       cdo -sellevel,${level[$i]} -mulc,$w TSOIL.nc ttmp.nc
       cdo add mtmp.nc MS4.nc mkk.nc
       cdo add ttmp.nc TS4.nc tkk.nc
       mv mkk.nc MS4.nc
       mv tkk.nc TS4.nc
       rm mtmp.nc
       rm ttmp.nc
       j=$i
       z=`echo "$z + $w" | bc -l`
       break
    else
       u=${layer[$i]}
       v=$layer{[$((i-1))]}
       w=`echo "$u - $v" | bc -l`
       cdo -sellevel,${level[$i]} -mulc,$w MSOIL.nc mtmp.nc
       cdo -sellevel,${level[$i]} -mulc,$w TSOIL.nc ttmp.nc
       cdo add mtmp.nc MS4.nc mkk.nc
       cdo add ttmp.nc TS4.nc tkk.nc
       mv mkk.nc MS4.nc
       mv tkk.nc TS4.nc
       rm mtmp.nc
       rm ttmp.nc
       z=`echo "$z + $w" | bc -l`
    fi
  done

  cdo -f grb -setreftime,$new_year-01-01,00:00:00,h -setcode,31 -divc,0.1 TS1.nc TS1.grb # values are scaled to final units:
  cdo -f grb -setreftime,$new_year-01-01,00:00:00,h -setcode,32 -divc,0.3 TS2.nc TS2.grb #    adimensional -- soil moisture
  cdo -f grb -setreftime,$new_year-01-01,00:00:00,h -setcode,33 -divc,0.6 TS3.nc TS3.grb #        K        -- Soil Temperature
  cdo -f grb -setreftime,$new_year-01-01,00:00:00,h -setcode,34 -divc,1.0 TS4.nc TS4.grb
  cdo -f grb -setreftime,$new_year-01-01,00:00:00,h -setcode,35 -divc,0.1 MS1.nc MS1.grb
  cdo -f grb -setreftime,$new_year-01-01,00:00:00,h -setcode,36 -divc,0.3 MS2.nc MS2.grb
  cdo -f grb -setreftime,$new_year-01-01,00:00:00,h -setcode,37 -divc,0.6 MS3.nc MS3.grb
  cdo -f grb -setreftime,$new_year-01-01,00:00:00,h -setcode,38 -divc,1.0 MS4.nc MS4.grb

  for i in *.grb; do
     cdo settaxis,$new_year-01-01,00:00:00,6h "$i" tmp.grb
     mv tmp.grb "$i"
     #### tbd use a cdo calendar of 365-days maybe??
     #this condition is to take care of leap years since for paleo simulations we use no-leap years only
     if [ $new_year == 1992 ] || [ $new_year == 1996 ] || [ $new_year == 2000 ]; then
        cdo seldate,$new_year-01-01,"$new_year"-02-28 "$i" tmp1
        cdo settaxis,$new_year-03-01,00:00:00,6h -seldate,$new_year-02-29,"$new_year"-12-30 "$i" tmp2
        cdo -O mergetime tmp1 tmp2 "$i"
        rm tmp1 tmp2
     fi
  done


  for var in T M; do
    for lev in 1 2 3 4; do
      cdo setzaxis,lev${lev} ${var}S${lev}.grb tmp
      mv tmp ${var}S${lev}.grb
    done
  done

  if [[ $start_year -eq $year ]]; then
    cdo selvar,landmask soil.nc LM-CESM.nc
    cdo -f grb settaxis,$new_year-01-01,00:00:00 LM-CESM.nc tmp.grb
    cdo setcode,25 tmp.grb LM-CESM.grb

    ### tbd check if topography is working ###
    cdo selvar,topo input.nc HGT-CESM.nc
    cdo -f grb settaxis,$new_year-01-01,00:00:00 TER-CESM.nc tmp.grb
    cdo setcode,26 tmp.grb TER-CESM.grb
  fi

# close loop over years
  year=$((year + 1))

done
