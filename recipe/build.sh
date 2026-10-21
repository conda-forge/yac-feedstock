#!/bin/bash

set -x

if [[ "${mpi}" == "openmpi" ]]; then
  export MPI_LAUNCH="${PREFIX}/bin/mpirun --oversubscribe"
  export OMPI_MCA_plm_rsh_agent=""
  if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    # openmpi's mpicc/mpifort under $PREFIX are compiled binaries for the
    # host (target) arch; when cross-compiling (e.g. osx-64 -> osx-arm64)
    # they can't run on the build machine at all. $BUILD_PREFIX carries a
    # build-arch copy of openmpi (added to requirements/build for exactly
    # this case) whose wrapper is configured -- via OMPI_CC/OMPI_FC/
    # OPAL_PREFIX, set automatically by openmpi's own activation script --
    # to target the host env instead. Same fix as
    # conda-forge/libpnetcdf-feedstock.
    COMPILER_PREFIX="${BUILD_PREFIX}"
  else
    COMPILER_PREFIX="${PREFIX}"
  fi
  export CC="${COMPILER_PREFIX}/bin/mpicc"
  export FC="${COMPILER_PREFIX}/bin/mpifort"
else
  export MPI_LAUNCH="${PREFIX}/bin/mpirun"
  export CC=mpicc
  export FC=mpifort
fi

Python_INCLUDE_DIR="$(python -c 'import sysconfig; print(sysconfig.get_path("include"))')"
Python_NumPy_INCLUDE_DIR="$(python -c 'import numpy; print(numpy.get_include())')"

cmake -B build -S . \
      -DCMAKE_INSTALL_PREFIX=${PREFIX} \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON \
      -DYAC_ENABLE_PYTHON=ON \
      -DYAC_ENABLE_NETCDF=OFF \
      -DYAC_ENABLE_EXAMPLES=OFF \
      -DYAC_ENABLE_TOOLS=OFF \
      -DYAC_ENABLE_MPI_CHECKS=OFF \
      -DYAC_LAPACK_INTERFACE=system \
      -DPython3_FIND_STRATEGY=LOCATION \
      -DPython3_EXECUTABLE:PATH=${PYTHON} \
      -DPython3_INCLUDE_DIR:PATH=${Python_INCLUDE_DIR} \
      -DPython3_NumPy_INCLUDE_DIR=${Python_NumPy_INCLUDE_DIR}

cmake --build build -j ${CPU_COUNT}

cmake --install build

# Since YAC 3.21.0, `cmake --install` no longer installs the Python bindings
# (only scikit-build builds do). Instead, CMake generates build/python/setup.py,
# which copies the prebuilt extension modules into site-packages.
${PYTHON} -m pip install ./build/python --no-deps --no-build-isolation -vv
