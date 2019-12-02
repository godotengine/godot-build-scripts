#!/bin/bash

set -e

export BUILD_NAME=official
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="builtin_libpng=yes builtin_openssl=yes builtin_zlib=yes debug_symbols=no use_static_cpp=yes use_lto=yes"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes mono_prefix=/root/mono-installs/wasm-runtime-release"
export TERM=xterm

source /root/emsdk/emsdk_env.sh

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

cp /root/mono-glue/*.cpp modules/mono/glue/
cp -r /root/mono-glue/Managed/Generated modules/mono/glue/Managed/

$SCONS platform=javascript ${OPTIONS} target=release_debug tools=no
$SCONS platform=javascript ${OPTIONS} target=release tools=no

mkdir -p /root/out/templates
cp -rvp bin/*.zip /root/out/templates
rm -f bin/*.zip

$SCONS platform=javascript ${OPTIONS} ${OPTIONS_MONO} target=release_debug tools=no
$SCONS platform=javascript ${OPTIONS} ${OPTIONS_MONO} target=release tools=no

mkdir -p /root/out/templates-mono
cp -rvp bin/*.zip /root/out/templates-mono
rm -f bin/*.zip

mkdir -p /root/out/templates-mono/bcl
cp -r /root/mono-installs/wasm-bcl/wasm /root/out/templates-mono/bcl/
