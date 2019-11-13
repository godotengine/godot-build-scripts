#!/bin/bash

set -e

export BUILD_NAME=official
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="builtin_libpng=yes builtin_openssl=yes builtin_zlib=yes debug_symbols=no"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf ../godot.tar.gz --strip-components=1

mono --version
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/lib/pkgconfig/

${SCONS} platform=x11 bits=64 ${OPTIONS} target=release_debug tools=yes module_mono_enabled=yes mono_glue=no

rm -rf /root/mono-glue/*
xvfb-run bin/godot.x11.opt.tools.64.mono --generate-mono-glue /root/mono-glue || /bin/true
