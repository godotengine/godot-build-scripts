#!/bin/bash

set -e

export BUILD_NAME=official
export SCONS="scons -j16 verbose=yes warnings=no progress=no"
export OPTIONS="builtin_libpng=yes builtin_openssl=yes builtin_zlib=yes debug_symbols=no use_static_cpp=yes use_lto=yes"
export MONO_OPTIONS="module_mono_enabled=yes mono_static=yes copy_mono_root=yes"
export TERM=xterm
export MONO32_PREFIX=/usr
export MONO64_PREFIX=/usr
export CC="gcc-8"
export CXX="g++-8"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

$SCONS platform=server CC=$CC CXX=$CXX $OPTIONS tools=no target=release_debug 
$SCONS platform=server CC=$CC CXX=$CXX $OPTIONS tools=no target=release
mkdir -p /root/out/templates
cp -rvp bin/* /root/out/templates
rm -rf bin

$SCONS platform=server CC=$CC CXX=$CXX $OPTIONS tools=yes target=release_debug
mkdir -p /root/out/tools
cp -rvp bin/* /root/out/tools
rm -rf bin

