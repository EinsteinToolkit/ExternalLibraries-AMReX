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
NAME=amrex-21.07
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

if [ "${CCTK_DEBUG_MODE}" = yes ]; then
    AMREX_BUILD_TYPE=Debug
else
    AMREX_BUILD_TYPE=Release
fi

if [ "${CCTK_OPENMP_MODE}" = yes ]; then
    AMREX_ENABLE_OPENMP=ON
else
    AMREX_ENABLE_OPENMP=OFF
fi

if [ "$(echo ${AMREX_ENABLE_CUDA} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
  AMREX_GPU_OPTIONS="-DAMReX_CUDA=ON -DAMReX_GPU_BACKEND=CUDA -DAMReX_CUDA_ERROR_CAPTURE_THIS=ON -DAMReX_CUDA_ERROR_CROSS_EXECUTION_SPACE_CALL=ON ${CUCC:+-DCMAKE_CUDA_COMPILER=${CUCC}}"
  #TODO: make possible to specify CUDA arch in case AMReX's auto-detect fails
  #  -DAMReX_CUDA_ARCH=75
else
  AMREX_GPU_OPTIONS="-DAMReX_CUDA=OFF"
fi


mkdir build
cd build
${CMAKE_DIR:+${CMAKE_DIR}/bin/}cmake -DCMAKE_BUILD_TYPE=${AMREX_BUILD_TYPE} -DAMReX_PARTICLES=ON -DAMReX_ASSERTIONS=ON -DAMReX_FORTRAN=${AMREX_ENABLE_FORTRAN} ${AMREX_GPU_OPTIONS} -DAMReX_OMP=${AMREX_ENABLE_OPENMP} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} ..

echo "AMReX: Building..."
${MAKE}

echo "AMReX: Installing..."
${MAKE} install
popd

echo "AMReX: Cleaning up..."
rm -rf ${BUILD_DIR}

date > ${DONE_FILE}
echo "AMReX: Done."
