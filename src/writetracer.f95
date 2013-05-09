  ! write the simulated tracer
  subroutine writetracer
#ifdef tracer
    USE mod_param
    USE mod_name
    USE mod_time
    USE mod_tracer
    USE mod_grid

    IMPLICIT none
    
    CHARACTER(LEN=200)                         :: outDataDir, outDataFile
    INTEGER nwx
    print *,'outDataDir', outDataDir
    nwx=IMT*JMT*KM*4
    open(53,file=trim(outDataDir)//trim(outDataFile)//'_tracerfile',form='unformatted', &
         access='DIRECT',recl=nwx)
    write(53,rec=ints+1) tra
close(53)
return
#endif /*tracer*/
end subroutine writetracer


