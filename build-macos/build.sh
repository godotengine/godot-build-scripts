#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no redirect_build_objects=no"
export OSX_SDK=darwin25.1
export OPTIONS="osxcross_sdk=${OSX_SDK} production=yes debug_symbols=yes separate_debug_symbols=no debug_paths_relative=yes use_volk=no vulkan_sdk_path=/root/moltenvk angle_libs=/root/angle accesskit_sdk_path=/root/accesskit/accesskit-c SWIFT_FRONTEND=/root/.local/share/swiftly/toolchains/6.2.1/usr/bin/swift-frontend"
export OPTIONS_MONO="module_mono_enabled=yes"
export OPTIONS_DOTNET="module_dotnet_enabled=yes"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

lipo_and_extract_dsym() {
  [ "$2" == "mono" ] && mono=".mono"
  x86_64-apple-${OSX_SDK}-lipo -create bin/$1.x86_64$mono bin/$1.arm64$mono -output bin/$1.universal$mono
  x86_64-apple-${OSX_SDK}-dsymutil bin/$1.universal$mono -o bin/$1.universal$mono.dSYM
  x86_64-apple-${OSX_SDK}-strip bin/$1.universal$mono
}

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for macOS..."

  $SCONS platform=macos $OPTIONS arch=x86_64 target=editor
  $SCONS platform=macos $OPTIONS arch=arm64 target=editor
  lipo_and_extract_dsym godot.macos.editor

  mkdir -p /root/out/tools
  cp -rvp bin/* /root/out/tools
  rm -rf bin

  if [ "${STEAM}" == "1" ]; then
    build_name=${BUILD_NAME}
    export BUILD_NAME="steam"
    $SCONS platform=macos arch=x86_64 $OPTIONS target=editor steamapi=yes
    $SCONS platform=macos arch=arm64 $OPTIONS target=editor steamapi=yes
    lipo_and_extract_dsym godot.macos.editor

    mkdir -p /root/out/steam
    cp -rvp bin/* /root/out/steam
    rm -rf bin
    export BUILD_NAME=${build_name}
  fi

  $SCONS platform=macos $OPTIONS arch=x86_64 target=template_debug
  $SCONS platform=macos $OPTIONS arch=arm64 target=template_debug
  lipo_and_extract_dsym godot.macos.template_debug
  $SCONS platform=macos $OPTIONS arch=x86_64 target=template_release
  $SCONS platform=macos $OPTIONS arch=arm64 target=template_release
  lipo_and_extract_dsym godot.macos.template_release

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
  lipo_and_extract_dsym godot.macos.editor mono
  ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --godot-platform=macos

  mkdir -p /root/out/tools-mono
  cp -rvp bin/* /root/out/tools-mono
  rm -rf bin

  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=x86_64 target=template_debug
  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_debug
  lipo_and_extract_dsym godot.macos.template_debug mono
  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=x86_64 target=template_release
  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_release
  lipo_and_extract_dsym godot.macos.template_release mono

  mkdir -p /root/out/templates-mono
  cp -rvp bin/* /root/out/templates-mono
  rm -rf bin
fi

# .NET

if [ "${DOTNET}" == "1" ]; then
  echo "Starting .NET build for macOS..."

  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=x86_64 target=editor
  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=arm64 target=editor
  lipo -create bin/godot.macos.editor.x86_64.dotnet bin/godot.macos.editor.arm64.dotnet -output bin/godot.macos.editor.universal.dotnet

  mkdir -p /root/out/tools-dotnet
  cp -rvp bin/* /root/out/tools-dotnet
  rm -rf bin

  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=x86_64 target=template_debug
  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=arm64 target=template_debug
  lipo -create bin/godot.macos.template_debug.x86_64.dotnet bin/godot.macos.template_debug.arm64.dotnet -output bin/godot.macos.template_debug.universal.dotnet
  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=x86_64 target=template_release
  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=arm64 target=template_release
  lipo -create bin/godot.macos.template_release.x86_64.dotnet bin/godot.macos.template_release.arm64.dotnet -output bin/godot.macos.template_release.universal.dotnet

  mkdir -p /root/out/templates-dotnet
  cp -rvp bin/* /root/out/templates-dotnet
  rm -rf bin
fi

echo "macOS build successful"
