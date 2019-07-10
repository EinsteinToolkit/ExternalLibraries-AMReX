#! /bin/bash

################################################################################
# Prepare
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors

. $CCTK_HOME/lib/make/bash_utils.sh

# Take care of requests to build the library in any case
AMREX_DIR_INPUT=$AMREX_DIR
if [ "$(echo "${AMREX_DIR}" | tr '[a-z]' '[A-Z]')" = 'BUILD' ]; then
    AMREX_BUILD=1
    AMREX_DIR=
else
    AMREX_BUILD=
fi

################################################################################
# Decide which libraries to link with
################################################################################

# Set up names of the libraries based on configuration variables. Also
# assign default values to variables.
# Try to find the library if build isn't explicitly requested
if [ -z "${AMREX_BUILD}" -a -z "${AMREX_INC_DIRS}" -a -z "${AMREX_LIB_DIRS}" -a -z "${AMREX_LIBS}" ]; then
    find_lib AMREX amrex 1 1.0 "amrex" "AMReX.H" "$AMREX_DIR"
fi

THORN=AMReX

# configure library if build was requested or is needed (no usable
# library found)
if [ -n "$AMREX_BUILD" -o -z "${AMREX_DIR}" ]; then
    echo "BEGIN MESSAGE"
    echo "Using bundled AMReX..."
    echo "END MESSAGE"
    AMREX_BUILD=1

    check_tools "tar patch"
    
    # Set locations
    NAME=hdf5-1.8.17
    SRCDIR="$(dirname $0)"
    BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
    if [ -z "${AMREX_INSTALL_DIR}" ]; then
        INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
    else
        echo "BEGIN MESSAGE"
        echo "Installing AMReX into ${AMREX_INSTALL_DIR}"
        echo "END MESSAGE"
        INSTALL_DIR=${AMREX_INSTALL_DIR}
    fi
    AMREX_DIR=${INSTALL_DIR}
    # Fortran modules may be located in the lib directory
    AMREX_INC_DIRS="${AMREX_DIR}/include ${AMREX_DIR}/lib"
    AMREX_LIB_DIRS="${AMREX_DIR}/lib"
    AMREX_LIBS="${AMREX_CXX_LIBS} ${AMREX_FORTRAN_LIBS} ${AMREX_C_LIBS}"
else
    DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
    if [ ! -e ${DONE_FILE} ]; then
        mkdir ${SCRATCH_BUILD}/done 2> /dev/null || true
        date > ${DONE_FILE}
    fi
fi

if [ -n "$AMREX_DIR" ]; then
    : ${AMREX_RAW_LIB_DIRS:="$AMREX_LIB_DIRS"}
    # Fortran modules may be located in the lib directory
    AMREX_INC_DIRS="$AMREX_RAW_LIB_DIRS $AMREX_INC_DIRS"
    # We need the un-scrubbed inc dirs to look for a header file below.
    : ${AMREX_RAW_INC_DIRS:="$AMREX_INC_DIRS"}
else
    echo 'BEGIN ERROR'
    echo 'ERROR in AMReX configuration: Could neither find nor build library.'
    echo 'END ERROR'
    exit 1
fi

################################################################################
# Check for additional libraries
################################################################################


# Check whether we are running on Windows
if perl -we 'exit (`uname` =~ /^CYGWIN/)'; then
    is_windows=0
else
    is_windows=1
fi

# check installed library, assume that everything is fine if we build
if [ -z "$AMREX_BUILD" -a -n "${AMREX_DIR}" ]; then
  # find public include file
  H5PUBCONFFILES="H5pubconf.h H5pubconf-64.h H5pubconf-32.h"
  for dir in $AMREX_RAW_INC_DIRS; do
      for file in $H5PUBCONFFILES ; do
          if [ -r "$dir/$file" ]; then
              H5PUBCONF="$H5PUBCONF $dir/$file"
              break
          fi
      done
  done
  if [ -z "$H5PUBCONF" ]; then
      echo 'BEGIN MESSAGE'
      echo 'WARNING in AMReX configuration: '
      echo "None of $H5PUBCONFFILES found in $AMREX_RAW_INC_DIRS"
      echo "Automatic detection of szip/zlib compression not possible"
      echo 'END MESSAGE'
  fi
fi

# Add the math library which might not be linked by default
if [ $is_windows -eq 0 ]; then
    AMREX_LIBS="$AMREX_LIBS m"
fi



################################################################################
# Configure Cactus
################################################################################

# Pass configuration options to build script
echo "BEGIN MAKE_DEFINITION"
echo "AMREX_BUILD          = ${AMREX_BUILD}"
echo "AMREX_ENABLE_CXX     = ${AMREX_ENABLE_CXX}"
echo "AMREX_ENABLE_FORTRAN = ${AMREX_ENABLE_FORTRAN}"
echo "LIBSZ_DIR           = ${LIBSZ_DIR}"
echo "LIBZ_DIR            = ${LIBZ_DIR}"
echo "AMREX_INSTALL_DIR    = ${AMREX_INSTALL_DIR}"
echo "END MAKE_DEFINITION"

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "AMREX_DIR            = ${AMREX_DIR}"
echo "AMREX_ENABLE_CXX     = ${AMREX_ENABLE_CXX}"
echo "AMREX_ENABLE_FORTRAN = ${AMREX_ENABLE_FORTRAN}"
echo "AMREX_INC_DIRS       = ${AMREX_INC_DIRS} ${ZLIB_INC_DIRS}"
echo "AMREX_LIB_DIRS       = ${AMREX_LIB_DIRS} ${ZLIB_LIB_DIRS}"
echo "AMREX_LIBS           = ${AMREX_LIBS} ${ZLIB_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(AMREX_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(AMREX_LIB_DIRS)'
echo 'LIBRARY           $(AMREX_LIBS)'
