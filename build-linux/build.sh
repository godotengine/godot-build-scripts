#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="production=yes"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes"
export MONO_PREFIX_X86_64="/root/mono-installs/desktop-linux-x86_64-release"
export MONO_PREFIX_X86="/root/mono-installs/desktop-linux-x86-release"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for Linux..."

  export PATH="${GODOT_SDK_LINUX_X86_64}/bin:${BASE_PATH}"

  $SCONS platform=x11 $OPTIONS tools=yes target=release_debug
  mkdir -p /root/out/x64/tools
  cp -rvp bin/* /root/out/x64/tools
  rm -rf bin

  $SCONS platform=x11 $OPTIONS tools=no target=release_debug
  $SCONS platform=x11 $OPTIONS tools=no target=release
  mkdir -p /root/out/x64/templates
  cp -rvp bin/* /root/out/x64/templates
  rm -rf bin

  export PATH="${GODOT_SDK_LINUX_X86}/bin:${BASE_PATH}"

  $SCONS platform=x11 $OPTIONS tools=yes target=release_debug bits=32
  mkdir -p /root/out/x86/tools
  cp -rvp bin/* /root/out/x86/tools
  rm -rf bin

  $SCONS platform=x11 $OPTIONS tools=no target=release_debug bits=32
  $SCONS platform=x11 $OPTIONS tools=no target=release bits=32
  mkdir -p /root/out/x86/templates
  cp -rvp bin/* /root/out/x86/templates
  rm -rf bin
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for Linux..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  export PATH="${GODOT_SDK_LINUX_X86_64}/bin:${BASE_PATH}"
  export OPTIONS_MONO_PREFIX="${OPTIONS} ${OPTIONS_MONO} mono_prefix=${MONO_PREFIX_X86_64}"

  $SCONS platform=x11 $OPTIONS_MONO_PREFIX tools=yes target=release_debug copy_mono_root=yes
  mkdir -p /root/out/x64/tools-mono
  cp -rvp bin/* /root/out/x64/tools-mono
  rm -rf bin

  $SCONS platform=x11 $OPTIONS_MONO_PREFIX tools=no target=release_debug
  $SCONS platform=x11 $OPTIONS_MONO_PREFIX tools=no target=release
  mkdir -p /root/out/x64/templates-mono
  cp -rvp bin/* /root/out/x64/templates-mono
  rm -rf bin

  export PATH="${GODOT_SDK_LINUX_X86}/bin:${BASE_PATH}"
  export OPTIONS_MONO_PREFIX="${OPTIONS} ${OPTIONS_MONO} mono_prefix=${MONO_PREFIX_X86}"

  $SCONS platform=x11 $OPTIONS_MONO_PREFIX tools=yes target=release_debug copy_mono_root=yes bits=32
  mkdir -p /root/out/x86/tools-mono
  cp -rvp bin/* /root/out/x86/tools-mono
  rm -rf bin

  $SCONS platform=x11 $OPTIONS_MONO_PREFIX tools=no target=release_debug bits=32
  $SCONS platform=x11 $OPTIONS_MONO_PREFIX tools=no target=release bits=32
  mkdir -p /root/out/x86/templates-mono
  cp -rvp bin/* /root/out/x86/templates-mono
  rm -rf bin
fi

echo "Linux build successful"
