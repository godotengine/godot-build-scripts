#!/bin/bash

set -e

# Config

# Debug symbols are enabled for the Android builds. Gradle will strip them out of 
# the final artifacts and generate a separate debug symbols file.
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no redirect_build_objects=no"
export OPTIONS="production=yes debug_symbols=yes"
export OPTIONS_MONO="module_mono_enabled=yes"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1
cp -rf /root/swappy/* thirdparty/swappy-frame-pacing/

# Environment variables and keystore needed for signing store editor build,
# as well as signing and publishing to MavenCentral.
source /root/keystore/config.sh

store_release="yes"
if [ -z "${GODOT_ANDROID_SIGN_KEYSTORE}" ]; then
  echo "No keystore provided to sign the Android release editor build, using debug build instead."
  store_release="no"
fi

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for Android..."

  $SCONS platform=android arch=arm32 $OPTIONS target=editor store_release=${store_release}
  $SCONS platform=android arch=arm64 $OPTIONS target=editor store_release=${store_release}
  $SCONS platform=android arch=x86_32 $OPTIONS target=editor store_release=${store_release}
  $SCONS platform=android arch=x86_64 $OPTIONS target=editor store_release=${store_release}

  pushd platform/android/java
  # Generate the regular Android editor.
  ./gradlew generateGodotEditor
  # Generate the Android editor for HorizonOS devices.
  ./gradlew generateGodotHorizonOSEditor
  # Generate the Android editor for PicoOS devices.
  ./gradlew generateGodotPicoOSEditor
  popd

  mkdir -p /root/out/tools
  # Copy the generated Android editor binaries (apk & aab).
  if [ "$store_release" == "yes" ]; then
    cp bin/android_editor_builds/android-editor-android-release-native-debug-symbols.zip /root/out/tools/android_editor_native_debug_symbols.zip
    cp bin/android_editor_builds/android_editor-android-release.apk /root/out/tools/android_editor.apk
    cp bin/android_editor_builds/android_editor-android-release.aab /root/out/tools/android_editor.aab

    # For the HorizonOS and PicoOS builds, we only copy the apk.
    cp bin/android_editor_builds/android-editor-horizonos-release-native-debug-symbols.zip /root/out/tools/android_editor_horizonos_native_debug_symbols.zip
    cp bin/android_editor_builds/android_editor-horizonos-release.apk /root/out/tools/android_editor_horizonos.apk

    cp bin/android_editor_builds/android-editor-picoos-release-native-debug-symbols.zip /root/out/tools/android_editor_picoos_native_debug_symbols.zip
    cp bin/android_editor_builds/android_editor-picoos-release.apk /root/out/tools/android_editor_picoos.apk
  else
    cp bin/android_editor_builds/android-editor-android-debug-native-debug-symbols.zip /root/out/tools/android_editor_native_debug_symbols.zip
    cp bin/android_editor_builds/android_editor-android-debug.apk /root/out/tools/android_editor.apk
    cp bin/android_editor_builds/android_editor-android-debug.aab /root/out/tools/android_editor.aab

    # For the HorizonOS and PicoOS build, we only copy the apk.
    cp bin/android_editor_builds/android-editor-horizonos-debug-native-debug-symbols.zip /root/out/tools/android_editor_horizonos_native_debug_symbols.zip
    cp bin/android_editor_builds/android_editor-horizonos-debug.apk /root/out/tools/android_editor_horizonos.apk

    cp bin/android_editor_builds/android-editor-picoos-debug-native-debug-symbols.zip /root/out/tools/android_editor_picoos_native_debug_symbols.zip
    cp bin/android_editor_builds/android_editor-picoos-debug.apk /root/out/tools/android_editor_picoos.apk
  fi

  # Template builds

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
  cp bin/android-template-standard-debug-native-debug-symbols.zip /root/out/templates/android_debug_template_native_debug_symbols.zip
  cp bin/android-template-standard-release-native-debug-symbols.zip /root/out/templates/android_release_template_native_debug_symbols.zip
fi

# Mono

if [ "${MONO}" == "1" ]; then
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
  ./gradlew generateGodotMonoTemplates
  popd

  mkdir -p /root/out/templates-mono
  cp bin/android_source.zip /root/out/templates-mono/
  cp bin/android_monoDebug.apk /root/out/templates-mono/android_debug.apk
  cp bin/android_monoRelease.apk /root/out/templates-mono/android_release.apk
  cp bin/godot-lib.template_release.aar /root/out/templates-mono/
  cp bin/android-template-mono-debug-native-debug-symbols.zip /root/out/templates-mono/android_debug_template_native_debug_symbols.zip
  cp bin/android-template-mono-release-native-debug-symbols.zip /root/out/templates-mono/android_release_template_native_debug_symbols.zip
fi

echo "Android build successful"
