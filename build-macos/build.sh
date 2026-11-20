#!/bin/bash

set -e

# Config

# Swift compiler path, macOS SDK sysroot and link flags are image-specific;
# the container (godot-apple) exports them so this script doesn't hardcode
# paths that move with the SDK / toolchain version.
#   SWIFT_COMPILER   — passed to scons; platform_methods.py uses it.
#   MACOS_SDK_PATH   — passed to scons; detect.py uses it as the isysroot
#                      (there is no xcrun on Linux).
#   EXTRA_LINK_FLAGS — lld via -fuse-ld/-B, plus Xcode's clang_rt.osx.
SWIFT_COMPILER="${SWIFT_COMPILER:-}"
MACOS_SDK_PATH="${MACOS_SDK_PATH:-}"
EXTRA_LINK_FLAGS="${EXTRA_LINK_FLAGS:-}"

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no redirect_build_objects=no"
export OPTIONS="production=yes debug_symbols=yes separate_debug_symbols=yes debug_paths_relative=yes use_volk=no angle_libs=/root/angle accesskit_sdk_path=/root/accesskit/accesskit-c SWIFT_COMPILER=${SWIFT_COMPILER} MACOS_SDK_PATH=${MACOS_SDK_PATH}"
export OPTIONS_INTEL="metal=no vulkan=yes vulkan_sdk_path=/root/moltenvk"
export OPTIONS_ARM="metal=yes vulkan=no"
export OPTIONS_MONO="module_mono_enabled=yes"
export OPTIONS_DOTNET="module_dotnet_enabled=yes"
export TERM=xterm

run_scons() {
  ${SCONS} "linkflags=${EXTRA_LINK_FLAGS}" $@
}

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for macOS..."

  run_scons platform=macos $OPTIONS $OPTIONS_INTEL arch=x86_64 target=editor
  run_scons platform=macos $OPTIONS $OPTIONS_ARM arch=arm64 target=editor

  mkdir -p /root/out/tools
  cp -rvp bin/* /root/out/tools
  rm -rf bin

  if [ "${STEAM}" == "1" ]; then
    build_name=${BUILD_NAME}
    export BUILD_NAME="steam"
    run_scons platform=macos arch=x86_64 $OPTIONS $OPTIONS_INTEL target=editor steamapi=yes
    run_scons platform=macos arch=arm64 $OPTIONS $OPTIONS_ARM target=editor steamapi=yes

    mkdir -p /root/out/steam
    cp -rvp bin/* /root/out/steam
    rm -rf bin
    export BUILD_NAME=${build_name}
  fi

  run_scons platform=macos $OPTIONS $OPTIONS_INTEL arch=x86_64 target=template_debug
  run_scons platform=macos $OPTIONS $OPTIONS_ARM arch=arm64 target=template_debug
  run_scons platform=macos $OPTIONS $OPTIONS_INTEL arch=x86_64 target=template_release
  run_scons platform=macos $OPTIONS $OPTIONS_ARM arch=arm64 target=template_release

  mkdir -p /root/out/templates
  cp -rvp bin/* /root/out/templates
  rm -rf bin
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for macOS..."

  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  run_scons platform=macos $OPTIONS $OPTIONS_INTEL $OPTIONS_MONO arch=x86_64 target=editor
  run_scons platform=macos $OPTIONS $OPTIONS_ARM $OPTIONS_MONO arch=arm64 target=editor
  ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --godot-platform=macos

  mkdir -p /root/out/tools-mono
  cp -rvp bin/* /root/out/tools-mono
  rm -rf bin

  run_scons platform=macos $OPTIONS $OPTIONS_INTEL $OPTIONS_MONO arch=x86_64 target=template_debug
  run_scons platform=macos $OPTIONS $OPTIONS_ARM $OPTIONS_MONO arch=arm64 target=template_debug
  run_scons platform=macos $OPTIONS $OPTIONS_INTEL $OPTIONS_MONO arch=x86_64 target=template_release
  run_scons platform=macos $OPTIONS $OPTIONS_ARM $OPTIONS_MONO arch=arm64 target=template_release

  mkdir -p /root/out/templates-mono
  cp -rvp bin/* /root/out/templates-mono
  rm -rf bin
fi

# .NET

if [ "${DOTNET}" == "1" ]; then
  echo "Starting .NET build for macOS..."

  run_scons platform=macos $OPTIONS $OPTIONS_INTEL $OPTIONS_DOTNET arch=x86_64 target=editor
  run_scons platform=macos $OPTIONS $OPTIONS_ARM $OPTIONS_DOTNET arch=arm64 target=editor

  mkdir -p /root/out/tools-dotnet
  cp -rvp bin/* /root/out/tools-dotnet
  rm -rf bin

  run_scons platform=macos $OPTIONS $OPTIONS_INTEL $OPTIONS_DOTNET arch=x86_64 target=template_debug
  run_scons platform=macos $OPTIONS $OPTIONS_ARM $OPTIONS_DOTNET arch=arm64 target=template_debug
  run_scons platform=macos $OPTIONS $OPTIONS_INTEL $OPTIONS_DOTNET arch=x86_64 target=template_release
  run_scons platform=macos $OPTIONS $OPTIONS_ARM $OPTIONS_DOTNET arch=arm64 target=template_release

  mkdir -p /root/out/templates-dotnet
  cp -rvp bin/* /root/out/templates-dotnet
  rm -rf bin
fi

echo "macOS build successful"
