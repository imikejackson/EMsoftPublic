! ###################################################################
! Copyright (c) 2013-2014, Marc De Graef/Carnegie Mellon University
! All rights reserved.
!
! Redistribution and use in source and binary forms, with or without modification, are 
! permitted provided that the following conditions are met:
!
!     - Redistributions of source code must retain the above copyright notice, this list 
!        of conditions and the following disclaimer.
!     - Redistributions in binary form must reproduce the above copyright notice, this 
!        list of conditions and the following disclaimer in the documentation and/or 
!        other materials provided with the distribution.
!     - Neither the names of Marc De Graef, Carnegie Mellon University nor the names 
!        of its contributors may be used to endorse or promote products derived from 
!        this software without specific prior written permission.
!
! THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
! AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
! IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
! ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
! LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
! DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
! SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
! CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
! OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
! USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
! ###################################################################
!--------------------------------------------------------------------------
! EMsoft:EMEBSD.f90
!--------------------------------------------------------------------------
!
! PROGRAM: EMDPFit
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief EMDPFit Fitting diffraction pattern using bobyqa with dot product as the metric
!
!> @date  02/22/16  SS 1.0 original
! ###################################################################

program EMDPFit

use local
use NameListTypedefs
use NameListHandlers
use io
use files

IMPLICIT NONE

character(fnlen)                       :: nmldeffile, progname, progdesc
type(EMDPFitListType)                  :: enl
integer(kind=irg)                      :: istat
logical                                :: verbose

nmldeffile = 'EMDPFit.nml'
progname = 'EMDPFit.f90'
progdesc = 'Fitting diffraction modality using bobyqa and dot product as the metric'

! print some information
call EMsoft(progname, progdesc)

! deal with the command line arguments, if any
call Interpret_Program_Arguments(nmldeffile,1,(/ 43 /), progname)

call GetEMDPFitNameList(nmldeffile, enl)

call FitDP(enl, progname, nmldeffile)

end program EMDPFit

!--------------------------------------------------------------------------
!
! SUBROUTINE:ComputeEBSDPatterns
!
!> @author Saransh SIngh, Carnegie Mellon University
!
!> @brief compute an energy-weighted EBSD pattern
!
!> @param enl name list
!> @param nmldeffile name of nml file
!
!> @date 02/22/16  SS 1.0 original
!> @date 08/08/16  SS 1.1 4 pattern fit
!> @date 08/10/16  SS 1.2 added variable stepsize
!--------------------------------------------------------------------------
subroutine FitDP(enl, progname, nmldeffile)

use local
use typedefs
use NameListTypedefs
use HDF5
use HDFsupport
use,INTRINSIC :: ISO_C_BINDING
use omp_lib
use error
use EMdymod
use bobyqa_module
use io, only:WriteValue

IMPLICIT NONE

type(EMDPFitListType),INTENT(IN)                :: enl
character(fnlen),INTENT(IN)                     :: progname
character(fnlen),INTENT(IN)                     :: nmldeffile

real(kind=sgl),allocatable                      :: mLPNH(:,:,:,:), mLPSH(:,:,:,:)
real(kind=sgl),allocatable                      :: mLPNHtmp(:,:,:,:), mLPSHtmp(:,:,:,:)
real(kind=sgl),allocatable                      :: mLPNH3(:,:,:), mLPSH3(:,:,:)
real(kind=sgl),allocatable                      :: accum_e(:,:,:)
integer(kind=irg),allocatable                   :: accum_e_int(:,:,:)

real(kind=dbl),allocatable                      :: X(:), XL(:), XU(:)
real(c_float),allocatable                       :: EXPT(:)
real(kind=dbl)                                  :: RHOBEG, RHOEND
integer(kind=irg),parameter                     :: MAXFUN = 10000
integer(kind=irg)                               :: NPT, N, IPRINT, NIPAR, NFPAR, NINIT, NSTEP, NRUN, ii
integer(kind=8),allocatable                     :: IPAR(:)
integer(kind=4)                                 :: iread
real(kind=sgl),allocatable                      :: FPAR(:)
real(kind=sgl),allocatable                      :: INITMEANVAL(:), STEPSIZE(:)

integer(kind=irg)                               :: nnx
integer(kind=irg)                               :: h5int,io_int(1)
real(kind=sgl)                                  :: h5flt
integer(HSIZE_T), dimension(1:4)                :: hdims4, offset4, dims4
integer(HSIZE_T), dimension(1:3)                :: hdims3, offset3, dims3 
character(fnlen)                                :: groupname, dataset, filename
character(11)                                   :: dstr
character(15)                                   :: tstrb
character(15)                                   :: tstre
logical                                         :: overwrite = .TRUE., insert = .TRUE., readonly, stat, verbose
integer(kind=irg)                               :: hdferr
type(HDFobjectStackType),pointer                :: HDF_head

integer(kind=irg)                               :: i, j

verbose = enl%verbose

RHOBEG = enl%rhobeg
RHOEND = enl%rhoend
NRUN = enl%nrun

io_int(1) = NRUN
call WriteValue('-> Number of minimization runs set to',io_int,1,"(I4/)")


if (trim(enl%modalityname) .eq. 'EBSD') then

! ipar(1) = 2
! ipar(2) = detnumsx
! ipar(3) = detnumsy
! ipar(4) = detnumEbins
! ipar(5) = mcnsx
! ipar(6) = mpnpx
! ipar(7) = numset
! ipar(8) = numquats
! ipar(9) = Emin
! ipar(10) = Emax
! ipar(11) = 0/1 ;0 for no mask, 1 for mask
! ipar(12) = binning
! ipar(13) = 0/1; 0 for Dot Product and 1 for Jaccard Distance 
! ipar(14) = nregions 

! fpar(1) = enl%xpc
! fpar(2) = enl%ypc
! fpar(3) = enl%delta
! fpar(4) = enl%MCsig
! fpar(5) = enl%omega
! fpar(6) = enl%thetac
! fpar(7) = enl%L
! fpar(8) = enl%beamcurrent
! fpar(9) = enl%dwelltime
! fpar(10) = alphaBD barrell distortion
! fpar(11) = maskradius
! fpar(12) = enl%gammavalue

! initmeanval(1) = fpar(7)
! initmeanval(2) = phi1
! initmeanval(3) = phi
! initmeanval(4) = phi2
! initmeanval(5) = xpc
! initmeanval(6) = ypc

! stepsize(1) = step_xpc
! stepsize(2) = step_ypc
! stepsize(3) = step_phi1 
! stepsize(4) = step_phi 
! stepsize(5) = step_phi2 
! stepsize(6) = step_L

! X = (/xpc, ypc, omega, L, phi1, phi, phi2/)


! set parameters and allocate arrays based on the modality

    NIPAR = 14
    NFPAR = 12

    NINIT = 6
    N = 7

    NSTEP = 6

    NPT   = N+6
    IPRINT = 0

    if (verbose) IPRINT = 2

    allocate(IPAR(NIPAR),FPAR(NFPAR),INITMEANVAL(NINIT),X(N),XL(N),XU(N),STEPSIZE(NSTEP))
    X = 0.5D0
    XL = 0.D0
    XU = 1.D0

    IPAR(1) = 2
    IPAR(8) = 1
    IPAR(11) = 0
    IPAR(14) = enl%nregions

    if(enl%metric .eq. 'DP') then
        IPAR(13) = 0;
    else if(enl%metric .eq. 'JD') then
        IPAR(13) = 1;
    else
        call FatalError('EMDPFit','Unknown similarity measure for images')
    end if

    if(enl%mask) IPAR(11) = 1
! open the fortran HDF interface
    call h5open_EMsoft(hdferr)

    nullify(HDF_head, HDF_head)

! is this a propoer HDF5 file ?
    call h5fis_hdf5_f(trim(EMsoft_getEMdatapathname())//trim(enl%masterfile), stat, hdferr)

    if (stat) then 
! open the master file 
        readonly = .TRUE.
        filename = trim(EMsoft_getEMdatapathname())//trim(enl%masterfile)
        
        hdferr =  HDF_openFile(filename, HDF_head, readonly)
        
        groupname = 'EMData'
        hdferr = HDF_openGroup(groupname, HDF_head)

        groupname = 'EBSDmaster'
        hdferr = HDF_openGroup(groupname, HDF_head)

        dataset = 'mLPNH'
        call HDF_readDatasetFloatArray4D(dataset, dims4, HDF_head, hdferr, mLPNHtmp)

        dataset = 'mLPSH'
        call HDF_readDatasetFloatArray4D(dataset, dims4, HDF_head, hdferr, mLPSHtmp)

        nnx = (dims4(1)-1)/2
        IPAR(6) = nnx

        allocate(mLPNH(-nnx:nnx,-nnx:nnx,dims4(3),dims4(4)), mLPSH(-nnx:nnx,-nnx:nnx,dims4(3),dims4(4)))

        mLPNH = mLPNHtmp
        mLPSH = mLPSHtmp

        deallocate(mLPNHtmp, mLPSHtmp) 

        dataset = 'numEbins'
        call HDF_readDatasetInteger(dataset, HDF_head, hdferr, iread)
        IPAR(4) = iread

        dataset = 'numset'
        call HDF_readDatasetInteger(dataset, HDF_head, hdferr, iread)
        IPAR(7) = iread

        call HDF_pop(HDF_head)

! open the Data group
        groupname = 'MCOpenCL'
        hdferr = HDF_openGroup(groupname, HDF_head)

        dataset = 'accum_e'
        call HDF_readDatasetIntegerArray3D(dataset, dims3, HDF_head, hdferr, accum_e_int)
        nnx = (dims3(2)-1)/2
        IPAR(5) = nnx

        allocate(accum_e(1:dims3(1),-nnx:nnx,-nnx:nnx))

! and close EMData group
        call HDF_pop(HDF_head)
        call HDF_pop(HDF_head)

! open the namelist group
        groupname = 'NMLparameters'
        hdferr = HDF_openGroup(groupname, HDF_head)

        groupname = 'MCCLNameList'
        hdferr = HDF_openGroup(groupname, HDF_head)

        dataset = 'sig'
        call HDF_readDatasetFloat(dataset, HDF_head, hdferr, fpar(4))

        dataset = 'omega'
        call HDF_readDatasetFloat(dataset, HDF_head, hdferr, fpar(5))

        call HDF_pop(HDF_head,.TRUE.)

    end if

! close the fortran HDF interface
    call h5close_EMsoft(hdferr)

    accum_e = float(accum_e_int)
    deallocate(accum_e_int)

    IPAR(2) = enl%numsx
    IPAR(3) = enl%numsy
    IPAR(12) = enl%binning
    IPAR(9) = 1
    IPAR(10) = IPAR(4)

    FPAR(1) = enl%xpc
    FPAR(2) = enl%ypc
    FPAR(3) = enl%delta
    FPAR(6) = enl%thetac
    FPAR(7) = enl%L
    FPAR(8) = enl%beamcurrent
    FPAR(9) = enl%dwelltime
    FPAR(10) = 0.0  
    FPAR(11) = enl%maskradius
    FPAR(12) = enl%gammavalue

    INITMEANVAL(1) = enl%L
    INITMEANVAL(2) = enl%phi1
    INITMEANVAL(3) = enl%phi
    INITMEANVAL(4) = enl%phi2
    INITMEANVAL(5) = enl%xpc
    INITMEANVAL(6) = enl%ypc

    STEPSIZE(1) = enl%step_xpc
    STEPSIZE(2) = enl%step_ypc
    STEPSIZE(3) = enl%step_phi1
    STEPSIZE(4) = enl%step_phi
    STEPSIZE(5) = enl%step_phi2
    STEPSIZE(6) = enl%step_L
    
    allocate(EXPT(IPAR(2)*IPAR(3)/IPAR(12)**2))

    open(unit=dataunit,file=trim(EMsoft_getEMdatapathname())//trim(enl%exptfile),action='read',access='direct',&
    form='unformatted',recl=(4*ipar(2)*ipar(3)/ipar(12)**2))
    read(dataunit,rec=1) EXPT
    close(dataunit)


    EXPT = EXPT/NORM2(EXPT)

    do ii = 1,NRUN

        io_int(1) = ii
        call WriteValue('-> Starting minimization run #',io_int,1,"(I4/)")
        
        call BOBYQA(NIPAR, NFPAR, NINIT, IPAR, FPAR, INITMEANVAL, EXPT, N, NPT, X, XL, XU, RHOBEG, RHOEND,&
        IPRINT, MAXFUN, EBSDCALFUN, accum_e, mLPNH, mLPSH, NSTEP, STEPSIZE, verbose)
         
       
        if (ii .lt. NRUN) then

            INITMEANVAL(1) = sngl(X(4))*2.0*stepsize(6)*fpar(3) - stepsize(6)*fpar(3) + INITMEANVAL(1)
            INITMEANVAL(2) = X(5)*2.0*stepsize(3) - stepsize(3) + INITMEANVAL(2)
            INITMEANVAL(3) = X(6)*2.0*stepsize(4) - stepsize(4)  + INITMEANVAL(3)
            INITMEANVAL(4) =  X(7)*2.0*stepsize(5) - stepsize(5) + INITMEANVAL(4)
            INITMEANVAL(5) = sngl(X(1))*2.0*stepsize(1) - stepsize(1) + INITMEANVAL(5)
            INITMEANVAL(6) = sngl(X(2))*2.0*stepsize(2) - stepsize(2) + INITMEANVAL(6)

            X = 0.5D0

        else
         
            write(6,'(A)')'Best fit values are as follows:'
            write(6,'(A,F15.6)')'X-Pattern Center :',sngl(X(1))*2.0*stepsize(1) - stepsize(1) + INITMEANVAL(5)
            write(6,'(A,F15.6)')'Y-Pattern Center :',sngl(X(2))*2.0*stepsize(2) - stepsize(2) + INITMEANVAL(6)
            write(6,'(A,F15.6)')'Scintillator to sample distance:',sngl(X(4))*2.0*stepsize(6)*fpar(3) - &
            stepsize(6)*fpar(3) + INITMEANVAL(1)
            write(6,*)''

            write(6,'(A,3F15.6)')'(phi1,PHI,phi2) :',X(5)*2.0*stepsize(3) - stepsize(3) + INITMEANVAL(2), &
            X(6)*2.0*stepsize(4) - stepsize(4)  + INITMEANVAL(3), X(7)*2.0*stepsize(5) - stepsize(5) + INITMEANVAL(4)
            write(6,*)''

        end if

        STEPSIZE = STEPSIZE/2.0

        
    end do

else if(trim(enl%modalityname) .eq. 'ECP') then

! ipar(1) = 2 
! ipar(2) = detnumsx
! ipar(3) = detnumsy
! ipar(4) = numangle
! ipar(5) = mcnsx
! ipar(6) = numset
! ipar(7) = mpnx
! ipar(8) = numquats
! ipar(9) = 0/1 ;0 for no mask, 1 for mask
! ipar(10) = 1 ; this is numEbins for EBSD modality
! ipar(11) = 0/1 for DP or JD
! ipar(12) = 1; binning

! fpar(1) = ecpnl%thetac
! fpar(2) = ecpnl%sampletilt
! fpar(3) = ecpnl%workingdistance
! fpar(4) = ecpnl%Rin
! fpar(5) = ecpnl%Rout
! fpar(6) = ecpnl%sigstart
! fpar(7) = ecpnl%sigend
! fpar(8) = ecpnl%sigstep
! fpar(9) = ecpnl%gammavalue
! fpar(10) = maskradius

! initmeanval(1) = thetac
! initmeanval(2) = phi1
! initmeanval(3) = phi
! initmeanval(4) = phi2

! stepsize(1) = step_thetacone
! stepsize(2) = step_phi1
! stepsize(3) = step_phi ; all 4 patterns
! stepsize(4) = step_phi2 ; all 4 patterns


! set parameters and allocate arrays based on the modality

    NIPAR = 12
    NFPAR = 10
    NINIT = 4 
    N     = 4
    NSTEP = 4

    NPT   = N+6
    IPRINT = 0

    if(verbose) IPRINT = 2

    allocate(IPAR(NIPAR),FPAR(NFPAR),INITMEANVAL(NINIT),X(N),XL(N),XU(N),STEPSIZE(NSTEP))
    X = 0.5D0
    XL = 0.D0
    XU = 1.D0
  
    IPAR(1) = 2
    IPAR(9) = 0
    IPAR(8) = 1
    IPAR(10) = 1
    
    if(enl%metric .eq. 'DP') then
        IPAR(11) = 0;
    else if(enl%metric .eq. 'JD') then
        IPAR(11) = 1;
    else
        call FatalError('EMDPFit','Unknown similarity measure for images')
    end if

    IPAR(12) = 1!enl%nregions

    if(enl%mask) IPAR(9) = 1

! open the fortran HDF interface
    call h5open_EMsoft(hdferr)

    nullify(HDF_head, HDF_head)

! is this a propoer HDF5 file ?
    call h5fis_hdf5_f(trim(EMsoft_getEMdatapathname())//trim(enl%masterfile), stat, hdferr)

    if (stat) then 
! open the master file 
        readonly = .TRUE.
        filename = trim(EMsoft_getEMdatapathname())//trim(enl%masterfile) 
        hdferr =  HDF_openFile(filename, HDF_head, readonly)

        groupname = 'EMData'
        hdferr = HDF_openGroup(groupname, HDF_head)

        groupname = 'ECPmaster'
        hdferr = HDF_openGroup(groupname, HDF_head)

        dataset = 'mLPNH'
        call HDF_readDatasetFloatArray3D(dataset, dims3, HDF_head, hdferr, mLPNH3)

        dataset = 'mLPSH'
        call HDF_readDatasetFloatArray3D(dataset, dims3, HDF_head, hdferr, mLPSH3)

        nnx = (dims3(1)-1)/2
        IPAR(7) = nnx

        allocate(mLPNH(-nnx:nnx,-nnx:nnx,1,dims3(3)), mLPSH(-nnx:nnx,-nnx:nnx,1,dims3(3)))

        mLPNH(:,:,1,:) = mLPNH3(:,:,:)
        mLPSH(:,:,1,:) = mLPSH3(:,:,:)

        deallocate(mLPNH3, mLPSH3)

        dataset = 'numset'
        call HDF_readDatasetInteger(dataset, HDF_head, hdferr, iread)
        IPAR(6) = iread

        call HDF_pop(HDF_head)
 
! open the Data group
        groupname = 'MCOpenCL'
        hdferr = HDF_openGroup(groupname, HDF_head)

        dataset = 'accum_e'
        call HDF_readDatasetIntegerArray3D(dataset, dims3, HDF_head, hdferr, accum_e_int)
        nnx = (dims3(2)-1)/2
        IPAR(5) = nnx
        IPAR(4) = dims3(1)

        allocate(accum_e(1:dims3(1),-nnx:nnx,-nnx:nnx))

        accum_e = float(accum_e_int)
        deallocate(accum_e_int)

! and close EMData
        call HDF_pop(HDF_head)
        call HDF_pop(HDF_head)

! open the namelist group
        groupname = 'NMLparameters'
        hdferr = HDF_openGroup(groupname, HDF_head)

        groupname = 'MCCLNameList'
        hdferr = HDF_openGroup(groupname, HDF_head)

        dataset = 'sigstart'
        call HDF_readDatasetFloat(dataset, HDF_head, hdferr, FPAR(6))

        dataset = 'sigend'
        call HDF_readDatasetFloat(dataset, HDF_head, hdferr, FPAR(7))

        dataset = 'sigstep'
        call HDF_readDatasetFloat(dataset, HDF_head, hdferr, FPAR(8))

        call HDF_pop(HDF_head,.TRUE.)
       
    end if


! close the fortran HDF interface
    call h5close_EMsoft(hdferr)


    IPAR(2) = enl%npix
    IPAR(3) = enl%npix

    FPAR(1) = enl%thetacone
    FPAR(2) = enl%sampletilt
    FPAR(3) = enl%workingdistance
    FPAR(4) = enl%Rin
    FPAR(5) = enl%Rout
    FPAR(9) = enl%gammavalue
    FPAR(10) = enl%maskradius

    initmeanval(1) = enl%thetacone
    initmeanval(2) = enl%phi1
    initmeanval(3) = enl%phi
    initmeanval(4) = enl%phi2

    STEPSIZE(1) = enl%step_thetacone
    STEPSIZE(2) = enl%step_phi1
    STEPSIZE(3) = enl%step_phi
    STEPSIZE(4) = enl%step_phi2

    allocate(EXPT(IPAR(2)*IPAR(3)/IPAR(12)**2))
    open(unit=dataunit,file=trim(EMsoft_getEMdatapathname())//trim(enl%exptfile),action='read',access='direct',&
    form='unformatted',recl=(4*ipar(2)*ipar(3)/ipar(12)**2))
    read(dataunit,rec=1) EXPT
    close(dataunit)

    EXPT = EXPT/NORM2(EXPT)
    
    do ii = 1,NRUN

        io_int(1) = ii
        call WriteValue('-> Starting minimization run #',io_int,1,"(I4)")

        call BOBYQA(NIPAR, NFPAR, NINIT, IPAR, FPAR, INITMEANVAL, EXPT, N, NPT, X, XL, XU, RHOBEG, RHOEND,&
        IPRINT, MAXFUN, ECPCALFUN, accum_e, mLPNH, mLPSH, NSTEP, STEPSIZE, verbose)

        if (ii .lt. NRUN) then

            INITMEANVAL(1) = sngl(X(1))*2.0*stepsize(1) - stepsize(1) + INITMEANVAL(1) 
            INITMEANVAL(4) = X(4)*2.0*stepsize(3) - stepsize(3) + INITMEANVAL(4)
            INITMEANVAL(5) = X(5)*2.0*stepsize(4) - stepsize(4)  + INITMEANVAL(5)
            INITMEANVAL(6) = X(6)*2.0*stepsize(5) - stepsize(5) + INITMEANVAL(6)

            X = 0.5D0
    
        else

            write(6,'(A)')'Best fit values are as follows:'
            write(6,'(A,F15.6)')'Opening angle of cone :',sngl(X(1))*2.0*stepsize(1) - stepsize(1) + INITMEANVAL(1)
            write(6,*)''
            write(6,'(A,3F15.6)')'(phi1,PHI,phi2) for pattern 1 :',X(2)*2.0*stepsize(2) - stepsize(2) + INITMEANVAL(2),&
            X(3)*2.0*stepsize(3) - stepsize(3)  + INITMEANVAL(3), X(4)*2.0*stepsize(4) - stepsize(4) + INITMEANVAL(4)

        end if

        STEPSIZE = STEPSIZE/2.0

    end do
 
else
    call FatalError('EMDPFit','Name of modality unknown. Please check and try again')
end if

end subroutine FitDp
