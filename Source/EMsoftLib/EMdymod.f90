! ###################################################################
! Copyright (c) 2013-2016, Marc De Graef/Carnegie Mellon University
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
! EMsoft:EMdymod.f90
!--------------------------------------------------------------------------
!
! MODULE: EMdymod
!
!> @author Marc De Graef, Carnegie Mellon University
!
!> @brief routines that can be called by external code; all routines requiring HDF are in EMdymodHDF.f90
!
!> @date  10/16/15 MDG 1.0 original
!> @date  01/11/16 MDG 2.0 split into this file and EMdymodHDF.f90
!> @date  01/12/16 MDG 2.1 added functionality for DREAM.3D progress callback and cancel option
!> @date  01/13/16 MDG 2.2 name change of SingleEBSDPattern routine and split into two versions (C and other)
!> @date  01/14/16 MDG 2.3 added EMsoftCgetECPatterns routine
!> @date  01/25/16 MDG 2.4 several routine name changes
!> @date  04/28/16 MDG 2.5 unified the ipar and fpar arrays for all C-callable routines
!--------------------------------------------------------------------------
!
! general information: the ipar and fpar arrays for all the routines that are C-callable
! are identical, so we document here their component definitions; to allow for future expansion, each
! array has 40 entries, of which about half are currently (April 2016) used.
!
! integer(kind=irg) :: ipar(40)  components 
! ipar(1) : nx  = (numsx-1)/2
! ipar(2) : globalworkgrpsz
! ipar(3) : num_el
! ipar(4) : totnum_el
! ipar(5) : multiplier
! ipar(6) : devid
! ipar(7) : platid
! ipar(8) : CrystalSystem
! ipar(9) : Natomtypes
! ipar(10): SpaceGroupNumber
! ipar(11): SpaceGroupSetting
! ipar(12): numEbins
! ipar(13): numzbins
! ipar(14): mcmode  ( 1 = 'full', 2 = 'bse1' )
! ipar(15): numangle
! ipar(16): nxten = nx/10
! the following are only used in the master routine
! ipar(17): npx
! ipar(18): nthreads
! the following are only used in the EBSD pattern routine
! ipar(19): numx of detector pixels
! ipar(20): numy of detector pixels
! ipar(21): number of orientation in quaternion set
! ipar(22): binning factor (0-3)
! ipar(23): binned x-dimension
! ipar(24): binned y-dimension
! ipar(25): anglemode  (0 for quaternions, 1 for Euler angles)
! ipar(26:40) : 0 (unused for now)


! real(kind=dbl) :: fpar(40)  components
! fpar(1) : sig
! fpar(2) : omega
! fpar(3) : EkeV
! fpar(4) : Ehistmin
! fpar(5) : Ebinsize
! fpar(6) : depthmax
! fpar(7) : depthstep
! fpar(8) : sigstart
! fpar(9) : sigend
! fpar(10): sigstep
! parameters only used in the master pattern routine
! fpar(11) : dmin
! fpar(12) : Bethe  c1
! fpar(13) : Bethe  c2
! fpar(14) : Bethe  c3
! parameters only used in the EBSD pattern routine
! fpar(15): pattern center x
! fpar(16): pattern center y
! fpar(17): scintillator pixel size
! fpar(18): detector tilt angle
! fpar(19): sample-scintillator distance
! fpar(20): beam current
! fpar(21): dwelltime
! fpar(22): gamma value
! fpar(23:40): 0 (unused for now)




!
module EMdymod

!--------------------------------------------------------------------------
! Callback routine(s) to communicate progress with DREAM.3D package

! Define interface of call-back routine
! arguments are:
!  objAddress: unique 8-byte integer to identify the calling class in DREAM.3D
!  patternCompleted: integer indicating the current pattern ID number
!
ABSTRACT INTERFACE
   SUBROUTINE ProgressCallBack(objAddress, patternCompleted)
    USE, INTRINSIC :: ISO_C_BINDING
    INTEGER(c_size_t),INTENT(IN), VALUE          :: objAddress
    INTEGER(KIND=4), INTENT(IN), VALUE           :: patternCompleted
   END SUBROUTINE ProgressCallBack
END INTERFACE


! similar callback routine, with two integer arguments
ABSTRACT INTERFACE
   SUBROUTINE ProgressCallBack2(objAddress, loopCompleted, totalLoops, bseYield)
    USE, INTRINSIC :: ISO_C_BINDING
    INTEGER(c_size_t),INTENT(IN), VALUE          :: objAddress
    INTEGER(KIND=4), INTENT(IN), VALUE           :: loopCompleted
    INTEGER(KIND=4), INTENT(IN), VALUE           :: totalLoops
    REAL(KIND=4),INTENT(IN), VALUE              :: bseYield
   END SUBROUTINE ProgressCallBack2
END INTERFACE

! similar callback routine, with two integer arguments
ABSTRACT INTERFACE
   SUBROUTINE ProgressCallBack3(objAddress, loopCompleted, totalLoops, EloopCompleted, totalEloops)
    USE, INTRINSIC :: ISO_C_BINDING
    INTEGER(c_size_t),INTENT(IN), VALUE          :: objAddress
    INTEGER(KIND=4), INTENT(IN), VALUE           :: loopCompleted
    INTEGER(KIND=4), INTENT(IN), VALUE           :: totalLoops
    INTEGER(KIND=4), INTENT(IN), VALUE           :: EloopCompleted
    INTEGER(KIND=4), INTENT(IN), VALUE           :: totalELoops
   END SUBROUTINE ProgressCallBack3
END INTERFACE

!--------------------------------------------------------------------------

contains

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
! the first series of routines starting with EMsoftC are callable from C/C++
! programs and can handle progress callback and a cancel request.
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------

!--------------------------------------------------------------------------
!
! SUBROUTINE:EMsoftCgetEBSDPatterns
!
!> @author Marc De Graef, Carnegie Mellon University
!
!> @brief This subroutine can be called by a C/C++ program as a standalone function to compute EBSD patterns
!
!> @details This subroutine provides a method to compute a series of EBSD patterns and
!> can be called from an external C/C++ program; the routine provides a callback mechanism to
!> update the calling program about computational progress, as well as a cancel option.
!> The routine is intended to be called form a C/C++ program, e.g., DREAM.3D.  This routine is a simplified version
!> of the core of the EMEBSD program. 
!>
!> @param ipar array with integer input parameters
!> @param fpar array with float input parameters
!> @param EBSDpattern output array
!> @param quats quaternion input array
!> @param accum_e array with Monte Carlo histogram
!> @param mLPNH Northern hemisphere master pattern
!> @param mLPSH Southern hemisphere master pattern
!> @param cproc pointer to a C-function for the callback process
!> @param objAddress unique integer identifying the calling class in DREAM.3D
!> @param cancel character defined by DREAM.3D; when not equal to NULL (i.e., char(0)), the computation should be halted
!
!> @date 10/16/15 MDG 1.0 original
!> @date 11/02/15 MDG 1.1 simplification of the input variables
!> @date 11/04/15 MDG 1.2 added array of quaternions as input parameter; used complete mLPNH/SH arrays with local sum
!> @date 01/12/16 MDG 1.3 added arguments and functionality for interface with DREAM.3D and other calling programs
!> @date 01/13/16 MDG 2.0 forked from original SingleEBSDPattern routine; SAVE atrribute removed; ipar redefined (ipar(1) removed)
!> @date 04/28/16 MDG 2.1 adjusted ipar and fpar components to new convention
!> @date 06/12/16 MDG 2.2 correction for effective pixel area with respect to equal-area Lambert projection
!> @date 07/01/16 MDG 2.3 correction of array subscripts in rgx/y/z arrays.
!> @date 12/05/16 MDG 2.4 added option to pass in Euler angles instead of quaternions; quats array dimensions are unchanged
!--------------------------------------------------------------------------
recursive subroutine EMsoftCgetEBSDPatterns(ipar, fpar, EBSDpattern, quats, accum_e, mLPNH, mLPSH, cproc, objAddress, cancel) &
           bind(c, name='EMsoftCgetEBSDPatterns')    ! this routine is callable from a C/C++ program
!DEC$ ATTRIBUTES DLLEXPORT :: EMsoftCgetEBSDPatterns

! the input parameters are all part of a ipar and fpar input arrays instead of the usual namelist structure to
! make this routine callable by external programs, such as DREAM.3D

! The following is the mapping for the ipar and fpar array components used in this routine:
!
! ipar(1)  = mcnsx
! ipar(9)  = numset
! ipar(12) = detnumEbins
! ipar(17) = mpnpx
! ipar(19) = detnumsx
! ipar(20) = detnumsy
! ipar(21) = numquats
! ipar(22) = binning
! ipar(23) = binned x-dimension
! ipar(24) = binned y-dimension
! ipar(25) = anglemode

! fpar(1)  = enl%MCsig
! fpar(2)  = enl%omega
! fpar(15) = enl%xpc
! fpar(16) = enl%ypc
! fpar(17) = enl%delta
! fpar(18) = enl%thetac
! fpar(19) = enl%L
! fpar(20) = enl%beamcurrent
! fpar(21) = enl%dwelltime
! fpar(22) = gammavalue

use local
use constants
use Lambert
use quaternions
use rotations
use,INTRINSIC :: ISO_C_BINDING

IMPLICIT NONE

integer(c_int32_t),PARAMETER            :: nipar=40
integer(c_int32_t),PARAMETER            :: nfpar=40
integer(c_int32_t),INTENT(IN)           :: ipar(nipar)
real(kind=sgl),INTENT(IN)               :: fpar(nfpar)
integer(c_int32_t),PARAMETER            :: nq=4
real(kind=sgl),INTENT(IN)               :: quats(nq,ipar(21))
integer(c_int32_t),INTENT(IN)           :: accum_e(ipar(12),-ipar(1):ipar(1),-ipar(1):ipar(1))
real(kind=sgl),INTENT(IN)               :: mLPNH(-ipar(17):ipar(17), -ipar(17):ipar(17), ipar(12), ipar(9))
real(kind=sgl),INTENT(IN)               :: mLPSH(-ipar(17):ipar(17), -ipar(17):ipar(17), ipar(12), ipar(9))
real(kind=sgl),INTENT(OUT)              :: EBSDpattern(ipar(23),ipar(24),ipar(21))
TYPE(C_FUNPTR), INTENT(IN), VALUE       :: cproc
integer(c_size_t),INTENT(IN), VALUE     :: objAddress
character(len=1),INTENT(IN)             :: cancel

! various variables and arrays
real(kind=sgl)                          :: fullsizepattern(ipar(19),ipar(20)), binned(ipar(23),ipar(24))
real(kind=irg),allocatable              :: accum_e_detector(:,:,:)
real(kind=sgl),allocatable              :: rgx(:,:), rgy(:,:), rgz(:,:)
real(kind=sgl),allocatable              :: mLPNHsum(:,:,:), mLPSHsum(:,:,:)
real(kind=sgl),save                     :: prefactor
real(kind=sgl),allocatable              :: scin_x(:), scin_y(:)                 ! scintillator coordinate arrays [microns]
real(kind=sgl),parameter                :: dtor = 0.0174533  ! convert from degrees to radians
real(kind=sgl)                          :: alp, ca, sa, cw, sw, quat(4)
real(kind=sgl)                          :: L2, Ls, Lc     ! distances
integer(kind=irg)                       :: nix, niy, binx, biny,  nixp, niyp, i, j, Emin, Emax, istat, k, ip, dn, cn, & 
                                           ii, jj, binfac, ipx, ipy      ! various parameters
real(kind=sgl)                          :: dc(3), scl, alpha, theta, gam, pcvec(3), dp, calpha           ! direction cosine array
real(kind=sgl)                          :: sx, dx, dxm, dy, dym, rhos, x, bindx         ! various parameters
real(kind=sgl)                          :: ixy(2)
real(kind=dbl),parameter                :: nAmpere = 6.241D+18 
PROCEDURE(ProgressCallBack), POINTER    :: proc

! link the proc procedure to the cproc argument
CALL C_F_PROCPOINTER (cproc, proc)

! binned pattern dimensions
  binx = ipar(23)
  biny = ipar(24)
  binfac = 2**ipar(22)
  bindx = 1.0/float(binfac)**2

!====================================
! ------ generate the detector rgx, rgy, rgz arrays (and a few others)
!====================================
  if (allocated(mLPNHsum)) deallocate(mLPNHsum)
  if (allocated(mLPSHsum)) deallocate(mLPSHsum)

  allocate(mLPNHsum(-ipar(17):ipar(17), -ipar(17):ipar(17), ipar(12)))
  allocate(mLPSHsum(-ipar(17):ipar(17), -ipar(17):ipar(17), ipar(12)))
  mLPNHsum = sum(mLPNH,4)
  mLPSHsum = sum(mLPSH,4)

  allocate(scin_x(ipar(19)),scin_y(ipar(20)),stat=istat)
  
  scin_x = - ( fpar(15) - ( 1.0 - float(ipar(19)) ) * 0.5 - (/ (i-1, i=1,ipar(19)) /) ) * fpar(17)
  scin_y = ( fpar(16) - ( 1.0 - float(ipar(20)) ) * 0.5 - (/ (i-1, i=1,ipar(20)) /) ) * fpar(17)

! auxiliary angle to rotate between reference frames
  alp = 0.5 * cPi - (fpar(1) - fpar(18)) * dtor
  ca = cos(alp)
  sa = sin(alp)

  cw = cos(fpar(2) * dtor)
  sw = sin(fpar(2) * dtor)

! compute auxilliary interpolation arrays
  if (allocated(rgx)) deallocate(rgx, rgy, rgz)

  allocate(rgx(ipar(19),ipar(20)), rgy(ipar(19),ipar(20)), rgz(ipar(19),ipar(20)))

  L2 = fpar(19) * fpar(19)
  do j=1,ipar(19)
    sx = L2 + scin_x(j) * scin_x(j)
    Ls = -sw * scin_x(j) + fpar(19) * cw
    Lc = cw * scin_x(j) + fpar(19) * sw
    do i=1,ipar(20)
!   rhos = 1.0/sqrt(sx + scin_y(i)**2)
     rgx(j,i) = (scin_y(i) * ca + sa * Ls) ! * rhos
     rgy(j,i) = Lc ! * rhos
     rgz(j,i) = (-sa * scin_y(i) + ca * Ls) ! * rhos
! make sure that these vectors are normalized !
     x = sqrt(rgx(j,i)**2+rgy(j,i)**2+rgz(j,i)**2)
     rgx(j,i) = rgx(j,i) / x
     rgy(j,i) = rgy(j,i) / x
     rgz(j,i) = rgz(j,i) / x
    end do
  end do

! remove the auxiliary arrays scin_x and scin_y
  deallocate(scin_x, scin_y)

!====================================
! ------ create the equivalent detector energy array
!====================================
! from the Monte Carlo energy data, we need to extract the relevant
! entries for the detector geometry defined above.  

! determine the scale factor for the Lambert interpolation; the square has
! an edge length of 2 x sqrt(pi/2)
  scl = float(ipar(1)) 

! energy summation will go over all energy bins
  Emin = 1
  Emax = ipar(12)

  if (allocated(accum_e_detector)) deallocate(accum_e_detector)

  allocate(accum_e_detector(ipar(12),ipar(19),ipar(20)))

! correction of change in effective pixel area compared to equal-area Lambert projection
  alpha = atan(fpar(17)/fpar(19)/sqrt(sngl(cPi)))
  ipx = ipar(19)/2 + nint(fpar(15))
  ipy = ipar(20)/2 + nint(fpar(16))
  if (ipx .gt. ipar(19)) ipx = ipar(19)
  if (ipx .lt. 1) ipx = 1
  if (ipy .gt. ipar(20)) ipy = ipar(20)
  if (ipy .lt. 1) ipy = 1
  pcvec = (/ rgx(ipx,ipy), rgy(ipx,ipy), rgz(ipx,ipy) /)
  calpha = cos(alpha)
  do i=1,ipar(19)
    do j=1,ipar(20)
! do the coordinate transformation for this detector pixel
       dc = (/ rgx(i,j), rgy(i,j), rgz(i,j) /)
! make sure the third one is positive; if not, switch all 
       if (dc(3).lt.0.0) dc = -dc
! convert these direction cosines to coordinates in the Rosca-Lambert projection
        ixy = scl * LambertSphereToSquare( dc, istat )
        x = ixy(1)
        ixy(1) = ixy(2)
        ixy(2) = -x
! four-point interpolation (bi-quadratic)
        nix = int(ipar(1)+ixy(1))-ipar(1)
        niy = int(ipar(1)+ixy(2))-ipar(1)
        dx = ixy(1)-nix
        dy = ixy(2)-niy
        dxm = 1.0-dx
        dym = 1.0-dy
! do the area correction for this detector pixel
        dp = dot_product(pcvec,dc)
        if ((i.eq.ipx).and.(j.eq.ipy)) then
          gam = 0.25 
        else
          theta = calpha*calpha + dp*dp - 1.0
          gam = theta**1.5/(calpha**3) * 0.25
          
        end if
! interpolate the intensity 
        do k= Emin, Emax
          accum_e_detector(k,i,j) = gam * (accum_e(k,nix,niy) * dxm * dym + &
                                    accum_e(k,nix+1,niy) * dx * dym + &
                                    accum_e(k,nix,niy+1) * dxm * dy + &
                                    accum_e(k,nix+1,niy+1) * dx * dy)
        end do
    end do
  end do 
  prefactor = 0.25D0 * nAmpere * fpar(20) * fpar(21)  * 1.0D-15 / sum(accum_e_detector)
  accum_e_detector = accum_e_detector * prefactor

! from here on, we simply compute the EBSD patterns by interpolation, using the above arrays
! no intensity scaling or anything else...other than multiplication by pre-factor
! intensity scaling is left to the user of the calling program.

! define some parameters and initialize EBSDpattern
scl = dble(ipar(17)) 
EBSDpattern = 0.0
fullsizepattern = 0.0
dn = nint(float(ipar(21))*0.01)
cn = dn

! here is the main loop over all quaternions
quatloop: do ip=1,ipar(21)
  binned = 0.0
  fullsizepattern = 0.0
  if (ipar(25).eq.0) then 
    quat = quats(1:4,ip)
  else
    quat = eu2qu(quats(1:3,ip)) ! this assumes that the input Euler angles are in radians
  end if
  do i=1,ipar(19)
    do j=1,ipar(20)
! do the active coordinate transformation for this euler angle
      dc = quat_Lp(quat,  (/ rgx(i,j), rgy(i,j), rgz(i,j) /) )
! normalize dc
      dc = dc/sqrt(sum(dc*dc))
! convert these direction cosines to coordinates in the Rosca-Lambert projection (always square projection !!!)
      ixy = scl * LambertSphereToSquare( dc, istat )

      if (istat.eq.0) then 
! four-point interpolation (bi-quadratic)
        nix = int(ipar(17)+ixy(1))-ipar(17)
        niy = int(ipar(17)+ixy(2))-ipar(17)
        nixp = nix+1
        niyp = niy+1
        if (nixp.gt.ipar(17)) nixp = nix
        if (niyp.gt.ipar(17)) niyp = niy
        if (nix.lt.-ipar(17)) nix = nixp
        if (niy.lt.-ipar(17)) niy = niyp
        dx = ixy(1)-nix
        dy = ixy(2)-niy
        dxm = 1.0-dx
        dym = 1.0-dy
        if (dc(3).gt.0.0) then ! we're in the Northern hemisphere
          do k=1,ipar(12) 
            fullsizepattern(i,j) = fullsizepattern(i,j) + accum_e_detector(k,i,j) * ( mLPNHsum(nix,niy,k) * dxm * dym +&
                                        mLPNHsum(nixp,niy,k) * dx * dym + mLPNHsum(nix,niyp,k) * dxm * dy + &
                                        mLPNHsum(nixp,niyp,k) * dx * dy )
          end do
        else                   ! we're in the Southern hemisphere
          do k=1,ipar(12) 
            fullsizepattern(i,j) = fullsizepattern(i,j) + accum_e_detector(k,i,j) * ( mLPSHsum(nix,niy,k) * dxm * dym +&
                                        mLPSHsum(nixp,niy,k) * dx * dym + mLPSHsum(nix,niyp,k) * dxm * dy + &
                                        mLPSHsum(nixp,niyp,k) * dx * dy )
          end do
        end if
      end if
    end do
  end do

! bin the pattern if necessary and apply the gamma scaling factor
  if (binx.ne.ipar(19)) then 
    do ii=1,ipar(19),binfac
        do jj=1,ipar(20),binfac
            binned(ii/binfac+1,jj/binfac+1) = &
            sum(fullsizepattern(ii:ii+binfac-1,jj:jj+binfac-1))
        end do
    end do
    EBSDpattern(1:binx,1:biny,ip) = (binned(1:binx,1:biny)* bindx)**fpar(22)
  else
    EBSDpattern(1:binx,1:biny,ip) = (fullsizepattern(1:binx,1:biny))**fpar(22)
  end if

! has the cancel flag been set by the calling program ?
  if(cancel.ne.char(0)) EXIT quatloop

! update the progress counter and report it to the calling program via the proc callback routine
  if(objAddress.ne.0) then
    if (ip.ge.cn) then
      cn = cn+dn
      call proc(objAddress, ip)
    end if
  end if

end do quatloop


end subroutine EMsoftCgetEBSDPatterns

!--------------------------------------------------------------------------
!
! SUBROUTINE:EMsoftCgetECPatterns
!
!> @author Saransh Singh/Marc De Graef, Carnegie Mellon University
!
!> @brief This subroutine can be called by a C/C++ program as a standalone function to compute ECPs
!
!> @details This subroutine provides a method to compute a series of ECPs and
!> can be called from an external C/C++ program; the routine provides a callback mechanism to
!> update the calling program about computational progress, as well as a cancel option.
!> The routine is intended to be called form a C/C++ program, e.g., DREAM.3D.  This routine is a simplified version
!> of the core of the EMECP program. 
!>
!> This routine will first compute the incident cone vectors etc. if necessary, and then perform
!> the usual interpolation from the square Lambert projection. The pattern will be a basic pattern,
!> without any intensity scaling or binning etc; the calling program should take care of those 
!> operations.
!
!> @param ipar array with integer input parameters
!> @param fpar array with float input parameters
!> @param ECPattern output array
!> @param quats array of quaternions
!> @param accum_e array with Monte Carlo histogram
!> @param mLPNH Northern hemisphere master pattern
!> @param mLPSH Southern hemisphere master pattern
!
!> @date 10/16/15  SS 1.0 original
!> @date 11/02/14 MDG 1.1 put all integer parameters inside ipar and fixed size of ipar/fpar
!> @date 11/04/15 MDG 1.2 added array of quaternions as input parameter
!> @date 01/14/16 MDG 2.0 forked from original SingleECPattern routine; SAVE atrribute removed; ipar redefined (ipar(1) removed)
!--------------------------------------------------------------------------
recursive subroutine EMsoftCgetECPatterns(ipar, fpar, ECpattern, quats, accum_e, mLPNH, mLPSH, cproc, objAddress, cancel) &
           bind(c, name='EMsoftCgetECPatterns')    ! this routine is callable from a C/C++ program
!DEC$ ATTRIBUTES DLLEXPORT :: EMsoftCgetECPatterns

! the input parameters are all part of a ipar and fpar input arrays instead of the usual namelist structures.
! The following is the mapping:
!
! ipar(1) = detnumpix
! ipar(2) = numangle
! ipar(3) = mcnsx
! ipar(4) = numset
! ipar(5) = mpnpx
! ipar(6) = numquats

! fpar(1) = ecpnl%thetac
! fpar(2) = ecpnl%sampletilt
! fpar(3) = ecpnl%workingdistance
! fpar(4) = ecpnl%Rin
! fpar(5) = ecpnl%Rout
! fpar(6) = ecpnl%sigstart
! fpar(7) = ecpnl%sigend
! fpar(8) = ecpnl%sigstep

use local
use constants
use Lambert
use quaternions
use,INTRINSIC :: ISO_C_BINDING

IMPLICIT NONE

integer(c_size_t),PARAMETER             :: nipar=6
integer(c_size_t),PARAMETER             :: nfpar=8
integer(c_size_t),PARAMETER             :: nq=4
integer(c_size_t),INTENT(IN)            :: ipar(nipar)
real(kind=sgl),INTENT(IN)               :: fpar(nfpar)
real(kind=sgl),INTENT(OUT)              :: ECpattern(ipar(1),ipar(1),ipar(6))
real(kind=sgl),INTENT(IN)               :: quats(nq,ipar(6))
real(kind=sgl),INTENT(IN)               :: accum_e(ipar(2),-ipar(3):ipar(3),-ipar(3):ipar(3))
real(kind=sgl),INTENT(IN)               :: mLPNH(-ipar(5):ipar(5), -ipar(5):ipar(5), ipar(4))
real(kind=sgl),INTENT(IN)               :: mLPSH(-ipar(5):ipar(5), -ipar(5):ipar(5), ipar(4))
TYPE(C_FUNPTR), INTENT(IN), VALUE       :: cproc
integer(c_size_t),INTENT(IN), VALUE     :: objAddress
character(len=1),INTENT(IN)             :: cancel

real(kind=sgl),allocatable              :: klist(:,:,:), rgx(:,:), rgy(:,:), rgz(:,:), weightfact(:)
real(kind=sgl),allocatable              :: mLPNHsum(:,:), mLPSHsum(:,:)
real(kind=dbl),parameter                :: Rtod = 57.2957795131D0
real(kind=dbl),parameter                :: dtoR = 0.01745329251D0

real(kind=sgl)                          :: kk(3), thetacr, ktmax, delta, wf, quat(4)
integer(kind=irg)                       :: istat, imin, imax, jmin, jmax, ii ,jj, nazimuth, npolar, nsig, ip, dn, cn
integer(kind=irg)                       :: ipolar, iazimuth, isig, isampletilt, nix, niy, nixp, niyp, isigp
real(kind=sgl)                          :: thetain, thetaout, polar, azimuthal, delpolar, delazimuth, om(3,3)
real(kind=sgl)                          :: dc(3), scl, deltheta, acc_sum, MCangle, ixy(2), dx, dy, dxm, dym, dp
PROCEDURE(ProgressCallBack), POINTER    :: proc

! link the proc procedure to the cproc argument
CALL C_F_PROCPOINTER (cproc, proc)


!==================================================================================
! ------ generate the detector klist, rgx, rgy, rgz, weightfactors arrays 
!==================================================================================

imin = 1
imax = ipar(1)
jmin = 1
jmax = ipar(1)


    if (allocated(mLPNHsum)) deallocate(mLPNHsum)
    if (allocated(mLPSHsum)) deallocate(mLPSHsum)

    allocate(mLPNHsum(-ipar(5):ipar(5), -ipar(5):ipar(5)))
    allocate(mLPSHsum(-ipar(5):ipar(5), -ipar(5):ipar(5)))
    mLPNHsum = sum(mLPNH,3)
    mLPSHsum = sum(mLPSH,3)

    if (allocated(klist)) deallocate(klist)
    allocate(klist(1:3,1:ipar(1),1:ipar(1)), stat=istat)
    kk = (/0.0,0.0,1.0/)
    thetacr = DtoR*fpar(1)
    ktmax = tan(thetacr)
    delta = 2.0*ktmax/dble(ipar(1)-1)
     
    do ii = imin, imax
        do jj = jmin, jmax
            klist(1:3,ii,jj) = (/-ktmax+delta*(ii-1),-ktmax+delta*(jj-1),0.0/) + kk(1:3)
            klist(1:3,ii,jj) =  klist(1:3,ii,jj)/sqrt(sum( klist(1:3,ii,jj)**2))
        end do
    end do

    thetain = atan2(fpar(4),fpar(3))
    thetaout = atan2(fpar(5),fpar(3))

    om(1,:) = (/cos(fpar(2)*sngl(dtor)),0.0,sin(fpar(2)*sngl(dtor))/)
    om(2,:) = (/0.0,1.0,0.0/)
    om(3,:) = (/-sin(fpar(2)*sngl(dtor)),0.0,cos(fpar(2)*sngl(dtor))/)

    npolar = nint((thetaout - thetain)*180.0/cPi) + 1
    delpolar = (thetaout - thetain)/float(npolar-1)

    nazimuth = 361
    delazimuth = 2.0*cPi/float(nazimuth-1)

    if (allocated(rgx)) deallocate(rgx, rgy, rgz)
    allocate(rgx(npolar, nazimuth), rgy(npolar, nazimuth), rgz(npolar, nazimuth), stat=istat)

    do ipolar = 1,npolar
         polar = thetain + float(ipolar-1)*delpolar

         do iazimuth = 1,nazimuth
             azimuthal = float(iazimuth-1)*delazimuth

             dc(1) = cos(azimuthal)*sin(polar)
             dc(2) = sin(azimuthal)*sin(polar)
             dc(3) = cos(polar)

             dc = matmul(om,dc)

             rgx(ipolar,iazimuth) = dc(1)
             rgy(ipolar,iazimuth) = dc(2)
             rgz(ipolar,iazimuth) = dc(3)
        end do
    end do

!===================================================================
! ------ generate the weight factors from the monte carlo histogram
!===================================================================

    scl = float(ipar(3))
    nsig = nint(fpar(1) + abs(fpar(2))) + 1

    deltheta = (fpar(1)+abs(fpar(2)))/float(nsig-1)

    if (allocated(weightfact)) deallocate(weightfact)
    allocate(weightfact(1:nsig), stat=istat)
    weightfact = 0.0

    do isig = 1,nsig
        acc_sum = 0.0
        MCangle = (isig - 1)*deltheta
        isampletilt = nint((MCangle - fpar(6))/fpar(8))
    
        if (isampletilt .lt. 1) then
            isampletilt = abs(isampletilt) + 1
        else
            isampletilt = isampletilt + 1
        end if

        do ipolar = 1,npolar
            do iazimuth = 1,nazimuth
                dc(1:3) = (/rgx(ipolar,iazimuth), rgy(ipolar,iazimuth), rgz(ipolar,iazimuth)/)
! convert to Rosca-lambert projection
                ixy = scl *  LambertSphereToSquare( dc, istat )
                nix = int(ipar(3)+ixy(1))-ipar(3)
                niy = int(ipar(3)+ixy(2))-ipar(3)
                nixp = nix+1
                niyp = niy+1
                if (nixp.gt.ipar(3)) nixp = nix
                if (niyp.gt.ipar(3)) niyp = niy
                if (nix.lt.-ipar(3)) nix = nixp
                if (niy.lt.-ipar(3)) niy = niyp
                dx = ixy(1)-nix
                dy = ixy(2)-niy
                dxm = 1.0-dx
                dym = 1.0-dy
            
                acc_sum = 0.25*(accum_e(isampletilt,nix,niy) * dxm * dym + &
                                accum_e(isampletilt,nixp,niy) * dx * dym + &
                                accum_e(isampletilt,nix,niyp) * dxm * dy + &
                                accum_e(isampletilt,nixp,niyp) * dx * dy)
             
                weightfact(isig) = weightfact(isig) + acc_sum

            end do
        end do
    end do

    weightfact(1:nsig) = weightfact(1:nsig)/weightfact(1)

!===================================================================
! ------ perform interpolation from square lambert map
!===================================================================
scl = float(ipar(5))
ECPattern = 0.0
dn = nint(float(ipar(6))*0.01)
cn = dn

quatloop: do ip=1,ipar(6)
  do ii = imin, imax
    do jj = jmin, jmax

        dc(1:3) = klist(1:3,ii,jj)
        dc = dc/sqrt(sum(dc*dc))
        
        dp = DOT_PRODUCT(dc(1:3),(/sin(fpar(2)*dtoR),0.D0,cos(fpar(2)*dtoR)/))      
        if (dp .gt. 1.D0) dp = 1.0
        MCangle = acos(dp)*Rtod
        isig = int(MCangle) + 1
        if (isig .gt. nsig) isig = nsig

        isigp = isig + 1
        if (isigp .gt. nsig) isigp = nsig
        dx = MCangle - int(MCangle)
        dxm =  1.0 - dx
        
        wf = weightfact(isig) * dxm + weightfact(isigp) * dx
        wf = 1.0
        dc = quat_LP(quats(1:4,ip), dc)
        dc = dc/sqrt(sum(dc*dc))

        ixy = scl * LambertSphereToSquare( dc, istat )
        nix = int(ipar(5)+ixy(1))-ipar(5)
        niy = int(ipar(5)+ixy(2))-ipar(5)
        nixp = nix+1
        niyp = niy+1
        if (nixp.gt.ipar(5)) nixp = nix
        if (niyp.gt.ipar(5)) niyp = niy
        if (nix.lt.-ipar(5)) nix = nixp
        if (niy.lt.-ipar(5)) niy = niyp
        dx = ixy(1)-nix
        dy = ixy(2)-niy
        dxm = 1.0-dx
        dym = 1.0-dy
        
        if (dc(3).ge.0.D0) then 
            ECpattern(ii,jj,ip) = wf * ( mLPNHsum(nix,niy) * dxm * dym + &
                         mLPNHsum(nixp,niy) * dx * dym + &
                         mLPNHsum(nix,niyp) * dxm * dy + &
                         mLPNHsum(nixp,niyp) * dx * dy )

        else
            ECpattern(ii,jj,ip) =  wf * ( mLPSHsum(nix,niy) * dxm * dym + &
                         mLPSHsum(nixp,niy) * dx * dym + &
                         mLPSHsum(nix,niyp) * dxm * dy + &
                         mLPSHsum(nixp,niyp) * dx * dy )
        end if

    end do
  end do

! has the cancel flag been set by the calling program ?
  if(cancel.ne.char(0)) EXIT quatloop

! update the progress counter and report it to the calling program via the proc callback routine
  if(objAddress.ne.0) then
    if (ip.ge.cn) then
      cn = cn+dn
      call proc(objAddress, ip)
    end if
  end if
end do quatloop

end subroutine EMsoftCgetECPatterns

!--------------------------------------------------------------------------
!
! SUBROUTINE:EMsoftCgetMCOpenCL
!
!> @author Marc De Graef, Carnegie Mellon University
!
!> @brief This subroutine can be called by a C/C++ program as a standalone routine to compute Monte Carlo data
!
!> @details This subroutine provides a method to compute a Monte Carlo data set, normally computed
!> with the EMMCOpenCL.f90 program.  The routine can be called from an external C/C++ program; 
!> the routine provides a callback mechanism to update the calling program about computational 
!> progress, as well as a cancel option.
!>
!> The routine is intended to be called from a C/C++ program, e.g., DREAM.3D.  This routine is a 
!> simplified version of the core of the EMMCOpenCL program. 
!>
!> Since the HDF5 library with fortran90 support can only be a static library on Mac OS X, we must
!> have the calling program read the .xtal HDF5 file and pass the necessary information on to
!> this routine.  This is a workaround until the HDF group fixes the static library issue; DREAM.3D
!> requires a dynamical HDF5 library, so for DREAM.3D and EMsoft to properly work together, the 
!> callable routines in this file may not depend on any HDF code at all, either directly or indirectly.
!>
!> @param ipar array with integer input parameters
!> @param fpar array with float input parameters
!> @param atdata atom coordinate array
!> @param attypes atom type array
!> @param latparm lattice parameter array
!> @param accum_e output array with Monte Carlo energy histogram
!> @param accum_z output array with Monte Carlo depth histogram
!
!> @date 03/08/16 MDG 1.0 original
!> @date 03/19/16 MDG 1.1 corrections to a few variable types
!> @date 04/13/16 MDG 1.2 correction to accum_z array size due to changes in calling DREAM.3D filter
!> @date 04/18/16 MDG 1.3 increased number of entries in ipar, fpar for compatibility with EMsoftCgetEBSDmaster routine
!> @date 04/28/16 MDG 1.4 corrected error in indexing of init_seeds array; caused DREAM.3D to crash randomly
!--------------------------------------------------------------------------
recursive subroutine EMsoftCgetMCOpenCL(ipar, fpar, atompos, atomtypes, latparm, accum_e, accum_z, cproc, objAddress, cancel) &
           bind(c, name='EMsoftCgetMCOpenCL')    ! this routine is callable from a C/C++ program
!DEC$ ATTRIBUTES DLLEXPORT :: EMsoftCgetMCOpenCL

! ipar components
! ipar(1) : integer(kind=irg)       :: nx  = (numsx-1)/2
! ipar(2) : integer(kind=irg)       :: globalworkgrpsz
! ipar(3) : integer(kind=irg)       :: num_el
! ipar(4) : integer(kind=irg)       :: totnum_el
! ipar(5) : integer(kind=irg)       :: multiplier
! ipar(6) : integer(kind=irg)       :: devid
! ipar(7) : integer(kind=irg)       :: platid
! ipar(8) : integer(kind=irg)       :: CrystalSystem
! ipar(9) : integer(kind=irg)       :: Natomtypes
! ipar(10): integer(kind=irg)       :: SpaceGroupNumber
! ipar(11): integer(kind=irg)       :: SpaceGroupSetting
! ipar(12): integer(kind=irg)       :: numEbins
! ipar(13): integer(kind=irg)       :: numzbins
! ipar(14): integer(kind=irg)       :: mcmode  ( 1 = 'full', 2 = 'bse1' )
! ipar(15): integer(kind=irg)       :: numangle
! ipar(16): integer(kind=irg)       :: nxten = nx/10
! other entries are not used

! fpar components
! fpar(1) : real(kind=dbl)          :: sig
! fpar(2) : real(kind=dbl)          :: omega
! fpar(3) : real(kind=dbl)          :: EkeV
! fpar(4) : real(kind=dbl)          :: Ehistmin
! fpar(5) : real(kind=dbl)          :: Ebinsize
! fpar(6) : real(kind=dbl)          :: depthmax
! fpar(7) : real(kind=dbl)          :: depthstep
! fpar(8) : real(kind=dbl)          :: sigstart
! fpar(9) : real(kind=dbl)          :: sigend
! fpar(10): real(kind=dbl)          :: sigstep
! other entries are not used


use local
use constants
use crystal
use constants
use symmetry
use io
use typedefs
use clfortran
use CLsupport
use timing
use,INTRINSIC :: ISO_C_BINDING

IMPLICIT NONE

integer(c_int32_t),PARAMETER            :: nipar=40
integer(c_int32_t),PARAMETER            :: nfpar=40
integer(c_int32_t),INTENT(IN)           :: ipar(nipar)
real(kind=sgl),INTENT(IN)               :: fpar(nfpar)
real(kind=sgl),INTENT(IN)               :: atompos(ipar(9),5)
integer(kind=irg),INTENT(IN)            :: atomtypes(ipar(9))
real(kind=sgl),INTENT(IN)               :: latparm(6)
integer(kind=irg),INTENT(OUT)           :: accum_e(ipar(12),-ipar(1):ipar(1),-ipar(1):ipar(1))
integer(kind=irg),INTENT(OUT)           :: accum_z(ipar(12),ipar(13),-ipar(16):ipar(16),-ipar(16):ipar(16))
TYPE(C_FUNPTR), INTENT(IN), VALUE       :: cproc
integer(c_size_t),INTENT(IN), VALUE     :: objAddress
character(len=1),INTENT(IN)             :: cancel

! local variables and parameters
type(unitcell),pointer                  :: cell
character(4)                            :: mode
integer(kind=ill)                       :: i, j, k, io_int(1), num_max, totnum_el, ipg, isave, istat
integer(kind=irg)                       :: nx, numEbins, numzbins, numangle, iang, cn, dn, totn 
integer(kind=irg),target                :: globalworkgrpsz, num_el, steps
integer(kind=8),target                  :: globalsize(2), localsize(2) 
integer(kind=8)                         :: size_in_bytes,size_in_bytes_seeds 

real(kind=sgl),target                   :: dens, avA, avZ, omega, EkeV, sig, bseyield, io_real(3)
real(kind=4),target                     :: density, Ze, at_wt, delta
real(kind=8),parameter                  :: dtoR = 0.01745329251D0  ! pi/180
real(kind=4),allocatable, target        :: Lamresx(:), Lamresy(:), depthres(:), energyres(:)

integer(kind=4),allocatable             :: rnseeds(:)
integer(kind=4),allocatable,target      :: init_seeds(:)
integer(kind=4)                         :: idxy(2), iE, px, py, iz, nseeds, hdferr, tstart ! auxiliary variables
real(kind=4)                            :: cxyz(3), edis, bse, xy(2), xs, ys, zs, sclf ! auxiliary variables
real(kind=8)                            :: rand
logical                                 :: f_exists


! OpenCL variables
integer(c_intptr_t),allocatable, target :: platform(:)
integer(c_intptr_t),allocatable, target :: device(:)
integer(c_intptr_t),target              :: context
integer(c_intptr_t),target              :: command_queue
integer(c_intptr_t),target              :: prog
integer(c_intptr_t),target              :: kernel
integer(c_intptr_t),target              :: LamX, LamY, LamZ, depth, energy, seeds
type(c_ptr)                             :: event
integer(c_int32_t)                      :: ierr, pcnt
integer(c_size_t),target                :: slength
integer(c_intptr_t),target              :: ctx_props(3)
character(2),target                     :: kernelname
character(19),target                    :: progoptions
character(fnlen),target                 :: info ! info about the GPU
integer(c_int64_t)                      :: cmd_queue_props

integer, parameter                      :: iunit = 10
integer, parameter                      :: source_length = 50000
character(len=source_length),target     :: source
character(len=source_length, KIND=c_char),TARGET :: csource
type(c_ptr), target                     :: psource
integer(c_int)                          :: nump, numd, irec, val,val1 ! auxiliary variables
integer(c_size_t)                       :: cnum, cnuminfo
character(fnlen)                        :: instring, dataname, fname, sourcefile
PROCEDURE(ProgressCallBack2), POINTER   :: proc

! link the proc procedure to the cproc argument
CALL C_F_PROCPOINTER (cproc, proc)

! since this routine needs to read a .cl file, we need to make sure that the pathnames are 
! properly set...
call EMsoft_path_init

! the following is necessitated by the fact that none of this code may 
! depend on HDF5 routines, so we need to cut-and-paste from various 
! other library routines to set things up so that we can compute the 
! density, and the average atomic number and atomic mass...

! copy all the unit cell parameters into the proper fields and compute the 
! density parameters needed by the Monte Carlo routine; then discard the cell structure
nullify(cell)
allocate(cell)
! lattice parameters
cell%a = dble(latparm(1))
cell%b = dble(latparm(2))
cell%c = dble(latparm(3))
cell%alpha = dble(latparm(4))
cell%beta = dble(latparm(5))
cell%gamma = dble(latparm(6))
! symmetry parameters
cell%xtal_system = ipar(8)
cell%SYM_SGset = ipar(11)
cell%SYM_SGnum = ipar(10)
if ((cell%SYM_SGnum.ge.143).and.(cell%SYM_SGnum.le.167)) then
  cell%SG%SYM_trigonal = .TRUE.
else
  cell%SG%SYM_trigonal = .FALSE.
end if 
! atom type and coordinate parameters
cell%ATOM_ntype = ipar(9)
cell%ATOM_type(1:cell%ATOM_ntype) = atomtypes(1:cell%ATOM_ntype) 
cell%ATOM_pos(1:cell%ATOM_ntype,1:5) = atompos(1:cell%ATOM_ntype,1:5) 
! generate the symmetry operations
cell%hexset = .FALSE.
if (cell%xtal_system.eq.4) cell%hexset = .TRUE.
if ((cell%xtal_system.eq.5).AND.(cell%SYM_SGset.ne.2)) cell%hexset = .TRUE.
! compute the metric matrices
 call CalcMatrices(cell)
! First generate the point symmetry matrices, then the actual space group.
! Get the symmorphic space group corresponding to the point group
! of the actual space group
 ipg=0
 do i=1,32
  if (SGPG(i).le.cell%SYM_SGnum) ipg=i
 end do
! if the actual group is also the symmorphic group, then both 
! steps can be done simultaneously, otherwise two calls to 
! GenerateSymmetry are needed.
 if (SGPG(ipg).eq.cell%SYM_SGnum) then
  call GenerateSymmetry(cell,.TRUE.)
 else
  isave = cell%SYM_SGnum
  cell%SYM_SGnum = SGPG(ipg)
  call GenerateSymmetry(cell,.TRUE.)
  cell%SYM_SGnum = isave
  call GenerateSymmetry(cell,.FALSE.)
 end if
! next we get all the atom positions
call CalcPositions(cell,'v')
! and now we have all we need to compute the density, average A and average Z
call CalcDensity(cell, dens, avZ, avA)
! deallocate the cell structure
deallocate(cell)

! and copy these values into the desired variables
density = dble(dens)
Ze = dble(avZ)
at_wt = dble(avA)

! define a number of parameters
steps = 300
mode = 'full'
if (ipar(14).ne.1) mode = 'bse1'   
EkeV = sngl(fpar(3))
!sig = mcnl%sig*dtoR    ! this is defined later on and depends on the mode
omega = sngl(fpar(2))*dtoR
globalworkgrpsz = ipar(2)
num_el = int(ipar(3))  ! no. of electron simulation by one work item
num_max = globalworkgrpsz*globalworkgrpsz*num_el ! total simulation in one loop
totnum_el = ipar(4) * ipar(5) ! total number of electrons to simulate
globalsize = (/ globalworkgrpsz, globalworkgrpsz /)
!localsize = (/ globalworkgrpsz, globalworkgrpsz /)
!localsize = (/ globalworkgrpsz/10, globalworkgrpsz/10 /)
numEbins =  int(ipar(12))
numzbins =  int(ipar(13))
nx = int(ipar(1))
delta = dble(nx)
size_in_bytes = num_max*sizeof(EkeV)
size_in_bytes_seeds = 4*globalworkgrpsz*globalworkgrpsz*sizeof(EkeV)
numangle = int(ipar(15))

! next allocate and initialize a couple of arrays
allocate(Lamresx(num_max), Lamresy(num_max), depthres(num_max), energyres(num_max), stat=istat)
depthres = 0.0
energyres = 0.0
Lamresx = 0.0
Lamresy = 0.0
accum_e = 0
accum_z = 0


!======================
! OpenCL INITIALIZATION
!======================
call CLinit_PDCCQ(platform, nump, int(ipar(7)), device, numd, int(ipar(6)), info, context, command_queue)

!=====================
! BUILD THE KERNEL
!=====================
! read the source file
sourcefile = 'EMMC.cl'
call CLread_source_file(sourcefile, csource, slength)

! we disable all screen output; perhaps we can feed error messages back to the calling program...

! create the program
pcnt = 1
psource = C_LOC(csource)
prog = clCreateProgramWithSource(context, pcnt, C_LOC(psource), C_LOC(slength), ierr)
! if(ierr /= CL_SUCCESS) call FatalError("clCreateProgramWithSource: ",'Error: cannot create program from source.')

! build the program
progoptions = '-cl-no-signed-zeros'
ierr = clBuildProgram(prog, numd, C_LOC(device), C_LOC(progoptions), C_NULL_FUNPTR, C_NULL_PTR)
! if(ierr /= CL_SUCCESS) call FatalError("clBuildProgram: ",'Error: cannot build program.')

! get the compilation log
ierr = clGetProgramBuildInfo(prog, device(ipar(6)), CL_PROGRAM_BUILD_LOG, sizeof(source), C_LOC(source), cnum)
! if(len(trim(source)) > 0) call Message(trim(source(1:cnum)),frm='(A)')
! if(ierr /= CL_SUCCESS) call FatalError("clGetProgramBuildInfo: ",'Error building program.')

! if we get here, then the program build was successful and we can proceed with the creation of the kernel
! call Message('Program Build Successful... Creating kernel')

! finally get the kernel and release the program
kernelname = 'MC'
kernel = clCreateKernel(prog, C_LOC(kernelname), ierr)
! if(ierr /= CL_SUCCESS) call FatalError("clCreateKernel: ",'Error creating kernel MC.')

ierr = clReleaseProgram(prog)
! if(ierr /= CL_SUCCESS) call FatalError("clReleaseProgram: ",'Error releasing program.')

open(unit = iunit, file = trim(EMsoft_toNativePath(EMsoft_getRandomseedfilename())), form='unformatted', status='old')
read(iunit) nseeds
allocate(rnseeds(nseeds))
read(iunit) rnseeds
close(unit=iunit,status='keep')

! the next error needs to be checked in the calling program
! if (globalworkgrpsz**2 .gt. nseeds) call FatalError('EMMCOpenCL:','insufficient prime numbers')

allocate(init_seeds(4*globalworkgrpsz*globalworkgrpsz),stat=istat)
init_seeds = 0
do i = 1,globalworkgrpsz
    do j = 1,globalworkgrpsz
        do k = 1,4
            init_seeds(4*((i-1)*globalworkgrpsz+(j-1))+k) = rnseeds(4*((i-1)*globalworkgrpsz+j)+k)
        end do
    end do
end do

! create device memory buffers
LamX = clCreateBuffer(context, CL_MEM_WRITE_ONLY, size_in_bytes, C_NULL_PTR, ierr)
! if(ierr /= CL_SUCCESS) call FatalError('clCreateBuffer: ','cannot allocate device memory for LamX.')

LamY = clCreateBuffer(context, CL_MEM_WRITE_ONLY, size_in_bytes, C_NULL_PTR, ierr)
! if(ierr /= CL_SUCCESS) call FatalError('clCreateBuffer: ','cannot allocate device memory for LamY.')

depth = clCreateBuffer(context, CL_MEM_WRITE_ONLY, size_in_bytes, C_NULL_PTR, ierr)
!   if(ierr /= CL_SUCCESS) call FatalError('clCreateBuffer: ','cannot allocate device memory for depth.')

energy = clCreateBuffer(context, CL_MEM_WRITE_ONLY, size_in_bytes, C_NULL_PTR, ierr)
!   if(ierr /= CL_SUCCESS) call FatalError('clCreateBuffer: ','cannot allocate device memory for energy.')

seeds = clCreateBuffer(context, CL_MEM_READ_WRITE, size_in_bytes, C_NULL_PTR, ierr)
! if(ierr /= CL_SUCCESS) call FatalError('clCreateBuffer: ','cannot allocate device memory for seeds.')

ierr = clEnqueueWriteBuffer(command_queue, seeds, CL_TRUE, 0_8, size_in_bytes_seeds, C_LOC(init_seeds(1)), &
                            0, C_NULL_PTR, C_NULL_PTR)
! if(ierr /= CL_SUCCESS) call FatalError('clEnqueueWriteBuffer: ','cannot Enqueue write buffer.')

! set the callback parameters
dn = 1
cn = dn
totn = numangle * (totnum_el/num_max+1)

call Time_tick(tstart)

! loop over angles (used for BSE1, single run for full)
angleloop: do iang = 1,numangle

  if (mode .eq. 'bse1') then
    sig = (fpar(8) + (iang-1)*fpar(10))*dtoR
  else 
    sig = fpar(1)*dtoR
  end if

  mainloop: do i = 1,(totnum_el/num_max+1)

! set the kernel arguments
    ierr = clSetKernelArg(kernel, 0, sizeof(LamX), C_LOC(LamX))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 1, sizeof(LamY), C_LOC(LamY))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 2, sizeof(EkeV), C_LOC(EkeV))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 3, sizeof(globalworkgrpsz), C_LOC(globalworkgrpsz))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 4, sizeof(Ze), C_LOC(Ze))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 5, sizeof(density), C_LOC(density))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 6, sizeof(at_wt), C_LOC(at_wt))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 7, sizeof(num_el), C_LOC(num_el))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 8, sizeof(seeds), C_LOC(seeds))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 9, sizeof(sig), C_LOC(sig))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 10, sizeof(omega), C_LOC(omega))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 11, sizeof(depth), C_LOC(depth))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 12, sizeof(energy), C_LOC(energy))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

    ierr = clSetKernelArg(kernel, 13, sizeof(steps), C_LOC(steps))
    !   if(ierr /= CL_SUCCESS) stop 'Error: cannot set kernel argument.'

! execute the kernel
!   ierr = clEnqueueNDRangeKernel(command_queue, kernel, 2, C_NULL_PTR, C_LOC(globalsize), C_LOC(localsize), &
!                                 0, C_NULL_PTR, C_NULL_PTR)
    ierr = clEnqueueNDRangeKernel(command_queue, kernel, 2, C_NULL_PTR, C_LOC(globalsize), C_NULL_PTR, &
                                  0, C_NULL_PTR, C_NULL_PTR)
! wait for the commands to finish
    ierr = clFinish(command_queue)

! read the resulting vector from device memory
    ierr = clEnqueueReadBuffer(command_queue,LamX,CL_TRUE,0_8,size_in_bytes,C_LOC(Lamresx(1)),0,C_NULL_PTR,C_NULL_PTR)
    ierr = clEnqueueReadBuffer(command_queue,LamY,CL_TRUE,0_8,size_in_bytes,C_LOC(Lamresy(1)),0,C_NULL_PTR,C_NULL_PTR)
    ierr = clEnqueueReadBuffer(command_queue,depth,CL_TRUE,0_8,size_in_bytes,C_LOC(depthres(1)),0,C_NULL_PTR,C_NULL_PTR)
    ierr = clEnqueueReadBuffer(command_queue,energy,CL_TRUE,0_8,size_in_bytes,C_LOC(energyres(1)),0,C_NULL_PTR,C_NULL_PTR)



    if (mode .eq. 'full') then
      subloopfull: do j = 1, num_max
        if ((Lamresx(j) .ne. -10.0) .and. (Lamresy(j) .ne. -10.0) &
          .and. (depthres(j) .ne. 10.0) .and. (energyres(j) .ne. 0.0) &
          .and. .not.isnan(Lamresx(j)) .and. .not.isnan(Lamresy(j))) then
! and get the nearest pixel [ take into account reversal of coordinate frame (x,y) -> (y,-x) ]
             if ((nint(delta*Lamresy(j)) .eq. 0.0) .and. (nint(-delta*Lamresx(j)) .eq. 0.0)) then
               val1 = val1 + 1
             end if

             val = val + 1
             idxy = (/ nint(delta*Lamresy(j)), nint(-delta*Lamresx(j)) /)

             if (maxval(abs(idxy)).le.nx) then
! If Ec larger than Emin, then we should count this electron
               if (energyres(j).gt.fpar(4)) then

                 iE = nint((energyres(j)-fpar(4))/fpar(5))+1
! first add this electron to the correct exit distance vs. energy bin (coarser than the angular plot)
                 edis = abs(depthres(j))  ! distance from last scattering point to surface along trajectory
                 iz = nint(edis/fpar(7)) +1
                 if ( (iz.gt.0).and.(iz.le.ipar(13)) ) then

                   px = nint(idxy(1)/10.0)
                   py = nint(idxy(2)/10.0)
                   accum_z(iE,iz,px,py) = accum_z(iE,iz,px,py) + 1

                 end if
! then add it to the modified Lambert accumulator array.
                 accum_e(iE,idxy(1),idxy(2)) = accum_e(iE,idxy(1),idxy(2)) + 1
               end if
             end if
        end if
      end do subloopfull
    end if

    if (mode .eq. 'bse1') then
      subloopbse1: do j = 1, num_max

        if ((Lamresx(j) .ne. -10.0) .and. (Lamresy(j) .ne. -10.0) &
          .and. (depthres(j) .ne. 10.0) .and. (energyres(j) .ne. 0.0) &
          .and. .not.isnan(Lamresx(j)) .and. .not.isnan(Lamresy(j))) then
! and get the nearest pixel [ take into account reversal of coordinate frame (x,y) -> (y,-x) ]
          if ((nint(delta*Lamresy(j)) .eq. 0.0) .and. (nint(-delta*Lamresx(j)) .eq. 0.0)) then
            val1 = val1 + 1
          end if

          val = val + 1
          idxy = (/ nint(delta*Lamresy(j)), nint(-delta*Lamresx(j)) /)

          if (maxval(abs(idxy)).le.nx) then
! first add this electron to the correct exit distance vs. sigma (coarser than the angular plot)
            edis = abs(depthres(j))  ! distance from last scattering point to surface along trajectory
            iz = nint(edis/fpar(7)) +1
            if ( (iz.gt.0).and.(iz.le.ipar(13)) ) then
              px = nint(idxy(1)/10.0)
              py = nint(idxy(2)/10.0)
              accum_z(iang,iz,px,py) = accum_z(iang,iz,px,py) + 1

            end if
! then add it to the modified Lambert accumulator array.
            accum_e(iang,idxy(1),idxy(2)) = accum_e(iang,idxy(1),idxy(2)) + 1
          end if
        end if
      end do subloopbse1
    end if

! has the cancel flag been set by the calling program ?
  if(cancel.ne.char(0)) EXIT angleloop

! update the progress counter and report it to the calling program via the proc callback routine
  if(objAddress.ne.0) then
    cn = cn+dn
    bseyield = 100.0*float(sum(accum_e))/float(i*num_max)
    write(*,*)cn, totn, bseyield
    call proc(objAddress, cn, totn, bseyield)
  end if

  end do mainloop
end do angleloop 

write(*,*)'Total GPU time [s] = ',Time_tock(tstart)

!=====================
! RELEASE EVERYTHING
!=====================

ierr = clReleaseKernel(kernel)
ierr = clReleaseCommandQueue(command_queue)
ierr = clReleaseContext(context)
ierr = clReleaseMemObject(LamX)
ierr = clReleaseMemObject(LamY)
ierr = clReleaseMemObject(depth)
ierr = clReleaseMemObject(energy)
ierr = clReleaseMemObject(seeds)


end subroutine EMsoftCgetMCOpenCL


!--------------------------------------------------------------------------
!
! SUBROUTINE:EMsoftCgetEBSDmaster
!
!> @author Marc De Graef, Carnegie Mellon University
!
!> @brief This subroutine can be called by a C/C++ program as a standalone routine to compute EBSD master patterns
!
!> @details This subroutine provides a method to compute an EBSD master pattern for the northern and southern
!> hemispheres, i.e., it implements the EMEBSDmaster.f90 program.  The routine can be called from an external C/C++ program; 
!> the routine provides a callback mechanism to update the calling program about computational 
!> progress, as well as a cancel option.
!>
!> The routine is intended to be called from a C/C++ program, e.g., DREAM.3D.  This routine is a 
!> simplified version of the core of the EMEBSDmaster program. 
!>
!> Since the HDF5 library with fortran90 support can only be a static library on Mac OS X, we must
!> have the calling program read the .xtal HDF5 file and pass the necessary information on to
!> this routine.  This is a workaround until the HDF group fixes the static library issue; DREAM.3D
!> requires a dynamical HDF5 library, so for DREAM.3D and EMsoft to properly work together, the 
!> callable routines in this file may not depend on any HDF code at all, either directly or indirectly.
!>
!> @param ipar array with integer input parameters
!> @param fpar array with float input parameters
!> @param atdata atom coordinate array
!> @param attypes atom type array
!> @param latparm lattice parameter array
!> @param accum_z output array with Monte Carlo depth histogram
!> @param mLPNH modified Lambert projection northern hemisphere (output)
!> @param mLPSH modified Lambert projection southern hemisphere (output)
!
!> @date 04/17/16 MDG 1.0 original
!--------------------------------------------------------------------------
recursive subroutine EMsoftCgetEBSDmaster(ipar,fpar,atompos,atomtypes,latparm,accum_z,mLPNH,mLPSH,cproc,objAddress,cancel) &
           bind(c, name='EMsoftCgetEBSDmaster')    ! this routine is callable from a C/C++ program
!DEC$ ATTRIBUTES DLLEXPORT :: EMsoftCgetEBSDmaster

! these are the same as in the EMsoftCgetMCOpenCL routine, with a few extras at the end.
! ipar components
! ipar(1) : integer(kind=irg)       :: nx  = (numsx-1)/2
! ipar(2) : integer(kind=irg)       :: globalworkgrpsz
! ipar(3) : integer(kind=irg)       :: num_el
! ipar(4) : integer(kind=irg)       :: totnum_el
! ipar(5) : integer(kind=irg)       :: multiplier
! ipar(6) : integer(kind=irg)       :: devid
! ipar(7) : integer(kind=irg)       :: platid
! ipar(8) : integer(kind=irg)       :: CrystalSystem
! ipar(9) : integer(kind=irg)       :: Natomtypes
! ipar(10): integer(kind=irg)       :: SpaceGroupNumber
! ipar(11): integer(kind=irg)       :: SpaceGroupSetting
! ipar(12): integer(kind=irg)       :: numEbins
! ipar(13): integer(kind=irg)       :: numzbins
! ipar(14): integer(kind=irg)       :: mcmode  ( 1 = 'full', 2 = 'bse1' )
! ipar(15): integer(kind=irg)       :: numangle
! ipar(16): integer(kind=irg)       :: nxten = nx/10
! the following are only used in this routine, not in the Monte Carlo routine
! ipar(17): integer(kind=irg)       :: npx
! ipar(18): integer(kind=irg)       :: nthreads

! fpar components
! fpar(1) : real(kind=dbl)          :: sig
! fpar(2) : real(kind=dbl)          :: omega
! fpar(3) : real(kind=dbl)          :: EkeV
! fpar(4) : real(kind=dbl)          :: Ehistmin
! fpar(5) : real(kind=dbl)          :: Ebinsize
! fpar(6) : real(kind=dbl)          :: depthmax
! fpar(7) : real(kind=dbl)          :: depthstep
! fpar(8) : real(kind=dbl)          :: sigstart
! fpar(9) : real(kind=dbl)          :: sigend
! fpar(10): real(kind=dbl)          :: sigstep
! parameters only used in this routine, this includes the Bethe Parameters !!!!
! fpar(11) : real(kind=dbl)         :: dmin
! fpar(12) : real(kind=dbl)         :: Bethe  c1
! fpar(13) : real(kind=dbl)         :: Bethe  c2
! fpar(14) : real(kind=dbl)         :: Bethe  c3

use typedefs
use NameListTypedefs
use initializers
use MBmodule
use symmetry
use crystal
use constants
use error
use gvectors
use kvectors
use io
use local
use files
use diffraction
use multibeams
use timing
use Lambert
use ISO_C_BINDING
use omp_lib

IMPLICIT NONE

integer(c_int32_t),PARAMETER            :: nipar=40
integer(c_int32_t),PARAMETER            :: nfpar=40
integer(c_int32_t),INTENT(IN)           :: ipar(nipar)
real(kind=sgl),INTENT(IN)               :: fpar(nfpar)
real(kind=sgl),INTENT(IN)               :: atompos(ipar(9),5)
integer(kind=irg),INTENT(IN)            :: atomtypes(ipar(9))
real(kind=sgl),INTENT(IN)               :: latparm(6)
integer(kind=irg),INTENT(IN)            :: accum_z(ipar(12),ipar(13),-ipar(16):ipar(16),-ipar(16):ipar(16))
real(kind=sgl),INTENT(OUT)              :: mLPNH(-ipar(17):ipar(17),-ipar(17):ipar(17),1:ipar(12),1:ipar(9))
real(kind=sgl),INTENT(OUT)              :: mLPSH(-ipar(17):ipar(17),-ipar(17):ipar(17),1:ipar(12),1:ipar(9))
TYPE(C_FUNPTR), INTENT(IN), VALUE       :: cproc
integer(c_size_t),INTENT(IN), VALUE     :: objAddress
character(len=1),INTENT(IN)             :: cancel

real(kind=dbl)          :: ctmp(192,3), arg

integer(kind=irg)       :: isym,i,j,ik,npy,ipx,ipy,ipz,debug,iE,izz, izzmax, iequiv(3,48), nequiv, num_el, MCnthreads, & ! counters
                           numk, & ! number of independent incident beam directions
                           ir,nat(100),kk(3), skip, ijmax, one, NUMTHREADS, TID, SamplingType, cancelerr, &
                           numset,n,ix,iy,iz, nns, nnw, nref, Estart, ipg, isave, npx, nthreads,  &
                           istat,gzero,ic,ip,ikk, totstrong, totweak, jh, ierr, nix, niy, nixp, niyp, nxten     ! counters
real(kind=dbl)          :: tpi,Znsq, kkl, DBWF, kin, delta, h, lambda, omtl, srt, dc(3), xy(2), edge, scl, tmp, &
                           dx, dxm, dy, dym, dmin !
real(kind=sgl)          :: io_real(5), selE, kn, FN(3), kkk(3), tstart, tstop, bp(4)
real(kind=sgl),allocatable      :: EkeVs(:), svals(:), auxNH(:,:,:), auxSH(:,:,:)  ! results
complex(kind=dbl)               :: czero
complex(kind=dbl),allocatable   :: Lgh(:,:), Sgh(:,:,:)
logical                 :: usehex, switchmirror, verbose

! Monte Carlo derived quantities
integer(kind=irg)       :: numEbins, numzbins, nsx, nsy, hdferr, nlines, lastEnergy, cn, dn, totn, cn2, totn2 ! variables used in MC energy file
real(kind=dbl)          :: EkeV, Ehistmin, Ebinsize, depthmax, depthstep, etotal ! enery variables from MC program
integer(kind=irg),allocatable :: thick(:), acc_z(:,:,:,:)
real(kind=sgl),allocatable :: lambdaE(:,:)
logical                 :: f_exists, readonly, overwrite=.TRUE., insert=.TRUE., stereog
character(fnlen, KIND=c_char),allocatable,TARGET :: stringarray(:)
character(fnlen,kind=c_char)                     :: line2(1)

integer(kind=irg)       :: imh, imk, iml, gg(3)
real(kind=sgl)          :: dhkl, ddt

type(unitcell),pointer          :: cell
type(DynType),save              :: Dyn
type(gnode),save                :: rlp
type(reflisttype),pointer       :: reflist,firstw, rltmp
type(BetheParameterType)        :: BetheParameters
type(kvectorlist),pointer       :: khead, ktmp
real(kind=sgl),allocatable      :: karray(:,:)
integer(kind=irg),allocatable   :: kij(:,:)
complex(kind=dbl),allocatable   :: DynMat(:,:)
character(fnlen)                :: dataset, instring
PROCEDURE(ProgressCallBack3), POINTER   :: proc

!$OMP THREADPRIVATE(rlp) 

! link the proc procedure to the cproc argument
CALL C_F_PROCPOINTER (cproc, proc)


! initalize a few variables
tpi = 2.D0*cPi
czero = dcmplx(0.D0,0.D0)

! parameters that would normally be read from the MC HDF5 file
npx = ipar(17)
nxten = ipar(16)
EkeV = fpar(3)
Ehistmin = fpar(4)
Ebinsize = fpar(5)
depthmax = fpar(6)
depthstep = fpar(7)
numEbins = ipar(12)
Estart = numEbins
numzbins = ipar(13)
num_el = ipar(3)
dmin = fpar(11)
nthreads = ipar(18)
etotal = dble(ipar(4))*dble(ipar(5))

! extract the BetheParameters ... 
BetheParameters%c1 = fpar(12)
BetheParameters%c2 = fpar(13)
BetheParameters%c3 = fpar(14)

!=============================================
!=============================================
! crystallography section

nullify(cell)
allocate(cell)


! lattice parameters
cell%a = dble(latparm(1))
cell%b = dble(latparm(2))
cell%c = dble(latparm(3))
cell%alpha = dble(latparm(4))
cell%beta = dble(latparm(5))
cell%gamma = dble(latparm(6))
! symmetry parameters
cell%xtal_system = ipar(8)
cell%SYM_SGset = ipar(11)
cell%SYM_SGnum = ipar(10)
if ((cell%SYM_SGnum.ge.143).and.(cell%SYM_SGnum.le.167)) then
  cell%SG%SYM_trigonal = .TRUE.
else
  cell%SG%SYM_trigonal = .FALSE.
end if 
! atom type and coordinate parameters
cell%ATOM_ntype = ipar(9)
cell%ATOM_type(1:cell%ATOM_ntype) = atomtypes(1:cell%ATOM_ntype) 
cell%ATOM_pos(1:cell%ATOM_ntype,1:5) = atompos(1:cell%ATOM_ntype,1:5) 
! generate the symmetry operations
cell%hexset = .FALSE.
if (cell%xtal_system.eq.4) cell%hexset = .TRUE.
if ((cell%xtal_system.eq.5).AND.(cell%SYM_SGset.ne.2)) cell%hexset = .TRUE.
! compute the metric matrices
 call CalcMatrices(cell)
! First generate the point symmetry matrices, then the actual space group.
! Get the symmorphic space group corresponding to the point group
! of the actual space group
 ipg=0
 do i=1,32
  if (SGPG(i).le.cell%SYM_SGnum) ipg=i
 end do
! if the actual group is also the symmorphic group, then both 
! steps can be done simultaneously, otherwise two calls to 
! GenerateSymmetry are needed.
 if (SGPG(ipg).eq.cell%SYM_SGnum) then
  call GenerateSymmetry(cell,.TRUE.)
 else
  isave = cell%SYM_SGnum
  cell%SYM_SGnum = SGPG(ipg)
  call GenerateSymmetry(cell,.TRUE.)
  cell%SYM_SGnum = isave
  call GenerateSymmetry(cell,.FALSE.)
 end if
! next we get all the atom positions
call CalcPositions(cell,'v')

! voltage will be set in the energyloop later on...
cell%voltage = dble(EkeV)
skip = 3        ! always use Weickenmeier&Kohl scattering coefficients, including absorptive form factors
call CalcWaveLength(cell,rlp,skip)

! compute the range of reflections for the lookup table and allocate the table
! The master list is easily created by brute force
 imh = 1
 do 
   dhkl = 1.0/CalcLength(cell,  (/float(imh) ,0.0_sgl,0.0_sgl/), 'r')
   if (dhkl.lt.dmin) EXIT
   imh = imh + 1
 end do
 imk = 1
 do 
   dhkl = 1.0/CalcLength(cell, (/0.0_sgl,float(imk),0.0_sgl/), 'r')
   if (dhkl.lt.dmin) EXIT
   imk = imk + 1
 end do
 iml = 1
 do 
   dhkl = 1.0/CalcLength(cell, (/0.0_sgl,0.0_sgl,float(iml)/), 'r')
   if (dhkl.lt.dmin) EXIT
   iml = iml + 1
 end do
  
! the LUT array stores all the Fourier coefficients, so that we only need to compute them once... i.e., here and now
 allocate(cell%LUT(-2*imh:2*imh,-2*imk:2*imk,-2*iml:2*iml),stat=istat)
 if (istat.ne.0) call FatalError('InitializeCell:',' unable to allocate cell%LUT array')
 cell%LUT = dcmplx(0.D0,0.D0)
 allocate(cell%LUTqg(-2*imh:2*imh,-2*imk:2*imk,-2*iml:2*iml),stat=istat)
 if (istat.ne.0) call FatalError('InitializeCell:',' unable to allocate cell%LUTqg array')
 cell%LUTqg = dcmplx(0.D0,0.D0)
 
! allocate an array that keeps track of potential double diffraction reflections
 allocate(cell%dbdiff(-2*imh:2*imh,-2*imk:2*imk,-2*iml:2*iml),stat=istat)
 if (istat.ne.0) call FatalError('InitializeCell:',' unable to allocate cell%dbdiff array')
 cell%dbdiff = .FALSE.
 ddt = 1.0e-5  
! changed from 1.0e-10 on 08/14/15 by MDG in response to some issues with double
! diffraction spots not being taken into account in EBSD master pattern simulations 

! next, we compute the overall lookup table cell%LUT; we do not, at this point, create a 
! list of linked reflections; in the old code, this was done at the same time, but it appears
! it is better to decouple these two computations. In this new approach, we'll compute a much
! shorter linked list based on the incident wave vector direction.

! first, we deal with the transmitted beam
 gg = (/ 0,0,0 /)
 call CalcUcg(cell,rlp,gg,applyqgshift=.TRUE.)  
 Dyn%Upz = rlp%Vpmod         ! U'0 normal absorption parameter 
 
! and add this reflection to the look-up table
 cell%LUT(0,0,0) = rlp%Ucg
 cell%LUTqg(0,0,0) = rlp%qg

! now do the same for the other allowed reflections
! note that the lookup table must be twice as large as the list of participating reflections,
! since the dynamical matrix uses g-h as its index !!!  
ixl: do ix=-2*imh,2*imh
iyl:  do iy=-2*imk,2*imk
izl:   do iz=-2*iml,2*iml
        gg = (/ ix, iy, iz /)
        if (IsGAllowed(cell,gg)) then  ! is this reflection allowed by lattice centering ?
! add the reflection to the look up table
           call CalcUcg(cell,rlp,gg,applyqgshift=.TRUE.)
           cell%LUT(ix, iy, iz) = rlp%Ucg
           cell%LUTqg(ix, iy, iz) = rlp%qg
! flag this reflection as a double diffraction candidate if cabs(Ucg)<ddt threshold
           if (cabs(rlp%Ucg).le.ddt) then 
             cell%dbdiff(ix,iy,iz) = .TRUE.
           end if
        end if ! IsGAllowed
       end do izl
      end do iyl
    end do ixl

! determine the point group number
 j=0
 do i=1,32
  if (SGPG(i).le.cell%SYM_SGnum) j=i
 end do
 isym = j

! here is new code dealing with all the special cases (quite a few more compared to the 
! Laue group case)...  isym is the point group number. Once the symmetry case has been
! fully determined (taking into account things like 31m and 3m1 an such), then the only places
! that symmetry is handled are the modified Calckvectors routine, and the filling of the modified
! Lambert projections after the dynamical simulation step.  We are also changing the name of the 
! sr array (or srhex) to mLPNH and mLPSH (modified Lambert Projection Northern/Southern Hemisphere).

! Here, we encode isym into a new number that describes the sampling scheme; the new schemes are 
! described in detail in the EBSD manual pdf file.
SamplingType = PGSamplingType(isym)

! next, intercept the special cases (hexagonal vs. rhombohedral cases that require special treatment)
if ((SamplingType.eq.-1).or.(isym.eq.14).or.(isym.eq.26)) then 
  SamplingType = getHexvsRho(cell,isym)
end if 

! if the point group is trigonal or hexagonal, we need to switch usehex to .TRUE. so that
! the program will use the hexagonal sampling method
usehex = .FALSE.
if ((cell%xtal_system.eq.4).or.(cell%xtal_system.eq.5)) usehex = .TRUE.

! ---------- end of symmetry and crystallography section
!=============================================
!=============================================

!=============================================
!=============================================
! this is where we determine the value for the thickness integration limit for the CalcLgh3 routine...
allocate(EkeVs(numEbins),thick(numEbins))

do i=1,numEbins
  EkeVs(i) = Ehistmin + float(i-1)*Ebinsize
end do

! then, for each energy determine the 95% histogram thickness
izzmax = 0
do iE = 1,numEbins
 do ix=-nxten,nxten
  do iy=-nxten,nxten
   istat = sum(accum_z(iE,:,ix,iy))
   izz = 1
   do while (sum(accum_z(iE,1:izz,ix,iy)).lt.(0.99*istat)) 
    izz = izz+1
   end do
   if (izz.gt.izzmax) izzmax = izz
  end do
 end do
 thick(iE) = dble(izzmax) * depthstep
end do

izz = nint(maxval(thick)/depthstep)
allocate(lambdaE(1:numEbins,1:izz),stat=istat)
do iE=1,numEbins
 do iz=1,izz
  lambdaE(iE,iz) = float(sum(accum_z(iE,iz,-nxten:nxten,-nxten:nxten)))/etotal
 end do
end do

! ---------- end of 'read Monte Carlo output file and extract necessary parameters' section
!=============================================
!=============================================

!=============================================
!=============================================
! ---------- a couple of initializations
   numset = cell % ATOM_ntype  
   npy = npx
   allocate(svals(numset),stat=istat)
   gzero = 1  ! index of incident beam
   debug = 0  ! no longer used
! ----------
!=============================================
!=============================================

!=============================================
!=============================================
! ---------- allocate memory for the master patterns (done in calling program)
! allocate(mLPNH(-emnl%npx:emnl%npx,-npy:npy,1,1:numset),stat=istat)
! allocate(mLPSH(-emnl%npx:emnl%npx,-npy:npy,1,1:numset),stat=istat)

! set various arrays to zero
   mLPNH = 0.0
   mLPSH = 0.0

! force dynamical matrix routine to read new Bethe parameters from file
! this will all be changed with the new version of the Bethe potentials
! these parameters were already defined above, having been passed in 
! from the external calling program
!  call Set_Bethe_Parameters(BetheParameters)

! set the callback parameters
dn = 1
cn = dn
cn2 = 0
totn2 = Estart

!=============================================
!=============================================
! ---------- from here on, we need to repeat the entire computation for each energy value
cancelerr = 0
energyloop: do iE=Estart,1,-1
   cn2 = cn2+dn 

! set the accelerating voltage
   skip = 3
   cell%voltage = dble(EkeVs(iE))
   call CalcWaveLength(cell, rlp, skip)

!=============================================
! ---------- create the incident beam directions list
! determine all independent incident beam directions (use a linked list starting at khead)
! numk is the total number of k-vectors to be included in this computation;
! note that this needs to be redone for each energy, since the wave vector changes with energy
   nullify(khead)
   if (usehex) then
    call Calckvectors(khead,cell, (/ 0.D0, 0.D0, 1.D0 /), (/ 0.D0, 0.D0, 0.D0 /),0.D0,npx,npy,numk, &
                SamplingType,ijmax,'RoscaLambert',usehex)
   else 
    call Calckvectors(khead,cell, (/ 0.D0, 0.D0, 1.D0 /), (/ 0.D0, 0.D0, 0.D0 /),0.D0,npx,npy,numk, &
                SamplingType,ijmax,'RoscaLambert',usehex)
   end if
   totn = numk
   cn = dn

! convert part of the kvector linked list into arrays for OpenMP
  allocate(karray(4,numk), kij(3,numk),stat=istat)
! point to the first beam direction
  ktmp => khead
! and loop through the list, keeping k, kn, and i,j
  karray(1:3,1) = sngl(ktmp%k(1:3))
  karray(4,1) = sngl(ktmp%kn)
  kij(1:3,1) = (/ ktmp%i, ktmp%j, ktmp%hs /)
   do ik=2,numk
     ktmp => ktmp%next
     karray(1:3,ik) = sngl(ktmp%k(1:3))
     karray(4,ik) = sngl(ktmp%kn)
     kij(1:3,ik) = (/ ktmp%i, ktmp%j, ktmp%hs /)
   end do
! and remove the linked list
  call Delete_kvectorlist(khead)

  verbose = .FALSE.
  totstrong = 0
  totweak = 0

! ---------- end of "create the incident beam directions list"
!=============================================

! here's where we introduce the OpenMP calls, to spead up the overall calculations...

! set the number of OpenMP threads 
  call OMP_SET_NUM_THREADS(nthreads)

! use OpenMP to run on multiple cores ... 
!$OMP PARALLEL COPYIN(rlp) &
!$OMP& PRIVATE(DynMat,Sgh,Lgh,ik,FN,TID,kn,ipx,ipy,ix,iequiv,nequiv,reflist,firstw) &
!$OMP& PRIVATE(kkk,nns,nnw,nref,svals,nat) SHARED(cancelerr)

  NUMTHREADS = OMP_GET_NUM_THREADS()
  TID = OMP_GET_THREAD_NUM()


!$OMP DO SCHEDULE(DYNAMIC,100)    
! ---------- and here we start the beam direction loop
   beamloop:do ik = 1,numk

!=============================================
! ---------- create the master reflection list for this beam direction
! Then we must determine the masterlist of reflections (also a linked list);
! This list basically samples a large reciprocal space volume; it does not 
! distinguish between zero and higher order Laue zones, since that 
! distinction becomes meaningless when we consider the complete 
! reciprocal lattice.  
     nullify(reflist)
     kkk = karray(1:3,ik)
     FN = kkk

     call Initialize_ReflectionList(cell, reflist, BetheParameters, FN, kkk, sngl(dmin), nref)
! ---------- end of "create the master reflection list"
!=============================================


! determine strong and weak reflections
     nullify(firstw)
     nns = 0
     nnw = 0
     call Apply_BethePotentials(cell, reflist, firstw, BetheParameters, nref, nns, nnw)

! generate the dynamical matrix
     allocate(DynMat(nns,nns))
     call GetDynMat(cell, reflist, firstw, rlp, DynMat, nns, nnw)
     totstrong = totstrong + nns
     totweak = totweak + nnw

! then we need to initialize the Sgh and Lgh arrays
     if (allocated(Sgh)) deallocate(Sgh)
     if (allocated(Lgh)) deallocate(Lgh)
     allocate(Sgh(nns,nns,numset),Lgh(nns,nns))
     Sgh = czero
     Lgh = czero
     nat = 0
     call CalcSgh(cell,reflist,nns,numset,Sgh,nat)

! solve the dynamical eigenvalue equation for this beam direction  
     kn = karray(4,ik)
     call CalcLgh(DynMat,Lgh,dble(thick(iE)),dble(kn),nns,gzero,depthstep,lambdaE(iE,1:izzmax),izzmax)
     deallocate(DynMat)

! sum over the element-wise (Hadamard) product of the Lgh and Sgh arrays 
     svals = 0.0
     do ix=1,numset
       svals(ix) = real(sum(Lgh(1:nns,1:nns)*Sgh(1:nns,1:nns,ix)))
     end do
     svals = svals/float(sum(nat(1:numset)))

! and store the resulting svals values, applying point group symmetry where needed.
     ipx = kij(1,ik)
     ipy = kij(2,ik)
     ipz = kij(3,ik)
!
     if (usehex) then 
       call Apply3DPGSymmetry(cell,ipx,ipy,ipz,npx,iequiv,nequiv,usehex)
     else
       if ((cell%SYM_SGnum.ge.195).and.(cell%SYM_SGnum.le.230)) then
         call Apply3DPGSymmetry(cell,ipx,ipy,ipz,npx,iequiv,nequiv,cubictype=SamplingType)
       else
         call Apply3DPGSymmetry(cell,ipx,ipy,ipz,npx,iequiv,nequiv)
       end if
     end if
!$OMP CRITICAL
     do ix=1,nequiv
       if (iequiv(3,ix).eq.-1) mLPSH(iequiv(1,ix),iequiv(2,ix),iE,1:numset) = svals(1:numset)
       if (iequiv(3,ix).eq.1) mLPNH(iequiv(1,ix),iequiv(2,ix),iE,1:numset) = svals(1:numset)
     end do
!$OMP END CRITICAL
  
     call Delete_gvectorlist(reflist)

! has the cancel flag been set by the calling program ?
!!!!$OMP CANCELLATION POINT
    if(cancel.ne.char(0)) then
!$OMP ATOMIC WRITE
       cancelerr = 1
!$OMP CANCEL DO
    end if 

! update the progress counter and report it to the calling program via the proc callback routine
!$OMP CRITICAL
   if(objAddress.ne.0) then
     cn = cn+dn
     if (mod(cn,1000).eq.0) then 
       call proc(objAddress, cn, totn, cn2, totn2)
     end if
   end if
!$OMP END CRITICAL

    end do beamloop

! end of OpenMP portion
!$OMP END PARALLEL
  
! was the Cancel button pressed in the calling program?
  if(cancelerr.ne.0) EXIT energyloop

  deallocate(karray, kij)

 if (usehex) then
! and finally, we convert the hexagonally sampled array to a square Lambert projection which will be used 
! for all EBSD pattern interpolations;  we need to do this for both the Northern and Southern hemispheres

! we begin by allocating auxiliary arrays to hold copies of the hexagonal data; the original arrays will
! then be overwritten with the newly interpolated data.
  allocate(auxNH(-npx:npx,-npy:npy,1:numset),stat=istat)
  allocate(auxSH(-npx:npx,-npy:npy,1:numset),stat=istat)
  auxNH = mLPNH(-npx:npx,-npy:npy,iE,1:numset)
  auxSH = mLPSH(-npx:npx,-npy:npy,iE,1:numset)

! 
  edge = 1.D0 / dble(npx)
  scl = float(npx) 
  do i=-npx,npx
    do j=-npy,npy
! determine the spherical direction for this point
      xy = (/ dble(i), dble(j) /) * edge
      dc = LambertSquareToSphere(xy, ierr)
! convert direction cosines to hexagonal Lambert projections
      xy = scl * LambertSphereToHex( dc, ierr )
! interpolate intensity from the neighboring points
      if (ierr.eq.0) then 
        nix = floor(xy(1))
        niy = floor(xy(2))
        nixp = nix+1
        niyp = niy+1
        if (nixp.gt.npx) nixp = nix
        if (niyp.gt.npx) niyp = niy
        dx = xy(1) - nix
        dy = xy(2) - niy
        dxm = 1.D0 - dx
        dym = 1.D0 - dy
        mLPNH(i,j,iE,1:numset) = auxNH(nix,niy,1:numset)*dxm*dym + auxNH(nixp,niy,1:numset)*dx*dym + &
                             auxNH(nix,niyp,1:numset)*dxm*dy + auxNH(nixp,niyp,1:numset)*dx*dy
        mLPSH(i,j,iE,1:numset) = auxSH(nix,niy,1:numset)*dxm*dym + auxSH(nixp,niy,1:numset)*dx*dym + &
                             auxSH(nix,niyp,1:numset)*dxm*dy + auxSH(nixp,niyp,1:numset)*dx*dy
      end if
    end do
  end do
  deallocate(auxNH, auxSH)
 end if

! make sure that the outer pixel rim of the mLPSH patterns is identical to
! that of the mLPNH array.
 mLPSH(-npx,-npx:npx,iE,1:numset) = mLPNH(-npx,-npx:npx,iE,1:numset)
 mLPSH( npx,-npx:npx,iE,1:numset) = mLPNH( npx,-npx:npx,iE,1:numset)
 mLPSH(-npx:npx,-npx,iE,1:numset) = mLPNH(-npx:npx,-npx,iE,1:numset)
 mLPSH(-npx:npx, npx,iE,1:numset) = mLPNH(-npx:npx, npx,iE,1:numset)


end do energyloop

! that's the end of it...

end subroutine EMsoftCgetEBSDmaster

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------


!--------------------------------------------------------------------------
!
! SUBROUTINE:getEBSDPatterns
!
!> @author Marc De Graef, Carnegie Mellon University
!
!> @brief This function can be called as a standalone function to compute an EBSD pattern
!
!> @etails The main purpose of this routine and its accompanying wrapper routine is to
!> provide a way for an external program to compute a channeling pattern.  The idea is that 
!> all the necessary arrays and variables are passed in by reference as arguments, without
!> the need for the routine to fetch any other data from files etc...  The initial goal is
!> to have a function that can be called with the CALL_EXTERNAL mechanism in IDL or MatLab.
!> This routine should be called via the getEBSDPatternsWrapper routine!  For calls from
!> a C/C++ program, use the EMsoftCgetEBSDPatterns routine instead.
!
!> @param ipar array with integer input parameters
!> @param fpar array with float input parameters
!> @param EBSDpattern output array
!> @param quats quaternion input array
!> @param accum_e array with Monte Carlo histogram
!> @param mLPNH Northern hemisphere master pattern
!> @param mLPSH Southern hemisphere master pattern
!
!> @date 10/16/15 MDG 1.0 original
!> @date 11/02/15 MDG 1.1 simplification of the input variables
!> @date 11/04/15 MDG 1.2 added array of quaternions as input parameter; used complete mLPNH/SH arrays with local sum
!> @date 01/12/15 MDG 1.3 added arguments and functionality for interface with DREAM.3D and other calling programs
!> @date 01/13/15 MDG 1.4 after split with EMsoftCgetEBSDPatterns subroutine, removed DREAM.3D interfacing stuff
!> @date 07/10/16 MDG 1.5 added energy min/max parameters
!> @date 08/03/16 MDG 1.6 corrected normalizing issue in rgx,y,z arrays that causes NANs to be returned from Lambert projection routines
!> @date 08/R2516 MDG 1.7 added transfer optics barrel distortion to rgx,y,z arrays.
!--------------------------------------------------------------------------
recursive subroutine getEBSDPatterns(ipar, fpar, EBSDpattern, quats, accum_e, mLPNH, mLPSH)
!DEC$ ATTRIBUTES DLLEXPORT :: getEBSDPatterns

! the input parameters are all part of a ipar and fpar input arrays instead of the usual namelist structure to
! make this routine callable by external programs; for calls from  C/C++, use the EsoftCgetEBSDPatterns routine instead.  

! The following is the mapping for the ipar and fpar arrays:
!
! ipar(1) = 2 if rgx, rgy, rgz detector arrays need to be computed, 1 if not (arrays will have save status)
! ipar(2) = detnumsx
! ipar(3) = detnumsy
! ipar(4) = detnumEbins
! ipar(5) = mcnsx
! ipar(6) = mpnpx
! ipar(7) = numset
! ipar(8) = numquats
! ipar(9) = Eminsel
! ipar(10) = Emaxsel

! fpar(1) = enl%xpc
! fpar(2) = enl%ypc
! fpar(3) = enl%delta
! fpar(4) = enl%MCsig
! fpar(5) = enl%omega
! fpar(6) = enl%thetac
! fpar(7) = enl%L
! fpar(8) = enl%beamcurrent
! fpar(9) = enl%dwelltime
! fpar(10) = enl%alphaBD

use local
use constants
use Lambert
use quaternions
use,INTRINSIC :: ISO_C_BINDING

IMPLICIT NONE

integer(c_size_t),PARAMETER             :: nipar=10
integer(c_size_t),PARAMETER             :: nfpar=10
integer(c_size_t),PARAMETER             :: nq=4
integer(c_size_t),INTENT(IN)            :: ipar(nipar)
real(kind=sgl),INTENT(IN)               :: fpar(nfpar)
real(kind=sgl),INTENT(IN)               :: quats(nq,ipar(8))
real(kind=sgl),INTENT(IN)               :: accum_e(ipar(4),-ipar(5):ipar(5),-ipar(5):ipar(5))
real(kind=sgl),INTENT(IN)               :: mLPNH(-ipar(6):ipar(6), -ipar(6):ipar(6), ipar(4), ipar(7))
real(kind=sgl),INTENT(IN)               :: mLPSH(-ipar(6):ipar(6), -ipar(6):ipar(6), ipar(4), ipar(7))
real(kind=sgl),INTENT(OUT)              :: EBSDpattern(ipar(2),ipar(3),ipar(8))

! variables that must potentially be saved for the next time this function is called
real(kind=sgl),allocatable,save         :: accum_e_detector(:,:,:)
real(kind=sgl),allocatable,save         :: rgx(:,:), rgy(:,:), rgz(:,:)
real(kind=sgl),allocatable,save         :: mLPNHsum(:,:,:), mLPSHsum(:,:,:)
real(kind=sgl),save                     :: prefactor

! other variables
real(kind=sgl),allocatable              :: scin_x(:), scin_y(:)                 ! scintillator coordinate arrays [microns]
real(kind=sgl),parameter                :: dtor = 0.0174533  ! convert from degrees to radians
real(kind=sgl)                          :: alp, ca, sa, cw, sw
real(kind=sgl)                          :: L2, Ls, Lc, pcxd, pcyd, xx, yy     ! distances
integer(kind=irg)                       :: nix, niy, binx, biny,  nixp, niyp, i, j, Emin, Emax, istat, k, ip, ipx, ipy ! various parameters
real(kind=sgl)                          :: dc(3), scl, alpha, theta, gam, pcvec(3), dp, calpha           ! direction cosine array
real(kind=sgl)                          :: sx, dx, dxm, dy, dym, rhos, x, bindx         ! various parameters
real(kind=sgl)                          :: ixy(2)
real(kind=dbl),parameter                :: nAmpere = 6.241D+18 

!====================================
! ------ generate the detector rgx, rgy, rgz arrays if needed (calling program must decide this via ipar(1))
!====================================
if (ipar(1).ge.1) then

  if ((ipar(1).eq.2).or.(.not.allocated(mLPNHsum))) then ! complete reset, including the mLPNHsum and mLPSHsum arrays
    if (allocated(mLPNHsum)) deallocate(mLPNHsum)
    if (allocated(mLPSHsum)) deallocate(mLPSHsum)

    allocate(mLPNHsum(-ipar(6):ipar(6), -ipar(6):ipar(6), ipar(4)))
    allocate(mLPSHsum(-ipar(6):ipar(6), -ipar(6):ipar(6), ipar(4)))
    mLPNHsum = sum(mLPNH,4)
    mLPSHsum = sum(mLPSH,4)

  end if

! This needs to be done only once for a given detector geometry (i.e., when ipar(1)=1 or larger)
  allocate(scin_x(ipar(2)),scin_y(ipar(3)),stat=istat)
  
  pcxd = fpar(1) * fpar(3)
  pcyd = fpar(2) * fpar(3)

  scin_x = - ( fpar(1) - ( 1.0 - float(ipar(2)) ) * 0.5 - (/ (i-1, i=1,ipar(2)) /) ) * fpar(3)
  scin_y = ( fpar(2) - ( 1.0 - float(ipar(3)) ) * 0.5 - (/ (i-1, i=1,ipar(3)) /) ) * fpar(3)

! auxiliary angle to rotate between reference frames
  alp = 0.5 * cPi - (fpar(4) - fpar(6)) * dtor
  ca = cos(alp)
  sa = sin(alp)

  cw = cos(fpar(5) * dtor)
  sw = sin(fpar(5) * dtor)

! compute auxilliary interpolation arrays
  if (allocated(rgx)) deallocate(rgx, rgy, rgz)

  allocate(rgx(ipar(2),ipar(3)), rgy(ipar(2),ipar(3)), rgz(ipar(2),ipar(3)))

! do we need to perform a Barrel Distortion?
! we will do this here by expanding/contracting the radial component of the 
! (rgx, rgy) to (rgx,rgy) * (1+alphaBD * (rgx^2+rgy^2))
! in other words, we pre-distort the sampling grid with the barrel distortion.

  L2 = fpar(7) * fpar(7)
  do j=1,ipar(2)
    Ls = -sw * scin_x(j) + fpar(7) * cw
    Lc = cw * scin_x(j) + fpar(7) * sw
    do i=1,ipar(3)
!    rhos = 1.0/sqrt(sx + scin_y(i)**2)
     rgx(j,i) = (scin_y(i) * ca + sa * Ls) ! * rhos
     rgy(j,i) = Lc ! * rhos
     rgz(j,i) = (-sa * scin_y(i) + ca * Ls) ! * rhos
! apply Barrel Distortion ?
     if (fpar(10).ne.0.0) then
! shift the components to the detector center coordinate frame
       xx = rgx(j,i)-pcyd
       yy = rgy(j,i)+pcxd
! compute the distortion amount; the factor of 10^(-10) is inserted here...
       sx = 1.0 + 1.E-10 * fpar(10) * (xx**2+yy**2) 
! and shift them back to the pattern center reference frame
       rgx(j,i) = xx*sx+pcyd
       rgy(j,i) = yy*sx-pcxd
     end if
! make sure that these vectors are normalized !
     x = sqrt(rgx(j,i)**2+rgy(j,i)**2+rgz(j,i)**2)
     rgx(j,i) = rgx(j,i) / x
     rgy(j,i) = rgy(j,i) / x
     rgz(j,i) = rgz(j,i) / x
    end do
  end do

! test dump of rgx/y/z arrays to check for proper inclusion of barrel distortion:
!open(unit=dataunit,file='rgxyz.data',status='unknown',form='unformatted')
!write(dataunit) rgx
!write(dataunit) rgy
!write(dataunit) rgz
!close(unit=dataunit,status='keep')

! remove the auxiliary arrays scin_x and scin_y
  deallocate(scin_x, scin_y)

!====================================
! ------ create the equivalent detector energy array
!====================================
! from the Monte Carlo energy data, we need to extract the relevant
! entries for the detector geometry defined above.  

! determine the scale factor for the Lambert interpolation; the square has
! an edge length of 2 x sqrt(pi/2)
  scl = float(ipar(5)) 

! energy summation will go over all energy bins
  Emin = ipar(9)
  Emax = ipar(10)

  if (allocated(accum_e_detector)) deallocate(accum_e_detector)

  allocate(accum_e_detector(ipar(4),ipar(2),ipar(3)))

! correction of change in effective pixel area compared to equal-area Lambert projection
  alpha = atan(fpar(3)/fpar(7)/sqrt(sngl(cPi)))
  ipx = ipar(2)/2 + nint(fpar(1))
  ipy = ipar(3)/2 + nint(fpar(2))
  
  if (ipx .gt. ipar(2)) ipx = ipar(2)
  if (ipx .lt. 1) ipx = 1
  
  if (ipy .gt. ipar(3)) ipy = ipar(3)
  if (ipy .lt. 1) ipy = 1
  
  pcvec = (/ rgx(ipx,ipy), rgy(ipx,ipy), rgz(ipx,ipy) /)
  calpha = cos(alpha)
  do i=1,ipar(2)
    do j=1,ipar(3)
! do the coordinate transformation for this detector pixel
       dc = (/ rgx(i,j), rgy(i,j), rgz(i,j) /)
! make sure the third one is positive; if not, switch all 
       if (dc(3).lt.0.0) dc = -dc
! convert these direction cosines to coordinates in the Rosca-Lambert projection
        ixy = scl * LambertSphereToSquare( dc, istat )
        x = ixy(1)
        ixy(1) = ixy(2)
        ixy(2) = -x
! four-point interpolation (bi-quadratic)
        nix = int(ipar(5)+ixy(1))-ipar(5)
        niy = int(ipar(5)+ixy(2))-ipar(5)
        nixp = nix+1
        niyp = niy+1
        if (nix .gt. ipar(5)) nix = ipar(5)
        if (niy .gt. ipar(5)) niy = ipar(5)
        if (nix .lt. -ipar(5)) nix = -ipar(5)
        if (niy .lt. -ipar(5)) niy = -ipar(5)

        if (nixp .gt. ipar(5)) nixp = ipar(5)
        if (niyp .gt. ipar(5)) niyp = ipar(5)
        if (nixp .lt. -ipar(5)) nixp = -ipar(5)
        if (niyp .lt. -ipar(5)) niyp = -ipar(5)

        dx = ixy(1)-nix
        dy = ixy(2)-niy
        dxm = 1.0-dx
        dym = 1.0-dy
! do the area correction for this detector pixel
        dp = dot_product(pcvec,dc)
        if ((i.eq.ipx).and.(j.eq.ipy)) then
          gam = 0.25 
        else
          gam = ((calpha*calpha + dp*dp - 1.0)**1.5)/(calpha**3) * 0.25
        end if
! interpolate the intensity 
        do k= Emin, Emax
          accum_e_detector(k,i,j) = gam * (accum_e(k,nix,niy) * dxm * dym + &
                                    accum_e(k,nixp,niy) * dx * dym + &
                                    accum_e(k,nix,niyp) * dxm * dy + &
                                    accum_e(k,nixp,niyp) * dx * dy)
        end do
    end do
  end do 
  prefactor = 0.25D0 * nAmpere * fpar(8) * fpar(9)  * 1.0D-15 / sum(accum_e_detector)
end if   ! end of ipar(1)=1 test

! from here on, we simply compute the EBSD patterns by interpolation, using the saved arrays from above
! no intensity scaling or anything else...other than multiplication by pre-factor
! intensity scaling is left to the user of the calling program.

! define some parameters and initialize EBSDpattern
scl = dble(ipar(6)) 
EBSDpattern = 0.0

! here is the main loop over all quaternions
quatloop: do ip=1,ipar(8)
  do i=1,ipar(2)
    do j=1,ipar(3)
! do the active coordinate transformation for this euler angle
      dc = quat_Lp(quats(1:4,ip),  (/ rgx(i,j), rgy(i,j), rgz(i,j) /) )
! normalize dc
      dc = dc/sqrt(sum(dc*dc))
! convert these direction cosines to coordinates in the Rosca-Lambert projection (always square projection !!!)
      ixy = scl * LambertSphereToSquare( dc, istat )

      if (istat.eq.0) then 
! four-point interpolation (bi-quadratic)
        nix = int(ipar(6)+ixy(1))-ipar(6)
        niy = int(ipar(6)+ixy(2))-ipar(6)
        nixp = nix+1
        niyp = niy+1
        if (nix .gt. ipar(6)) nix = ipar(6)
        if (niy .gt. ipar(6)) niy = ipar(6)
        if (nix .lt. -ipar(6)) nix = -ipar(6)
        if (niy .lt. -ipar(6)) niy = -ipar(6)

        if (nixp .gt. ipar(6)) nixp = ipar(6)
        if (niyp .gt. ipar(6)) niyp = ipar(6)
        if (nixp .lt. -ipar(6)) nixp = -ipar(6)
        if (niyp .lt. -ipar(6)) niyp = -ipar(6)

        dx = ixy(1)-nix
        dy = ixy(2)-niy
        dxm = 1.0-dx
        dym = 1.0-dy
        if (dc(3).gt.0.0) then ! we're in the Northern hemisphere
          do k=Emin,Emax
            EBSDpattern(i,j,ip) = EBSDpattern(i,j,ip) + accum_e_detector(k,i,j) * ( mLPNHsum(nix,niy,k) * dxm * dym +&
                                        mLPNHsum(nixp,niy,k) * dx * dym + mLPNHsum(nix,niyp,k) * dxm * dy + &
                                        mLPNHsum(nixp,niyp,k) * dx * dy )
          end do
        else                   ! we're in the Southern hemisphere
          do k=Emin,Emax 
            EBSDpattern(i,j,ip) = EBSDpattern(i,j,ip) + accum_e_detector(k,i,j) * ( mLPSHsum(nix,niy,k) * dxm * dym +&
                                        mLPSHsum(nixp,niy,k) * dx * dym + mLPSHsum(nix,niyp,k) * dxm * dy + &
                                        mLPSHsum(nixp,niyp,k) * dx * dy )
          end do
        end if
      end if
    end do
  end do
end do quatloop

! finally, scale the patterns by the appropriate factor and return to the calling program
EBSDpattern = prefactor * EBSDpattern

end subroutine getEBSDPatterns



!--------------------------------------------------------------------------
!
! SUBROUTINE:getECPatterns
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief This function can be called as a standalone function to compute an electron channeling pattern
!> based on Marc's code above
!
!> @etails The main purpose of this routine and its accompanying wrapper routine is to
!> provide a way for an external program to compute an EC pattern.  The idea is that 
!> all the necessary arrays and variables are passed in by reference as arguments, without
!> the need for the routine to fetch any other data from files etc...  The initial goal is
!> to have a function that can be called with the CALL_EXTERNAL mechanism in IDL, but 
!> in the long run this will also be the approach for calling the routine from C/C++, which
!> is an essential part of integration with DREAM.3D.  This routine is a simplified version
!> of the core of the EMECP program. 
!>
!> This routine will first compute the incident cone vectors etc. if necessary, and then perform
!> the usual interpolation from the square Lambert projection. The pattern will be a basic pattern,
!> without any intensity scaling or binning etc; the calling program should take care of those 
!> operations.
!
!> @param ipar array with integer input parameters
!> @param fpar array with float input parameters
!> @param ECPattern output array
!> @param quats array of quaternions
!> @param accum_e array with Monte Carlo histogram
!> @param mLPNH Northern hemisphere master pattern
!> @param mLPSH Southern hemisphere master pattern
!
!> @date 10/16/15  SS 1.0 original
!> @date 11/02/14 MDG 1.1 put all integer parameters inside ipar and fixed size of ipar/fpar
!> @date 11/04/15 MDG 1.2 added array of quaternions as input parameter
!--------------------------------------------------------------------------
recursive subroutine getECPatterns(ipar, fpar, ECpattern, quats, accum_e, mLPNH, mLPSH)
!DEC$ ATTRIBUTES DLLEXPORT :: GetECPatterns

! the input parameters are all part of a ipar and fpar input arrays instead of the usual namelist structures.
! The following is the mapping:
!
! ipar(1) = 1 if GetVectorsCone detector arrays need to be computed, 0 if not (arrays will have save status)
! ipar(2) = detnumsx
! ipar(3) = detnumsy
! ipar(4) = numangle
! ipar(5) = mcnsx
! ipar(6) = numset
! ipar(7) = mpnpx
! ipar(8) = numquats

! fpar(1) = ecpnl%thetac
! fpar(2) = ecpnl%sampletilt
! fpar(3) = ecpnl%workingdistance
! fpar(4) = ecpnl%Rin
! fpar(5) = ecpnl%Rout
! fpar(6) = ecpnl%sigstart
! fpar(7) = ecpnl%sigend
! fpar(8) = ecpnl%sigstep

!!!!!!!! removed:  fpar(9-12) =  quaternion for requested Euler angles

use local
use constants
use Lambert
use quaternions
use distortion
use,INTRINSIC :: ISO_C_BINDING

IMPLICIT NONE

integer(c_size_t),PARAMETER             :: nipar=8
integer(c_size_t),PARAMETER             :: nfpar=8
integer(c_size_t),PARAMETER             :: nq=4
integer(c_size_t),INTENT(IN)            :: ipar(nipar)
real(kind=sgl),INTENT(IN)               :: fpar(nfpar)
real(kind=sgl),INTENT(OUT)              :: ECpattern(ipar(2),ipar(3),ipar(8))
real(kind=sgl),INTENT(IN)               :: quats(nq,ipar(8))
real(kind=sgl),INTENT(IN)               :: accum_e(ipar(4),-ipar(5):ipar(5),-ipar(5):ipar(5))
real(kind=sgl),INTENT(IN)               :: mLPNH(-ipar(7):ipar(7), -ipar(7):ipar(7), ipar(6))
real(kind=sgl),INTENT(IN)               :: mLPSH(-ipar(7):ipar(7), -ipar(7):ipar(7), ipar(6))

real(kind=sgl),allocatable,save         :: klist(:,:,:), rgx(:,:), rgy(:,:), rgz(:,:), weightfact(:)
real(kind=sgl),allocatable,save         :: mLPNHsum(:,:), mLPSHsum(:,:)

real(kind=dbl),parameter                :: Rtod = 57.2957795131D0
real(kind=dbl),parameter                :: dtoR = 0.01745329251D0

real(kind=sgl)                          :: kk(3), thetacr, ktmax, delta, wf, quat(4)
integer(kind=irg)                       :: istat, imin, imax, jmin, jmax, ii ,jj, nazimuth, npolar, nsig, ip
integer(kind=irg)                       :: ipolar, iazimuth, isig, isampletilt, nix, niy, nixp, niyp, isigp
real(kind=sgl)                          :: thetain, thetaout, polar, azimuthal, delpolar, delazimuth, om(3,3)
real(kind=sgl)                          :: dc(3), scl, deltheta, acc_sum, MCangle, ixy(2), dx, dy, dxm, dym, dp


!==================================================================================
! ------ generate the detector klist, rgx, rgy, rgz, weightfactors arrays if needed 
!------- (calling program must decide this via ipar(1))
!==================================================================================

imin = 1
imax = ipar(2)
jmin = 1
jmax = ipar(3)

if (ipar(1).ge.1) then

  if (ipar(1).eq.2) then ! complete reset, including the mLPNHsum and mLPSHsum arrays
    if (allocated(mLPNHsum)) deallocate(mLPNHsum)
    if (allocated(mLPSHsum)) deallocate(mLPSHsum)

    allocate(mLPNHsum(-ipar(7):ipar(7), -ipar(7):ipar(7)))
    allocate(mLPSHsum(-ipar(7):ipar(7), -ipar(7):ipar(7)))
    mLPNHsum = sum(mLPNH,3)
    mLPSHsum = sum(mLPSH,3)
  end if

    if (allocated(klist)) deallocate(klist)
    allocate(klist(1:3,1:ipar(2),1:ipar(3)), stat=istat)
    kk = (/0.0,0.0,1.0/)
    thetacr = DtoR*fpar(1)
    ktmax = tan(thetacr)
    delta = 2.0*ktmax/dble(ipar(2)-1)
     
    do ii = imin, imax
        do jj = jmin, jmax
            klist(1:3,ii,jj) = (/-ktmax+delta*(ii-1),-ktmax+delta*(jj-1),0.0/) + kk(1:3)
            klist(1:3,ii,jj) =  klist(1:3,ii,jj)/sqrt(sum( klist(1:3,ii,jj)**2))
        end do
    end do

    thetain = atan2(fpar(4),fpar(3))
    thetaout = atan2(fpar(5),fpar(3))

    om(1,:) = (/cos(fpar(2)*sngl(dtor)),0.0,sin(fpar(2)*sngl(dtor))/)
    om(2,:) = (/0.0,1.0,0.0/)
    om(3,:) = (/-sin(fpar(2)*sngl(dtor)),0.0,cos(fpar(2)*sngl(dtor))/)

    npolar = nint((thetaout - thetain)*180.0/cPi) + 1
    delpolar = (thetaout - thetain)/float(npolar-1)

    nazimuth = 361
    delazimuth = 2.0*cPi/float(nazimuth-1)

    if (allocated(rgx)) deallocate(rgx, rgy, rgz)
    allocate(rgx(npolar, nazimuth), rgy(npolar, nazimuth), rgz(npolar, nazimuth), stat=istat)

    do ipolar = 1,npolar
         polar = thetain + float(ipolar-1)*delpolar

         do iazimuth = 1,nazimuth
             azimuthal = float(iazimuth-1)*delazimuth

             dc(1) = cos(azimuthal)*sin(polar)
             dc(2) = sin(azimuthal)*sin(polar)
             dc(3) = cos(polar)

             dc = matmul(om,dc)

             rgx(ipolar,iazimuth) = dc(1)
             rgy(ipolar,iazimuth) = dc(2)
             rgz(ipolar,iazimuth) = dc(3)
        end do
    end do

!===================================================================
! ------ generate the weight factors from the monte carlo histogram
!===================================================================

    scl = float(ipar(5))
    nsig = nint(fpar(1) + abs(fpar(2))) + 1

    deltheta = (fpar(1)+abs(fpar(2)))/float(nsig-1)

    if (allocated(weightfact)) deallocate(weightfact)
    allocate(weightfact(1:nsig), stat=istat)
    weightfact = 0.0

    do isig = 1,nsig
        acc_sum = 0.0
        MCangle = (isig - 1)*deltheta
        isampletilt = nint((MCangle - fpar(6))/fpar(8))
    
        if (isampletilt .lt. 1) then
            isampletilt = abs(isampletilt) + 1
        else
            isampletilt = isampletilt + 1
        end if

        do ipolar = 1,npolar
            do iazimuth = 1,nazimuth
                dc(1:3) = (/rgx(ipolar,iazimuth), rgy(ipolar,iazimuth), rgz(ipolar,iazimuth)/)
! convert to Rosca-lambert projection
                ixy = scl *  LambertSphereToSquare( dc, istat )
                nix = int(ipar(5)+ixy(1))-ipar(5)
                niy = int(ipar(5)+ixy(2))-ipar(5)
                nixp = nix+1
                niyp = niy+1
                if (nixp.gt.ipar(5)) nixp = nix
                if (niyp.gt.ipar(5)) niyp = niy
                if (nix.lt.-ipar(5)) nix = nixp
                if (niy.lt.-ipar(5)) niy = niyp
                dx = ixy(1)-nix
                dy = ixy(2)-niy
                dxm = 1.0-dx
                dym = 1.0-dy
            
                acc_sum = 0.25*(accum_e(isampletilt,nix,niy) * dxm * dym + &
                                accum_e(isampletilt,nixp,niy) * dx * dym + &
                                accum_e(isampletilt,nix,niyp) * dxm * dy + &
                                accum_e(isampletilt,nixp,niyp) * dx * dy)
             
                weightfact(isig) = weightfact(isig) + acc_sum

            end do
        end do
    end do

    weightfact(1:nsig) = weightfact(1:nsig)/weightfact(1)

end if

!===================================================================
! ------ perform interpolation from square lambert map
!===================================================================
scl = float(ipar(7))

do ip=1,ipar(8)
  do ii = imin, imax
    do jj = jmin, jmax

        dc(1:3) = klist(1:3,ii,jj)
        dc = dc/sqrt(sum(dc*dc))
        
        dp = DOT_PRODUCT(dc(1:3),(/sin(fpar(2)*dtoR),0.D0,cos(fpar(2)*dtoR)/))      
        if (dp .gt. 1.D0) dp = 1.0
        MCangle = acos(dp)*Rtod
        isig = int(MCangle) + 1
        if (isig .gt. nsig) isig = nsig

        isigp = isig + 1
        if (isigp .gt. nsig) isigp = nsig
        dx = MCangle - int(MCangle)
        dxm =  1.0 - dx
        
        wf = weightfact(isig) * dxm + weightfact(isigp) * dx
        wf = 1.0
        dc = quat_LP(quats(1:4,ip), dc)
        dc = dc/sqrt(sum(dc*dc))

        ixy = scl * LambertSphereToSquare( dc, istat )
        nix = int(ipar(7)+ixy(1))-ipar(7)
        niy = int(ipar(7)+ixy(2))-ipar(7)
        nixp = nix+1
        niyp = niy+1
        if (nixp.gt.ipar(7)) nixp = nix
        if (niyp.gt.ipar(7)) niyp = niy
        if (nix.lt.-ipar(7)) nix = nixp
        if (niy.lt.-ipar(7)) niy = niyp
        dx = ixy(1)-nix
        dy = ixy(2)-niy
        dxm = 1.0-dx
        dym = 1.0-dy

        if (dc(3).gt.0.0) then 
            ECpattern(ii,jj,ip) = wf * ( mLPNHsum(nix,niy) * dxm * dym + &
                         mLPNHsum(nixp,niy) * dx * dym + &
                         mLPNHsum(nix,niyp) * dxm * dy + &
                         mLPNHsum(nixp,niyp) * dx * dy )

        else
            ECpattern(ii,jj,ip) =  wf * ( mLPSHsum(nix,niy) * dxm * dym + &
                         mLPSHsum(nixp,niy) * dx * dym + &
                         mLPSHsum(nix,niyp) * dxm * dy + &
                         mLPSHsum(nixp,niyp) * dx * dy )
        end if

    end do
  end do
end do


end subroutine getECPatterns

!--------------------------------------------------------------------------
!
! SUBROUTINE:getKosselPatterns
!
!> @author Marc De Graef, Carnegie Mellon University
!
!> @brief This function can be called as a standalone function to compute a Kossel pattern
!
!> @etails The main purpose of this routine and its accompanying wrapper routine is to
!> provide a way for an external program to compute a Kossel pattern.  The idea is that 
!> all the necessary arrays and variables are passed in by reference as arguments, without
!> the need for the routine to fetch any other data from files etc...  The initial goal is
!> to have a function that can be called with the CALL_EXTERNAL mechanism in IDL, but 
!> in the long run this will also be the approach for calling the routine from C/C++, which
!> is an essential part of integration with DREAM.3D.  
!>
!> This routine will first compute the incident cone vectors etc. if necessary, and then perform
!> the usual interpolation from the square Lambert projection. The pattern will be a basic pattern,
!> without any intensity scaling or binning etc; the calling program should take care of those 
!> operations. This is simpler than the ECP case, since there is no energy dependent stuff to 
!> worry about. We're also keeping the ipar and fpar arrays the same as for the ECP case, even
!> though we could in principle simplify them; this facilitates integration with the SEMDisplay 
!> program.
!
!> @param ipar array with integer input parameters
!> @param fpar array with float input parameters
!> @param KosselPattern output array
!> @param quats array of quaternions
!> @param mLPNH Northern hemisphere master pattern
!> @param mLPSH Southern hemisphere master pattern
!
!> @date 11/09/15 MDG 1.0 original
!--------------------------------------------------------------------------
recursive subroutine getKosselPatterns(ipar, fpar, Kosselpattern, quats, mLPNH, mLPSH)
!DEC$ ATTRIBUTES DLLEXPORT :: getKosselPatterns

! the input parameters are all part of a ipar and fpar input arrays instead of the usual namelist structures.
! The following is the mapping:
!
! ipar(1) = 1 if GetVectorsCone detector arrays need to be computed, 0 if not (arrays will have save status)
! ipar(2) = detnumsx
! ipar(3) = mpnpx
! ipar(4) = numquats
! ipar(5) = numdepths
! ipar(6) = depthsel

! fpar(1) = ecpnl%thetac

use local
use constants
use Lambert
use quaternions
use,INTRINSIC :: ISO_C_BINDING

IMPLICIT NONE

integer(c_size_t),PARAMETER             :: nipar=6
integer(c_size_t),PARAMETER             :: nfpar=1
integer(c_size_t),PARAMETER             :: nq=4
integer(c_size_t),INTENT(IN)            :: ipar(nipar)
real(kind=sgl),INTENT(IN)               :: fpar(nfpar)
real(kind=sgl),INTENT(OUT)              :: Kosselpattern(ipar(2),ipar(2),ipar(4))
real(kind=sgl),INTENT(IN)               :: quats(nq,ipar(4))
real(kind=sgl),INTENT(IN)               :: mLPNH(-ipar(3):ipar(3), -ipar(3):ipar(3),ipar(5))
real(kind=sgl),INTENT(IN)               :: mLPSH(-ipar(3):ipar(3), -ipar(3):ipar(3),ipar(5))

real(kind=sgl),allocatable,save         :: klist(:,:,:)

real(kind=dbl),parameter                :: Rtod = 57.2957795131D0
real(kind=dbl),parameter                :: dtoR = 0.01745329251D0

real(kind=sgl)                          :: kk(3), thetacr, ktmax, delta, quat(4)
integer(kind=irg)                       :: istat, imin, imax, jmin, jmax, ii ,jj, nsig, ip
integer(kind=irg)                       :: isig, nix, niy, nixp, niyp, isigp
real(kind=sgl)                          :: dc(3), scl, ixy(2), dx, dy, dxm, dym, dp


!==================================================================================
! ------ generate the detector klist array if needed 
!------- (calling program must decide this via ipar(1))
!==================================================================================

if (ipar(1).ge.1) then

    if (allocated(klist)) deallocate(klist)
    allocate(klist(1:3,-ipar(2):ipar(2),-ipar(2):ipar(2)), stat=istat)
    kk = (/0.0,0.0,1.0/)
    thetacr = DtoR*fpar(1)
    ktmax = tan(thetacr)
    delta = 2.0*ktmax/dble(ipar(2)-1)

    imin = 1
    imax = ipar(2)
    jmin = 1
    jmax = ipar(2)
     
    do ii = imin, imax
        do jj = jmin, jmax
            klist(1:3,ii,jj) = (/-ktmax+delta*(ii-1),-ktmax+delta*(jj-1),0.0/) + kk(1:3)
            klist(1:3,ii,jj) =  klist(1:3,ii,jj)/sqrt(sum( klist(1:3,ii,jj)**2))
        end do
    end do
end if

!===================================================================
! ------ perform interpolation from square lambert map
!===================================================================

scl = float(ipar(3))

do ip=1,ipar(4)
  do ii = imin, imax
    do jj = jmin, jmax

        dc(1:3) = klist(1:3,ii,jj)
        dc = quat_LP(quats(1:4,ip), dc)
        dc = dc/sqrt(sum(dc*dc))

        ixy = scl * LambertSphereToSquare( dc, istat )
        nix = int(ipar(3)+ixy(1))-ipar(3)
        niy = int(ipar(3)+ixy(2))-ipar(3)
        nixp = nix+1
        niyp = niy+1
        if (nixp.gt.ipar(3)) nixp = nix
        if (niyp.gt.ipar(3)) niyp = niy
        if (nix.lt.-ipar(3)) nix = nixp
        if (niy.lt.-ipar(3)) niy = niyp
        dx = ixy(1)-nix
        dy = ixy(2)-niy
        dxm = 1.0-dx
        dym = 1.0-dy

        if (dc(3).gt.0.0) then 
            Kosselpattern(ii,jj,ip) =  mLPNH(nix,niy,ipar(6)) * dxm * dym + &
                         mLPNH(nixp,niy,ipar(6)) * dx * dym + &
                         mLPNH(nix,niyp,ipar(6)) * dxm * dy + &
                         mLPNH(nixp,niyp,ipar(6)) * dx * dy 

        else
            Kosselpattern(ii,jj,ip) =  mLPSH(nix,niy,ipar(6)) * dxm * dym + &
                         mLPSH(nixp,niy,ipar(6)) * dx * dym + &
                         mLPSH(nix,niyp,ipar(6)) * dxm * dy + &
                         mLPSH(nixp,niyp,ipar(6)) * dx * dy 
        end if
    end do
  end do
end do

end subroutine getKosselPatterns

!--------------------------------------------------------------------------
!
! SUBROUTINE:EBSD4calfun
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief This function is used by bobyqa to fit an EBSD pattern
!
!> @details The main purpose of this routine is to calculte the difference of 1 with the dot
!> product of an experimental pattern with the given set of detector parameters. This is used
!> by bobyqa module to fit an EBSD pattern when 4 patterns are fitted simultaneously
!>
!> This routine will first compute the detector arrays rgx etc. if necessary, and then perform
!> the usual interpolation from the square Lambert projection. The pattern will be a basic pattern,
!> without any intensity scaling or binning etc; the calling program should take care of those 
!> operations.
!
!> @param ipar array with integer input parameters
!> @param fpar array with float input parameters
!> @param initmeanval mean value of search space
!> @param EBSDpattern output array
!> @param quats quaternion input array
!> @param accum_e array with Monte Carlo histogram
!> @param mLPNH Northern hemisphere master pattern
!> @param mLPSH Southern hemisphere master pattern
!
!> @date 12/12/15 SS 1.0 original
!> @date 03/28/16 SS 1.1 omega is no longer a variable parameter
!--------------------------------------------------------------------------

recursive subroutine EBSD4calfun(nipar, nfpar, ninit, ipar, fpar, initmeanval, expt, accum_e, &
                                mLPNH, mLPSH, n, x, f, expt2, expt3, expt4, nstep, stepsize, verbose)
!DEC$ ATTRIBUTES DLLEXPORT :: EBSD4calfun

! the input parameters are all part of a ipar and fpar input arrays instead of the usual namelist structures.
! The following is the mapping:
!

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
! ipar(13) = pixx_pat1
! ipar(14) = pixy_pat1
! ipar(15) = pixx_pat2
! ipar(16) = pixy_pat2
! ipar(17) = pixx_pat3
! ipar(18) = pixy_pat3
! ipar(19) = pixx_pat4
! ipar(20) = pixy_pat4

! fpar(1) = enl%xpc
! fpar(2) = enl%ypc
! fpar(3) = enl%delta
! fpar(4) = enl%MCsig
! fpar(5) = enl%omega
! fpar(6) = enl%thetac
! fpar(7) = enl%L
! fpar(8) = enl%beamcurrent
! fpar(9) = enl%dwelltime
! fpar(10) = enl%gammavalue
! fpar(11) = maskradius
! fpar(12) = stepx
! fpar(13) = stepy

! initmeanval(1) = fpar(7)
! initmeanval(2) = phi1
! initmeanval(3) = phi
! initmeanval(4) = phi2
! initmeanval(5) = xpc
! initmeanval(6) = ypc

! stepsize(1) = step_xpc
! stepsize(2) = step_ypc
! stepsize(3) = step_phi1 ; all 4 patterns
! stepsize(4) = step_phi ; all 4 patterns
! stepsize(5) = step_phi2 ; all 4 patterns
! stepsize(6) = step_L

! X = (/xpc, ypc, omega, L, phi1, phi, phi2/)

            
use local
use rotations
use constants
use distortion
use filters
use Indexingmod, ONLY:Jaccard_Distance
use,INTRINSIC :: ISO_C_BINDING
           
implicit none

integer(irg),intent(in)                 :: nipar
integer(irg),intent(in)                 :: nfpar
integer(irg),intent(in)                 :: ninit         
integer(c_size_t),intent(in)            :: ipar(nipar)
real(sgl),intent(inout)                 :: fpar(nfpar)
real(sgl),intent(in)                    :: initmeanval(ninit)
integer(irg),intent(in)                 :: nstep
real(sgl),intent(in)                    :: stepsize(nstep)
real(c_float),intent(in)                :: expt(ipar(2)*ipar(3)/ipar(12)/ipar(12))
real(c_float),intent(in)                :: expt2(ipar(2)*ipar(3)/ipar(12)/ipar(12))
real(c_float),intent(in)                :: expt3(ipar(2)*ipar(3)/ipar(12)/ipar(12))
real(c_float),intent(in)                :: expt4(ipar(2)*ipar(3)/ipar(12)/ipar(12))
real(kind=sgl),INTENT(in)               :: accum_e(ipar(4),-ipar(5):ipar(5),-ipar(5):ipar(5))
real(kind=sgl),INTENT(in)               :: mLPNH(-ipar(6):ipar(6), -ipar(6):ipar(6), ipar(10), ipar(7))
real(kind=sgl),INTENT(in)               :: mLPSH(-ipar(6):ipar(6), -ipar(6):ipar(6), ipar(10), ipar(7))
integer(irg),intent(in)                 :: n
real(dbl),dimension(:),intent(in)       :: x
real(dbl),intent(out)                   :: f
logical,intent(in),optional             :: verbose

integer(kind=irg)                       :: nnx, nny, binx, biny
complex(dbl)                            :: D
real(kind=sgl)                          :: quats(4,1), bindx, ma, mi
real(kind=sgl),allocatable              :: EBSDpattern(:,:,:), binned(:,:)
real(kind=sgl),allocatable              :: EBSDpatternintd(:,:)
integer(kind=irg),allocatable           :: EBSDpatterninteger(:,:), EBSDpatternad(:,:)

! variables that must be saved for the next time this function is called
real(kind=sgl)                          :: prefactor
integer(kind=irg),allocatable           :: img1(:), img2(:), img_fit_cumul(:), img_expt_cumul(:)
! other variables
real(kind=sgl),parameter                :: dtor = 0.0174533  ! convert from degrees to radians
real(kind=sgl)                          :: ixy(2), eu(3), eu2(3), eu3(3), eu4(3)
real(kind=sgl), allocatable             :: EBSDvector(:), EBSDflip(:,:), mask(:,:)
integer(kind=irg)                       :: i, j, istat

logical                                 :: stat, readonly
integer(kind=irg)                       :: hdferr, nlines
real(kind=sgl)                          :: fpar2(nfpar)

!fpar(1) = sngl(X(1))*ipar(2) - ipar(2)/2 + initmeanval(5) ! xpc +/- detnumx/2 pixels
!fpar(2) = sngl(X(2))*ipar(3) - ipar(3)/2 + initmeanval(6) ! ypc +/- detnumy/2 pixels

fpar(1) = sngl(X(1))*2.0*stepsize(1) - stepsize(1) + initmeanval(5) ! xpc +/- 5 pixels
fpar(2) = sngl(X(2))*2.0*stepsize(2) - stepsize(2) + initmeanval(6) ! ypc +/- 5 pixels

!fpar(1) = initmeanval(5) ! xpc +/- detnumx/2 pixels
!fpar(2) = initmeanval(6) ! ypc +/- detnumy/2 pixels

fpar(7) = sngl(X(4))*2.0*stepsize(6)*fpar(3) - stepsize(6)*fpar(3) + initmeanval(1) ! mean +/- 5 pixels
!fpar(7) = initmeanval(1) ! mean +/- 2000 microns

! 03/28/16 omega is no longer a variable parameter anymore
fpar(5) = sngl(X(3))*0.0 - 0.0 ! omega 0 +/- 5 degrees

!eu = (/initmeanval(2), initmeanval(3), initmeanval(4)/)*dtor ! don't change the values for euler angles
eu = (/X(5)*2.0*stepsize(3) - stepsize(3) + initmeanval(2), X(6)*2.0*stepsize(4) - stepsize(4)  + initmeanval(3), &
       X(7)*2.0*stepsize(5) - stepsize(5) + initmeanval(4)/)*dtor ! mean +/- 2 degrees
eu2 = (/X(8)*2.0*stepsize(3) - stepsize(3) + initmeanval(7), X(9)*2.0*stepsize(4) - stepsize(4) + initmeanval(8), &
       X(10)*2.0*stepsize(5) - stepsize(5) + initmeanval(9)/)*dtor ! mean +/- 2 degrees
eu3 = (/X(11)*2.0*stepsize(3) - stepsize(3) + initmeanval(10), X(12)*2.0*stepsize(4) - stepsize(4) + initmeanval(11), &
       X(13)*2.0*stepsize(5) - stepsize(5) + initmeanval(12)/)*dtor ! mean +/- 2 degrees
eu4 = (/X(14)*2.0*stepsize(3) - stepsize(3) + initmeanval(13), X(15)*2.0*stepsize(4) - stepsize(4) + initmeanval(14), &
       X(16)*2.0*stepsize(5) - stepsize(5) + initmeanval(15)/)*dtor ! mean +/- 2 degrees

!D = dcmplx(X(8)*0.000002D0 - 0.000001D0 + dble(initmeanval(5)), X(9)*0.000002D0 - 0.000001D0 + dble(initmeanval(6)))

binx = ipar(2)/ipar(12)
biny = ipar(3)/ipar(12)
bindx = 1.0/float(ipar(12)**2)

allocate(EBSDvector(binx*biny),mask(binx,biny))
allocate(EBSDpattern(ipar(2),ipar(3),1))
allocate(binned(binx,biny))
allocate(EBSDpatternintd(ipar(2),ipar(3)),EBSDpatterninteger(ipar(2),ipar(3)), EBSDpatternad(ipar(2),ipar(3)))
allocate(img1(binx*biny),img2(binx*biny))
allocate(img_fit_cumul(4*binx*biny),img_expt_cumul(4*binx*biny))

binned = 0.0
EBSDpatternintd = 0.0
EBSDpatterninteger = 0
EBSDpatternad = 0
img1 = 0
img2 = 0
img_fit_cumul = 0
img_expt_cumul = 0

mask = 1.0

if (present(verbose)) then
    if(verbose) then    
        print*,'xpc, ypc, L, eu_pat1, eu_pat2, eu_pat3, eu_pat4 = ', fpar(1), fpar(2), fpar(7),eu(1:3)*180.0/cPi,&
        eu2(1:3)*180.0/cPi,eu3(1:3)*180.0/cPi,eu4(1:3)*180.0/cPi
    end if
end if

fpar2(1:nfpar) = fpar(1:nfpar)

!==============================================================================
!============IMAGE 1===========================================================
!==============================================================================

quats(1:4,1) = eu2qu(eu)

fpar2(1:nfpar) = fpar(1:nfpar)
fpar2(1) = fpar(1) + ipar(13)*fpar(12)/fpar(3)
fpar2(2) = fpar(2) - ipar(14)*fpar(13)/fpar(3)

call getEBSDPatterns(ipar, fpar2, EBSDpattern, quats, accum_e, mLPNH, mLPSH)

!nnx = ipar(2)
!nny = ipar(3)

!EBSDpatternintd = ((EBSDPattern(:,:,1) - mi)/ (ma-mi))
!EBSDpatterninteger = nint(EBSDpatternintd*255.0)
!EBSDpatternad =  adhisteq(10,nnx,nny,EBSDpatterninteger)
!EBSDPattern(:,:,1) = float(EBSDpatternad)

if (ipar(12) .ne. 1) then
    do i=1,binx
        do j=1,biny
            binned(i,j) = sum(EBSDpattern((i-1)*ipar(12)+1:i*ipar(12),(j-1)*ipar(12)+1:j*ipar(12),1))
        end do
    end do 
    binned = binned * bindx 
else
    binned(1:binx,1:biny) = EBSDpattern(1:binx,1:biny,1)
end if


if (ipar(11) .eq. 1) then
    do i = 1,binx
        do j = 1,biny
            if(((float(i)-ceiling(float(binx)/2.0))**2 + (float(j)-ceiling(float(biny)/2.0))**2) .gt. fpar(11)**2) then
                mask(i,j) = 0.0
            end if
        end do
    end do
end if

binned(1:binx,1:biny) = binned(1:binx,1:biny)*mask(1:binx,1:biny)
binned = binned**fpar(10)


do i=1,biny
    do j=1,binx
        EBSDvector((i-1)*binx+j) = binned(j,i)
    end do
end do

ma = maxval(EBSDvector)
mi = minval(EBSDvector)

img1 = nint(255.0*(EBSDvector - mi)/(ma - mi))

ma = maxval(expt)
mi = minval(expt)

img2 = nint(255.0*(expt - mi)/(ma - mi))

img_fit_cumul(1:binx*biny) = img1(1:binx*biny)
img_expt_cumul(1:binx*biny) = img2(1:binx*biny)

!open(unit=13,file='/Users/saranshsingh/Desktop/testd.txt',action='write')
!open(unit=14,file='/Users/saranshsingh/Desktop/teste.txt',action='write')

!do i = 1,binx
!    do j = 1,biny
!        write(13,'(F15.6)',advance='no')EBSDvector((i-1)*biny+j)
!        write(14,'(F15.6)',advance='no')expt((i-1)*biny+j)
!    end do
!    write(13,*)''
!    write(14,*)''
!end do

!close(13)
!close(14)
!stop


!==============================================================================
!============IMAGE 2===========================================================
!==============================================================================

quats(1:4,1) = eu2qu(eu2)
fpar2(1:nfpar) = fpar(1:nfpar)
fpar2(1) = fpar(1) + ipar(15)*fpar(12)/fpar(3)
fpar2(2) = fpar(2) - ipar(16)*fpar(13)/fpar(3)


call getEBSDPatterns(ipar, fpar2, EBSDpattern, quats, accum_e, mLPNH, mLPSH)

if (ipar(12) .ne. 1) then
    do i=1,binx
        do j=1,biny
            binned(i,j) = sum(EBSDpattern((i-1)*ipar(12)+1:i*ipar(12),(j-1)*ipar(12)+1:j*ipar(12),1))
        end do
    end do 
    binned = binned * bindx 
else
    binned(1:binx,1:biny) = EBSDpattern(1:binx,1:biny,1)
end if

binned(1:binx,1:biny) = binned(1:binx,1:biny)*mask(1:binx,1:biny)
binned = binned**fpar(10)


do i=1,biny
    do j=1,binx
        EBSDvector((i-1)*binx+j) = binned(j,i)
    end do
end do

ma = maxval(EBSDvector)
mi = minval(EBSDvector)

img1 = nint(255.0*(EBSDvector - mi)/(ma - mi))

ma = maxval(expt2)
mi = minval(expt2)

img2 = nint(255.0*(expt2 - mi)/(ma - mi))

img_fit_cumul(binx*biny+1:2*binx*biny) = img1(1:binx*biny)
img_expt_cumul(binx*biny+1:2*binx*biny) = img2(1:binx*biny)

!==============================================================================
!============IMAGE 3===========================================================
!==============================================================================

quats(1:4,1) = eu2qu(eu3)
fpar2(1:nfpar) = fpar(1:nfpar)
fpar2(1) = fpar(1) + ipar(17)*fpar(12)/fpar(3)
fpar2(2) = fpar(2) - ipar(18)*fpar(13)/fpar(3)


call getEBSDPatterns(ipar, fpar2, EBSDpattern, quats, accum_e, mLPNH, mLPSH)

if (ipar(12) .ne. 1) then
    do i=1,binx
        do j=1,biny
            binned(i,j) = sum(EBSDpattern((i-1)*ipar(12)+1:i*ipar(12),(j-1)*ipar(12)+1:j*ipar(12),1))
        end do
    end do 
    binned = binned * bindx 
else
    binned(1:binx,1:biny) = EBSDpattern(1:binx,1:biny,1)
end if

binned(1:binx,1:biny) = binned(1:binx,1:biny)*mask(1:binx,1:biny)
binned = binned**fpar(10)


do i=1,biny
    do j=1,binx
        EBSDvector((i-1)*binx+j) = binned(j,i)
    end do
end do

ma = maxval(EBSDvector)
mi = minval(EBSDvector)

img1 = nint(255.0*(EBSDvector - mi)/(ma - mi))

ma = maxval(expt3)
mi = minval(expt3)

img2 = nint(255.0*(expt3 - mi)/(ma - mi))

img_fit_cumul(2*binx*biny+1:3*binx*biny) = img1(1:binx*biny)
img_expt_cumul(2*binx*biny+1:3*binx*biny) = img2(1:binx*biny)

!==============================================================================
!============IMAGE 4===========================================================
!==============================================================================

quats(1:4,1) = eu2qu(eu4)
fpar2(1:nfpar) = fpar(1:nfpar)
fpar2(1) = fpar(1) + ipar(19)*fpar(12)/fpar(3)
fpar2(2) = fpar(2) - ipar(20)*fpar(13)/fpar(3)

call getEBSDPatterns(ipar, fpar2, EBSDpattern, quats, accum_e, mLPNH, mLPSH)

if (ipar(12) .ne. 1) then
    do i=1,binx
        do j=1,biny
            binned(i,j) = sum(EBSDpattern((i-1)*ipar(12)+1:i*ipar(12),(j-1)*ipar(12)+1:j*ipar(12),1))
        end do
    end do 
    binned = binned * bindx 
else
    binned(1:binx,1:biny) = EBSDpattern(1:binx,1:biny,1)
end if

binned(1:binx,1:biny) = binned(1:binx,1:biny)*mask(1:binx,1:biny)
binned = binned**fpar(10)


do i=1,biny
    do j=1,binx
        EBSDvector((i-1)*binx+j) = binned(j,i)
    end do
end do

ma = maxval(EBSDvector)
mi = minval(EBSDvector)

img1 = nint(255.0*(EBSDvector - mi)/(ma - mi))

ma = maxval(expt4)
mi = minval(expt4)

img2 = nint(255.0*(expt4 - mi)/(ma - mi))

img_fit_cumul(3*binx*biny+1:4*binx*biny) = img1(1:binx*biny)
img_expt_cumul(3*binx*biny+1:4*binx*biny) = img2(1:binx*biny)

F = Jaccard_Distance(img_fit_cumul,img_expt_cumul,4*binx*biny)

!F = 1.0 - DOT_PRODUCT(EBSDvector,expt)

end subroutine EBSD4calfun

!--------------------------------------------------------------------------
!
! SUBROUTINE:EBSDcalfun
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief This function is used by bobyqa to fit an EBSD pattern
!
!> @details The main purpose of this routine is to calculte the difference of 1 with the dot
!> product of an experimental pattern with the given set of detector parameters. This is used
!> by bobyqa module to fit an EBSD pattern.
!>
!> This routine will first compute the detector arrays rgx etc. if necessary, and then perform
!> the usual interpolation from the square Lambert projection. The pattern will be a basic pattern,
!> without any intensity scaling or binning etc; the calling program should take care of those 
!> operations.
!
!> @param ipar array with integer input parameters
!> @param fpar array with float input parameters
!> @param initmeanval mean value of search space
!> @param EBSDpattern output array
!> @param quats quaternion input array
!> @param accum_e array with Monte Carlo histogram
!> @param mLPNH Northern hemisphere master pattern
!> @param mLPSH Southern hemisphere master pattern
!
!> @date 12/12/15 SS 1.0 original
!> @date 03/28/16 SS 1.1 omega is no longer a variable parameter
!--------------------------------------------------------------------------

recursive subroutine EBSDcalfun(nipar, nfpar, ninit, ipar, fpar, initmeanval, expt, accum_e, &
                                mLPNH, mLPSH, n, x, f, nstep, stepsize, verbose)
!DEC$ ATTRIBUTES DLLEXPORT :: EBSDcalfun

! the input parameters are all part of a ipar and fpar input arrays instead of the usual namelist structures.
! The following is the mapping:
!

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
! ipar(13) = 0/1; 0 for DP and 1 for JD
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
! fpar(10) = alphaBD ; barrell distortion coefficient
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

            
use local
use rotations
use constants
use distortion
use filters
use Indexingmod, ONLY:Jaccard_Distance
use,INTRINSIC :: ISO_C_BINDING
           
implicit none

integer(irg),intent(in)                 :: nipar
integer(irg),intent(in)                 :: nfpar
integer(irg),intent(in)                 :: ninit         
integer(c_size_t),intent(in)            :: ipar(nipar)
real(sgl),intent(inout)                 :: fpar(nfpar)
real(sgl),intent(in)                    :: initmeanval(ninit)
integer(irg),intent(in)                 :: nstep
real(sgl),intent(in)                    :: stepsize(nstep)
real(c_float),intent(in)                :: expt(ipar(2)*ipar(3)/ipar(12)**2)
real(kind=sgl),INTENT(in)               :: accum_e(ipar(4),-ipar(5):ipar(5),-ipar(5):ipar(5))
real(kind=sgl),INTENT(in)               :: mLPNH(-ipar(6):ipar(6), -ipar(6):ipar(6), ipar(10), ipar(7))
real(kind=sgl),INTENT(in)               :: mLPSH(-ipar(6):ipar(6), -ipar(6):ipar(6), ipar(10), ipar(7))
integer(irg),intent(in)                 :: n
real(dbl),dimension(:),intent(in)       :: x
real(dbl),intent(out)                   :: f
logical,intent(in),optional             :: verbose

integer(kind=irg)                       :: nnx, nny, binx, biny
complex(dbl)                            :: D
real(kind=sgl)                          :: quats(4,1), bindx, ma, mi
real(kind=sgl),allocatable              :: EBSDpattern(:,:,:), binned(:,:)
real(kind=sgl),allocatable              :: EBSDpatternintd(:,:)
integer(kind=irg),allocatable           :: EBSDpatterninteger(:,:), EBSDpatternad(:,:)

! variables that must be saved for the next time this function is called
real(kind=sgl)                          :: prefactor
integer(kind=irg),allocatable           :: img1(:), img2(:)
! other variables
real(kind=sgl),parameter                :: dtor = 0.0174533  ! convert from degrees to radians
real(kind=sgl)                          :: ixy(2), eu(3), eu2(3), eu3(3), eu4(3)
real(kind=sgl), allocatable             :: EBSDvector(:), EBSDflip(:,:), mask(:,:)
integer(kind=irg)                       :: i, j, istat

logical                                 :: stat, readonly
integer(kind=irg)                       :: hdferr, nlines, nregions
real(kind=sgl)                          :: fpar2(10)
integer(kind=8)                         :: ipar2(10)

fpar(1) = sngl(X(1))*2.0*stepsize(1) - stepsize(1) + initmeanval(5) ! xpc +/- 5 pixels
fpar(2) = sngl(X(2))*2.0*stepsize(2) - stepsize(2) + initmeanval(6) ! ypc +/- 5 pixels


fpar(7) = sngl(X(4))*2.0*stepsize(6)*fpar(3) - stepsize(6)*fpar(3) + initmeanval(1) ! mean +/- 5 pixels

! 03/28/16 omega is no longer a variable parameter anymore
fpar(5) = sngl(X(3))*0.0 - 0.0 

eu = (/X(5)*2.0*stepsize(3) - stepsize(3) + initmeanval(2), X(6)*2.0*stepsize(4) - stepsize(4)  + initmeanval(3), &
       X(7)*2.0*stepsize(5) - stepsize(5) + initmeanval(4)/)*dtor ! mean +/- 2 degrees


binx = ipar(2)/ipar(12)
biny = ipar(3)/ipar(12)
bindx = 1.0/float(ipar(12)**2)
nnx = ipar(2)
nny = ipar(3)
nregions = IPAR(14)

allocate(EBSDvector(binx*biny),mask(binx,biny))
allocate(EBSDpattern(ipar(2),ipar(3),1))
allocate(binned(binx,biny))
allocate(EBSDpatternintd(ipar(2),ipar(3)),EBSDpatterninteger(ipar(2),ipar(3)), EBSDpatternad(ipar(2),ipar(3)))
allocate(img1(binx*biny),img2(binx*biny))

binned = 0.0
EBSDpatternintd = 0.0
EBSDpatterninteger = 0
EBSDpatternad = 0
img1 = 0
img2 = 0

mask = 1.0

if (present(verbose)) then
    if(verbose) then    
        print*,'xpc, ypc, L, eu = ', fpar(1), fpar(2), fpar(7), eu(1:3)*180.0/cPi
     end if
end if

fpar2(1:10) = fpar(1:10)
ipar2(1:10) = ipar(1:10)
quats(1:4,1) = eu2qu(eu)

call getEBSDPatterns(ipar2, fpar2, EBSDpattern, quats, accum_e, mLPNH, mLPSH)

ma = maxval(EBSDPattern(:,:,1))
mi = minval(EBSDPattern(:,:,1))

EBSDpatternintd = ((EBSDPattern(:,:,1) - mi)/ (ma-mi))
EBSDpatterninteger = nint(EBSDpatternintd*255.0)
EBSDpatternad =  adhisteq(nregions,nnx,nny,EBSDpatterninteger)
EBSDPattern(:,:,1) = float(EBSDpatternad)

if (ipar(12) .ne. 1) then
    do i=1,binx
        do j=1,biny
            binned(i,j) = sum(EBSDpattern((i-1)*ipar(12)+1:i*ipar(12),(j-1)*ipar(12)+1:j*ipar(12),1))
        end do
    end do 
    binned = binned * bindx 
else
    binned(1:binx,1:biny) = EBSDpattern(1:binx,1:biny,1)
end if


if (ipar(11) .eq. 1) then
    do i = 1,binx
        do j = 1,biny
            if(((float(i)-ceiling(float(binx)/2.0))**2 + (float(j)-ceiling(float(biny)/2.0))**2) .gt. fpar(11)**2) then
                mask(i,j) = 0.0
            end if
        end do
    end do
end if

binned(1:binx,1:biny) = binned(1:binx,1:biny)*mask(1:binx,1:biny)
binned = binned**fpar(12)


do i=1,biny
    do j=1,binx
        EBSDvector((i-1)*binx+j) = binned(j,i)
    end do
end do

EBSDvector = EBSDvector/NORM2(EBSDvector)

if(IPAR(13) .eq. 1) then
    ma = maxval(EBSDvector)
    mi = minval(EBSDvector)

    img1 = nint(255.0*(EBSDvector - mi)/(ma - mi))

    ma = maxval(expt)
    mi = minval(expt)

    img2 = nint(255.0*(expt - mi)/(ma - mi))

    F = Jaccard_Distance(img1,img2,binx*biny)
else
    F = 1.0 - DOT_PRODUCT(EBSDvector,expt)
end if

end subroutine EBSDcalfun


!--------------------------------------------------------------------------
!
! SUBROUTINE:ECPcalfun
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief This function is used by bobyqa to fit an EBSD pattern
!
!> @etails The main purpose of this routine is to calculte the difference of 1 with the dot
!> product of an experimental pattern with the given set of detector parameters. This is used
!> by bobyqa module to fit an EBSD pattern.
!>
!> This routine will first compute the detector arrays rgx etc. if necessary, and then perform
!> the usual interpolation from the square Lambert projection. The pattern will be a basic pattern,
!> without any intensity scaling or binning etc; the calling program should take care of those 
!> operations.
!
!> @param ipar array with integer input parameters
!> @param fpar array with float input parameters
!> @param initmeanval array with mean value of search space
!> @param ECPattern output array
!> @param quats array of quaternions
!> @param accum_e array with Monte Carlo histogram
!> @param mLPNH Northern hemisphere master pattern
!> @param mLPSH Southern hemisphere master pattern
!
!> @date 12/12/15  SS 1.0 original
!--------------------------------------------------------------------------

recursive subroutine ECPcalfun (nipar, nfpar, ninit, ipar, fpar, initmeanval, expt, accum_e, mLPNH, mLPSH, &
                                n, x, f, nstep, stepsize, verbose)
!DEC$ ATTRIBUTES DLLEXPORT :: ECPcalfun

! the input parameters are all part of a ipar and fpar input arrays instead of the usual namelist structures.
! The following is the mapping:
!
! ipar(1) = 1 
! ipar(2) = detnumsx
! ipar(3) = detnumsy
! ipar(4) = numangle
! ipar(5) = mcnsx
! ipar(6) = mpnpx
! ipar(7) = numset
! ipar(8) = numquats
! ipar(9) = 0/1 ;0 for no mask, 1 for mask
! ipar(10) = 1; equal to numEbins
! ipar(11) = 0/1; 0 for DP 1 for JD
! ipar(12) = 1 ;binning

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
! initmeanval(2) = sampletilt
! initmeanval(3) = working distance 
! initmeanval(4) = phi1
! initmeanval(5) = phi
! initmeanval(6) = phi2

! stepsize(1) = step_thetacone
! stepsize(2) = step_phi1
! stepsize(3) = step_phi ; all 4 patterns
! stepsize(4) = step_phi2 ; all 4 patterns


use local
use rotations
use constants
use distortion 
use,INTRINSIC :: ISO_C_BINDING
use filters
use Indexingmod, ONLY:Jaccard_Distance

IMPLICIT NONE

integer(c_size_t),intent(in)            :: ipar(nipar)
real(sgl),intent(inout)                 :: fpar(nfpar)
real(sgl),intent(in)                    :: initmeanval(ninit)
integer(irg),intent(in)                 :: nipar
integer(irg),intent(in)                 :: nfpar
integer(irg),intent(in)                 :: ninit
real(c_float),intent(in)                :: expt(ipar(2)*ipar(3)/ipar(12)**2)
integer(irg),intent(in)                 :: nstep
real(sgl),intent(in)                    :: stepsize(nstep)
real(kind=sgl),INTENT(in)               :: accum_e(ipar(4),-ipar(5):ipar(5),-ipar(5):ipar(5))
real(kind=sgl),INTENT(in)               :: mLPNH(-ipar(6):ipar(6), -ipar(6):ipar(6), ipar(10), ipar(7))
real(kind=sgl),INTENT(in)               :: mLPSH(-ipar(6):ipar(6), -ipar(6):ipar(6), ipar(10), ipar(7))
integer(irg),intent(in)                 :: n
real(dbl),dimension(:),intent(in)       :: x
real(dbl),intent(out)                   :: f
logical,intent(in),optional             :: verbose

integer(kind=irg)                       :: nnx, nny
complex(dbl)                            :: D
real(kind=sgl)                          :: quats(4,1), ma, mi
real(kind=sgl),allocatable              :: ECPpattern(:,:,:)

real(kind=sgl),allocatable              :: binned(:,:)
real(kind=sgl),allocatable              :: ECPpatternintd(:,:)
integer(kind=irg),allocatable           :: ECPpatterninteger(:,:), ECPpatternad(:,:)
real(kind=sgl),allocatable              :: ECPvector(:), ECPvectorcpy(:), ECPtmp(:,:)
real(kind=sgl),allocatable              :: mask(:,:)
integer(kind=irg),allocatable           :: img1(:), img2(:)

integer(kind=irg)                       :: istat, i, j
real(kind=sgl),parameter                :: dtor = 0.0174533  ! convert from degrees to radians
real(kind=sgl)                          :: eu(3)
logical                                 :: stat, readonly
integer(kind=irg)                       :: hdferr, nlines, nregions


fpar(1) = sngl(X(1))*2.0*stepsize(1) - stepsize(1) + initmeanval(1) ! thetac mean +/- stepsize degrees degrees only

eu = (/X(2)*2.0*stepsize(2) - stepsize(2) + initmeanval(2), X(3)*2.0*stepsize(3) - stepsize(3)  + initmeanval(3), &
       X(4)*2.0*stepsize(4) - stepsize(4) + initmeanval(4)/)*cPi/180.0 ! mean +/- stepsize

quats(1:4,1) = eu2qu(eu)

!D = dcmplx(0.D0,0.D0)
! read all the files 

allocate(ECPvector(ipar(2)*ipar(3)),mask(ipar(2),ipar(3)))
allocate(ECPpattern(ipar(2),ipar(3),ipar(8)))
allocate(ECPpatternintd(ipar(2),ipar(3)),ECPpatterninteger(ipar(2),ipar(3)), ECPpatternad(ipar(2),ipar(3)))
ECPpatternintd = 0.0
ECPpatterninteger = 0
ECPpatternad = 0

if (present(verbose)) then
    if(verbose) then    
        print*,'thetac, eu = ',sngl(X(1))*2.0*stepsize(1) - stepsize(1) + initmeanval(1), eu*180.0/cPi
    end if
end if

mask = 1.0
do i = 1,ipar(2)
    do j = 1,ipar(3)
        if(((float(i)-ceiling(float(ipar(2))/2.0))**2 + (float(j)-ceiling(float(ipar(3))/2.0))**2) .gt. fpar(10)**2) then
            mask(i,j) = 0.0
        end if
    end do
end do

call getECPatterns(ipar, fpar, ECPpattern, quats, accum_e, mLPNH, mLPSH)

nnx = ipar(2)
nny = ipar(3)
!nregions = ipar(12)

allocate(ECPvector(ipar(2)*ipar(3)),stat=istat)

if (ipar(9) .eq. 1) then
    do i = 1,ipar(8)
        ECPpattern(:,:,i) = ECPpattern(:,:,i)*mask
    end do
end if

do i=1,ipar(2)
    do j=1,ipar(3)
        ECPvector((i-1)*ipar(3)+j) = ECPpattern(j,i,1)
    end do
end do

!ECPvector = 0.0

!do i = 1,ipar(2)
!    ECPvector((i-1)*ipar(3)+1:i*ipar(3)) = ECPvectorcpy((ipar(2)-i)*ipar(3)+1:(ipar(2)-i+1)*ipar(3))
!end do

ECPvector = ECPvector**fpar(9)
ECPvector = ECPvector/NORM2(ECPvector)

if(IPAR(11) .eq. 0) then
    F = 1.0 - DOT_PRODUCT(ECPvector,expt)
else
    allocate(img1(ipar(2)*ipar(3)),img2(ipar(2)*ipar(3)))
    ma = maxval(ECPvector)
    mi = minval(ECPvector)

    img1 = nint(255.0*(ECPvector - mi)/(ma - mi))

    ma = maxval(expt)
    mi = minval(expt)

    img2 = nint(255.0*(expt - mi)/(ma - mi))

    F = Jaccard_Distance(img1,img2,nnx*nny)
    
end if

end subroutine ECPcalfun

!===================================================================
!===================================================================
! here we start with the Wrapper routines that are actually
! called from another language
!
! Tested languages:  IDL
! To be tested:  Matlab
!===================================================================
!===================================================================

!--------------------------------------------------------------------------
!
! SUBROUTINE:getEBSDPatternsWrapper
!
!> @author Marc De Graef, Carnegie Mellon University
!
!> @brief wrapper routine for getEBSDPatterns
!>
!> see example at https://groups.google.com/forum/#!topic/comp.lang.idl-pvwave/Gk0xxVFbW8E
!
!> @param argc number of argument
!> @param argv pointers to subroutine parameters
!
!> @date 10/16/15 MDG 1.0 original
!> @date 11/02/15 MDG 1.1 simplified parameters
!> @date 01/12/16 MDG 1.2 added dummy arguments for progress callback and cancel handling
!> @date 01/13/16 MDG 1.3 removed dummy arguments for progress callback and cancel handling
!> @date 07/10/16 MDG 1.4 added energy min/max indices
!--------------------------------------------------------------------------
recursive function getEBSDPatternsWrapper(argc, argv) bind(c, name='getEBSDPatternsWrapper') 
!DEC$ ATTRIBUTES DLLEXPORT :: getEBSDPatternsWrapper

use,INTRINSIC :: ISO_C_BINDING

IMPLICIT NONE

INTEGER(c_size_t), VALUE, INTENT(IN)            :: argc 
type(c_ptr), dimension(argc), INTENT(INOUT)     :: argv
REAL(c_float)                                   :: getEBSDPatternsWrapper

! wrapper function dependent declarations; they are all pointers 
! since we pass everything by reference from IDL 
integer(c_size_t)                               :: nipar, nfpar, nq
integer(c_size_t),dimension(:), pointer         :: ipar
real(c_float), dimension(:), pointer            :: fpar
real(c_float), dimension(:,:), pointer          :: quats
real(c_float), dimension(:,:,:), pointer        :: EBSDpattern, accum_e 
real(c_float), dimension(:,:,:,:),pointer       :: mLPNH, mLPSH

! the following line just helps in identifying the correct order of the subroutine arguments...
!                             1      2      3           4         5       6     7
!subroutine getEBSDPatterns(ipar, fpar, EBSDpattern, quats, accum_e, mLPNH, mLPSH)
!
! transform the C pointers above to fortran pointers, and use them in the regular function call
nipar = 10
nfpar = 10
nq = 4

call c_f_pointer(argv(1),ipar,(/nipar/)) 
call c_f_pointer(argv(2),fpar,(/nfpar/)) 
call c_f_pointer(argv(3),EBSDpattern,(/ipar(2),ipar(3),ipar(8)/))
call c_f_pointer(argv(4),quats,(/nq,ipar(8)/))
call c_f_pointer(argv(5),accum_e,(/ipar(4),2*ipar(5)+1,2*ipar(5)+1/))
call c_f_pointer(argv(6),mLPNH,(/2*ipar(6)+1, 2*ipar(6)+1, ipar(4), ipar(7)/))
call c_f_pointer(argv(7),mLPSH,(/2*ipar(6)+1, 2*ipar(6)+1, ipar(4), ipar(7)/))

call getEBSDPatterns(ipar, fpar, EBSDpattern, quats, accum_e, mLPNH, mLPSH)

getEBSDPatternsWrapper = 1._c_float
end function getEBSDPatternsWrapper


!--------------------------------------------------------------------------
!
! SUBROUTINE:getECPatternsWrapper
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief wrapper routine for SingleECPPattern; based on Marc's routine above
!>
!> see https://groups.google.com/forum/#!topic/comp.lang.idl-pvwave/Gk0xxVFbW8E
!>
!
!> @param argc number of argument
!> @param argv pointers to subroutine parameters
!
!> @date 10/28/15  SS 1.0 original
!> @date 11/02/15 MDG 1.1 simplified parameters
!--------------------------------------------------------------------------
recursive function getECPatternsWrapper(argc, argv) bind(c, name='getECPatternsWrapper') 
!DEC$ ATTRIBUTES DLLEXPORT :: getECPatternsWrapper

use,INTRINSIC :: ISO_C_BINDING

IMPLICIT NONE

INTEGER(c_size_t), VALUE, INTENT(IN)            :: argc 
type(c_ptr), dimension(argc), INTENT(INOUT)     :: argv
REAL(c_float)                                   :: getECPatternsWrapper

! wrapper function dependent declarations; they are all pointers 
! since we pass everything by reference from IDL 
integer(c_size_t)                               :: nipar, nfpar, nq
integer(c_size_t),dimension(:), pointer         :: ipar
real(c_float), dimension(:), pointer            :: fpar
real(c_float), dimension(:,:,:), pointer        :: accum_e, mLPNH, mLPSH, ECPattern
real(c_float), dimension(:,:), pointer          :: quats

! the following line just helps in identifying the correct order of the subroutine arguments...
!                             1      2     3       4       5       6       7
!subroutine getECPatterns(ipar, fpar, ECPattern, quats, accum_e, mLPNH, mLPSH)
!
! transform the C pointers above to fortran pointers, and use them in the regular function call
nipar = 8
nfpar = 8
nq = 4
call c_f_pointer(argv(1),ipar,(/nipar/)) 
call c_f_pointer(argv(2),fpar,(/nfpar/)) 
call c_f_pointer(argv(3),ECpattern,(/ipar(2),ipar(3),ipar(8)/))
call c_f_pointer(argv(4),quats,(/nq,ipar(8)/))
call c_f_pointer(argv(5),accum_e,(/ipar(4),2*ipar(5)+1,2*ipar(5)+1/))
call c_f_pointer(argv(6),mLPNH,(/2*ipar(7)+1, 2*ipar(7)+1, ipar(6)/))
call c_f_pointer(argv(7),mLPSH,(/2*ipar(7)+1, 2*ipar(7)+1, ipar(6)/))

call getECPatterns(ipar, fpar, ECpattern, quats, accum_e, mLPNH, mLPSH)

getECPatternsWrapper = 1._c_float
end function getECPatternsWrapper

!--------------------------------------------------------------------------
!
! SUBROUTINE: getKosselPatternsWrapper
!
!> @author Marc De Graef, Carnegie Mellon University
!
!> @brief wrapper routine for SingleKosselPattern; nearly identical to ECP case
!>
!> see https://groups.google.com/forum/#!topic/comp.lang.idl-pvwave/Gk0xxVFbW8E
!
!> @param argc number of argument
!> @param argv pointers to subroutine parameters
!
!> @date 11/09/15 MDG 1.0 first version
!--------------------------------------------------------------------------
recursive function getKosselPatternsWrapper(argc, argv) bind(c, name='getKosselPatternsWrapper') 
!DEC$ ATTRIBUTES DLLEXPORT :: getKosselPatternsWrapper

use,INTRINSIC :: ISO_C_BINDING

IMPLICIT NONE

INTEGER(c_size_t), VALUE, INTENT(IN)            :: argc 
type(c_ptr), dimension(argc), INTENT(INOUT)     :: argv
REAL(c_float)                                   :: getKosselPatternsWrapper

! wrapper function dependent declarations; they are all pointers 
! since we pass everything by reference from IDL 
integer(c_size_t)                               :: nipar, nfpar, nq
integer(c_size_t),dimension(:), pointer         :: ipar
real(c_float), dimension(:), pointer            :: fpar
real(c_float), dimension(:,:), pointer          :: quats
real(c_float), dimension(:,:,:), pointer        :: KosselPattern, mLPNH, mLPSH

! the following line just helps in identifying the correct order of the subroutine arguments...
!                             1      2     3             4       5       6
!subroutine getKosselPatterns(ipar, fpar, KosselPattern, quats, mLPNH, mLPSH)
!
! transform the C pointers above to fortran pointers, and use them in the regular function call
nipar = 6
nfpar = 1
nq = 4
call c_f_pointer(argv(1),ipar,(/nipar/)) 
call c_f_pointer(argv(2),fpar,(/nfpar/)) 
call c_f_pointer(argv(3),Kosselpattern,(/ipar(2),ipar(2),ipar(4)/))
call c_f_pointer(argv(4),quats,(/nq,ipar(4)/))
call c_f_pointer(argv(5),mLPNH,(/2*ipar(3)+1, 2*ipar(3)+1,ipar(5)/))
call c_f_pointer(argv(6),mLPSH,(/2*ipar(3)+1, 2*ipar(3)+1,ipar(5)/))

call getKosselPatterns(ipar, fpar, Kosselpattern, quats, mLPNH, mLPSH)

getKosselPatternsWrapper = 1._c_float
end function getKosselPatternsWrapper

!--------------------------------------------------------------------------
!
! SUBROUTINE:efitECPWrapper
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief wrapper routine for fitting ECP pattern
!>
!> see https://groups.google.com/forum/#!topic/comp.lang.idl-pvwave/Gk0xxVFbW8E
!>
!
!> @param argc number of argument
!> @param argv pointers to subroutine parameters
!
!> @date 12/15/15  SS 1.0 original
!--------------------------------------------------------------------------
recursive function efitECPWrapper(argc, argv) bind(c, name='efitECPWrapper') 
!DEC$ ATTRIBUTES DLLEXPORT :: efitECPWrapper

use,INTRINSIC :: ISO_C_BINDING
! use bobyqa_module
use local

IMPLICIT NONE

INTEGER(c_size_t), VALUE, INTENT(IN)            :: argc 
type(c_ptr), dimension(argc), INTENT(INOUT)     :: argv
REAL(c_float)                                   :: efitECPWrapper

! wrapper function dependent declarations; they are all pointers 
! since we pass everything by reference from IDL 
integer(4)                                      :: nipar, nfpar, ninit, n, iprint, maxfun, npt
real(c_double), dimension(:), pointer           :: rhobeg, rhoend
integer(c_size_t),dimension(:), pointer         :: ipar
real(c_float), dimension(:), pointer            :: fpar
real(c_float), dimension(:), pointer            :: initmeanval
real(c_float), dimension(:), pointer            :: expt
real(c_float), dimension(:,:,:), pointer        :: accum_e
real(c_float), dimension(:,:,:,:), pointer      :: mLPNH
real(c_float), dimension(:,:,:,:), pointer      :: mLPSH
real(c_double), dimension(:), pointer           :: X
real(c_double), dimension(:), pointer           :: XL
real(c_double), dimension(:), pointer           :: XU


! the following line just helps in identifying the correct order of the subroutine arguments...
!                                        
!subroutine BOBYQA(nipar, nfpar, ninit, ipar, fpar, initmeanval, expt, N, NPT, X, XL, XU, RHOBEG, RHOEND, IPRINT, MAXFUN, ECPCALFUN, ACCUM_E, mLPNH, mLPSH)
!
! transform the C pointers above to fortran pointers, and use them in the regular function call
nipar = 9
nfpar = 10
ninit = 6
n = 6
iprint = 2
maxfun = 10000
npt = n + 6

call c_f_pointer(argv(1),ipar,(/nipar/)) 
call c_f_pointer(argv(2),fpar,(/nfpar/)) 
call c_f_pointer(argv(4),initmeanval,(/n/))
call c_f_pointer(argv(5),expt,(/ipar(2)*ipar(3)/))
call c_f_pointer(argv(6),X,(/n/))
call c_f_pointer(argv(7),XL,(/n/))
call c_f_pointer(argv(8),XU,(/n/))
call c_f_pointer(argv(9),RHOBEG,(/1/))
call c_f_pointer(argv(10),RHOEND,(/1/))
call c_f_pointer(argv(11),accum_e,(/ipar(4),2*ipar(5)+1,2*ipar(5)+1/))
call c_f_pointer(argv(12),mLPNH,(/2*ipar(6)+1, 2*ipar(6)+1, ipar(4), ipar(7)/))
call c_f_pointer(argv(13),mLPSH,(/2*ipar(6)+1, 2*ipar(6)+1, ipar(4), ipar(7)/))

! call BOBYQA(NIPAR, NFPAR, NINIT, IPAR, FPAR, INITMEANVAL, EXPT, N, NPT, X, XL, XU, RHOBEG(1), RHOEND(1),&
!      IPRINT, MAXFUN, ECPCALFUN, accum_e, mLPNH, mLPSH)

efitECPWrapper = 1._c_float

end function efitECPWrapper

!--------------------------------------------------------------------------
!
! SUBROUTINE:efitEBSDWrapper
!
!> @author Saransh Singh, Carnegie Mellon University
!
!> @brief wrapper routine for fitting EBSD pattern
!>
!> see https://groups.google.com/forum/#!topic/comp.lang.idl-pvwave/Gk0xxVFbW8E
!>
!
!> @param argc number of argument
!> @param argv pointers to subroutine parameters
!
!> @date 12/15/15  SS 1.0 original
!--------------------------------------------------------------------------
recursive function efitEBSDWrapper(argc, argv) bind(c, name='efitEBSDWrapper') 
!DEC$ ATTRIBUTES DLLEXPORT :: efitEBSDWrapper

use,INTRINSIC :: ISO_C_BINDING
!use bobyqa_module
use local

IMPLICIT NONE

INTEGER(c_size_t), VALUE, INTENT(IN)            :: argc 
type(c_ptr), dimension(argc), INTENT(INOUT)     :: argv
REAL(c_float)                                   :: efitEBSDWrapper

! wrapper function dependent declarations; they are all pointers 
! since we pass everything by reference from IDL 
integer(4)                                      :: nipar, nfpar, ninit, n, iprint, maxfun, npt
real(c_double), dimension(:), pointer           :: rhobeg, rhoend
integer(c_size_t),dimension(:), pointer         :: ipar
real(c_float), dimension(:), pointer            :: fpar
real(c_float), dimension(:), pointer            :: initmeanval
real(c_float), dimension(:), pointer            :: expt
real(c_float), dimension(:,:,:), pointer        :: accum_e
real(c_float), dimension(:,:,:,:), pointer      :: mLPNH
real(c_float), dimension(:,:,:,:), pointer      :: mLPSH
real(c_double), dimension(:), pointer           :: X
real(c_double), dimension(:), pointer           :: XL
real(c_double), dimension(:), pointer           :: XU



! the following line just helps in identifying the correct order of the subroutine arguments...
!                                        1      2     3       4           5           6   7   8   9        10
!subroutine BOBYQA(nipar, nfpar, ninit, ipar, fpar, fname, initmeanval, expt, N, NPT, X, XL, XU, RHOBEG, RHOEND, IPRINT, MAXFUN, EBSDCALFUN)
!
! transform the C pointers above to fortran pointers, and use them in the regular function call
nipar = 9
nfpar = 11
ninit = 4
n = 7
iprint = 2
maxfun = 10000
npt = n + 6

call c_f_pointer(argv(1),ipar,(/nipar/)) 
call c_f_pointer(argv(2),fpar,(/nfpar/)) 
call c_f_pointer(argv(3),initmeanval,(/n/))
call c_f_pointer(argv(4),expt,(/ipar(2)*ipar(3)/))
call c_f_pointer(argv(5),X,(/n/))
call c_f_pointer(argv(6),XL,(/n/))
call c_f_pointer(argv(7),XU,(/n/))
call c_f_pointer(argv(8),RHOBEG,(/1/))
call c_f_pointer(argv(9),RHOEND,(/1/))
call c_f_pointer(argv(10),accum_e,(/ipar(4),2*ipar(5)+1,2*ipar(5)+1/))
call c_f_pointer(argv(11),mLPNH,(/2*ipar(6)+1, 2*ipar(6)+1, ipar(4), ipar(7)/))
call c_f_pointer(argv(12),mLPSH,(/2*ipar(6)+1, 2*ipar(6)+1, ipar(4), ipar(7)/))

! call BOBYQA(NIPAR, NFPAR, NINIT, IPAR, FPAR, INITMEANVAL, EXPT, N, NPT, X, XL, XU, RHOBEG(1), RHOEND(1),&
!      IPRINT, MAXFUN, EBSDCALFUN, accum_e, mLPNH, mLPSH)

efitEBSDWrapper = 1._c_float

end function efitEBSDWrapper

end module EMdymod
