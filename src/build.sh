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
NAME=amrex-25.11
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
export CFLAGS="$(echo ${MPI_INC_DIRS} | sed 's/[^ ][^ ]*/-I&/g') ${CFLAGS}"
export CXXFLAGS="$(echo ${MPI_INC_DIRS} | sed 's/[^ ][^ ]*/-I&/g') ${CXXFLAGS}"
export CUCCFLAGS="$(echo ${MPI_INC_DIRS} | sed 's/[^ ][^ ]*/-I&/g') ${CUCCFLAGS}"
export F90FLAGS="$(echo ${MPI_INC_DIRS} | sed 's/[^ ][^ ]*/-I&/g') ${F90FLAGS}"

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
  AMREX_GPU_OPTIONS=(-DAMReX_GPU_BACKEND=CUDA -DAMReX_CUDA_ERROR_CAPTURE_THIS=ON -DAMReX_CUDA_ERROR_CROSS_EXECUTION_SPACE_CALL=ON ${CUCC:+"-DCMAKE_CUDA_COMPILER=${CUCC}"} ${CUCCFLAGS:+"-DCMAKE_CUDA_FLAGS=${CUCCFLAGS}"} -DCMAKE_CUDA_COMPILER_FORCED=ON -DCMAKE_CUDA_COMPILE_FEATURES=cuda_std_17 -DCMAKE_CUDA_IMPLICIT_INCLUDE_DIRECTORIES='${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES}' -DCMAKE_CUDA_ARCHITECTURES=${AMREX_CMAKE_CUDA_ARCHITECTURES})
elif [ "$(echo ${AMREX_ENABLE_HIP} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
  AMREX_GPU_OPTIONS=(-DAMReX_CUDA=OFF -DAMReX_GPU_BACKEND=HIP -DCMAKE_CXX_COMPILER=${CXX} -DAMReX_AMD_ARCH=${AMREX_AMD_ARCH})
else
  AMREX_GPU_OPTIONS=(-DAMReX_CUDA=OFF -DAMReX_GPU_BACKEND=NONE)
fi

# CMake's FindMPI does not reliably locate an MPI installation built from
# source by the MPI thorn (no system MPI is registered), which causes
# find_package(MPI) to fail with e.g. "Could NOT find MPI_CXX (missing:
# MPI_CXX_LIB_NAMES MPI_CXX_HEADER_DIR MPI_CXX_WORKS)". When the MPI thorn
# built MPI from source (MPI_BUILD set), hint CMake at it via MPI_HOME and
# the wrapper compilers found beneath MPI_DIR.
#
# For a system or manually configured MPI (MPI_BUILD empty) FindMPI instead
# interrogates whatever wrapper compiler it finds, and some wrappers defeat
# it: Intel oneAPI's mpicc answers none of the -showme / -compile-info style
# queries FindMPI issues (only -show, which FindMPI does not use), so
# MPI_<LANG>_LIB_NAMES stays empty and FindMPI's link test fails with
# "undefined symbol: MPI_Init" even though mpi.h was found via MPI_HOME.
# The MPI thorn has already resolved MPI_INC_DIRS / MPI_LIB_DIRS / MPI_LIBS
# for exactly this configuration, so skip wrapper interrogation altogether
# and pass those to FindMPI as its manual MPI_<LANG>_HEADER_DIR,
# MPI_<LANG>_LIB_NAMES and MPI_<lib>_LIBRARY settings (C and C++ only;
# Fortran keeps CMake's own detection). Only libraries found beneath
# MPI_LIB_DIRS are listed: FindMPI demands a resolved path for every name
# and does not fall back to the system paths, and the remaining entries of
# MPI_LIBS (typically rt, pthread, dl) are system libraries the final Cactus
# link adds from MPI_LIBS anyway.
MPI_C_OPTION=
MPI_CXX_OPTION=
MPI_Fortran_OPTION=
MPI_MANUAL_OPTIONS=
if [ -n "${MPI_BUILD}" ] && [ -n "${MPI_DIR}" ] && [ -d "${MPI_DIR}" ]; then
  export MPI_HOME="${MPI_DIR}"
  if [ -x "${MPI_DIR}/bin/mpicc" ]; then
    MPI_C_OPTION="-DMPI_C_COMPILER=${MPI_DIR}/bin/mpicc"
  fi
  if [ -x "${MPI_DIR}/bin/mpicxx" ]; then
    MPI_CXX_OPTION="-DMPI_CXX_COMPILER=${MPI_DIR}/bin/mpicxx"
  fi
  if [ "${AMREX_ENABLE_FORTRAN}" = ON ] && [ -x "${MPI_DIR}/bin/mpifort" ]; then
    MPI_Fortran_OPTION="-DMPI_Fortran_COMPILER=${MPI_DIR}/bin/mpifort"
  fi
  export PATH="${MPI_DIR}/bin:${PATH}"
elif [ -n "${MPI_INC_DIRS}" ] && [ -n "${MPI_LIBS}" ]; then
  MPI_FIRST_INC_DIR="${MPI_INC_DIRS%% *}"
  MPI_EXTRA_INC_DIRS=$(echo ${MPI_INC_DIRS#"${MPI_FIRST_INC_DIR}"} | tr ' ' ';')
  MPI_MANUAL_OPTIONS="-DMPI_C_HEADER_DIR=${MPI_FIRST_INC_DIR} -DMPI_CXX_HEADER_DIR=${MPI_FIRST_INC_DIR}"
  if [ -n "${MPI_EXTRA_INC_DIRS}" ]; then
    MPI_MANUAL_OPTIONS="${MPI_MANUAL_OPTIONS} -DMPI_C_ADDITIONAL_INCLUDE_DIRS=${MPI_EXTRA_INC_DIRS} -DMPI_CXX_ADDITIONAL_INCLUDE_DIRS=${MPI_EXTRA_INC_DIRS}"
  fi
  MPI_LIB_NAMES=
  for MPI_LIB in ${MPI_LIBS}; do
    for MPI_LIB_DIR in ${MPI_LIB_DIRS}; do
      for MPI_LIB_FILE in "${MPI_LIB_DIR}/lib${MPI_LIB}.so" "${MPI_LIB_DIR}/lib${MPI_LIB}.a"; do
        if [ -f "${MPI_LIB_FILE}" ]; then
          MPI_LIB_NAMES="${MPI_LIB_NAMES}${MPI_LIB_NAMES:+;}${MPI_LIB}"
          MPI_MANUAL_OPTIONS="${MPI_MANUAL_OPTIONS} -DMPI_${MPI_LIB}_LIBRARY=${MPI_LIB_FILE}"
          break 2
        fi
      done
    done
  done
  MPI_MANUAL_OPTIONS="${MPI_MANUAL_OPTIONS} -DMPI_C_LIB_NAMES=${MPI_LIB_NAMES} -DMPI_CXX_LIB_NAMES=${MPI_LIB_NAMES}"
fi

mkdir build
cd build
${CMAKE_DIR:+${CMAKE_DIR}/bin/}cmake -DCMAKE_BUILD_TYPE=${AMREX_BUILD_TYPE} -DAMReX_PARTICLES=ON -DAMReX_ASSERTIONS=ON -DAMReX_FORTRAN=${AMREX_ENABLE_FORTRAN} "${AMREX_GPU_OPTIONS[@]}" ${MPI_C_OPTION} ${MPI_CXX_OPTION} ${MPI_Fortran_OPTION} ${MPI_MANUAL_OPTIONS} -DAMReX_OMP=${AMREX_ENABLE_OPENMP} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} ..

echo "AMReX: Building..."
${MAKE}

echo "AMReX: Installing..."
${MAKE} install
popd

echo "AMReX: Cleaning up..."
rm -rf ${BUILD_DIR}

date > ${DONE_FILE}
echo "AMReX: Done."
