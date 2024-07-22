#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="osxcross_sdk=darwin23.6 production=yes use_volk=no vulkan_sdk_path=/root/moltenvk angle_libs=/root/angle"
export OPTIONS_MONO="module_mono_enabled=yes"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for macOS..."

  $SCONS platform=macos $OPTIONS arch=x86_64 target=editor
  $SCONS platform=macos $OPTIONS arch=arm64 target=editor
  lipo -create bin/godot.macos.editor.x86_64 bin/godot.macos.editor.arm64 -output bin/godot.macos.editor.universal

  mkdir -p /root/out/tools
  cp -rvp bin/* /root/out/tools
  rm -rf bin

  $SCONS platform=macos $OPTIONS arch=x86_64 target=template_debug
  $SCONS platform=macos $OPTIONS arch=arm64 target=template_debug
  lipo -create bin/godot.macos.template_debug.x86_64 bin/godot.macos.template_debug.arm64 -output bin/godot.macos.template_debug.universal
  $SCONS platform=macos $OPTIONS arch=x86_64 target=template_release
  $SCONS platform=macos $OPTIONS arch=arm64 target=template_release
  lipo -create bin/godot.macos.template_release.x86_64 bin/godot.macos.template_release.arm64 -output bin/godot.macos.template_release.universal

  mkdir -p /root/out/templates
  cp -rvp bin/* /root/out/templates
  rm -rf bin
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for macOS..."

  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=x86_64 target=editor
  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=arm64 target=editor
  lipo -create bin/godot.macos.editor.x86_64.mono bin/godot.macos.editor.arm64.mono -output bin/godot.macos.editor.universal.mono
  ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --godot-platform=macos

  mkdir -p /root/out/tools-mono
  cp -rvp bin/* /root/out/tools-mono
  rm -rf bin

  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=x86_64 target=template_debug
  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_debug
  lipo -create bin/godot.macos.template_debug.x86_64.mono bin/godot.macos.template_debug.arm64.mono -output bin/godot.macos.template_debug.universal.mono
  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=x86_64 target=template_release
  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_release
  lipo -create bin/godot.macos.template_release.x86_64.mono bin/godot.macos.template_release.arm64.mono -output bin/godot.macos.template_release.universal.mono

  mkdir -p /root/out/templates-mono
  cp -rvp bin/* /root/out/templates-mono
  rm -rf bin
fi

echo "macOS build successful"
