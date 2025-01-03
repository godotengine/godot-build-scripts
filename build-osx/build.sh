#!/bin/bash

set -e

# We need Python 2, Fedora 41+ dropped it and provides PyPy instead.
dnf install -y pypy

export SCONS="pypy /root/scons-local/scons.py -j${NUM_CORES}"
export OPTIONS="osxcross_sdk=darwin24.2"
export STRIP="x86_64-apple-darwin24.2-strip"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

${SCONS} platform=osx ${OPTIONS} bits=64 tools=yes target=release_debug
${SCONS} platform=osx ${OPTIONS} bits=64 tools=no target=release_debug
${SCONS} platform=osx ${OPTIONS} bits=64 tools=no target=release

${STRIP} bin/godot.osx.*
cp -rvp bin/godot.osx.* /root/out/

echo "OSX build successful"
