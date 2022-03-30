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

  $SCONS platform=android android_arch=arm64v8 $OPTIONS tools=yes target=release_debug
  $SCONS platform=android android_arch=x86_64 $OPTIONS tools=yes target=release_debug

  pushd platform/android/java
  ./gradlew generateGodotEditor
  popd

  mkdir -p /root/out/tools
  cp bin/android_editor.apk /root/out/tools/

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
  cp bin/android_source.zip /root/out/templates/
  cp bin/android_debug.apk /root/out/templates/
  cp bin/android_release.apk /root/out/templates/
  cp bin/godot-lib.release.aar /root/out/templates/
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for Android..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  #$SCONS platform=android android_arch=arm64v8 $OPTIONS $OPTIONS_MONO mono_prefix=/root/mono-installs/android-arm64-v8a-release tools=yes target=release_debug
  #$SCONS platform=android android_arch=x86_64 $OPTIONS $OPTIONS_MONO mono_prefix=/root/mono-installs/android-x86_64-release tools=yes target=release_debug

  #pushd platform/android/java
  #./gradlew generateGodotEditor
  #popd

  #mkdir -p /root/out/tools-mono
  #cp bin/android_editor.apk /root/out/tools-mono/

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
  cp bin/android_source.zip /root/out/templates-mono/
  cp bin/android_debug.apk /root/out/templates-mono/
  cp bin/android_release.apk /root/out/templates-mono/
  cp bin/godot-lib.release.aar /root/out/templates-mono/

  mkdir -p /root/out/templates-mono/bcl
  cp -r /root/mono-installs/android-bcl/* /root/out/templates-mono/bcl/
fi

echo "Android build successful"
