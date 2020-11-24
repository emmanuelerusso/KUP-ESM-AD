;*********************************************
; vert_2_500.ncl / This script interpolates sigma to pressure coordinates in outputs the geopotential height (for all plevs chosen)
;*********************************************
setfileoption("nc","Format","NetCDF4")
begin
;*************************************************
; read in data
;*************************************************

  path1= getenv("inFile")
  
  in1    = addfile(path1,"r")
  intVar = in1->RELHUM  ;*****intVar is the Variable which is going to be interpolated
  Z3     = in1->Z3      ;*****intVar is the Variable which is going to be interpolated
  P0mb   = 1000.
  ps     = in1->PS
  TBOT   = in1->TBOT    ; get temperature at lowest layer (closest to surface)
  dims   = dimsizes(Z3)
  nlevs  = dims(1)
  PHIS   = Z3(:,nlevs-1,:,:)*9.81   ; get geopotential [m^2/s^2] at the bottom (lowest layer)
  
  path3  = getenv("p0_path")
  in3    = addfile(path3+"/P0.hyam.hybm.nc","r")  
  hbcofa = in3->hyam  
  hbcofb = in3->hybm        

;***************************************************
; interpolate to pressure levels
;***************************************************
  plevs =(/ 1000.0,950.,900.0,850.,800.0,750.,700.0,600.0,500.0,400.0,300.0,200.0,100.0,50.0 /)			
  plevs!0     = "plevs"
  plevs&plevs =  plevs
  plevs@long_name = "Pressure"
  plevs@unit = "hPa"
  
;   type of interpolation: 1 = linear, 2 = log, 3 = loglog
  interp = 1
 
;   is extrapolation desired if data is outside the range of PS
;   extrap = False
  extrap = True
 
;  A scalar integer indicating which variable to interpolate: 1 = temperature, -1 = geopotential height, 0 = all others. 
  varflg = 0

  intVar_PS = vinth2p_ecmwf(intVar,hbcofa,hbcofb,plevs,ps,interp,P0mb,1,extrap,varflg,TBOT,PHIS)
  plevs                = plevs*100
  intVar_PS&plevs      = plevs
  intVar_PS&plevs@unit = "Pa"
  
  system("echo saving")	
  
  fileout  = getenv("FRH")
  fout     = addfile(fileout,"c")
  
  fout->RH = intVar_PS 	                 ; write into new file
  system("echo new file for RH")   	 ; print to screen as confirmation

end
