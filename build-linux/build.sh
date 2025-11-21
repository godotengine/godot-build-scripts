#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="use_static_cpp=yes"
export STRIP="strip"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

echo "Starting classical build for Linux..."

export PATH="${GODOT_SDK_LINUX_X86_64}/bin:${BASE_PATH}"

$SCONS platform=x11 bits=64 $OPTIONS tools=yes target=release_debug
$STRIP bin/godot.x11.*
mkdir -p /root/out/x86_64/tools
cp -rvp bin/* /root/out/x86_64/tools
rm -rf bin

$SCONS platform=x11 bits=64 $OPTIONS tools=no target=release_debug
$SCONS platform=x11 bits=64 $OPTIONS tools=no target=release
$STRIP bin/godot.x11.*
mkdir -p /root/out/x86_64/templates
cp -rvp bin/* /root/out/x86_64/templates
rm -rf bin

export PATH="${GODOT_SDK_LINUX_X86_32}/bin:${BASE_PATH}"

$SCONS platform=x11 bits=32 $OPTIONS tools=yes target=release_debug
$STRIP bin/godot.x11.*
mkdir -p /root/out/x86_32/tools
cp -rvp bin/* /root/out/x86_32/tools
rm -rf bin

$SCONS platform=x11 bits=32 $OPTIONS tools=no target=release_debug
$SCONS platform=x11 bits=32 $OPTIONS tools=no target=release
$STRIP bin/godot.x11.*
mkdir -p /root/out/x86_32/templates
cp -rvp bin/* /root/out/x86_32/templates
rm -rf bin

export PATH="${GODOT_SDK_LINUX_X86_64}/bin:${BASE_PATH}"

$SCONS platform=server bits=64 $OPTIONS tools=yes target=release_debug
mkdir -p /root/out/x86_64/server
cp -rvp bin/* /root/out/x86_64/server
rm -rf bin

export PATH="${BASE_PATH}"

echo "Linux build successful"
