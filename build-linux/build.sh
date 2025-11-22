#!/bin/bash

set -e

# We need Python 2, Fedora 41+ dropped it and provides PyPy instead.
dnf install -y pypy

export SCONS="pypy /root/scons-local/scons.py -j${NUM_CORES}"
export OPTIONS="openssl=builtin freetype=builtin builtin_zlib=yes"
export STRIP="strip"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

export PATH="${GODOT_SDK_LINUX_X86_64}/bin:${BASE_PATH}"
${SCONS} platform=x11 ${OPTIONS} bits=64 tools=yes target=release_debug
${SCONS} platform=x11 ${OPTIONS} bits=64 tools=no target=release_debug
${SCONS} platform=x11 ${OPTIONS} bits=64 tools=no target=release

export PATH="${GODOT_SDK_LINUX_X86_32}/bin:${BASE_PATH}"
${SCONS} platform=x11 ${OPTIONS} bits=32 tools=yes target=release_debug
${SCONS} platform=x11 ${OPTIONS} bits=32 tools=no target=release_debug
${SCONS} platform=x11 ${OPTIONS} bits=32 tools=no target=release

${STRIP} bin/godot.x11.*
cp -rvp bin/godot.x11.* /root/out/

export PATH="${GODOT_SDK_LINUX_X86_64}/bin:${BASE_PATH}"
${SCONS} platform=server ${OPTIONS} bits=64 tools=yes target=release_debug
${SCONS} platform=server ${OPTIONS} bits=64 tools=no target=release

export PATH="${GODOT_SDK_LINUX_X86_32}/bin:${BASE_PATH}"
${SCONS} platform=server ${OPTIONS} bits=32 tools=no target=release

${STRIP} bin/godot_server.server.*
cp -rvp bin/godot_server.server.* /root/out/

export PATH="${BASE_PATH}"

echo "Linux build successful"
