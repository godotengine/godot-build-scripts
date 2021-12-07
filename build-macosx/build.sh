#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="osxcross_sdk=darwin20.2 production=yes"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes"
export MONO_PREFIX_X86_64="/root/mono-installs/desktop-osx-x86_64-release"
export MONO_PREFIX_ARM64="/root/mono-installs/desktop-osx-arm64-release"
export STRIP="x86_64-apple-darwin20.2-strip -u -r"
export TERM=xterm

if [ ! -z "${PRESET_GODOT_DIR}" ]; then
  cd $PRESET_GODOT_DIR
  rm -rf bin
else
  rm -rf godot
  mkdir godot
  cd godot
  tar xf /root/godot.tar.gz --strip-components=1
fi

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for macOS..."

  $SCONS platform=osx $OPTIONS arch=x86_64 tools=yes target=release_debug
  $SCONS platform=osx $OPTIONS arch=arm64 tools=yes target=release_debug
  lipo -create bin/godot.osx.opt.tools.x86_64 bin/godot.osx.opt.tools.arm64 -output bin/godot.osx.opt.tools.universal
  $STRIP bin/godot.osx.opt.tools.universal

  mkdir -p /root/out/tools
  cp -rvp bin/* /root/out/tools
  rm -rf bin

  $SCONS platform=osx $OPTIONS arch=x86_64 tools=no target=release_debug
  $SCONS platform=osx $OPTIONS arch=arm64 tools=no target=release_debug
  lipo -create bin/godot.osx.opt.debug.x86_64 bin/godot.osx.opt.debug.arm64 -output bin/godot.osx.opt.debug.universal
  $STRIP bin/godot.osx.opt.debug.universal
  $SCONS platform=osx $OPTIONS arch=x86_64 tools=no target=release
  $SCONS platform=osx $OPTIONS arch=arm64 tools=no target=release
  lipo -create bin/godot.osx.opt.x86_64 bin/godot.osx.opt.arm64 -output bin/godot.osx.opt.universal
  $STRIP bin/godot.osx.opt.universal

  mkdir -p /root/out/templates
  cp -rvp bin/* /root/out/templates
  rm -rf bin
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for macOS..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  # Note: A bit of dylib wrangling involved as x86_64 and arm64 builds both generate GodotSharp
  # so the second build overrides the first, but we need to lipo the libs to make them universal.
  # We also need to ensure that /etc/mono/config has the proper filenames (keep arm64 as the last
  # build so that we rely on its config, which has libmono-native.dylib instead of
  # libmono-native-compat.dylib).
  mkdir -p tmp-lib/{x86_64,arm64}

  $SCONS platform=osx $OPTIONS $OPTIONS_MONO mono_prefix=$MONO_PREFIX_X86_64 arch=x86_64 tools=yes target=release_debug copy_mono_root=yes
  cp bin/GodotSharp/Mono/lib/*.dylib tmp-lib/x86_64/
  $SCONS platform=osx $OPTIONS $OPTIONS_MONO mono_prefix=$MONO_PREFIX_ARM64 arch=arm64 tools=yes target=release_debug copy_mono_root=yes
  cp bin/GodotSharp/Mono/lib/*.dylib tmp-lib/arm64/
  lipo -create bin/godot.osx.opt.tools.x86_64.mono bin/godot.osx.opt.tools.arm64.mono -output bin/godot.osx.opt.tools.universal.mono
  $STRIP bin/godot.osx.opt.tools.universal.mono

  # Make universal versions of the dylibs we use.
  lipo -create tmp-lib/x86_64/libmono-native-compat.dylib tmp-lib/arm64/libmono-native.dylib -output tmp-lib/libmono-native.dylib
  lipo -create tmp-lib/x86_64/libMonoPosixHelper.dylib tmp-lib/arm64/libMonoPosixHelper.dylib -output tmp-lib/libMonoPosixHelper.dylib
  # Somehow only included in x86_64 build.
  cp tmp-lib/x86_64/libmono-btls-shared.dylib tmp-lib/

  cp -f tmp-lib/*.dylib bin/GodotSharp/Mono/lib/

  mkdir -p /root/out/tools-mono
  cp -rvp bin/* /root/out/tools-mono
  rm -rf bin

  $SCONS platform=osx $OPTIONS $OPTIONS_MONO mono_prefix=$MONO_PREFIX_X86_64 arch=x86_64 tools=no target=release_debug
  $SCONS platform=osx $OPTIONS $OPTIONS_MONO mono_prefix=$MONO_PREFIX_ARM64 arch=arm64 tools=no target=release_debug
  lipo -create bin/godot.osx.opt.debug.x86_64.mono bin/godot.osx.opt.debug.arm64.mono -output bin/godot.osx.opt.debug.universal.mono
  $STRIP bin/godot.osx.opt.debug.universal.mono
  $SCONS platform=osx $OPTIONS $OPTIONS_MONO mono_prefix=$MONO_PREFIX_X86_64 arch=x86_64 tools=no target=release
  $SCONS platform=osx $OPTIONS $OPTIONS_MONO mono_prefix=$MONO_PREFIX_ARM64 arch=arm64 tools=no target=release
  lipo -create bin/godot.osx.opt.x86_64.mono bin/godot.osx.opt.arm64.mono -output bin/godot.osx.opt.universal.mono
  $STRIP bin/godot.osx.opt.universal.mono

  cp -f tmp-lib/*.dylib bin/data.mono.osx.64.release/Mono/lib/
  cp -f tmp-lib/*.dylib bin/data.mono.osx.64.release_debug/Mono/lib/

  mkdir -p /root/out/templates-mono
  cp -rvp bin/* /root/out/templates-mono
  rm -rf bin
fi

echo "macOS build successful"
