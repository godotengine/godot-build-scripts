#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="production=yes"
export OPTIONS_MONO="module_mono_enabled=yes"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# pkg-config wrongly points to lib instead of lib64 for arch-dependent header.
sed -i ${GODOT_SDK_LINUX_X86_64}/x86_64-godot-linux-gnu/sysroot/usr/lib/pkgconfig/dbus-1.pc -e "s@/lib@/lib64@g"

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for Linux..."

  export PATH="${GODOT_SDK_LINUX_X86_64}/bin:${BASE_PATH}"

  $SCONS platform=linuxbsd arch=x86_64 $OPTIONS tools=yes target=release_debug
  mkdir -p /root/out/x86_64/tools
  cp -rvp bin/* /root/out/x86_64/tools
  rm -rf bin

  $SCONS platform=linuxbsd arch=x86_64 $OPTIONS tools=no target=release_debug
  $SCONS platform=linuxbsd arch=x86_64 $OPTIONS tools=no target=release
  mkdir -p /root/out/x86_64/templates
  cp -rvp bin/* /root/out/x86_64/templates
  rm -rf bin

  export PATH="${GODOT_SDK_LINUX_X86}/bin:${BASE_PATH}"

  $SCONS platform=linuxbsd arch=x86_32 $OPTIONS tools=yes target=release_debug
  mkdir -p /root/out/x86_32/tools
  cp -rvp bin/* /root/out/x86_32/tools
  rm -rf bin

  $SCONS platform=linuxbsd arch=x86_32 $OPTIONS tools=no target=release_debug
  $SCONS platform=linuxbsd arch=x86_32 $OPTIONS tools=no target=release
  mkdir -p /root/out/x86_32/templates
  cp -rvp bin/* /root/out/x86_32/templates
  rm -rf bin
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for Linux..."

  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  export PATH="${GODOT_SDK_LINUX_X86_64}/bin:${BASE_PATH}"

  $SCONS platform=linuxbsd arch=x86_64 $OPTIONS $OPTIONS_MONO tools=yes target=release_debug
  ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --godot-platform=linuxbsd
  mkdir -p /root/out/x86_64/tools-mono
  cp -rvp bin/* /root/out/x86_64/tools-mono
  rm -rf bin

  $SCONS platform=linuxbsd arch=x86_64 $OPTIONS $OPTIONS_MONO tools=no target=release_debug
  $SCONS platform=linuxbsd arch=x86_64 $OPTIONS $OPTIONS_MONO tools=no target=release
  mkdir -p /root/out/x86_64/templates-mono
  cp -rvp bin/* /root/out/x86_64/templates-mono
  rm -rf bin

  export PATH="${GODOT_SDK_LINUX_X86}/bin:${BASE_PATH}"

  $SCONS platform=linuxbsd arch=x86_32 $OPTIONS $OPTIONS_MONO tools=yes target=release_debug
  ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --godot-platform=linuxbsd
  mkdir -p /root/out/x86_32/tools-mono
  cp -rvp bin/* /root/out/x86_32/tools-mono
  rm -rf bin

  $SCONS platform=linuxbsd arch=x86_32 $OPTIONS $OPTIONS_MONO tools=no target=release_debug
  $SCONS platform=linuxbsd arch=x86_32 $OPTIONS $OPTIONS_MONO tools=no target=release
  mkdir -p /root/out/x86_32/templates-mono
  cp -rvp bin/* /root/out/x86_32/templates-mono
  rm -rf bin
fi

echo "Linux build successful"
