GCC-7.3.0-offload
=================

A working script and set of files to build gcc-7.3.0 for offloading to Nvidia GPUs

The script "build-gcc-offload-nvptx.sh" builds GCC with support for offloading to NVIDIA GPUs.

For reference,  
   https://gcc.gnu.org/wiki/Offloading  
   https://gcc.gnu.org/install/specific.html#nvptx-x-none

You must have a working Cuda 9.1 package installed before running this script.
Obtain Cuda from https://developer.nvidia.com/cuda-downloads

An existing "bug" in Cuda 9.1 prevents building GCC versions > 6. The work-around is to install a local Cuda 9.1 stack minus the actual drivers (requires root) on a system where the drivers already exist, i.e. LANL HPC systems. Then edit the file

> cuda-9.1/include/crt/host_config.h

and simply comment out the line 

> error -- unsupported GNU version! gcc versions later than 6 are not supported!

(Line 268 in Cuda 9.1 patch 3)
Alternatively, have someone with root access change this line on an existing installation.

If you want the script to download the necessary source tarball falls, launch as

> $ build-gcc-offload-nvptx.sh use_repo

Otherwiwse you will need to download the following tarballs and place them at the same level as the install script:
   * gcc-7.3.0.tar.bz2
   * gmp-6.1.0.tar.bz2
   * mpfr-3.1.4.tar.bz2
   * mpc-1.0.3.tar.gz
   * isl-0.16.1.tar.bz2
  
Those versions match those defined in gcc-7.3.0/contrib/download_prerequisites.

