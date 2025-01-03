#!/bin/bash

set -e

# We need Python 2, Fedora 41+ dropped it and provides PyPy instead.
dnf install -y pypy

export SCONS="pypy /root/scons-local/scons.py -j${NUM_CORES}"
export OPTIONS=""
export STRIP="x86_64-w64-mingw32-strip"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

${SCONS} platform=windows ${OPTIONS} bits=64 tools=yes target=release_debug
${SCONS} platform=windows ${OPTIONS} bits=64 tools=no target=release_debug
${SCONS} platform=windows ${OPTIONS} bits=64 tools=no target=release

${SCONS} platform=windows ${OPTIONS} bits=32 tools=yes target=release_debug
${SCONS} platform=windows ${OPTIONS} bits=32 tools=no target=release_debug
${SCONS} platform=windows ${OPTIONS} bits=32 tools=no target=release

${STRIP} bin/godot.windows.*
cp -rvp bin/godot.windows.* /root/out/

echo "Windows build successful"
