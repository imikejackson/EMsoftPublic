# - Find szlib
# Find the native FORTRANCL_LIB includes and library
#
#  FORTRANCL_INCLUDE_DIR - where to find szlib.h, etc.
#  FORTRANCL_LIBRARIES   - List of libraries when using szlib.
#  FORTRANCL_FOUND       - True if szlib found.
set(FortranCL_DEBUG 0)
if(FortranCL_DEBUG)
  MESSAGE(STATUS "Finding FortranCL")
endif()

# Only set FORTRANCL_INSTALL to the environment variable if it is blank
if("${FORTRANCL_INSTALL}" STREQUAL "")
    set(FORTRANCL_INSTALL  $ENV{FORTRANCL_INSTALL})
endif()

IF (FORTRANCL_INCLUDE_DIR)
  # Already in cache, be silent
  SET(FORTRANCL_LIB_FIND_QUIETLY TRUE)
ENDIF (FORTRANCL_INCLUDE_DIR)

FIND_PATH(FORTRANCL_INCLUDE_DIR cl.mod
  ${FORTRANCL_INSTALL}/include
  /usr/local/include
  /usr/include
  NO_DEFAULT_PATH
)

SET(FORTRANCL_LIB_NAMES fortrancl)
FIND_LIBRARY(FORTRANCL_LIBRARY
  NAMES ${FORTRANCL_LIB_NAMES}
  PATHS
  ${FORTRANCL_INSTALL}/lib /usr/lib /usr/local/lib
  NO_DEFAULT_PATH
)

if(FortranCL_DEBUG)
  MESSAGE(STATUS "FORTRANCL_LIBRARY: ${FORTRANCL_LIBRARY}")
  MESSAGE(STATUS "FORTRANCL_INCLUDE_DIR: ${FORTRANCL_INCLUDE_DIR}")
ENDIF()

IF (FORTRANCL_INCLUDE_DIR AND FORTRANCL_LIBRARY)
   SET(FORTRANCL_FOUND TRUE)
   SET( FORTRANCL_LIBRARIES ${FORTRANCL_LIBRARY} )
ELSE (FORTRANCL_INCLUDE_DIR AND FORTRANCL_LIBRARY)
   SET(FORTRANCL_FOUND FALSE)
   SET( FORTRANCL_LIBRARIES )
ENDIF (FORTRANCL_INCLUDE_DIR AND FORTRANCL_LIBRARY)

IF (FORTRANCL_FOUND)
  message(STATUS "FortranCL Location: ${FORTRANCL_INSTALL}")
  message(STATUS "FortranCL Version: ${FORTRANCL_VERSION}")
  message(STATUS "FortranCL LIBRARY: ${FORTRANCL_LIBRARY}")

ELSE (FORTRANCL_FOUND)
  IF (FORTRANCL_LIB_FIND_REQUIRED)
    MESSAGE(STATUS "Looked for FortranCL libraries named ${FORTRANCL_LIBS_NAMES}.")
    MESSAGE(FATAL_ERROR "Could NOT find FortranCL library")
  ENDIF (FORTRANCL_LIB_FIND_REQUIRED)
ENDIF (FORTRANCL_FOUND)

MARK_AS_ADVANCED(
  FORTRANCL_LIBRARY
  FORTRANCL_INCLUDE_DIR
  )
