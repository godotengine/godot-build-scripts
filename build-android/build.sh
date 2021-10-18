#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="production=yes"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=no"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

dnf install -y java-11-openjdk-devel
java --version

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for Android..."

  $SCONS platform=android android_arch=armv7 $OPTIONS tools=no target=release_debug
  $SCONS platform=android android_arch=armv7 $OPTIONS tools=no target=release

  $SCONS platform=android android_arch=arm64v8 $OPTIONS tools=no target=release_debug
  $SCONS platform=android android_arch=arm64v8 $OPTIONS tools=no target=release

  $SCONS platform=android android_arch=x86 $OPTIONS tools=no target=release_debug
  $SCONS platform=android android_arch=x86 $OPTIONS tools=no target=release

  $SCONS platform=android android_arch=x86_64 $OPTIONS tools=no target=release_debug
  $SCONS platform=android android_arch=x86_64 $OPTIONS tools=no target=release

  pushd platform/android/java
  ./gradlew generateGodotTemplates
  popd

  mkdir -p /root/out/templates
  cp bin/android_source.zip /root/out/templates
  cp bin/android_debug.apk /root/out/templates/android_debug.apk
  cp bin/android_release.apk /root/out/templates/android_release.apk
  cp bin/godot-lib.release.aar /root/out/templates/godot-lib.release.aar
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for Android..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  $SCONS platform=android android_arch=armv7 $OPTIONS $OPTIONS_MONO mono_prefix=/root/mono-installs/android-armeabi-v7a-release tools=no target=release_debug
  $SCONS platform=android android_arch=armv7 $OPTIONS $OPTIONS_MONO mono_prefix=/root/mono-installs/android-armeabi-v7a-release tools=no target=release

  $SCONS platform=android android_arch=arm64v8 $OPTIONS $OPTIONS_MONO mono_prefix=/root/mono-installs/android-arm64-v8a-release tools=no target=release_debug
  $SCONS platform=android android_arch=arm64v8 $OPTIONS $OPTIONS_MONO mono_prefix=/root/mono-installs/android-arm64-v8a-release tools=no target=release

  $SCONS platform=android android_arch=x86 $OPTIONS $OPTIONS_MONO mono_prefix=/root/mono-installs/android-x86-release tools=no target=release_debug
  $SCONS platform=android android_arch=x86 $OPTIONS $OPTIONS_MONO mono_prefix=/root/mono-installs/android-x86-release tools=no target=release

  $SCONS platform=android android_arch=x86_64 $OPTIONS $OPTIONS_MONO mono_prefix=/root/mono-installs/android-x86_64-release tools=no target=release_debug
  $SCONS platform=android android_arch=x86_64 $OPTIONS $OPTIONS_MONO mono_prefix=/root/mono-installs/android-x86_64-release tools=no target=release

  pushd platform/android/java
  ./gradlew generateGodotTemplates
  popd

  mkdir -p /root/out/templates-mono
  cp bin/android_source.zip /root/out/templates-mono
  cp bin/android_debug.apk /root/out/templates-mono/android_debug.apk
  cp bin/android_release.apk /root/out/templates-mono/android_release.apk
  cp bin/godot-lib.release.aar /root/out/templates-mono/godot-lib.release.aar

  mkdir -p /root/out/templates-mono/bcl
  cp -r /root/mono-installs/android-bcl/* /root/out/templates-mono/bcl/
fi

echo "Android build successful"
