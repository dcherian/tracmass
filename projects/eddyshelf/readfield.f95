SUBROUTINE readfields

  USE netcdf
  USE mod_param
  USE mod_vel
  USE mod_coord
  USE mod_time
  USE mod_grid
  USE mod_name
  USE mod_vel
  USE mod_getfile
  
#ifdef tempsalt
  USE mod_dens
#endif
  
  IMPLICIT none
  ! ===   ===   ===   ===   ===   ===   ===   ===   ===   ===   ===
  ! = Variables for filename generation 
  CHARACTER                                  :: dates(62)*17
  CHARACTER (len=200)                        :: dataprefix, dstamp
!  INTEGER                                    :: intpart1 ,intpart2
  INTEGER                                    :: ndates
  INTEGER                                    :: yr1 ,mn1 ,dy1,hr
  INTEGER                                    :: yr2 ,mn2 ,dy2
  
  ! = Loop variables
  INTEGER                                    :: t ,i ,j ,k ,kk ,tpos
  
  ! = Variables used for getfield procedures
  CHARACTER (len=200)                        :: gridFile ,fieldFile
  CHARACTER (len=50)                         :: varName,fname

  ! = Variables for converting from S to Z
  REAL*8,       ALLOCATABLE, DIMENSION(:)    :: sc_r,Cs_r
  REAL*8,       ALLOCATABLE, DIMENSION(:)    :: sc_w,Cs_w
  INTEGER                                    :: hc

  ! = Input fields from GCM
  REAL*8,       ALLOCATABLE, DIMENSION(:,:)    :: ssh,dzt0
  ! ===   ===   ===

  
  alloCondUVW: if(.not. allocated (ssh)) then
     allocate ( ssh(imt,jmt), dzt0(imt,jmt) )
     allocate ( sc_r(km), Cs_r(km) )
     allocate ( sc_w(km), Cs_w(km) )
  end if alloCondUVW
  alloCondDZ: if(.not. allocated (dzu)) then
     allocate ( dzu(imt,jmt,km), dzv(imt,jmt,km) )
  end if alloCondDZ
  ! ===   ===   ===   ===   ===   ===   ===   ===   ===   ===   ===
  sc_r = 0
  Cs_r = 0
  sc_w = 0
  Cs_w = 0


  call datasetswap
  call updateClock

  ! === update the time counting ===
!  intpart1    = mod(ints,24)
!  intpart2    = floor((ints)/24.)
!  dstamp      = 'ocean_avg_XXXX.nc'

!  print *,currJDtot

! 2004...
!  write (dstamp(10:14),'(I5.5)') int(currJDtot) - 731576
!
! NEP6
!
! First run22 file is 1999, yearday 351, currJDtot 728279 - but it
! is labeled with 00005.
!  write (dstamp(10:14),'(I5.5)') int(currJDtot) - 728279 + 5

! First run23 file is 1999, yearday 351, currJDtot 730105 - but it
! is labeled with 00005.
!  write (dstamp(10:14),'(I5.5)') int(currJDtot) - 730105 + 5

!  dataprefix  = trim(inDataDir) // dstamp
  fname = 'ocean_his_0001.nc'
  dataprefix  = trim(inDataDir) // fname
! Update time counter
  ncTpos        = ints
!  print *,dataprefix

  uvel      = get3DfieldNC(trim(dataprefix) ,   'u')
  vvel      = get3DfieldNC(trim(dataprefix) ,   'v')
  ssh       = get2DfieldNC(trim(dataprefix) ,'zeta')
#ifdef explicit_w
  ! DC: changed omega to w
  wvel      = get3DfieldNC(trim(dataprefix) ,'w')
#endif
  where (uvel > 1000)
     uvel = 0
  end where
  where (vvel > 1000)
     vvel = 0
  end where
  where (ssh > 1000)
     ssh = 0
  end where
  hs(:imt,:jmt,2) = ssh(:imt,:jmt)

#ifdef explicit_w
  wflux(:,:,:,2) = 0.
  do j=1,jmt
    do i=1,imt
      wflux(i,j,0:km-1,2) = wvel(i,j,1:km)*dxdy(i,j)
    end do
  end do
#endif

  Cs_w = get1DfieldNC (trim(dataprefix), 'Cs_w')
  sc_w = get1DfieldNC (trim(dataprefix), 's_w')
  Cs_r = get1DfieldNC (trim(dataprefix), 'Cs_r')
  sc_r = get1DfieldNC (trim(dataprefix), 's_rho')
  hc   = getScalarNC (trim(dataprefix), 'hc')

  !do k=1,km
  !   dzt0 = (hc*sc_r(k) + depth*Cs_r(k)) / (hc + depth)
  !   dzt(:,:,k) = ssh + (ssh + depth) / dzt0
  !end do
  !dzt0 = dzt(:,:,km)
  !dzt(:,:,1:km-1)=dzt(:,:,2:km)-dzt(:,:,1:km-1)
  !dzt(:,:,km) = dzt0-ssh

! DC: removed all z_w & z_r code. compilation errors (01 May 2013)
! define zgrid3Dt for z_w etc. to be defined

#if defined roms && defined zgrid3Dt
  z_w(:,:,0,2) = depth
!  print *,'size(z_w) = ', size(z_w,1), size(z_w,2), size(z_w,3), size(z_w,4)
!  print *,'size(depth) = ', size(depth,1), size(depth,2)
#endif

  do k=1,km
#if defined roms && defined zgrid3Dt
     dzt0 = (hc*sc_r(k) + depth*Cs_r(k)) / (hc + depth)
     z_r(:,:,k,2) = ssh(:imt,:) + (ssh(:imt,:) + depth(:imt,:)) * dzt0(:imt,:)
#endif
     dzt0 = (hc*sc_w(k) + depth*Cs_w(k)) / (hc + depth)
#if defined roms && defined  zgrid3Dt
     z_w(:,:,k,2) = ssh(:imt,:) + (ssh(:imt,:) + depth(:imt,:)) * dzt0(:imt,:)
     dzt(:,:,k,2) = z_w(:,:,k,2)
#else
     dzt(:,:,k) = ssh(:imt,:) + (ssh(:imt,:) + depth(:imt,:)) * dzt0(:imt,:)
#endif

  end do
#ifdef zgrid3Dt
  dzt0 = dzt(:,:,km,2)
  dzt(:,:,1:km-1,2)=dzt(:,:,2:km,2)-dzt(:,:,1:km-1,2)
  dzt(:,:,km,2) = ssh(:imt,:) - dzt0
  dzt(:,:,:,1)=dzt(:,:,:,2)
  dzu(1:imt-1,:,:) = dzt(1:imt-1,:,:,2)*0.5 + dzt(2:imt,:,:,2)*0.5
  dzv(:,1:jmt-1,:) = dzt(:,1:jmt-1,:,2)*0.5 + dzt(:,2:jmt,:,2)*0.5
#else
  dzt0 = dzt(:,:,km)
  dzt(:,:,1:km-1)=dzt(:,:,2:km)-dzt(:,:,1:km-1)
  dzt(:,:,km) = ssh(:imt,:) - dzt0
  dzu(1:imt-1,:,:) = dzt(1:imt-1,:,:)*0.5 + dzt(2:imt,:,:)*0.5
  dzv(:,1:jmt-1,:) = dzt(:,1:jmt-1,:)*0.5 + dzt(:,2:jmt,:)*0.5
#endif

  do k=1,km
     uflux(:,:,k,2)   = uvel(:imt,:,k) * dzu(:,:,k) * dyu(:imt,:)
     vflux(:,1:jmt,k,2)   = vvel(:imt,:,k) * dzv(:,:,k) * dxv(:imt,:)
  end do

  if (intstep .le. 0) then
     uflux = -uflux
     vflux = -vflux
  end if

#ifdef tempsalt
!  print *,'Assuming linear equation of state + S = 35'
  tem(:,:,:,2)      = get3DfieldNC(trim(dataprefix) ,   'temp')
!  sal(:,:,:,2)      = get3DfieldNC(trim(dataprefix) ,   'salt')
  sal(:,:,:,2)      = 35d0
!  rho(:,:,:,2)      = get3DfieldNC(trim(dataprefix) ,   'rho')
  rho(:,:,:,2)      = 1027 - 1.7d-4*(tem(:,:,:,2)-24)
!  print *,'size(sal)=',size(sal,1),size(sal,2),size(sal,3)
!  print *,'size(rho)=',size(rho,1),size(rho,2),size(rho,3)
!  print *,'sal = ',maxval(sal),minval(sal)
!  print *,'rho = ',maxval(rho),minval(rho)
#ifdef larval_fish
  srflux(:,:,2)     = get2DfieldNC(trim(dataprefix) ,   'swrad')
! Note: this works as long as surface AKt is zero.
  ak2(:,:,:)        = get3DfieldNC(trim(dataprefix) ,   'AKt')
  akt(:,:,0:km-1,2) = ak2(:,:,:)
#endif
#endif

  return

end subroutine readfields
