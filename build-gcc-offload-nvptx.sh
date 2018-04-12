#! /bin/bash

# Usage: build-gcc-offload-nvptx.sh [use_repo]
#        use_repo : Download gcc-7.3.0 from the repo
#                   Without this option, you must download these archives
#                   manually and place them at the same level as the script:
#                     gcc-7.3.0.tar.bz2
#                     gmp-6.1.0.tar.bz2
#                     mpfr-3.1.4.tar.bz2
#                     mpc-1.0.3.tar.gz
#                     isl-0.16.1.tar.bz2
# 
#
# This builds GCC with support for offloading to NVIDIA GPUs.
# For reference,
#   https://gcc.gnu.org/wiki/Offloading
#   https://gcc.gnu.org/install/specific.html#nvptx-x-none #
#
# You must have a working Cuda 9.1 package installed before running
# this script.
# Obtain Cuda from https://developer.nvidia.com/cuda-downloads
#
# An existing "bug" in Cuda 9.1 prevents building GCC versions > 6.
# The work-around is to install a local Cuda 9.1 stack minus the
# actual drivers (requires root) on a system where the drivers
# already exist, i.e. Kodiak. Then edit the file
#    cuda-9.1/include/crt/host_config.h
# and simply comment out the line 
#    error -- unsupported GNU version! gcc versions later than 6 are not supported!
# (Line 268 in Cuda 9.1 patch 3)
# Alternatively, have someone with root access change this line on
# an existing installation.
#
# Below, replace <YOUR_INSTALL_PATH> with the infall install location for the
# gcc builds. Replace <FIXED_CUDA_PATH>/cuda-9.1 with the path to a version
# of Cuda that works with GCC-7.3.0.
#

# USER SETTINGS
installdir=<YOUR_INSTALL_PATH>/gcc-7.3-offloading
cudadir=<FIXED_CUDA_PATH>/cuda-9.1

# ------------- You shouldn't have to edit below this line ---------------

# Define an error handler.
#   Code 2: File does not exist
error() {
   local parent_lineno="$1"
   local message="$2"
   local code="${3:-1}"
   echo "Error on or near line ${parent_lineno}: ${message}; exiting with status ${code}"
   exit "${code}"
}

topdir=`pwd`
builddir=$topdir/build

mkdir -p $builddir
cd $builddir

# Use latest appropriate binutils for this release
# We build these first, install to the final location
# as they will be used by the final GCC.
if [ ! -d "binutils-2.30" ]; then
  tar xf ../binutils-2.30.tar.gz
fi
cd binutils-2.30
./configure  --prefix=$installdir
make
#TODO: Test if this build fails.
make install

export PATH=$installdir/bin:$PATH

# Build the assembler and linking tools
git clone https://github.com/MentorEmbedded/nvptx-tools
cd nvptx-tools
./configure \
    --with-cuda-driver-include=$cudadir/include \
    --with-cuda-driver-lib=$cudadir/lib64 \
    --prefix=$installdir
make
make install

# TODO: It would be great to have a way to test the nvptx-tools install at this stage

cd $builddir

# Set up the GCC source tree
git clone https://github.com/MentorEmbedded/nvptx-newlib
# Do we grab GCC from the repo, along with required downloads?
if [ $1="use_repo" ]; then
  svn co http://gcc.gnu.org/svn/gcc/tags/gcc_7_3_0_release gcc-7.3.0
  cd gcc-7.3.0
  contrib/download_prerequisites
else
# If your system doesn't allow SVN access (LANL)
# You will have to download the following files separately
# by hand.
# Versions for this release were obtained from 
# gcc-7.3.0/contrib/download_prerequisites
#   gmp-6.1.0.tar.bz2
#   mpfr-3.1.4.tar.bz2
#   mpc-1.0.3.tar.gz
#   isl-0.16.1.tar.bz2
  if [ ! -d "gcc-7.3.0" ]; then
    if [ -e "gcc-7.3.0.tar.bz2" ]; then
      tar xf ../gcc-7.3.0.tar.bz2
    else
      error ${LINENO} "gcc-7.3.0.tar.bz2 does not exist!" 2
    fi
  fi
  if [ ! -d "gmp-6.1.0" ]; then
    if [ -e "gmp-6.1.0.tar.bz2" ]; then
      tar xf ../gmp-6.1.0.tar.bz2
    else
      error ${LINENO} "gmp-6.1.0.tar.bz2 does not exist!" 2
    fi
  fi
  if [ ! -d "isl-0.16.1" ]; then
    if [ -e "isl-0.16.1.tar.bz2" ]; then
      tar xf ../isl-0.16.1.tar.bz2
    else
      error ${LINENO} "isl-0.16.1.tar.bz2 does not exist!" 2
    fi
  fi
  if [ ! -d "mpc-1.0.3" ]; then
    if [ -e "mpc-1.0.3.tar.gz" ]; then
      tar xf ../mpc-1.0.3.tar.gz
    else
      error ${LINENO} "mpc-1.0.3.tar.gz does not exist!" 2
    fi
  fi
  if [ ! -d "mpfr-3.1.4" ]; then
    if [ -e "mpfr-3.1.4.tar.bz2" ]; then
      tar xf ../mpfr-3.1.4.tar.bz2
    else
      error ${LINENO} "mpfr-3.1.4.tar.bz2 does not exist!" 2
    fi
  fi
  cd gcc-7.3.0
  ln -sf ../gmp-6.1.0 gmp
  ln -sf ../isl-0.16.1 isl
  ln -sf ../mpc-1.0.3 mpc
  ln -sf ../mpfr-3.1.4 mpfr
fi

ln -sf ../nvptx-newlib/newlib newlib
cd $builddir
hosttarget=$(gcc-7.3.0/config.guess)

# Build GCC for nvptx
mkdir build-gcc-nvptx
cd build-gcc-nvptx
../gcc-7.3.0/configure \
    --target=nvptx-none --with-build-time-tools=$installdir/nvptx-none/bin \
    --enable-as-accelerator-for=$hosttarget \
    --disable-sjlj-exceptions \
    --enable-newlib-io-long-long \
    --enable-languages="c,c++,fortran,lto" \
    --prefix=$installdir
make -j4
#TODO: Check if the above build fails
make install
cd $builddir

# Build GCC for host cpu
mkdir build-gcc-host
cd  build-gcc-host
../gcc-7.3.0/configure \
    --enable-offload-targets=nvptx-none \
    --with-cuda-driver-include=$cudadir/include \
    --with-cuda-driver-lib=$cudadir/lib64 \
    --disable-bootstrap \
    --disable-multilib \
    --enable-languages="c,c++,fortran,lto" \
    --prefix=$installdir
make -j4
#TODO: Check if the above build fails
make install
cd $topdir

