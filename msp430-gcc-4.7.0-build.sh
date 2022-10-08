#!/bin/bash

set -e

# Prerequisite for Linux (Ubuntu-based):
#   sudo apt-get install libncurses-dev flex libgmp3-dev libmpfr-dev bison libmpc-dev zlib1g-dev automake build-essential libtool patch tar wget
# If you have newer texinfo in the system, please uninstall or temporarily disable it during building this script:
#   sudo apt-get purge texinfo

# Prerequisite for macOS (Homebrew):
#   brew install wget texinfo gcc libtool
# Configure CC to homebrew's gcc, for example:
#   export CC=/usr/local/opt/gcc@12/bin/gcc-12

# Prerequisite for Windows (MSYS2):
#   pacman -S base-devel gmp gmp-devel mpfr mpfr-devel mpc mpc-devel ncurses-devel libtool patch tar wget

OS="`uname`"

BUILD=""
# Some aarch64 machine sometimes is not detected, select below as necessary
# BUILD="--build=aarch64-unknown-linux-gnu"
# If compiling for Windows, select build Cygwin (MSYS2 is based on it)
# BUILD="--build=x86_64-pc-cygwin"

HOST=""
# If cross-compiling for Windows from Linux of macOS, select host Cygwin (MSYS2 is based on it)
# HOST="--host=x86_64-pc-cygwin"

INSTALL_PREFIX="/usr/local/msp430"
echo The installation prefix:$INSTALL_PREFIX

# Switch to the tmp directory
mkdir -p tmp
cd tmp

# Getting sources
if [ $OS != "Darwin" ]; then
    if [ ! -f texinfo-4.8.tar.bz2 ]; then
        wget -c https://ftp.gnu.org/gnu/texinfo/texinfo-4.8.tar.bz2
    fi
fi
if [ ! -f mspgcc-20120911.tar.bz2 ]; then
    wget -c http://sourceforge.net/projects/mspgcc/files/mspgcc/DEVEL-4.7.x/mspgcc-20120911.tar.bz2
fi
if [ ! -f gcc-4.7.0-patches.tar.xz ]; then
    wget -c https://raw.githubusercontent.com/tgtakaoka/homebrew-mspgcc/master/patches/gcc-4.7.0-patches.tar.xz
fi
if [ ! -f msp430mcu-20130321.tar.bz2 ]; then
    wget -c http://sourceforge.net/projects/mspgcc/files/msp430mcu/msp430mcu-20130321.tar.bz2
fi
if [ ! -f msp430-libc-20120716.tar.bz2 ]; then
    wget -c http://sourceforge.net/projects/mspgcc/files/msp430-libc/msp430-libc-20120716.tar.bz2
fi
if [ ! -f binutils-2.22.tar.bz2 ]; then
    wget -c https://ftp.gnu.org/gnu/binutils/binutils-2.22.tar.bz2
fi
if [ ! -f gcc-4.7.0.tar.bz2 ]; then
    wget -c http://ftp.gnu.org/gnu/gcc/gcc-4.7.0/gcc-4.7.0.tar.bz2
fi

# Unpacking sources
if [ $OS != "Darwin" ]; then
    rm -rf texinfo-4.8
    tar xvfj texinfo-4.8.tar.bz2
fi
rm -rf binutils-2.22
tar xvfj binutils-2.22.tar.bz2
rm -rf gcc-4.7.0
tar xvfj gcc-4.7.0.tar.bz2
tar xvf gcc-4.7.0-patches.tar.xz
rm -rf mspgcc-20120911
tar xvfj mspgcc-20120911.tar.bz2
rm -rf msp430mcu-20130321
tar xvfj msp430mcu-20130321.tar.bz2
rm -rf msp430-libc-20120716
tar xvfj msp430-libc-20120716.tar.bz2

# 0) Build texinfo
if [ $OS != "Darwin" ]; then
    if [ -d texinfo-4.8 ]; then
        cd texinfo-4.8
        ./configure $BUILD $HOST --prefix="/usr/local"
        make
        sudo make install
        cd ..
    fi
fi

# 1) Incorporating the changes contained in the patch delievered in mspgcc-20120911
if [ -d binutils-2.22 ]; then
    cd binutils-2.22
    if [ ! -f patched ]; then
        patch -p1 < ../mspgcc-20120911/msp430-binutils-2.22-20120911.patch
        touch patched
    fi
    cd ..
fi

# 2) Incorporating the changes contained in the patch delievered in mspgcc-20120911
if [ -d gcc-4.7.0 ]; then
    cd gcc-4.7.0
    if [ ! -f patched ]; then
        patch -p1 < ../mspgcc-20120911/msp430-gcc-4.7.0-20120911.patch
        patch -p1 < ../gcc-4.7.0_PR-54638.patch
        patch -p1 < ../gcc-4.7.0_gperf.patch
        patch -p1 < ../gcc-4.7.0_libiberty-multilib.patch
        touch patched
    fi
    cd ..
fi

# 3) Creating new directories
mkdir -p binutils-2.22-msp430
mkdir -p gcc-4.7.0-msp430

# 4) Installing binutils in INSTALL_PREFIX
if [ -d binutils-2.22-msp430 ]; then
    cd binutils-2.22-msp430
    if [ ! -f configured ]; then
        ../binutils-2.22/configure --target=msp430 --program-prefix="msp430-" --prefix=$INSTALL_PREFIX $BUILD $HOST --disable-nls --disable-werror
        touch configured
    fi
    make
    make install
    cd ..
fi

# 5) Download the prerequisites
if [ -d gcc-4.7.0 ]; then
    cd gcc-4.7.0
    if [ ! -f downloaded ]; then
        ./contrib/download_prerequisites
        touch downloaded
    fi
    cd ..
fi

# 6) Compiling gcc-4.7.0 in INSTALL_PREFIX
if [ -d gcc-4.7.0-msp430 ]; then
    cd gcc-4.7.0-msp430
    if [ ! -f configured ]; then
        MAKEINFO=missing ../gcc-4.7.0/configure --target=msp430 --enable-languages=c --program-prefix="msp430-" --prefix=$INSTALL_PREFIX $BUILD $HOST --disable-nls --disable-werror
        touch configured
    fi
    make MAKEINFO=missing
    make install
    cd ..
fi

# 7) Compiling msp430mcu in INSTALL_PREFIX
if [ -d msp430mcu-20130321 ]; then
    cd msp430mcu-20130321
    export MSP430MCU_ROOT=$(pwd)
    scripts/install.sh ${INSTALL_PREFIX}/
    cd ..
fi

# 8) Compiling the msp430 lib in INSTALL_PREFIX
if [ -d msp430-libc-20120716 ]; then
    cd msp430-libc-20120716
    cd src
    PATH=${INSTALL_PREFIX}/bin:$PATH
    make
    make PREFIX=$INSTALL_PREFIX install
    cd ../..
fi

# Cleanup
# no need since every thing created in tmp
echo Reminder: remove tmp
