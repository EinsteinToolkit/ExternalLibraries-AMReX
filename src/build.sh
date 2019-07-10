#! /bin/bash

################################################################################
# Build
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors



# Set locations
THORN=AMReX
NAME=amrex-36a98cdd9
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
DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
AMREX_DIR=${INSTALL_DIR}

echo "AMReX: Preparing directory structure..."
cd ${SCRATCH_BUILD}
mkdir build external done 2> /dev/null || true
rm -rf ${BUILD_DIR} ${INSTALL_DIR}
mkdir ${BUILD_DIR} ${INSTALL_DIR}

# Build core library
echo "AMReX: Unpacking archive..."
pushd ${BUILD_DIR}
${TAR?} xf ${SRCDIR}/../dist/${NAME}.tar

echo "AMReX: Configuring..."
cd ${NAME}
export CFLAGS="$(echo ${MPI_INC_DIRS} | sed 's/[^ ]*/-I&/g') ${CFLAGS}"
export CXXFLAGS="$(echo ${MPI_INC_DIRS} | sed 's/[^ ]*/-I&/g') ${CXXFLAGS}"
export F90FLAGS="$(echo ${MPI_INC_DIRS} | sed 's/[^ ]*/-I&/g') ${F90FLAGS}"

export FC=${F90}
export FFLAGS="${F90FLAGS}"

./configure --prefix=${AMREX_DIR} --with-omp=${CCTK_OPENMP_MODE} --with-mpi=yes --dim=3

echo "AMReX: Building..."
${MAKE}

echo "AMReX: Installing..."
${MAKE} install
popd

echo "AMReX: Cleaning up..."
rm -rf ${BUILD_DIR}

date > ${DONE_FILE}
echo "AMReX: Done."
