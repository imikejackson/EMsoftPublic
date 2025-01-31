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
!--------------------------------------------------------------------------
! EMsoft:ECPmod.f90
!--------------------------------------------------------------------------
!
! MODULE: ECPmod
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief EMECP helper routines
!
!> @date 09/15/15 SS 1.0 original
!---------------------------------------------------------------------------
module ECPmod

use local 
use typedefs

IMPLICIT NONE

type ECPAngleType
        real(kind=dbl),allocatable      :: quatang(:,:)
end type ECPAngleType

type ECPLargeAccumType
        integer(kind=irg),allocatable   :: accum_z(:,:,:,:)
        integer(kind=irg),allocatable   :: accum_e(:,:,:)
end type ECPLargeAccumType

type ECPMasterType
        real(kind=sgl),allocatable      :: mLPNH(:,:) , mLPSH(:,:)
        real(kind=sgl),allocatable      :: rgx(:,:), rgy(:,:), rgz(:,:)
end type ECPMasterType

type IncidentListECP
        integer(kind=irg)               :: i, j
        real(kind=dbl)                  :: k(3)
        type(IncidentListECP),pointer   :: next
end type IncidentListECP


contains

!--------------------------------------------------------------------------
!
! SUBROUTINE:ECPreadMCfile
!
!> @author Marc De Graef/Saransh Singh, Carnegie Mellon University
!
!> @brief read monte carlo file
!
!> @param enl EBSD name list structure
!> @param acc energy structure
!
!> @date 06/24/14  MDG 1.0 original
!> @date 11/18/14  MDG 1.1 removed enl%MCnthreads from file read
!> @date 04/02/15  MDG 2.0 changed program input & output to HDF format
!> @date 04/29/15  MDG 2.1 add optional parameter efile
!> @date 09/15/15  SS  2.2 added accum_z reading 
!> @date 09/15/15  SS  3.0 made part of ECPmod module
!> @date 10/12/15  SS  3.1 changes to handle new mc program; old version of mc file
!>                         not supported anymore
!--------------------------------------------------------------------------
recursive subroutine ECPreadMCfile(enl,acc,efile,verbose)
!DEC$ ATTRIBUTES DLLEXPORT :: ECPreadMCfile

use NameListTypedefs
use files
use io
use HDF5
use HDFsupport
use error

IMPLICIT NONE

type(ECPNameListType),INTENT(INOUT)     :: enl
type(ECPLargeAccumType),pointer         :: acc
character(fnlen),INTENT(IN),OPTIONAL    :: efile
logical,INTENT(IN),OPTIONAL             :: verbose

integer(kind=irg)                       :: istat, hdferr, nlines, nx
logical                                 :: stat, readonly
integer(HSIZE_T)                        :: dims3(3),dims4(4)
character(fnlen)                        :: groupname, dataset, energyfile 
character(fnlen),allocatable            :: stringarray(:)

integer(kind=irg),allocatable           :: acc_z(:,:,:,:), acc_e(:,:,:)

type(HDFobjectStackType),pointer        :: HDF_head

! is the efile parameter present? If so, use it as the filename, otherwise use the enl%energyfile parameter
if (PRESENT(efile)) then
  energyfile = efile
else
  energyfile = trim(EMsoft_getEMdatapathname())//trim(enl%energyfile)
end if
energyfile = EMsoft_toNativePath(energyfile)

allocate(acc)

! first, we need to check whether or not the input file is of the HDF5 format type; if
! it is, we read it accordingly, otherwise we give error. Old format not supported anymore
!
call h5fis_hdf5_f(energyfile, stat, hdferr)

if (stat) then
! open the fortran HDF interface
  call h5open_EMsoft(hdferr)

  nullify(HDF_head)

! open the MC file using the default properties.
  readonly = .TRUE.
  hdferr =  HDF_openFile(energyfile, HDF_head, readonly)

! open the namelist group
  groupname = 'NMLparameters'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'MCCLNameList'
  hdferr = HDF_openGroup(groupname, HDF_head)

! read all the necessary variables from the namelist group
  dataset = 'xtalname'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%MCxtalname = trim(stringarray(1))
  deallocate(stringarray)

  dataset = 'mode'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%MCmode = trim(stringarray(1))
  deallocate(stringarray)

  if(enl%MCmode .ne. 'bse1') then
     call FatalError('ECPreadMCfile','This file is not bse1 mode. Please input correct HDF5 file')
  end if

  dataset = 'numsx'
  call HDF_readDatasetInteger(dataset, HDF_head, hdferr, enl%nsx)
  enl%nsx = (enl%nsx - 1)/2
  enl%nsy = enl%nsx

  dataset = 'EkeV'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%EkeV)

  dataset = 'Ehistmin'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%Ehistmin)

  dataset = 'Ebinsize'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%Ebinsize)

  dataset = 'depthmax'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%depthmax)

  dataset = 'depthstep'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%depthstep)

  dataset = 'sigstart'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%MCsigstart)

  dataset = 'sigend'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%MCsigend)

  dataset = 'sigstep'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%MCsigstep)

  dataset = 'omega'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%MComega)

! close the name list group
  call HDF_pop(HDF_head)
  call HDF_pop(HDF_head)

! read from the EMheader
  groupname = 'EMheader'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'MCOpenCL'
  hdferr = HDF_openGroup(groupname, HDF_head)

  dataset = 'ProgramName'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%MCprogname = trim(stringarray(1))
  deallocate(stringarray)

  dataset = 'Version'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%MCscversion = trim(stringarray(1))
  deallocate(stringarray)

  call HDF_pop(HDF_head)
  call HDF_pop(HDF_head)

! open the Data group
  groupname = 'EMData'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'MCOpenCL'
  hdferr = HDF_openGroup(groupname, HDF_head)

! read data items 
  dataset = 'numangle'
  call HDF_readDatasetInteger(dataset, HDF_head, hdferr, enl%numangle)

  dataset = 'numzbins'
  call HDF_readDatasetInteger(dataset, HDF_head, hdferr, enl%numzbins)

  dataset = 'accum_z'
  call HDF_readDatasetIntegerArray4D(dataset, dims4, HDF_head, hdferr, acc_z)
  allocate(acc%accum_z(1:dims4(1),1:dims4(2),1:dims4(3),1:dims4(4)))
  acc%accum_z = acc_z
  deallocate(acc_z)

  dataset = 'accum_e'
  call HDF_readDatasetIntegerArray3D(dataset, dims3, HDF_head, hdferr, acc_e)
  allocate(acc%accum_e(1:dims3(1),1:dims3(2),1:dims3(3)))
  acc%accum_e = acc_e
  deallocate(acc_e)
 
  enl%num_el = sum(acc%accum_z)

! and close everything
  call HDF_pop(HDF_head,.TRUE.)

! close the fortran HDF interface
  call h5close_EMsoft(hdferr)

else
!==============================================
! OLD VERSION OF MC FILE NOT SUPPORTED ANYMORE
! COMMENTING OUT THE FOLLOWING LINES
! REPLACING WITH FATALERROR COMMENT
!==============================================

  call FatalError('ECPreadMCfile','The file is not a h5 file. Old version of MC file not supported anymore!')
  !if (present(verbose)) call Message('opening '//trim(enl%energyfile), frm = "(A)")
end if

if (present(verbose)) then
    if (verbose) call Message(' -> completed reading '//trim(enl%energyfile), frm = "(A)")
end if

end subroutine ECPreadMCfile

!--------------------------------------------------------------------------
!
! SUBROUTINE:ECPreadMasterfile
!
!> @author Saransh Singh/Marc De Graef, Carnegie Mellon University
!
!> @brief read EBSD master pattern from file
!
!> @param enl EBSD name list structure
!
!> @date 06/24/14  MDG 1.0 original
!> @date 04/02/15  MDG 2.0 changed program input & output to HDF format
!> @date 09/01/15  MDG 3.0 changed Lambert maps to Northern + Southern maps; lots of changes...
!> @date 09/03/15  MDG 3.1 removed support for old file format (too difficult to maintain after above changes)
!> @date 09/15/15  SS  4.0 modified for ECP master program
!--------------------------------------------------------------------------
recursive subroutine ECPreadMasterfile(enl, master, mfile, verbose)
!DEC$ ATTRIBUTES DLLEXPORT :: ECPreadMasterfile

use NameListTypedefs
use files
use io
use error
use HDF5
use HDFsupport


IMPLICIT NONE

type(ECPNameListType),INTENT(INOUT)     :: enl
type(ECPMasterType),pointer             :: master
character(fnlen),INTENT(IN),OPTIONAL    :: mfile
logical,INTENT(IN),OPTIONAL             :: verbose

real(kind=sgl),allocatable              :: mLPNH(:,:) 
real(kind=sgl),allocatable              :: mLPSH(:,:) 
real(kind=sgl),allocatable              :: EkeVs(:) 
integer(kind=irg),allocatable           :: atomtype(:)

real(kind=sgl),allocatable              :: srtmp(:,:,:)
integer(kind=irg)                       :: istat

logical                                 :: stat, readonly
integer(kind=irg)                       :: hdferr, nlines
integer(HSIZE_T)                        :: dims(1), dims3(3)
character(fnlen)                        :: groupname, dataset, masterfile
character(fnlen),allocatable            :: stringarray(:)

type(HDFobjectStackType),pointer        :: HDF_head

allocate(master)

! open the fortran HDF interface
call h5open_EMsoft(hdferr)

nullify(HDF_head)

! is the mfile parameter present? If so, use it as the filename, otherwise use the enl%masterfile parameter
if (PRESENT(mfile)) then
  masterfile = mfile
else
  masterfile = trim(EMsoft_getEMdatapathname())//trim(enl%masterfile)
end if
masterfile = EMsoft_toNativePath(masterfile)

! is this a propoer HDF5 file ?
call h5fis_hdf5_f(trim(masterfile), stat, hdferr)

if (stat) then 
! open the master file 
  readonly = .TRUE.
  hdferr =  HDF_openFile(masterfile, HDF_head, readonly)

! open the namelist group
  groupname = 'NMLparameters'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'ECPMasterNameList'
  hdferr = HDF_openGroup(groupname, HDF_head)

! read all the necessary variables from the namelist group
  dataset = 'energyfile'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%Masterenergyfile = trim(stringarray(1))
  deallocate(stringarray)

  dataset = 'npx'
  call HDF_readDatasetInteger(dataset, HDF_head, hdferr, enl%npx)
  enl%npy = enl%npx

  call HDF_pop(HDF_head)
  call HDF_pop(HDF_head)

  groupname = 'EMData'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'ECPmaster'
  hdferr = HDF_openGroup(groupname, HDF_head)

  dataset = 'EkeV'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%EkeV) 
  
  dataset = 'numset'
  call HDF_readDatasetInteger(dataset, HDF_head, hdferr, enl%numset)

  dataset = 'mLPNH'
  call HDF_readDatasetFloatArray3D(dataset, dims3, HDF_head, hdferr, srtmp)
  allocate(master%mLPNH(-enl%npx:enl%npx,-enl%npy:enl%npy),stat=istat)
  master%mLPNH = sum(srtmp,3)
  deallocate(srtmp)

  dataset = 'mLPSH'
  call HDF_readDatasetFloatArray3D(dataset, dims3, HDF_head, hdferr, srtmp)
  allocate(master%mLPSH(-enl%npx:enl%npx,-enl%npy:enl%npy),stat=istat)
  master%mLPSH = sum(srtmp,3)
  deallocate(srtmp)

  dataset = 'xtalname'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%Masterxtalname = trim(stringarray(1))
  deallocate(stringarray)

  call HDF_pop(HDF_head)
  call HDF_pop(HDF_head)

  groupname = 'EMheader'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'ECPmaster'
  hdferr = HDF_openGroup(groupname, HDF_head)

  dataset = 'ProgramName'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%Masterprogname = trim(stringarray(1))
  deallocate(stringarray)
  
  dataset = 'Version'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%Masterscversion = trim(stringarray(1))
  deallocate(stringarray)
  
  call HDF_pop(HDF_head,.TRUE.)

! close the fortran HDF interface
  call h5close_EMsoft(hdferr)

else
  masterfile = 'File '//trim(masterfile)//' is not an HDF5 file'
  call FatalError('EBSDreadMasterfile',masterfile)
end if
!====================================

if (present(verbose)) call Message(' -> completed reading '//trim(enl%masterfile), frm = "(A)")

end subroutine ECPreadMasterfile

!--------------------------------------------------------------------------
!
! SUBROUTINE:GetVectorsCone
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief generate list of incident vectors for interpolation of ECP
!
!> @param ecpnl ECP namelist structure
!> @param klist IncidentListECP pointer
!> @param rotmat rotation matrix for the microscope to grain reference frame
!> @param numk number of incident vectors in the linked list
!
!> @date 10/12/15  SS 1.0 original
!> @date 11/02/15  SS 1.1 changed output image to be ecpnl%npix x ecpnl%npix instead of 2*ecpnl%npix+1
!--------------------------------------------------------------------------
recursive subroutine GetVectorsCone(ecpnl, klist, numk)
!DEC$ ATTRIBUTES DLLEXPORT :: GetVectorsCone

use local
use io
use NameListTypedefs
use error

type(ECPNameListType),INTENT(IN)                 :: ecpnl
type(IncidentListECP),pointer                    :: klist, ktmp
integer(kind=irg),INTENT(OUT)                    :: numk

real(kind=dbl)                                   :: kk(3), thetacr, delta, ktmax
real(kind=dbl),parameter                         :: DtoR = 0.01745329251D0
integer(kind=irg)                                :: imin, imax, jmin, jmax
integer(kind=irg)                                :: ii, jj, istat

numk = 0
kk = (/0.D0,0.D0,1.D0/)
thetacr = DtoR*ecpnl%thetac
ktmax = tan(thetacr)
delta = 2.0*ktmax/(float(ecpnl%npix)-1.0)

imin = 1
imax = ecpnl%npix
jmin = 1
jmax = ecpnl%npix

allocate(klist,stat=istat)
if (istat .ne. 0) then
    call FatalError('GetVectorsCone','Failed to allocate klist pointer')
end if

ktmp => klist
nullify(ktmp%next)

do ii = imin, imax
    do jj = jmin, jmax
        ktmp%k(1:3) = (/-ktmax+delta*(ii-1),-ktmax+delta*(jj-1),0.D0/) + kk(1:3)
        ktmp%k = ktmp%k/sqrt(sum(ktmp%k**2))
        ktmp%i = ii
        ktmp%j = jj
        numk = numk + 1
        allocate(ktmp%next)
        ktmp => ktmp%next
        nullify(ktmp%next)
    end do
end do

end subroutine GetVectorsCone

!--------------------------------------------------------------------------
!
! SUBROUTINE:GetVectorsConeSingle
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief generate list of incident vectors for calculation of single ECP
!
!> @param ecpnl ECP namelist structure
!> @param klist IncidentListECP pointer
!> @param rotmat rotation matrix for the microscope to grain reference frame
!> @param numk number of incident vectors in the linked list
!
!> @date 10/12/15  SS 1.0 original
!> @date 11/02/15  SS 1.1 changed output image to be ecpnl%npix x ecpnl%npix instead of 2*ecpnl%npix+1
!> @date 04/06/16  SS 1.2 modified for single ECP pattern calculation
!--------------------------------------------------------------------------
recursive subroutine GetVectorsConeSingle(ecpnl, klist, numk)
!DEC$ ATTRIBUTES DLLEXPORT :: GetVectorsConeSingle

use local
use io
use NameListTypedefs
use error

type(ECPSingleNameListType),INTENT(IN)           :: ecpnl
type(IncidentListECP),pointer                    :: klist, ktmp
integer(kind=irg),INTENT(OUT)                    :: numk

real(kind=dbl)                                   :: kk(3), thetacr, delta, ktmax
real(kind=dbl),parameter                         :: DtoR = 0.01745329251D0
integer(kind=irg)                                :: imin, imax, jmin, jmax
integer(kind=irg)                                :: ii, jj, istat

numk = 0
kk = (/0.D0,0.D0,1.D0/)
thetacr = DtoR*ecpnl%thetac
ktmax = tan(thetacr)
delta = 2.0*ktmax/(float(ecpnl%npix)-1.0)

imin = 1
imax = ecpnl%npix
jmin = 1
jmax = ecpnl%npix

allocate(klist,stat=istat)
if (istat .ne. 0) then
    call FatalError('GetVectorsCone','Failed to allocate klist pointer')
end if

ktmp => klist
nullify(ktmp%next)

do ii = imin, imax
    do jj = jmin, jmax
        ktmp%k(1:3) = (/-ktmax+delta*(ii-1),-ktmax+delta*(jj-1),0.D0/) + kk(1:3)
        ktmp%k = ktmp%k/sqrt(sum(ktmp%k**2))
        ktmp%i = ii
        ktmp%j = jj
        numk = numk + 1
        allocate(ktmp%next)
        ktmp => ktmp%next
        nullify(ktmp%next)
    end do
end do

end subroutine GetVectorsConeSingle

!--------------------------------------------------------------------------
!
! SUBROUTINE:GetVectorsConeZA
!
!> @author Marc De Graef/Saransh Singh, Carnegie Mellon University
!
!> @brief generate list of incident vectors for calculation of single ECP (zone axis case)
!
!> @param ecpnl ECP namelist structure
!> @param klist IncidentListECP pointer
!> @param rotmat rotation matrix for the microscope to grain reference frame
!> @param numk number of incident vectors in the linked list
!
!> @date 10/12/15  SS 1.0 original
!> @date 11/02/15  SS 1.1 changed output image to be ecpnl%npix x ecpnl%npix instead of 2*ecpnl%npix+1
!> @date 04/06/16  SS 1.2 modified for single ECP pattern calculation
!> @date 01/25/17 MDG 1.3 copied from GetVectorsConeSingle for one axis case modification
!--------------------------------------------------------------------------
recursive subroutine GetVectorsConeZA(ecpnl, klist, numk, theta)
!DEC$ ATTRIBUTES DLLEXPORT :: GetVectorsConeZA

use local
use io
use NameListTypedefs
use error

type(ECPZANameListType),INTENT(IN)               :: ecpnl
type(IncidentListECP),pointer                    :: klist, ktmp
integer(kind=irg),INTENT(OUT)                    :: numk
real(kind=sgl),INTENT(IN)                        :: theta

real(kind=dbl)                                   :: kk(3), delta, ktmax
real(kind=dbl),parameter                         :: DtoR = 0.01745329251D0
integer(kind=irg)                                :: imin, imax, jmin, jmax
integer(kind=irg)                                :: ii, jj, istat

numk = 0
kk = (/0.D0,0.D0,1.D0/)
ktmax = tan(theta)
delta = 2.0*ktmax/(float(ecpnl%npix)-1.0)

imin = 1
imax = ecpnl%npix
jmin = 1
jmax = ecpnl%npix

allocate(klist,stat=istat)
if (istat .ne. 0) then
    call FatalError('GetVectorsCone','Failed to allocate klist pointer')
end if

ktmp => klist
nullify(ktmp%next)

do ii = imin, imax
    do jj = jmin, jmax
        ktmp%k(1:3) = (/-ktmax+delta*(ii-1),-ktmax+delta*(jj-1),0.D0/) + kk(1:3)
        ktmp%k = ktmp%k/sqrt(sum(ktmp%k**2))
        ktmp%i = ii
        ktmp%j = jj
        numk = numk + 1
        allocate(ktmp%next)
        ktmp => ktmp%next
        nullify(ktmp%next)
    end do
end do

end subroutine GetVectorsConeZA


!--------------------------------------------------------------------------
!
! SUBROUTINE:ECPreadangles
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief read angles from an angle file
!
!> @param enl ECP name list structure
!> @param quatang array of unit quaternions (output)
!
!> @date 10/12/15  SS 1.0 original
!--------------------------------------------------------------------------
recursive subroutine ECPreadangles(enl,angles,verbose)
!DEC$ ATTRIBUTES DLLEXPORT :: ECPreadangles

use NameListTypedefs
use io
use files
use quaternions
use rotations

IMPLICIT NONE


type(ECPNameListType),INTENT(INOUT)     :: enl
type(ECPAngleType),pointer              :: angles
logical,INTENT(IN),OPTIONAL             :: verbose

integer(kind=irg)                       :: io_int(1), i
character(2)                            :: angletype
real(kind=sgl),allocatable              :: eulang(:,:)   ! euler angle array
real(kind=sgl)                          :: qax(4)        ! axis-angle rotation quaternion

real(kind=sgl),parameter                :: dtor = 0.0174533  ! convert from degrees to radians
integer(kind=irg)                       :: istat
character(fnlen)                        :: anglefile

allocate(angles)
!====================================
! get the angular information, either in Euler angles or in quaternions, from a file
!====================================
! open the angle file 
anglefile = trim(EMsoft_getEMdatapathname())//trim(enl%anglefile)
anglefile = EMsoft_toNativePath(anglefile)

open(unit=dataunit,file=trim(anglefile),status='old',action='read')

! get the type of angle first [ 'eu' or 'qu' ]
read(dataunit,*) angletype
if (angletype.eq.'eu') then 
  enl%anglemode = 'euler'
else
  enl%anglemode = 'quats'
end if

! then the number of angles in the file
read(dataunit,*) enl%numangle_anglefile

if (present(verbose)) then 
  io_int(1) = enl%numangle_anglefile
  call WriteValue(' -> Number of angle entries = ',io_int,1)
end if

if (enl%anglemode.eq.'euler') then
! allocate the euler angle array
  allocate(eulang(3,enl%numangle_anglefile),stat=istat)
! if istat.ne.0 then do some error handling ... 
  do i=1,enl%numangle_anglefile
    read(dataunit,*) eulang(1:3,i)
  end do
  close(unit=dataunit,status='keep')

  if (enl%eulerconvention.eq.'hkl') then
    if (present(verbose)) call Message(' -> converting Euler angles to TSL representation', frm = "(A/)")
    eulang(1,1:enl%numangle_anglefile) = eulang(1,1:enl%numangle_anglefile) + 90.0
  end if

! convert the euler angle triplets to quaternions
  allocate(angles%quatang(4,1:enl%numangle_anglefile),stat=istat)
! if (istat.ne.0) then ...

  if (present(verbose)) call Message(' -> converting Euler angles to quaternions', frm = "(A/)")
  
  do i=1,enl%numangle_anglefile
    angles%quatang(1:4,i) = eu2qu(eulang(1:3,i)*dtor)
  end do

else
! the input file has quaternions, not Euler triplets
  allocate(angles%quatang(4,enl%numangle_anglefile),stat=istat)
  do i=1,enl%numangle_anglefile
    read(dataunit,*) angles%quatang(1:4,i)
  end do
end if

close(unit=dataunit,status='keep')

!====================================
! Do we need to apply an additional axis-angle pair rotation to all the quaternions ?

! commented out for now; needs to be verified


!if (enl%axisangle(4).ne.0.0) then
!  enl%axisangle(4) = enl%axisangle(4) * dtor
!  qax = ax2qu( enl%axisangle )
!  do i=1,enl%numangles_
!    angles%quatang(1:4,i) = quat_mult(qax,angles%quatang(1:4,i))
!  end do 
!end if
call Message(' -> completed reading '//trim(enl%anglefile), frm = "(A)")

end subroutine ECPreadangles

!--------------------------------------------------------------------------
!
! SUBROUTINE:ECPGenerateDetector
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief discretize the annular detector as a set of direction cosines in the 
!> microscope frame
!
!> @param ecpnl ECP name list structure
!> @param master ECPMasterType data type
!
!> @date 10/27/15  SS 1.0 original
!--------------------------------------------------------------------------
recursive subroutine ECPGenerateDetector(ecpnl, master, verbose)
!DEC$ ATTRIBUTES DLLEXPORT :: ECPGenerateDetector

use NameListTypedefs
use io
use error
use files
use quaternions
use rotations
use constants

IMPLICIT NONE

type(ECPNameListType),INTENT(INOUT)     :: ecpnl
type(ECPMasterType),pointer             :: master
logical, INTENT(IN), OPTIONAL           :: verbose

real(kind=sgl)                          :: thetain, thetaout, polar, azimuthal, delpolar, delazimuth
real(kind=sgl)                          :: io_real(2), om(3,3), sampletilt, dc(3)
integer(kind=irg)                       :: iazimuth, ipolar, nazimuth, npolar, istat

if (ecpnl%Rin .gt. ecpnl%Rout) then
    call FatalError('ECPGenerateDetector','Inner radius of annular detector cannot be greater than outer radius')
end if

thetain = atan2(ecpnl%Rin,ecpnl%workingdistance)
thetaout = atan2(ecpnl%Rout,ecpnl%workingdistance)

sampletilt = ecpnl%sampletilt*cPi/180.0
om(1,:) = (/cos(sampletilt),0.0,sin(sampletilt)/)
om(2,:) = (/0.0,1.0,0.0/)
om(3,:) = (/-sin(sampletilt),0.0,cos(sampletilt)/)

if (present(verbose)) then
    if(verbose) then
       io_real(1) = thetain*180.0/cPi
       io_real(2) = thetaout*180.0/cPi
       call WriteValue('Inner and outer polar angles for detector (in degrees) are ',io_real,2)
    end if
end if


npolar = nint((thetaout - thetain)*180.0/cPi) + 1
delpolar = (thetaout - thetain)/float(npolar-1)

nazimuth = 361
delazimuth = 2.0*cPi/float(nazimuth-1)

ecpnl%npolar = npolar
ecpnl%nazimuth = nazimuth

allocate(master%rgx(npolar,nazimuth),master%rgy(npolar,nazimuth),master%rgz(npolar,nazimuth),stat=istat)
if (istat .ne. 0) call FatalError('ECPGenerateDetector','cannot allocate the rgx, rgy and rgz arrays')

master%rgx = 0.0
master%rgy = 0.0
master%rgz = 0.0

! compute the direction cosines of the detector elements in the sample reference frame.
do ipolar = 1,npolar
    polar = thetain + float(ipolar-1)*delpolar

    do iazimuth = 1,nazimuth
         azimuthal = float(iazimuth-1)*delazimuth

         dc(1) = cos(azimuthal)*sin(polar)
         dc(2) = Sin(azimuthal)*sin(polar)
         dc(3) = cos(polar)

         dc = matmul(om,dc)

         master%rgx(ipolar,iazimuth) = dc(1)
         master%rgy(ipolar,iazimuth) = dc(2)
         master%rgz(ipolar,iazimuth) = dc(3)
    end do
end do

if (present(verbose)) then
    if(verbose) then
        call Message(' -> Finished generating detector',frm='(A)')
    end if
end if


end subroutine ECPGenerateDetector

!--------------------------------------------------------------------------
!
! SUBROUTINE:ECPGetWeightFactors
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief calculate the interpolation weight factors 
!
!> @param ecpnl ECP name list structure
!> @param master ECPMasterType data type
!> @param weightfact weightfactor array for different incident angle
!> @param nsig number of sampling points for weightfactors
!
!> @date 10/27/15  SS 1.0 original
!--------------------------------------------------------------------------
recursive subroutine ECPGetWeightFactors(ecpnl, master, acc, weightfact, nsig, verbose)
!DEC$ ATTRIBUTES DLLEXPORT :: ECPGetWeightFactors

use NameListTypedefs
use io
use error
use files
use quaternions
use rotations
use constants
use Lambert

IMPLICIT NONE

type(ECPNameListType),INTENT(INOUT)     :: ecpnl
type(ECPMasterType),pointer             :: master
type(ECPLargeAccumType),pointer         :: acc
real(kind=sgl), INTENT(OUT)             :: weightfact(nsig)
integer(kind=irg), INTENT(IN)           :: nsig
logical, INTENT(IN), OPTIONAL           :: verbose

integer(kind=irg)                       :: isig, ipolar, iazimuth, istat
integer(kind=irg)                       :: nix, niy, nixp, niyp, isampletilt
real(kind=sgl)                          :: dx, dy, dxm, dym, acc_sum, samplenormal(3), dp
real(kind=sgl)                          :: dc(3), ixy(2), scl, deltheta, thetac, x, MCangle
real(kind=dbl),parameter                :: Rtod = 57.2957795131D0

scl = ecpnl%nsx

thetac = ecpnl%thetac
deltheta = (thetac+abs(ecpnl%sampletilt))/float(nsig-1)

weightfact = 0.0

do isig = 1,nsig
    acc_sum = 0.0
    MCangle = (isig - 1)*deltheta
    isampletilt = nint((MCangle - ecpnl%MCsigstart)/ecpnl%MCsigstep)
    
    if (isampletilt .lt. 1) then
        isampletilt = abs(isampletilt) + 1
    else
        isampletilt = isampletilt + 1
    end if
    
    do ipolar = 1,ecpnl%npolar
        do iazimuth = 1,ecpnl%nazimuth
            dc(1:3) = (/master%rgx(ipolar,iazimuth),master%rgy(ipolar,iazimuth),master%rgz(ipolar,iazimuth)/)
! convert to Rosca-lambert projection
            ixy = scl *  LambertSphereToSquare( dc, istat )
            if (istat .ne. 0) call FatalError('ECPGetWeightFactors','Cannot convert to square Lambert projection')
            nix = int(ecpnl%nsx+ixy(1))-ecpnl%nsx
            niy = int(ecpnl%nsy+ixy(2))-ecpnl%nsy
            nixp = nix+1
            niyp = niy+1
            if (nixp.gt.ecpnl%nsx) nixp = nix
            if (niyp.gt.ecpnl%nsy) niyp = niy
            if (nix.lt.-ecpnl%nsx) nix = nixp
            if (niy.lt.-ecpnl%nsy) niy = niyp
            dx = ixy(1)-nix
            dy = ixy(2)-niy
            dxm = 1.0-dx
            dym = 1.0-dy
            
            acc_sum = 0.25*(acc%accum_e(isampletilt,nix,niy) * dxm * dym + &
                            acc%accum_e(isampletilt,nixp,niy) * dx * dym + &
                            acc%accum_e(isampletilt,nix,niyp) * dxm * dy + &
                            acc%accum_e(isampletilt,nixp,niyp) * dx * dy)
             
            weightfact(isig) = weightfact(isig) + acc_sum

        end do
    end do
end do

weightfact(1:nsig) = weightfact(1:nsig)/weightfact(1)

if (present(verbose)) then
    if (verbose) call Message(' -> Finished calculating the weight factors',frm='(A)')
end if

end subroutine ECPGetWeightFactors

!--------------------------------------------------------------------------
!
! SUBROUTINE:ECPIndexingreadMCfile
!
!> @author Marc De Graef/Saransh Singh, Carnegie Mellon University
!
!> @brief read monte carlo file
!
!> @param enl EBSD name list structure
!> @param acc energy structure
!
!> @date 06/24/14  MDG 1.0 original
!> @date 11/18/14  MDG 1.1 removed enl%MCnthreads from file read
!> @date 04/02/15  MDG 2.0 changed program input & output to HDF format
!> @date 04/29/15  MDG 2.1 add optional parameter efile
!> @date 09/15/15  SS  2.2 added accum_z reading 
!> @date 09/15/15  SS  3.0 made part of ECPmod module
!> @date 10/12/15  SS  3.1 changes to handle new mc program; old version of mc file
!>                         not supported anymore
!> @date 01/26/16  SS  3.2 adjusted for ECPIndexing program
!--------------------------------------------------------------------------
recursive subroutine ECPIndexingreadMCfile(enl,acc,efile,verbose,NoHDFInterfaceOpen)
!DEC$ ATTRIBUTES DLLEXPORT :: ECPIndexingreadMCfile

use NameListTypedefs
use files
use io
use HDF5
use HDFsupport
use error

IMPLICIT NONE

type(ECPIndexingNameListType),INTENT(INOUT)     :: enl
type(ECPLargeAccumType),pointer                 :: acc
character(fnlen),INTENT(IN),OPTIONAL            :: efile
logical,INTENT(IN),OPTIONAL                     :: verbose
logical,INTENT(IN),OPTIONAL                     :: NoHDFInterfaceOpen

integer(kind=irg)                               :: istat, hdferr, nlines, nx
logical                                         :: stat, readonly, HDFopen
integer(HSIZE_T)                                :: dims3(3),dims4(4)
character(fnlen)                                :: groupname, dataset, energyfile 
character(fnlen),allocatable                    :: stringarray(:)

integer(kind=irg),allocatable                   :: acc_z(:,:,:,:), acc_e(:,:,:)

type(HDFobjectStackType),pointer                :: HDF_head

! is the efile parameter present? If so, use it as the filename, otherwise use the enl%energyfile parameter
if (PRESENT(efile)) then
  energyfile = efile
else
  energyfile = trim(EMsoft_getEMdatapathname())//trim(enl%energyfile)
end if
energyfile = EMsoft_toNativePath(energyfile)

HDFopen = .TRUE.
if (present(NoHDFInterfaceOpen)) then
  if (NoHDFInterfaceOpen.eqv..FALSE.) HDFopen = .FALSE.
end if 


! allocate(acc)

! first, we need to check whether or not the input file is of the HDF5 format type; if
! it is, we read it accordingly, otherwise we give error. Old format not supported anymore
!
call h5fis_hdf5_f(energyfile, stat, hdferr)

if (stat) then
! open the fortran HDF interface
  if (HDFopen.eqv..TRUE.) call h5open_EMsoft(hdferr)

  nullify(HDF_head)

! open the MC file using the default properties.
  readonly = .TRUE.
  hdferr =  HDF_openFile(energyfile, HDF_head, readonly)

! open the namelist group
  groupname = 'NMLparameters'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'MCCLNameList'
  hdferr = HDF_openGroup(groupname, HDF_head)

! read all the necessary variables from the namelist group
  dataset = 'xtalname'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%MCxtalname = trim(stringarray(1))
  deallocate(stringarray)

  dataset = 'mode'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%MCmode = trim(stringarray(1))
  deallocate(stringarray)

  if(enl%MCmode .ne. 'bse1') then
     call FatalError('ECPreadMCfile','This file is not bse1 mode. Please input correct HDF5 file')
  end if

  dataset = 'numsx'
  call HDF_readDatasetInteger(dataset, HDF_head, hdferr, enl%nsx)
  enl%nsx = (enl%nsx - 1)/2
  enl%nsy = enl%nsx

  dataset = 'EkeV'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%EkeV)

  dataset = 'Ehistmin'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%Ehistmin)

  dataset = 'Ebinsize'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%Ebinsize)

  dataset = 'depthmax'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%depthmax)

  dataset = 'depthstep'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%depthstep)

  dataset = 'sigstart'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%MCsigstart)

  dataset = 'sigend'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%MCsigend)

  dataset = 'sigstep'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%MCsigstep)

  dataset = 'omega'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%MComega)

! close the name list group
  call HDF_pop(HDF_head)
  call HDF_pop(HDF_head)

! read from the EMheader
  groupname = 'EMheader'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'MCOpenCL'
  hdferr = HDF_openGroup(groupname, HDF_head)

  dataset = 'ProgramName'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%MCprogname = trim(stringarray(1))
  deallocate(stringarray)

  dataset = 'Version'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%MCscversion = trim(stringarray(1))
  deallocate(stringarray)

  call HDF_pop(HDF_head)
  call HDF_pop(HDF_head)

! open the Data group
  groupname = 'EMData'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'MCOpenCL'
  hdferr = HDF_openGroup(groupname, HDF_head)

! read data items 
  dataset = 'numangle'
  call HDF_readDatasetInteger(dataset, HDF_head, hdferr, enl%numangle)

  dataset = 'numzbins'
  call HDF_readDatasetInteger(dataset, HDF_head, hdferr, enl%numzbins)

  dataset = 'accum_z'
  call HDF_readDatasetIntegerArray4D(dataset, dims4, HDF_head, hdferr, acc_z)
  allocate(acc%accum_z(1:dims4(1),1:dims4(2),1:dims4(3),1:dims4(4)))
  acc%accum_z = acc_z
  deallocate(acc_z)

  dataset = 'accum_e'
  call HDF_readDatasetIntegerArray3D(dataset, dims3, HDF_head, hdferr, acc_e)
  allocate(acc%accum_e(1:dims3(1),1:dims3(2),1:dims3(3)))
  acc%accum_e = acc_e
  deallocate(acc_e)
 
  enl%num_el = sum(acc%accum_z)

! and close everything
  call HDF_pop(HDF_head,.TRUE.)

! close the fortran HDF interface
  if (HDFopen.eqv..TRUE.) call h5close_EMsoft(hdferr)

else
  call FatalError('ECPreadMCfile','The file is not a h5 file. Old version of MC file not supported anymore!')
end if

if (present(verbose)) then
    if (verbose) call Message(' -> completed reading '//trim(enl%energyfile), frm = "(A)")
end if

end subroutine ECPIndexingreadMCfile

!--------------------------------------------------------------------------
!
! SUBROUTINE:ECPIndexingreadMasterfile
!
!> @author Saransh Singh/Marc De Graef, Carnegie Mellon University
!
!> @brief read EBSD master pattern from file
!
!> @param enl EBSD name list structure
!
!> @date 06/24/14  MDG 1.0 original
!> @date 04/02/15  MDG 2.0 changed program input & output to HDF format
!> @date 09/01/15  MDG 3.0 changed Lambert maps to Northern + Southern maps; lots of changes...
!> @date 09/03/15  MDG 3.1 removed support for old file format (too difficult to maintain after above changes)
!> @date 09/15/15  SS  4.0 modified for ECP master program
!> @date 01/16/16  SS  4.1 adjusted for ECPIndexing program
!--------------------------------------------------------------------------
recursive subroutine ECPIndexingreadMasterfile(enl, master, mfile, verbose, NoHDFInterfaceOpen)
!DEC$ ATTRIBUTES DLLEXPORT :: ECPIndexingreadMasterfile

use NameListTypedefs
use files
use io
use error
use HDF5
use HDFsupport


IMPLICIT NONE

type(ECPIndexingNameListType),INTENT(INOUT)     :: enl
type(ECPMasterType),pointer                     :: master
character(fnlen),INTENT(IN),OPTIONAL            :: mfile
logical,INTENT(IN),OPTIONAL                     :: verbose
logical,INTENT(IN),OPTIONAL                     :: NoHDFInterfaceOpen

real(kind=sgl),allocatable                      :: mLPNH(:,:) 
real(kind=sgl),allocatable                      :: mLPSH(:,:) 
real(kind=sgl),allocatable                      :: EkeVs(:) 
integer(kind=irg),allocatable                   :: atomtype(:)

real(kind=sgl),allocatable                      :: srtmp(:,:,:)
integer(kind=irg)                               :: istat

logical                                         :: stat, readonly, HDFopen
integer(kind=irg)                               :: hdferr, nlines
integer(HSIZE_T)                                :: dims(1), dims3(3)
character(fnlen)                                :: groupname, dataset, masterfile
character(fnlen),allocatable                    :: stringarray(:)

type(HDFobjectStackType),pointer                :: HDF_head

!allocate(master)

HDFopen = .TRUE.
if (present(NoHDFInterfaceOpen)) then
  if (NoHDFInterfaceOpen.eqv..FALSE.) HDFopen = .FALSE.
end if 

! open the fortran HDF interface
if (HDFopen.eqv..TRUE.) call h5open_EMsoft(hdferr)

nullify(HDF_head, HDF_head)

! is the mfile parameter present? If so, use it as the filename, otherwise use the enl%masterfile parameter
if (PRESENT(mfile)) then
  masterfile = mfile
else
  masterfile = trim(EMsoft_getEMdatapathname())//trim(enl%masterfile)
end if
masterfile = EMsoft_toNativePath(masterfile)

! is this a propoer HDF5 file ?
call h5fis_hdf5_f(trim(masterfile), stat, hdferr)

if (stat) then
 
! open the master file 
  readonly = .TRUE.
  hdferr =  HDF_openFile(masterfile, HDF_head, readonly)

! open the namelist group
  groupname = 'NMLparameters'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'ECPMasterNameList'
  hdferr = HDF_openGroup(groupname, HDF_head)

! read all the necessary variables from the namelist group
  dataset = 'energyfile'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%Masterenergyfile = trim(stringarray(1))
  deallocate(stringarray)

  dataset = 'npx'
  call HDF_readDatasetInteger(dataset, HDF_head, hdferr, enl%npx)
  enl%npy = enl%npx

  call HDF_pop(HDF_head)
  call HDF_pop(HDF_head)

  groupname = 'EMData'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'ECPmaster'
  hdferr = HDF_openGroup(groupname, HDF_head)

  dataset = 'EkeV'
  call HDF_readDatasetDouble(dataset, HDF_head, hdferr, enl%EkeV)
  
  dataset = 'numset'
  call HDF_readDatasetInteger(dataset, HDF_head, hdferr, enl%numset)

  dataset = 'mLPNH'
  call HDF_readDatasetFloatArray3D(dataset, dims3, HDF_head, hdferr, srtmp)
  allocate(master%mLPNH(-enl%npx:enl%npx,-enl%npy:enl%npy),stat=istat)
  master%mLPNH = sum(srtmp,3)
  deallocate(srtmp)

  dataset = 'mLPSH'
  call HDF_readDatasetFloatArray3D(dataset, dims3, HDF_head, hdferr, srtmp)
  allocate(master%mLPSH(-enl%npx:enl%npx,-enl%npy:enl%npy),stat=istat)
  master%mLPSH = sum(srtmp,3)
  deallocate(srtmp)

  dataset = 'xtalname'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%Masterxtalname = trim(stringarray(1))
  deallocate(stringarray)

  call HDF_pop(HDF_head)
  call HDF_pop(HDF_head)

  groupname = 'EMheader'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'ECPmaster'
  hdferr = HDF_openGroup(groupname, HDF_head)

  dataset = 'ProgramName'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%Masterprogname = trim(stringarray(1))
  deallocate(stringarray)
  
  dataset = 'Version'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%Masterscversion = trim(stringarray(1))
  deallocate(stringarray)
  
  call HDF_pop(HDF_head,.TRUE.)

! close the fortran HDF interface
  if (HDFopen.eqv..TRUE.) call h5close_EMsoft(hdferr)

else
  masterfile = 'File '//trim(masterfile)//' is not an HDF5 file'
  call FatalError('EBSDreadMasterfile',masterfile)
end if
!====================================

if (present(verbose)) call Message(' -> completed reading '//trim(enl%masterfile), frm = "(A)")

end subroutine ECPIndexingreadMasterfile

!--------------------------------------------------------------------------
!
! SUBROUTINE:GetVectorsConeIndexing
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief generate list of incident vectors for interpolation of ECP
!
!> @param ecpnl ECP namelist structure
!> @param klist IncidentListECP pointer
!> @param rotmat rotation matrix for the microscope to grain reference frame
!> @param numk number of incident vectors in the linked list
!
!> @date 10/12/15  SS 1.0 original
!> @date 11/02/15  SS 1.1 changed output image to be ecpnl%npix x ecpnl%npix instead of 2*ecpnl%npix+1
!> @date 01/26/16  SS 1.2 adjusted for ECPIndexing program
!--------------------------------------------------------------------------
recursive subroutine GetVectorsConeIndexing(ecpnl, klist, numk)
!DEC$ ATTRIBUTES DLLEXPORT :: GetVectorsConeIndexing

use local
use io
use NameListTypedefs
use error

type(ECPIndexingNameListType),INTENT(IN)         :: ecpnl
type(IncidentListECP),pointer                    :: klist, ktmp
integer(kind=irg),INTENT(OUT)                    :: numk

real(kind=dbl)                                   :: kk(3), thetacr, delta, ktmax
real(kind=dbl),parameter                         :: DtoR = 0.01745329251D0
integer(kind=irg)                                :: imin, imax, jmin, jmax
integer(kind=irg)                                :: ii, jj, istat

numk = 0
kk = (/0.D0,0.D0,1.D0/)
thetacr = DtoR*ecpnl%thetac
ktmax = tan(thetacr)
delta = 2.0*ktmax/(float(ecpnl%npix)-1.0)

imin = 1
imax = ecpnl%npix
jmin = 1
jmax = ecpnl%npix

allocate(klist,stat=istat)
if (istat .ne. 0) then
    call FatalError('GetVectorsCone','Failed to allocate klist pointer')
end if

ktmp => klist
nullify(ktmp%next)

do ii = imin, imax
    do jj = jmin, jmax
        ktmp%k(1:3) = (/-ktmax+delta*(ii-1),-ktmax+delta*(jj-1),0.D0/) + kk(1:3)
        ktmp%k = ktmp%k/sqrt(sum(ktmp%k**2))
        ktmp%i = ii
        ktmp%j = jj
        numk = numk + 1
        allocate(ktmp%next)
        ktmp => ktmp%next
        nullify(ktmp%next)
    end do
end do

end subroutine GetVectorsConeIndexing

!--------------------------------------------------------------------------
!
! SUBROUTINE:ECPIndexingGenerateDetector
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief discretize the annular detector as a set of direction cosines in the 
!> microscope frame
!
!> @param ecpnl ECP name list structure
!> @param master ECPMasterType data type
!
!> @date 10/27/15  SS 1.0 original
!> @date 01/26/16  SS 1.1 adjusted for ECPIndexing
!--------------------------------------------------------------------------
recursive subroutine ECPIndexingGenerateDetector(ecpnl, master, verbose)
!DEC$ ATTRIBUTES DLLEXPORT :: ECPIndexingGenerateDetector

use NameListTypedefs
use io
use error
use files
use quaternions
use rotations
use constants

IMPLICIT NONE

type(ECPIndexingNameListType),INTENT(INOUT)     :: ecpnl
type(ECPMasterType),pointer                     :: master
logical, INTENT(IN), OPTIONAL                   :: verbose

real(kind=sgl)                                  :: thetain, thetaout, polar, azimuthal, delpolar, delazimuth
real(kind=sgl)                                  :: io_real(2), om(3,3), sampletilt, dc(3)
integer(kind=irg)                               :: iazimuth, ipolar, nazimuth, npolar, istat

if (ecpnl%Rin .gt. ecpnl%Rout) then
    call FatalError('ECPGenerateDetector','Inner radius of annular detector cannot be greater than outer radius')
end if

thetain = atan2(ecpnl%Rin,ecpnl%workingdistance)
thetaout = atan2(ecpnl%Rout,ecpnl%workingdistance)

sampletilt = ecpnl%sampletilt*cPi/180.0
om(1,:) = (/cos(sampletilt),0.0,sin(sampletilt)/)
om(2,:) = (/0.0,1.0,0.0/)
om(3,:) = (/-sin(sampletilt),0.0,cos(sampletilt)/)

if (present(verbose)) then
    if(verbose) then
       io_real(1) = thetain*180.0/cPi
       io_real(2) = thetaout*180.0/cPi
       call WriteValue('Inner and outer polar angles for detector (in degrees) are ',io_real,2)
    end if
end if


npolar = nint((thetaout - thetain)*180.0/cPi) + 1
delpolar = (thetaout - thetain)/float(npolar-1)

nazimuth = 361
delazimuth = 2.0*cPi/float(nazimuth-1)

ecpnl%npolar = npolar
ecpnl%nazimuth = nazimuth

allocate(master%rgx(npolar,nazimuth),master%rgy(npolar,nazimuth),master%rgz(npolar,nazimuth),stat=istat)
if (istat .ne. 0) call FatalError('ECPGenerateDetector','cannot allocate the rgx, rgy and rgz arrays')

master%rgx = 0.0
master%rgy = 0.0
master%rgz = 0.0

! compute the direction cosines of the detector elements in the sample reference frame.
do ipolar = 1,npolar
    polar = thetain + float(ipolar-1)*delpolar

    do iazimuth = 1,nazimuth
         azimuthal = float(iazimuth-1)*delazimuth

         dc(1) = cos(azimuthal)*sin(polar)
         dc(2) = Sin(azimuthal)*sin(polar)
         dc(3) = cos(polar)

         dc = matmul(om,dc)

         master%rgx(ipolar,iazimuth) = dc(1)
         master%rgy(ipolar,iazimuth) = dc(2)
         master%rgz(ipolar,iazimuth) = dc(3)
    end do
end do

if (present(verbose)) then
    if(verbose) then
        call Message(' -> Finished generating detector',frm='(A)')
    end if
end if


end subroutine ECPIndexingGenerateDetector

!--------------------------------------------------------------------------
!
! SUBROUTINE:ECPIndexingGetWeightFactors
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief calculate the interpolation weight factors 
!
!> @param ecpnl ECP name list structure
!> @param master ECPMasterType data type
!> @param weightfact weightfactor array for different incident angle
!> @param nsig number of sampling points for weightfactors
!
!> @date 10/27/15  SS 1.0 original
!> @date 01/26/16  SS 1.1 adjusted for ECPIndexing
!--------------------------------------------------------------------------
recursive subroutine ECPIndexingGetWeightFactors(ecpnl, master, acc, weightfact, nsig, verbose)
!DEC$ ATTRIBUTES DLLEXPORT :: ECPIndexingGetWeightFactors

use NameListTypedefs
use io
use error
use files
use quaternions
use rotations
use constants
use Lambert

IMPLICIT NONE

type(ECPIndexingNameListType),INTENT(INOUT)     :: ecpnl
type(ECPMasterType),pointer                     :: master
type(ECPLargeAccumType),pointer                 :: acc
real(kind=sgl), INTENT(OUT)                     :: weightfact(nsig)
integer(kind=irg), INTENT(IN)                   :: nsig
logical, INTENT(IN), OPTIONAL                   :: verbose
 
integer(kind=irg)                               :: isig, ipolar, iazimuth, istat
integer(kind=irg)                               :: nix, niy, nixp, niyp, isampletilt
real(kind=sgl)                                  :: dx, dy, dxm, dym, acc_sum, samplenormal(3), dp
real(kind=sgl)                                  :: dc(3), ixy(2), scl, deltheta, thetac, x, MCangle
real(kind=dbl),parameter                        :: Rtod = 57.2957795131D0

scl = ecpnl%nsx

thetac = ecpnl%thetac
deltheta = (thetac+abs(ecpnl%sampletilt))/float(nsig-1)

weightfact = 0.0

do isig = 1,nsig
    acc_sum = 0.0
    MCangle = (isig - 1)*deltheta
    isampletilt = nint((MCangle - ecpnl%MCsigstart)/ecpnl%MCsigstep)
    
    if (isampletilt .lt. 1) then
        isampletilt = abs(isampletilt) + 1
    else
        isampletilt = isampletilt + 1
    end if
    
    do ipolar = 1,ecpnl%npolar
        do iazimuth = 1,ecpnl%nazimuth
            dc(1:3) = (/master%rgx(ipolar,iazimuth),master%rgy(ipolar,iazimuth),master%rgz(ipolar,iazimuth)/)
! convert to Rosca-lambert projection
            ixy = scl *  LambertSphereToSquare( dc, istat )
            if (istat .ne. 0) call FatalError('ECPGetWeightFactors','Cannot convert to square Lambert projection')
            nix = int(ecpnl%nsx+ixy(1))-ecpnl%nsx
            niy = int(ecpnl%nsy+ixy(2))-ecpnl%nsy
            nixp = nix+1
            niyp = niy+1
            if (nixp.gt.ecpnl%nsx) nixp = nix
            if (niyp.gt.ecpnl%nsy) niyp = niy
            if (nix.lt.-ecpnl%nsx) nix = nixp
            if (niy.lt.-ecpnl%nsy) niy = niyp
            dx = ixy(1)-nix
            dy = ixy(2)-niy
            dxm = 1.0-dx
            dym = 1.0-dy
            
            acc_sum = 0.25*(acc%accum_e(isampletilt,nix,niy) * dxm * dym + &
                            acc%accum_e(isampletilt,nixp,niy) * dx * dym + &
                            acc%accum_e(isampletilt,nix,niyp) * dxm * dy + &
                            acc%accum_e(isampletilt,nixp,niyp) * dx * dy)
             
            weightfact(isig) = weightfact(isig) + acc_sum

        end do
    end do
end do

weightfact(1:nsig) = weightfact(1:nsig)/weightfact(1)

if (present(verbose)) then
    if (verbose) call Message(' -> Finished calculating the weight factors',frm='(A)')
end if

end subroutine ECPIndexingGetWeightFactors

!--------------------------------------------------------------------------
!
! FUNCTION:GetPointGroup
!
!> @author Marc De Graef, Carnegie Mellon University
!
!> @brief read the .xtal file and return the point group number
!
!> @param xtalname name of .xtal file
!> @param NoHDFInterfaceOpen (optional) prevents hdf interface form being opened/closed
!
!> @date 01/26/16 MDG 1.0 original version
!> @date 01/26/16 SS  1.1 corrected path; changed name
!--------------------------------------------------------------------------
recursive function GetPointGroup(xtalname,NoHDFInterfaceOpen) result(pgnum) &
bind(c, name = 'GetPointGroup')
!DEC$ ATTRIBUTES DLLEXPORT :: GetPointGroup

! use typedefs
use error
use HDFsupport
use HDF5

IMPLICIT NONE

character(1),dimension(fnlen),INTENT(IN)    :: xtalname
logical,OPTIONAL,INTENT(IN)                 :: NoHDFInterfaceOpen
integer(kind=irg)                           :: pgnum

character(fnlen)                        :: filename, xtalname2
character(1)                            :: rchar
integer(kind=irg)                       :: hdferr, sgnum, i
logical                                 :: stat, readonly, HDFopen
character(fnlen)                        :: groupname, dataset

type(HDFobjectStackType),pointer        :: HDF_head

HDFopen = .TRUE.
if (present(NoHDFInterfaceOpen)) then
  if (NoHDFInterfaceOpen.eqv..FALSE.) HDFopen = .FALSE.
end if 

xtalname2 = ''
do i = 1,fnlen
    rchar = xtalname(i)
    xtalname2 = trim(xtalname2)//rchar
end do


! test to make sure the input file exists and is HDF5 format
filename = trim(EMsoft_getXtalpathname())//trim(xtalname2)
filename = EMsoft_toNativePath(filename)

stat = .FALSE.

call h5fis_hdf5_f(filename, stat, hdferr)
if (stat) then
! open the fortran HDF interface
  if (HDFopen.eqv..TRUE.) call h5open_EMsoft(hdferr)

  nullify(HDF_head)

! open the xtal file using the default properties.
  readonly = .TRUE.
  hdferr =  HDF_openFile(filename, HDF_head, readonly)

! open the namelist group
  groupname = 'CrystalData'
  hdferr = HDF_openGroup(groupname, HDF_head)

! read the space group number from the file
  dataset = 'SpaceGroupNumber'
  call HDF_readDatasetInteger(dataset, HDF_head, hdferr, sgnum)

! and close everything
  call HDF_pop(HDF_head,.TRUE.)

! close the fortran HDF interface
  if (HDFopen.eqv..TRUE.) call h5close_EMsoft(hdferr)

! and convert the space group number into a point group number
  pgnum = 0
  do i=1,32
    if (SGPG(i).le.sgnum) pgnum = i
  end do
else
  pgnum = 0
  call FatalError('GetPointGroup','Error reading xtal file '//trim(filename))
end if

end function GetPointGroup

!--------------------------------------------------------------------------
!
! SUBROUTINE:ECPkinematicreadMasterfile
!
!> @author Saransh Singh/Marc De Graef, Carnegie Mellon University
!
!> @brief read EBSD master pattern from file
!
!> @param enl EBSD name list structure
!
!> @date 11/22/16  SS 1.0 original
!--------------------------------------------------------------------------
recursive subroutine ECPkinematicreadMasterfile(enl, master, mfile, verbose)
!DEC$ ATTRIBUTES DLLEXPORT :: ECPkinematicreadMasterfile

use NameListTypedefs
use files
use io
use error
use HDF5
use HDFsupport


IMPLICIT NONE

type(ECPNameListType),INTENT(INOUT)     :: enl
type(ECPMasterType),pointer             :: master
character(fnlen),INTENT(IN),OPTIONAL    :: mfile
logical,INTENT(IN),OPTIONAL             :: verbose

real(kind=sgl),allocatable              :: mLPNH(:,:) 
real(kind=sgl),allocatable              :: mLPSH(:,:) 
real(kind=sgl)                          :: voltage
integer(kind=irg),allocatable           :: atomtype(:)

real(kind=sgl),allocatable              :: srtmp(:,:,:)
integer(kind=irg)                       :: istat

logical                                 :: stat, readonly
integer(kind=irg)                       :: hdferr, nlines
integer(HSIZE_T)                        :: dims(1), dims2(2)
character(fnlen)                        :: groupname, dataset, masterfile
character(fnlen),allocatable            :: stringarray(:)

type(HDFobjectStackType),pointer        :: HDF_head

allocate(master)

! open the fortran HDF interface
call h5open_EMsoft(hdferr)

nullify(HDF_head, HDF_head)

! is the mfile parameter present? If so, use it as the filename, otherwise use the enl%masterfile parameter
if (PRESENT(mfile)) then
  masterfile = mfile
else
  masterfile = trim(EMsoft_getEMdatapathname())//trim(enl%masterfile)
end if
masterfile = EMsoft_toNativePath(masterfile)

! is this a propoer HDF5 file ?
call h5fis_hdf5_f(trim(masterfile), stat, hdferr)

if (stat) then 
! open the master file 
  readonly = .TRUE.
  hdferr =  HDF_openFile(masterfile, HDF_head, readonly)

! open the namelist group
  groupname = 'NMLparameters'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'EMkinematicalNameList'
  hdferr = HDF_openGroup(groupname, HDF_head)

  dataset = 'voltage'
  call HDF_readDatasetfloat(dataset, HDF_head, hdferr, voltage)
  enl%Ekev = dble(voltage) 

  dataset = 'xtalname'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%Masterxtalname = trim(stringarray(1))
  deallocate(stringarray)

  dataset = 'dmin'
  call HDF_readDatasetfloat(dataset, HDF_head, hdferr, enl%dmin)

  call HDF_pop(HDF_head)
  call HDF_pop(HDF_head)

  groupname = 'EMData'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'EMkinematical'
  hdferr = HDF_openGroup(groupname, HDF_head)

  dataset = 'masterNH'
  call HDF_readDatasetFloatArray2D(dataset, dims2, HDF_head, hdferr, master%mLPNH)
  !allocate(master%mLPNH(-enl%npx:enl%npx,-enl%npy:enl%npy),stat=istat)

  dataset = 'masterSH'
  call HDF_readDatasetFloatArray2D(dataset, dims2, HDF_head, hdferr, master%mLPSH)
  !allocate(master%mLPSH(-enl%npx:enl%npx,-enl%npy:enl%npy),stat=istat)

  enl%npx = (dims2(1) - 1)/2
  enl%npy = enl%npx

  call HDF_pop(HDF_head)
  call HDF_pop(HDF_head)

  groupname = 'EMheader'
  hdferr = HDF_openGroup(groupname, HDF_head)

  groupname = 'EMkinematical'
  hdferr = HDF_openGroup(groupname, HDF_head)

  dataset = 'ProgramName'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%Masterprogname = trim(stringarray(1))
  deallocate(stringarray)
  
  dataset = 'Version'
  call HDF_readDatasetStringArray(dataset, nlines, HDF_head, hdferr, stringarray)
  enl%Masterscversion = trim(stringarray(1))
  deallocate(stringarray)
  
  call HDF_pop(HDF_head,.TRUE.)

! close the fortran HDF interface
  call h5close_EMsoft(hdferr)

else
  masterfile = 'File '//trim(masterfile)//' is not an HDF5 file'
  call FatalError('ECPreadMasterfile',masterfile)
end if
!====================================

if (present(verbose)) call Message(' -> completed reading '//trim(enl%masterfile), frm = "(A)")

end subroutine ECPkinematicreadMasterfile

!--------------------------------------------------------------------------
!
! SUBROUTINE: CalcECPatternSingleFull
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief compute a single ECP pattern, used in EMFitOrientations
!
!> @param ebsdnl ECP namelist
!
!> @date 03/17/17 SS 1.0 original
!--------------------------------------------------------------------------
recursive subroutine CalcECPatternSingleFull(ipar,qu,accum,mLPNH,mLPSH,rgx,rgy,rgz,binned,mask)
!DEC$ ATTRIBUTES DLLEXPORT :: CalcECPatternSingleFull

use local
use typedefs
use NameListTypedefs
use NameListHDFwriters
use symmetry
use crystal
use constants
use io
use files
use diffraction
use Lambert
use quaternions
use rotations

IMPLICIT NONE

integer(kind=irg),INTENT(IN)                    :: ipar(7)
real(kind=sgl),INTENT(IN)                       :: qu(4) 
real(kind=sgl),INTENT(IN)                       :: accum(ipar(6),ipar(2),ipar(3))
real(kind=sgl),INTENT(IN)                       :: mLPNH(-ipar(4):ipar(4),-ipar(5):ipar(5),ipar(7))
real(kind=sgl),INTENT(IN)                       :: mLPSH(-ipar(4):ipar(4),-ipar(5):ipar(5),ipar(7))
real(kind=sgl),INTENT(IN)                       :: rgx(ipar(2),ipar(3))
real(kind=sgl),INTENT(IN)                       :: rgy(ipar(2),ipar(3))
real(kind=sgl),INTENT(IN)                       :: rgz(ipar(2),ipar(3))
real(kind=sgl),INTENT(OUT)                      :: binned(ipar(2),ipar(3))
real(kind=sgl),INTENT(IN)                       :: mask(ipar(2),ipar(3))

real(kind=sgl),allocatable                      :: ECpattern(:,:)
real(kind=sgl),allocatable                      :: wf(:)
real(kind=sgl)                                  :: dc(3),ixy(2),scl,bindx
real(kind=sgl)                                  :: dx,dy,dxm,dym
integer(kind=irg)                               :: ii,jj,kk,istat
integer(kind=irg)                               :: nix,niy,nixp,niyp


! ipar(1) = binning (== 1)
! ipar(2) = ebsdnl%npix
! ipar(3) = ebsdnl%npix
! ipar(4) = ebsdnl%npx
! ipar(5) = ebsdnl%npy
! ipar(6) = 1
! ipar(7) = 1


allocate(ECpattern(ipar(2),ipar(3)),stat=istat)

binned = 0.0
ECpattern = 0.0

scl = float(ipar(4)) 

do ii = 1,ipar(2)
    do jj = 1,ipar(3)

        dc = sngl(quat_Lp(qu(1:4),  (/ rgx(ii,jj),rgy(ii,jj),rgz(ii,jj) /) ))

        dc = dc/sqrt(sum(dc**2))
        
! convert these direction cosines to coordinates in the Rosca-Lambert projection
        ixy = scl * LambertSphereToSquare( dc, istat )
        if (istat .ne. 0) stop 'Something went wrong during interpolation...'
! four-point interpolation (bi-quadratic)
        nix = int(ipar(4)+ixy(1))-ipar(4)
        niy = int(ipar(5)+ixy(2))-ipar(5)
        nixp = nix+1
        niyp = niy+1
        if (nixp.gt.ipar(4)) nixp = nix
        if (niyp.gt.ipar(5)) niyp = niy
        if (nix.lt.-ipar(4)) nix = nixp
        if (niy.lt.-ipar(5)) niy = niyp
        dx = ixy(1)-nix
        dy = ixy(2)-niy
        dxm = 1.0-dx
        dym = 1.0-dy
! interpolate the intensity
        if (dc(3) .ge. 0.0) then
                ECpattern(ii,jj) = ECpattern(ii,jj) + accum(1,ii,jj) * ( mLPNH(nix,niy,1) * dxm * dym + &
                                               mLPNH(nixp,niy,1) * dx * dym + mLPNH(nix,niyp,1) * dxm * dy + &
                                               mLPNH(nixp,niyp,1) * dx * dy )
        else
                ECpattern(ii,jj) = ECpattern(ii,jj) + accum(1,ii,jj) * ( mLPSH(nix,niy,1) * dxm * dym + &
                                               mLPSH(nixp,niy,1) * dx * dym + mLPSH(nix,niyp,1) * dxm * dy + &
                                               mLPSH(nixp,niyp,1) * dx * dy )
        end if
    end do
end do

binned = ECpattern * mask

end subroutine CalcECPatternSingleFull


end module ECPmod

