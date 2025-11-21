#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS=""

source /root/emsdk/emsdk_env.sh
export EMSCRIPTEN_ROOT=/root/emsdk/fastcomp/emscripten

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

echo "Starting classical build for Web..."

$SCONS platform=javascript ${OPTIONS} tools=no target=release_debug
$SCONS platform=javascript ${OPTIONS} tools=no target=release

mkdir -p /root/out/templates
cp -rvp bin/* /root/out/templates

echo "Web build successful"
