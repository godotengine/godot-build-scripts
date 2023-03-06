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

# Environment variables and keystore needed for signing store editor build,
# as well as signing and publishing to MavenCentral.
source /root/keystore/config.sh

store_release="yes"
if [ -z "${GODOT_ANDROID_SIGN_KEYSTORE}" ]; then
  echo "No keystore provided to sign the Android release editor build, using debug build instead."
  store_release="no"
fi

# Classical

dnf -y install gettext

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for Android..."

  $SCONS platform=android arch=arm32 $OPTIONS target=editor store_release=${store_release}
  $SCONS platform=android arch=arm64 $OPTIONS target=editor store_release=${store_release}
  $SCONS platform=android arch=x86_32 $OPTIONS target=editor store_release=${store_release}
  $SCONS platform=android arch=x86_64 $OPTIONS target=editor store_release=${store_release}

  pushd platform/android/java
  ./gradlew generateGodotEditor
  popd

  mkdir -p /root/out/tools
  # Copy the generated Android editor binaries (apk & aab).
  if [ "$store_release" == "yes" ]; then
    cp bin/android_editor_builds/android_editor-release.apk /root/out/tools/android_editor.apk
    cp bin/android_editor_builds/android_editor-release.aab /root/out/tools/android_editor.aab
  else
    cp bin/android_editor_builds/android_editor-debug.apk /root/out/tools/android_editor.apk
    cp bin/android_editor_builds/android_editor-debug.aab /root/out/tools/android_editor.aab
  fi

  # Restart from a clean tarball, as we'll copy all the contents
  # outside the container for the MavenCentral upload.
  rm -rf /root/godot/*
  tar xf /root/godot.tar.gz --strip-components=1

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

  if [ "$store_release" == "yes" ]; then
    # Copy source folder with compiled libs so we can optionally use it
    # in a separate script to upload the templates to MavenCentral.
    cp -r /root/godot /root/out/source/
    # Backup ~/.gradle too so we can reuse all the downloaded stuff.
    cp -r /root/.gradle /root/out/source/.gradle
  fi
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
