#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS=""
export STRIP="x86_64-w64-mingw32-strip"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

echo "Starting classical build for Windows..."

$SCONS platform=windows bits=64 $OPTIONS tools=yes target=release_debug
$STRIP bin/godot.windows.*
mkdir -p /root/out/x86_64/tools
cp -rvp bin/* /root/out/x86_64/tools
rm -rf bin

$SCONS platform=windows bits=64 $OPTIONS tools=no target=release_debug
$SCONS platform=windows bits=64 $OPTIONS tools=no target=release
$STRIP bin/godot.windows.*
mkdir -p /root/out/x86_64/templates
cp -rvp bin/* /root/out/x86_64/templates
rm -rf bin

$SCONS platform=windows bits=32 $OPTIONS tools=yes target=release_debug
$STRIP bin/godot.windows.*
mkdir -p /root/out/x86_32/tools
cp -rvp bin/* /root/out/x86_32/tools
rm -rf bin

$SCONS platform=windows bits=32 $OPTIONS tools=no target=release_debug
$SCONS platform=windows bits=32 $OPTIONS tools=no target=release
$STRIP bin/godot.windows.*
mkdir -p /root/out/x86_32/templates
cp -rvp bin/* /root/out/x86_32/templates
rm -rf bin

echo "Windows build successful"
