#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="osxcross_sdk=darwin24.5"
export STRIP="x86_64-apple-darwin24.5-strip"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

echo "Starting classical build for macOS..."

$SCONS platform=osx $OPTIONS bits=64 tools=yes target=release_debug
$STRIP bin/godot.osx.*
mkdir -p /root/out/tools
cp -rvp bin/* /root/out/tools
rm -rf bin

$SCONS platform=osx $OPTIONS bits=64 tools=no target=release_debug
$SCONS platform=osx $OPTIONS bits=64 tools=no target=release
$STRIP bin/godot.osx.*
mkdir -p /root/out/templates
cp -rvp bin/* /root/out/templates
rm -rf bin

echo "macOS build successful"
