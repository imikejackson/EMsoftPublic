# ---------- Find HDF5 Headers/Libraries -----------------------
# HDF5 now comes with everything that is needed for CMake to load
# up the targets (Exported) that it needs. We just need to find where
# HDF5 is installed.
include(${CMP_SOURCE_DIR}/ExtLib/HDF5Support.cmake)


# ---------- Find Json Fortran Headers/Libraries -----------------------
# Json-Fortran comes with everything that cmake needs to determine the
# include directories, libraries and other items. One only needs to put
# the correct path onto the CMAKE_PREFIX_PATH variable.
if (Fortran_COMPILER_NAME MATCHES "gfortran.*")
  find_package(jsonfortran-gnu REQUIRED)
  if( NOT jsonfortran-gnu_FOUND)
    message(STATUS "jsonfortran is REQUIRED for this project.")
    message(STATUS "jsonfortran source repository is at https://github.com/jacobwilliams/json-fortran")
    message(FATAL_ERROR "Please Download, Build and install. After install export the environment variable JSONFORTRAN_INSTALL to point to the installation location.")
  endif()
endif()

if (Fortran_COMPILER_NAME MATCHES "ifort.*")
  find_package(jsonfortran-intel REQUIRED)
  if( NOT jsonfortran-intel_FOUND)
    message(STATUS "jsonfortran is REQUIRED for this project.")
    message(STATUS "jsonfortran source repository is at https://github.com/jacobwilliams/json-fortran")
    message(FATAL_ERROR "Please Download, Build and install. After install export the environment variable JSONFORTRAN_INSTALL to point to the installation location.")
  endif()
endif()


GET_FILENAME_COMPONENT (jsonfortran_LIBRARY_DIRS "${jsonfortran_INCLUDE_DIRS}" PATH)
set(jsonfortran_LIBRARY_DIRS ${jsonfortran_LIBRARY_DIRS}/lib)
message(STATUS "jsonfortran Location: ${JSONFORTRAN_INSTALL}")
# message(STATUS "jsonfortran Version: ${jsonfortran_VERSION}")
# message(STATUS "jsonfortran LIBRARY DIR: ${jsonfortran_LIBRARY_DIRS}")
include_directories(${jsonfortran_INCLUDE_DIRS})

#------------------------------------------------------------------------------
# Find the BLAS/LAPACK library
# On mac systems, we likely have to link against the vecLib framework
if(APPLE)
  find_library(EMsoft_BLAS_LAPACK_LIBS Accelerate)
 # include_directories(" -FvecLib")
elseif(UNIX AND NOT APPLE)
  find_package(LAPACK REQUIRED)
  if(LAPACK_FOUND)
    set(EMsoft_BLAS_LAPACK_LIBS ${LAPACK_LIBRARIES})
  else()
    message(STATUS "LAPACK NOT Found for LINUX. Install LAPACK/BLAS on your system")
  endif()
elseif(WIN32)

  if (Fortran_COMPILER_NAME MATCHES "gfortran.*")
    message(FATAL_ERROR "EMsoft does not currently support GFotran on Windows. Please contact the developers.")
  endif()

  if (Fortran_COMPILER_NAME MATCHES "ifort.*")
    set(USE_MKL TRUE)
    find_package(MKL REQUIRED)
    if(MKL_FOUND)
      set(EMsoft_BLAS_LAPACK_LIBS ${MKL_LIBRARIES})
    else()
      message(FATAL_ERROR "Intel MKL libraries were not found.")
    endif()
  else()

  endif()

else()
  message(FATAL_ERROR "This platform needs to have CMake code inserted to find the BLAS/LAPACK Libraries.")
endif(APPLE)



include_directories(${JSONFORTRAN_INCLUDE_DIR} ${FFTW3_INCLUDE_DIR} ${CLFORTRAN_INCLUDE_DIR})

#------------------------------------------------------------------------------
# Find the OpenCL Package
find_package( OpenCL REQUIRED )
if(OpenCL_FOUND)
  message(STATUS "OpenCL_FOUND: ${OpenCL_FOUND}")
  # message(STATUS "OpenCL_VERSION_STRING: ${OpenCL_VERSION_STRING}")
  # message(STATUS "OpenCL_INCLUDE_DIRS: ${OpenCL_INCLUDE_DIRS}")
  # message(STATUS "OpenCL_LIBRARIES: ${OpenCL_LIBRARIES}")
#  message(STATUS "OpenCL_INCLUDE_DIR: ${OpenCL_INCLUDE_DIR}")
#  message(STATUS "OpenCL_LIBRARY: ${OpenCL_LIBRARY}")
else()
  message(FATAL_ERROR "OpenCL is needed to compile some programs in EMSoft. Please install a package appropriate for your Operating System")
endif()

include_directories( ${OpenCL_INCLUDE_DIRS} )

# Figure out if the OpenCL Package has CPP bindings
if( OPENCL_HAS_CPP_BINDINGS )
  message(STATUS "OpenCL has CPP bindings:: YES\n   Full include is: " ${OpenCL_INCLUDE_DIRS} )
else( OPENCL_HAS_CPP_BINDINGS )
  message(STATUS "OpenCL has CPP bindings:: NO" )
endif( OPENCL_HAS_CPP_BINDINGS )

#------------------------------------------------------------------------------
# Find the Fortran OpenCL Bindings Package
find_package(CLFortran REQUIRED)
if( NOT CLFORTRAN_FOUND)
  message(STATUS "CLFortran is REQUIRED for this project.")
  message(STATUS "CLFortran source repository is at http://code.google.com/p/fortrancl/downloads/list")
  message(FATAL_ERROR "Please Download, Build and install. After install export the environment variable CLFORTRAN_INSTALL to point to the installation location.")
else()
  message(STATUS "CLFortran Found.")
endif()

# ---------- Find FFTW3 Headers/Libraries -----------------------
include(${CMP_SOURCE_DIR}/Modules/FindFFTW3.cmake)
CMP_COPY_DEPENDENT_LIBRARIES(fftw3)
CMP_LIBRARIES_INSTALL_RULES(fftw3 bin)
