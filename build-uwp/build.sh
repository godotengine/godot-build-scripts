#!/bin/bash

set -e

export ANGLE_SRC_PATH='c:\angle'
export BUILD_NAME=official
export SCONS="call scons -j4 verbose=yes warnings=no progress=no"
export OPTIONS="builtin_libpng=yes builtin_openssl=yes builtin_zlib=yes debug_symbols=no"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

for arch in x86 x64 arm; do
  for release in release release_debug; do
    wine cmd /c /root/build/build.bat $arch $release

    sync
    wineserver -kw

    mkdir -p /root/out/$arch
    mv bin/* /root/out/$arch
  done
done

