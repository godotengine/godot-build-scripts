#!/bin/bash

set -e

export BUILD_NAME=official
export OPTIONS="builtin_libpng=yes builtin_openssl=yes builtin_zlib=yes debug_symbols=no"
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export TERM=xterm
export MONO32_PREFIX=/usr
export MONO64_PREFIX=/usr

rm -rf godot
mkdir godot
cd godot
tar xf ../godot.tar.gz --strip-components=1

${SCONS} platform=x11 bits=64 ${OPTIONS} target=release_debug tools=yes module_mono_enabled=yes mono_glue=no
xvfb-run bin/godot.x11.opt.tools.64.mono --generate-mono-glue /root/mono-glue || /bin/true

xvfb-run bin/godot.x11.opt.tools.64.mono --generate-cs-api /tmp/build_GodotSharp || /bin/true
xvfb-run msbuild /tmp/build_GodotSharp/GodotSharp.sln /p:Configuration=Release
mkdir -p /root/mono-glue/Api
cp -r /tmp/build_GodotSharp/GodotSharp/bin/Release/{GodotSharp.dll,GodotSharp.pdb,GodotSharp.xml} /root/mono-glue/Api
cp -r /tmp/build_GodotSharp/GodotSharpEditor/bin/Release/{GodotSharpEditor.dll,GodotSharpEditor.pdb,GodotSharpEditor.xml} /root/mono-glue/Api
