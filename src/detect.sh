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

# default value for FORTRAN support
if [ -z "$AMREX_ENABLE_FORTRAN" ] ; then
    AMREX_ENABLE_FORTRAN="OFF"
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
    AMREX_LIBS="amrex"
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


################################################################################
# Configure Cactus
################################################################################

# Pass configuration options to build script
echo "BEGIN MAKE_DEFINITION"
echo "AMREX_BUILD          = ${AMREX_BUILD}"
echo "AMREX_ENABLE_FORTRAN = ${AMREX_ENABLE_FORTRAN}"
echo "AMREX_ENABLE_CUDA    = ${AMREX_ENABLE_CUDA}"
echo "AMREX_INSTALL_DIR    = ${AMREX_INSTALL_DIR}"
echo "END MAKE_DEFINITION"

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "AMREX_DIR            = ${AMREX_DIR}"
echo "AMREX_ENABLE_FORTRAN = ${AMREX_ENABLE_FORTRAN}"
echo "AMREX_ENABLE_CUDA    = ${AMREX_ENABLE_CUDA}"
echo "AMREX_INC_DIRS       = ${AMREX_INC_DIRS}"
echo "AMREX_LIB_DIRS       = ${AMREX_LIB_DIRS}"
echo "AMREX_LIBS           = ${AMREX_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(AMREX_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(AMREX_LIB_DIRS)'
echo 'LIBRARY           $(AMREX_LIBS)'
