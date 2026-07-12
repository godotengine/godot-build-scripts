#!/bin/bash

set -e

# Config

# Swift toolchain path comes from the image (godot-apple sets SWIFT_VERSION);
# fall back to a sensible default if run against an older image.
SWIFT_VERSION="${SWIFT_VERSION:-6.3.2}"
SWIFT_COMPILER="/root/.local/share/swiftly/toolchains/${SWIFT_VERSION}/usr/bin/swiftc"

# macOS SDK sysroot and macOS link flags are image-specific; the container
# (godot-apple) exports them as MACOS_SDK_PATH and EXTRA_LINK_FLAGS so this
# script doesn't hardcode paths that move with the SDK / toolchain version.
#   MACOS_SDK_PATH   — passed to scons; detect.py uses it as the isysroot
#                      (there is no xcrun on Linux).
#   EXTRA_LINK_FLAGS — lld via -fuse-ld/-B, plus Xcode's clang_rt.osx.
MACOS_SDK_PATH="${MACOS_SDK_PATH:-}"
EXTRA_LINK_FLAGS="${EXTRA_LINK_FLAGS:-}"

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no redirect_build_objects=no"
export OPTIONS="production=yes use_volk=no vulkan_sdk_path=/root/moltenvk angle_libs=/root/angle accesskit_sdk_path=/root/accesskit/accesskit-c SWIFT_COMPILER=${SWIFT_COMPILER} MACOS_SDK_PATH=${MACOS_SDK_PATH}"
export OPTIONS_MONO="module_mono_enabled=yes"
export OPTIONS_DOTNET="module_dotnet_enabled=yes"
export TERM=xterm

# Wrap the image-provided macOS link flags in the scons `linkflags=` option.
EXTRA_LINKFLAGS="linkflags=${EXTRA_LINK_FLAGS}"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for macOS..."

  $SCONS platform=macos $OPTIONS arch=x86_64 target=editor "$EXTRA_LINKFLAGS"
  $SCONS platform=macos $OPTIONS arch=arm64 target=editor "$EXTRA_LINKFLAGS"
  lipo -create bin/godot.macos.editor.x86_64 bin/godot.macos.editor.arm64 -output bin/godot.macos.editor.universal

  mkdir -p /root/out/tools
  cp -rvp bin/* /root/out/tools
  rm -rf bin

  if [ "${STEAM}" == "1" ]; then
    build_name=${BUILD_NAME}
    export BUILD_NAME="steam"
    $SCONS platform=macos arch=x86_64 $OPTIONS target=editor steamapi=yes "$EXTRA_LINKFLAGS"
    $SCONS platform=macos arch=arm64 $OPTIONS target=editor steamapi=yes "$EXTRA_LINKFLAGS"
    lipo -create bin/godot.macos.editor.x86_64 bin/godot.macos.editor.arm64 -output bin/godot.macos.editor.universal

    mkdir -p /root/out/steam
    cp -rvp bin/* /root/out/steam
    rm -rf bin
    export BUILD_NAME=${build_name}
  fi

  $SCONS platform=macos $OPTIONS arch=x86_64 target=template_debug "$EXTRA_LINKFLAGS"
  $SCONS platform=macos $OPTIONS arch=arm64 target=template_debug "$EXTRA_LINKFLAGS"
  lipo -create bin/godot.macos.template_debug.x86_64 bin/godot.macos.template_debug.arm64 -output bin/godot.macos.template_debug.universal
  $SCONS platform=macos $OPTIONS arch=x86_64 target=template_release "$EXTRA_LINKFLAGS"
  $SCONS platform=macos $OPTIONS arch=arm64 target=template_release "$EXTRA_LINKFLAGS"
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

  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=x86_64 target=editor "$EXTRA_LINKFLAGS"
  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=arm64 target=editor "$EXTRA_LINKFLAGS"
  lipo -create bin/godot.macos.editor.x86_64.mono bin/godot.macos.editor.arm64.mono -output bin/godot.macos.editor.universal.mono
  ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --godot-platform=macos

  mkdir -p /root/out/tools-mono
  cp -rvp bin/* /root/out/tools-mono
  rm -rf bin

  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=x86_64 target=template_debug "$EXTRA_LINKFLAGS"
  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_debug "$EXTRA_LINKFLAGS"
  lipo -create bin/godot.macos.template_debug.x86_64.mono bin/godot.macos.template_debug.arm64.mono -output bin/godot.macos.template_debug.universal.mono
  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=x86_64 target=template_release "$EXTRA_LINKFLAGS"
  $SCONS platform=macos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_release "$EXTRA_LINKFLAGS"
  lipo -create bin/godot.macos.template_release.x86_64.mono bin/godot.macos.template_release.arm64.mono -output bin/godot.macos.template_release.universal.mono

  mkdir -p /root/out/templates-mono
  cp -rvp bin/* /root/out/templates-mono
  rm -rf bin
fi

# .NET

if [ "${DOTNET}" == "1" ]; then
  echo "Starting .NET build for macOS..."

  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=x86_64 target=editor "$EXTRA_LINKFLAGS"
  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=arm64 target=editor "$EXTRA_LINKFLAGS"
  lipo -create bin/godot.macos.editor.x86_64.dotnet bin/godot.macos.editor.arm64.dotnet -output bin/godot.macos.editor.universal.dotnet

  mkdir -p /root/out/tools-dotnet
  cp -rvp bin/* /root/out/tools-dotnet
  rm -rf bin

  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=x86_64 target=template_debug "$EXTRA_LINKFLAGS"
  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=arm64 target=template_debug "$EXTRA_LINKFLAGS"
  lipo -create bin/godot.macos.template_debug.x86_64.dotnet bin/godot.macos.template_debug.arm64.dotnet -output bin/godot.macos.template_debug.universal.dotnet
  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=x86_64 target=template_release "$EXTRA_LINKFLAGS"
  $SCONS platform=macos $OPTIONS $OPTIONS_DOTNET arch=arm64 target=template_release "$EXTRA_LINKFLAGS"
  lipo -create bin/godot.macos.template_release.x86_64.dotnet bin/godot.macos.template_release.arm64.dotnet -output bin/godot.macos.template_release.universal.dotnet

  mkdir -p /root/out/templates-dotnet
  cp -rvp bin/* /root/out/templates-dotnet
  rm -rf bin
fi

echo "macOS build successful"
