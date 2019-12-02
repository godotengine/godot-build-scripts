#!/bin/bash

set -e

export BUILD_NAME=official
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="builtin_libpng=yes builtin_openssl=yes builtin_zlib=yes debug_symbols=no use_static_cpp=yes use_lto=yes"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=no"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

cp /root/mono-glue/*.cpp modules/mono/glue/
cp -r /root/mono-glue/Managed/Generated modules/mono/glue/Managed/

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

mkdir /root/out/templates-mono/bcl
cp -r /root/mono-installs/android-bcl/monodroid /root/out/templates-mono/bcl/
