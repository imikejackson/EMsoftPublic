! ###################################################################
! Copyright (c) 2016, Marc De Graef Research Group/Carnegie Mellon University
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
! EMsoft:EBSDiomod.f90
!--------------------------------------------------------------------------
!
! MODULE: support routines for EBSD output files in .ang (TSL) and .ctf (HKL) formats
!
!> @author Marc De Graef, Carnegie Mellon University
!
!> @date 3/10/16 MDG 1.0 reorganization of a few existing routines
!--------------------------------------------------------------------------
module EBSDiomod

use local

IMPLICIT NONE

contains

!--------------------------------------------------------------------------
!
! SUBROUTINE:ctfebsd_writeFile
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief Write a *.ctf output file with EBSD data (HKL format)
!
!> @param ebsdnl namelist
!> @param ipar  series of integer dimensions
!> @param indexmain indices into the main Euler array
!> @param eulerarray array of Euler angle triplets
!> @param resultmain dot product array
!
!> @date 02/07/15  SS 1.0 original
!> @date 03/10/16 MDG 1.1 moved from program to module and updated [TO BE COMPLETED]
!> @date 06/05/16 MDG 1.2 added reading of xtal file for correct crystallography output; corrected Euler angles for hkl convention
!> @date 06/05/16 MDG 1.3 added sampling step sizes
!> @date 06/25/16 MDG 1.4 added noindex optional keyword
!> @date 07/10/16 MDG 1.5 swapped Error, MAD, and BC columns
!--------------------------------------------------------------------------
recursive subroutine ctfebsd_writeFile(ebsdnl,ipar,indexmain,eulerarray,resultmain,noindex)
!DEC$ ATTRIBUTES DLLEXPORT :: ctfebsd_writeFile

use NameListTypedefs
use HDF5
use HDFsupport
use typedefs
use error

IMPLICIT NONE

type(EBSDIndexingNameListType),INTENT(INOUT)        :: ebsdnl
integer(kind=irg),INTENT(IN)                        :: ipar(10)
integer(kind=irg),INTENT(IN)                        :: indexmain(ipar(1),ipar(2))
real(kind=sgl),INTENT(IN)                           :: eulerarray(3,ipar(4))
real(kind=sgl),INTENT(IN)                           :: resultmain(ipar(1),ipar(2))
logical,INTENT(IN),OPTIONAL                         :: noindex

integer(kind=irg)                                   :: ierr, i, ii, indx, hdferr, SGnum, LaueGroup
character(fnlen)                                    :: ctfname
character                                           :: TAB = CHAR(9)
character(fnlen)                                    :: str1,str2,str3,str4,str5,str6,str7,str8,str9,str10,filename,grname,dataset
real(kind=sgl)                                      :: euler(3)
logical                                             :: stat, readonly, donotuseindexarray
integer(HSIZE_T)                                    :: dims(1)
real(kind=dbl),allocatable                          :: cellparams(:)

type(HDFobjectStackType),pointer                    :: HDF_head_local

donotuseindexarray = .FALSE.
if (present(noindex)) then
  if (noindex.eqv..TRUE.) then 
    donotuseindexarray = .TRUE.
  end if
end if

! open the file (overwrite old one if it exists)
ctfname = trim(EMsoft_getEMdatapathname())//trim(ebsdnl%ctffile)
ctfname = EMsoft_toNativePath(ctfname)
open(unit=dataunit2,file=trim(ctfname),status='unknown',action='write',iostat=ierr)

write(dataunit2,'(A)'),'Channel Text File'
write(dataunit2,'(A)'),'Prj Test'
write(dataunit2,'(A)'),'Author	'//trim(EMsoft_getUsername())
write(dataunit2,'(A)'),'JobMode	Grid'
write(dataunit2,'(2A,I5)'),'XCells',TAB, ebsdnl%ipf_wd
write(dataunit2,'(2A,I5)'),'YCells',TAB, ebsdnl%ipf_ht
write(dataunit2,'(2A,F6.2)'),'XStep',TAB, ebsdnl%StepX
write(dataunit2,'(2A,F6.2)'),'YStep',TAB, ebsdnl%StepY
write(dataunit2,'(A)'),'AcqE1	0'
write(dataunit2,'(A)'),'AcqE2	0'
write(dataunit2,'(A)'),'AcqE3	0'
write(dataunit2,'(A,A,$)'),'Euler angles refer to Sample Coordinate system (CS0)!',TAB
str1 = 'Mag	30	Coverage	100	Device	0	KV'
write(str2,'(F4.1)') ebsdnl%EkeV
str1 = trim(str1)//TAB//trim(str2)//TAB//'TiltAngle'
write(str2,'(F5.2)') ebsdnl%MCsig
str2 = adjustl(str2)
str1 = trim(str1)//TAB//trim(str2)//TAB//'TiltAxis	0'
write(dataunit2,'(A)') trim(str1)
!write(dataunit2,'(A)')'Mag	30	Coverage	100	Device	0	KV	288.9	TiltAngle	-1	TiltAxis	0'
write(dataunit2,'(A)'),'Phases	1'

! here we need to read the .xtal file and extract the lattice parameters, Laue group and space group numbers
! test to make sure the input file exists and is HDF5 format
filename = trim(EMsoft_getXtalpathname())//trim(ebsdnl%MCxtalname)
filename = EMsoft_toNativePath(filename)

stat = .FALSE.

call h5fis_hdf5_f(filename, stat, hdferr)
nullify(HDF_head_local)


if (stat) then

! open the xtal file using the default properties.
  readonly = .TRUE.
  hdferr =  HDF_openFile(filename, HDF_head_local, readonly)

! open the namelist group
  grname = 'CrystalData'
  hdferr = HDF_openGroup(grname, HDF_head_local)

! get the spacegroupnumber
  dataset = 'SpaceGroupNumber'
  call HDF_readDatasetInteger(dataset, HDF_head_local, hdferr, SGnum)

! get the lattice parameters
  dataset = 'LatticeParameters'
  call HDF_readDatasetDoubleArray1D(dataset, dims, HDF_head_local, hdferr, cellparams) 

! and close the xtal file
  call HDF_pop(HDF_head_local,.TRUE.)
else
  call FatalError('ctfebsd_writeFile','Error reading xtal file '//trim(filename))
end if

! unit cell size
cellparams(1:3) = cellparams(1:3)*10.0  ! convert to Angstrom
write(str1,'(F8.3)') cellparams(1)
write(str2,'(F8.3)') cellparams(2)
write(str3,'(F8.3)') cellparams(3)
str1 = adjustl(str1)
str2 = adjustl(str2)
str3 = adjustl(str3)
str1 = trim(str1)//';'//trim(str2)//';'//trim(str3)

! unit cell angles
write(str4,'(F8.3)') cellparams(4)
write(str5,'(F8.3)') cellparams(5)
write(str6,'(F8.3)') cellparams(6)
str4 = adjustl(str5)
str5 = adjustl(str5)
str6 = adjustl(str6)
str1 = trim(str1)//TAB//trim(str4)//';'//trim(str5)//';'//trim(str6)

! structure name
str3 = ''
ii = len(trim(ebsdnl%MCxtalname))-5
do i=1,ii
  str3(i:i) = ebsdnl%MCxtalname(i:i)
end do
str1 = trim(str1)//TAB//trim(str3)

! rotational symmetry group
if (SGnum.ge.221) then
  i = 32
else
  i=1
  do while (SGPG(i).lt.SGnum) 
    i = i+1
  end do
end if
str4 = ''
LaueGroup = PGLaueinv(i)
write(str4,'(I2)') LaueGroup
str1 = trim(str1)//TAB//trim(adjustl(str4))

! space group
str2 = ''
write(str2,'(I3)') SGnum
str1 = trim(str1)//TAB//trim(adjustl(str2))

! and now collect them all into a single string
write(dataunit2,'(A)') str1

! write(dataunit2,'(A)'),'3.524;3.524;3.524	90;90;90	Nickel	11	225'

! this is the table header
write(dataunit2,'(A)'),'Phase	X	Y	Bands	Error	Euler1	Euler2	Euler3	MAD	BC	BS'

! go through the entire array and write one line per sampling point
do ii = 1,ipar(3)
    if (donotuseindexarray.eqv..TRUE.) then
      indx = 0
      euler = eulerarray(1:3,ii)
    else
      indx = indexmain(1,ii)
      euler = eulerarray(1:3,indx)
    end if
! changed order of coordinates to conform with ctf standard
    write(str2,'(F12.3)') float(floor(float(ii-1)/float(ebsdnl%ipf_wd)))*ebsdnl%stepX
    write(str1,'(F12.3)') float(MODULO(ii-1,ebsdnl%ipf_wd))*ebsdnl%stepY
    write(str3,'(I2)') 10
    write(str8,'(I8)') 0 ! integer zero error; was indx, which is now moved to BC
    write(str5,'(F12.3)') euler(1) - 90.0  ! conversion from TSL to Oxford convention
    write(str6,'(F12.3)') euler(2)
! intercept the hexagonal case, for which we need to subtract 30° from the third Euler angle
    if ((LaueGroup.eq.8).or.(LaueGroup.eq.9)) euler(3) = euler(3) - 30.0
    write(str7,'(F12.3)') euler(3)
    write(str4,'(F12.6)') resultmain(1,ii)   ! this replaces MAD
! the following two parameters need to be modified to contain more meaningful information
    write(str9,'(I8)') indx   ! index into the dictionary list
    write(str10,'(I8)') 255
! Oxford 3D files have four additional integer columns;
! GrainIndex
! GrainRandomColourR
! GrainRandomColourG
! GrainRandomColourB
!
    write(dataunit2,'(A,A,A,A,A,A,A,A,A,A,A,A,A,A,A,A,A,A,A,A,A)')'1',TAB,trim(adjustl(str1)),TAB,&
    trim(adjustl(str2)),TAB,trim(adjustl(str3)),TAB,trim(adjustl(str8)),TAB,trim(adjustl(str5)),&
    TAB,trim(adjustl(str6)),TAB,trim(adjustl(str7)),TAB,trim(adjustl(str4)),TAB,trim(adjustl(str9)),&
    TAB,trim(adjustl(str10))
end do

close(dataunit2,status='keep')

end subroutine ctfebsd_writeFile

!--------------------------------------------------------------------------
!
! SUBROUTINE:angebsd_writeFile
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief Write a *.ang output file with EBSD data (TSL format)
!
!> @param ebsdnl namelist
!> @param ipar  series of integer dimensions
!> @param indexmain indices into the main Euler array
!> @param eulerarray array of Euler angle triplets
!> @param resultmain dot product array
!
!> @date 02/07/15  SS 1.0 original
!> @date 03/10/16 MDG 1.1 moved from program to module and updated [TO BE COMPLETED]
!--------------------------------------------------------------------------
recursive subroutine angebsd_writeFile(ebsdnl,ipar,indexmain,eulerarray,resultmain)
!DEC$ ATTRIBUTES DLLEXPORT :: angebsd_writeFile

use NameListTypedefs

IMPLICIT NONE

type(EBSDIndexingNameListType),INTENT(INOUT)        :: ebsdnl
integer(kind=irg),INTENT(IN)                        :: ipar(10)
integer(kind=irg),INTENT(IN)                        :: indexmain(ipar(1),ipar(2))
real(kind=sgl),INTENT(IN)                           :: eulerarray(3,ipar(4))
real(kind=sgl),INTENT(IN)                           :: resultmain(ipar(1),ipar(2))

integer(kind=irg)                                   :: ierr, ii, indx
character(fnlen)                                    :: angname
character                                           :: TAB = CHAR(9)
real(kind=sgl)                                      :: euler(3), s

! open the file (overwrite old one if it exists)
angname = trim(EMsoft_getEMdatapathname())//trim(ebsdnl%angfile)
angname = EMsoft_toNativePath(angname)
open(unit=dataunit2,file=trim(angname),status='unknown',action='write',iostat=ierr)

! this requires a lot of information...
write(dataunit2,'(A)'),'# TEM_PIXperUM          1.000000'
s = ( float(ebsdnl%numsx)*0.5 + ebsdnl%xpc ) / float(ebsdnl%numsx)      ! x-star
write(dataunit2,'(A,F9.6)'),'# x-star                ', s
s = ( float(ebsdnl%numsy)*0.5 + ebsdnl%ypc ) / float(ebsdnl%numsy)      ! y-star
write(dataunit2,'(A,F9.6)'),'# y-star                ', s
s = ebsdnl%L / ( ebsdnl%delta * float(ebsdnl%numsx) )                   ! z-star
write(dataunit2,'(A,F9.6)'),'# z-star                ', s 
write(dataunit2,'(A,F9.6)'),'# WorkingDistance       ', ebsdnl%WD
write(dataunit2,'(A)'),'#'
write(dataunit2,'(A)'),'# Phase 1'

ii = scan(trim(ebsdnl%MCxtalname),'.')
angname = ebsdnl%MCxtalname(1:ii-1)
write(dataunit2,'(A)'),'# MaterialName  	',trim(angname)
write(dataunit2,'(A)'),'# Formula     	',trim(angname)
write(dataunit2,'(A)'),'# Info          indexed using EMsoft::EMEBSDDictionaryIndexing'


write(dataunit2,'(A)'),'# Symmetry              43'
write(dataunit2,'(A)'),'# LatticeConstants      3.520 3.520 3.520  90.000  90.000  90.000'

write(dataunit2,'(A)'),'# NumberFamilies        4'
write(dataunit2,'(A)'),'# hklFamilies   	 1  1  1 1 0.000000'
write(dataunit2,'(A)'),'# hklFamilies   	 2  0  0 1 0.000000'
write(dataunit2,'(A)'),'# hklFamilies   	 2  2  0 1 0.000000'
write(dataunit2,'(A)'),'# hklFamilies   	 3  1  1 1 0.000000'
write(dataunit2,'(A)'),'# Categories 0 0 0 0 0'
write(dataunit2,'(A)'),'#'
write(dataunit2,'(A)'),'# GRID: SqrGrid'
write(dataunit2,'(A,F9.6)'),'# XSTEP: ', ebsdnl%StepX
write(dataunit2,'(A,F9.6)'),'# YSTEP: ', ebsdnl%StepY
write(dataunit2,'(A,I5)'),'# NCOLS_ODD: ',ebsdnl%ipf_wd
write(dataunit2,'(A,I5)'),'# NCOLS_EVEN: ',ebsdnl%ipf_wd
write(dataunit2,'(A,I5)'),'# NROWS: ', ebsdnl%ipf_ht
write(dataunit2,'(A)'),'#'
write(dataunit2,'(A,A)'),'# OPERATOR: 	', trim(EMsoft_getUsername())
write(dataunit2,'(A)'),'#'
write(dataunit2,'(A)'),'# SAMPLEID:'
write(dataunit2,'(A)'),'#'
write(dataunit2,'(A)'),'# SCANID:'
write(dataunit2,'(A)'),'#'

! to be written !!!




close(dataunit2,status='keep')

end subroutine angebsd_writeFile




end module EBSDiomod
