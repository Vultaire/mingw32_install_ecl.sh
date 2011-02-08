#!/bin/bash
#
# Installation script for ECL 11.1.1
# For Mingw32/Msys
#
# Prerequisites:
#
# - MinGW/MSys installed via mingw-get-inst
#   (Tested with mingw-get-inst-20101030.exe.
#    Link: http://downloads.sourceforge.net/project/mingw/Automated%20MinGW%20Installer/mingw-get-inst/mingw-get-inst-20101030/mingw-get-inst-20101030.exe)
#
# - Wget for Windows
#   (Tested with gnuwin32 version:
#    http://gnuwin32.sourceforge.net/packages/wget.htm.
#    Link: http://downloads.sourceforge.net/gnuwin32/wget-1.11.4-1-setup.exe)
#
# NOTE: Wget must be added to your PATH!

set -e

BOEHM_URL=http://www.hpl.hp.com/personal/Hans_Boehm/gc/gc_source/gc-7.2alpha4.tar.gz
BOEHM_TARBALL=${BOEHM_URL##*/}
BOEHM_DIR=${BOEHM_TARBALL%.tar.gz}

ECL_URL=http://downloads.sourceforge.net/project/ecls/ecls/11.1/ecl-11.1.1.tar.gz
ECL_TARBALL=${ECL_URL##*/}
ECL_DIR=${ECL_TARBALL%.tar.gz}

FFI_URL=ftp://sources.redhat.com/pub/libffi/libffi-3.0.9.tar.gz
FFI_TARBALL=${FFI_URL##*/}
FFI_DIR=${FFI_TARBALL%.tar.gz}

# HOME should be set up automatically via MSys, or via your
# environment variable HOME if set.  There should be no need to set it.
if [ -z "$HOME" ]; then
    echo "The environment variable HOME is not defined. " \
        "This script cannot continue." 2>&1
    exit 1
fi

# CHOME (c:/-style HOME) can be determined in a round-about way as
# follows...
cd $HOME &>/dev/null
CHOME=$(pwd -W)
cd - &>/dev/null

BUILD_ROOT="$HOME/ecl_build"
PREFIX="$BUILD_ROOT/mingw32"
CPREFIX="$CHOME/ecl_build/mingw32"

# I *believe* win32 is correct for this.  The ECL configure also uses
# "win32" as the thread lib for MinGW builds.
THREADS=win32

######################################################################

prepare_sources () {
    if [ ! -e "$BUILD_ROOT" ]; then
        mkdir -v $BUILD_ROOT
    fi
    cd $BUILD_ROOT

    # Download all
    for url in $BOEHM_URL $ECL_URL $FFI_URL; do
        tarball="${url##*/}"
        if [ ! -e "$tarball" ]; then
            echo "Downloading $url..."
            wget $url &> $tarball.download.log
        fi
    done

    # Extract all
    for tarball in $BOEHM_TARBALL $ECL_TARBALL $FFI_TARBALL; do
        dir="${tarball%.tar.gz}"
        if [ ! -e "$dir" ]; then
            echo "Extracting $tarball..."
            tar -xf $tarball
        fi
    done
}

build_boehm_gc () {
    if [ -e "$PREFIX/lib/libgc.a" ]; then
        echo "Boehm GC detected; skipping build."
        return 0
    fi
    cd "$BUILD_ROOT/$BOEHM_DIR"
    echo "Building Boehm GC..."
    echo "- configure"
    ./configure --prefix="$PREFIX" --disable-shared --enable-threads=$THREADS \
        > configure.log
    echo "- make"
    make > make.log
    echo "- make install"
    make install > make_install.log
    echo "Boehm GC build complete."
}

build_gmp () {
    if [ -e "$PREFIX/lib/libgmp.a" ]; then
        echo "GMP detected; skipping build."
        return 0
    fi
    mkdir -p "$BUILD_ROOT/gmp"
    cd "$BUILD_ROOT/gmp"
    echo "Building GMP (version bundled within ECL)..."
    echo "- configure"
    "$BUILD_ROOT/$ECL_DIR/src/gmp/configure" --prefix="$PREFIX" \
        --disable-shared > configure.log
    echo "- make"
    make > make.log
    echo "- make install"
    make install > make_install.log
    echo "- make check"
    make check > make_check.log
    echo "GMP build complete."
}

build_libffi () {
    if [ -e "$PREFIX/lib/libffi.a" ]; then
        echo "libffi detected; skipping build."
        return 0
    fi
    cd "$BUILD_ROOT/$FFI_DIR"
    echo "Building libffi..."
    echo "- configure"
    ./configure --prefix="$PREFIX" --disable-shared > configure.log
    echo "- make"
    make > make.log
    echo "- make install"
    make install > make_install.log
    echo "libffi build complete."
}

build_ecl () {
    if [ -e "$PREFIX/ecl.exe" ]; then
        echo "ECL detected ($CPREFIX/ecl.exe); no need to compile."
        return 0
    fi

    cd "$BUILD_ROOT/$ECL_DIR"
    echo "Building ECL..."

    if [ -e "$BUILD_ROOT/$ECL_DIR/build" ]; then
        # NOTE: configure seems to fail if the build folder has been
        # previously created: it tries to make subfolders but fails.
        # I'll put a warning here in case anyone else hits this
        # problem.
        echo "WARNING: Previous build directory detected: this may need to " \
            "be deleted before building ECL: $BUILD_ROOT/$ECL_DIR/build" 2>&1
    fi

    echo "- configure"
    # NOTE: To build properly (via ECL), we need C:/-style paths for
    # includes/libs, not Msys paths.
    cppflags="-I$CPREFIX/include -I$CPREFIX/lib/$FFI_DIR/include"
    ldflags=-L$CPREFIX/lib
    ./configure --prefix="$PREFIX" --enable-threads CPPFLAGS="$cppflags" \
        LDFLAGS="$ldflags" --enable-boehm=system > configure.log

    echo "- make"
    make > make.log

    echo "- make install"
    make install > make_install.log

    echo "ECL build complete."
    echo "The ECL executable is located at $CPREFIX/ecl.exe."
}

prepare_sources
build_boehm_gc
build_gmp
build_libffi
build_ecl
