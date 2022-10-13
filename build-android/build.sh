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

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for Android..."

  $SCONS platform=android arch=arm32 $OPTIONS target=editor
  $SCONS platform=android arch=arm64 $OPTIONS target=editor
  $SCONS platform=android arch=x86_32 $OPTIONS target=editor
  $SCONS platform=android arch=x86_64 $OPTIONS target=editor

  pushd platform/android/java
  ./gradlew generateGodotEditor
  popd

  mkdir -p /root/out/tools
  cp bin/android_editor.apk /root/out/tools/

  $SCONS platform=android arch=arm32 $OPTIONS target=template_debug
  $SCONS platform=android arch=arm32 $OPTIONS target=template_release

  $SCONS platform=android arch=arm64 $OPTIONS target=template_debug
  $SCONS platform=android arch=arm64 $OPTIONS target=template_release

  $SCONS platform=android arch=x86_32 $OPTIONS target=template_debug
  $SCONS platform=android arch=x86_32 $OPTIONS target=template_release

  $SCONS platform=android arch=x86_64 $OPTIONS target=template_debug
  $SCONS platform=android arch=x86_64 $OPTIONS target=template_release

  pushd platform/android/java
  ./gradlew generateGodotTemplates
  popd

  mkdir -p /root/out/templates
  cp bin/android_source.zip /root/out/templates/
  cp bin/android_debug.apk /root/out/templates/
  cp bin/android_release.apk /root/out/templates/
  cp bin/godot-lib.template_release.aar /root/out/templates/
fi

# Mono

# No Android support with .NET 6 yet.
#if [ "${MONO}" == "1" ]; then
if false; then
  echo "Starting Mono build for Android..."

  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/

  $SCONS platform=android arch=arm32 $OPTIONS $OPTIONS_MONO target=template_debug
  $SCONS platform=android arch=arm32 $OPTIONS $OPTIONS_MONO target=template_release

  $SCONS platform=android arch=arm64 $OPTIONS $OPTIONS_MONO target=template_debug
  $SCONS platform=android arch=arm64 $OPTIONS $OPTIONS_MONO target=template_release

  $SCONS platform=android arch=x86_32 $OPTIONS $OPTIONS_MONO target=template_debug
  $SCONS platform=android arch=x86_32 $OPTIONS $OPTIONS_MONO target=template_release

  $SCONS platform=android arch=x86_64 $OPTIONS $OPTIONS_MONO target=template_debug
  $SCONS platform=android arch=x86_64 $OPTIONS $OPTIONS_MONO target=template_release

  pushd platform/android/java
  ./gradlew generateGodotTemplates
  popd

  mkdir -p /root/out/templates-mono
  cp bin/android_source.zip /root/out/templates-mono/
  cp bin/android_debug.apk /root/out/templates-mono/
  cp bin/android_release.apk /root/out/templates-mono/
  cp bin/godot-lib.release.aar /root/out/templates-mono/
fi

echo "Android build successful"
