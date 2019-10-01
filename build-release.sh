#!/bin/bash

set -e

if [ -z $1 ]; then
  echo "Usage: $0 <version>"
  echo "  For example: $0 3.0.3-rc3"
  echo ""
  exit 1
fi

function sign {
	./osslsigncode -pkcs12 REDACTED.pkcs12 -pass "REDACTED" -n "Godot Game Engine" -i "https://godotengine.org" -t http://timestamp.comodoca.com -in $1 -out $1-signed
	mv $1-signed $1
}

export GODOT_VERSION=$1

# Tarball
mkdir -p release-${GODOT_VERSION}
rm -rf release-${GODOT_VERSION}/*.xz release-${GODOT_VERSION}/*.sha256
zcat godot.tar.gz | xz -c > release-${GODOT_VERSION}/godot-${GODOT_VERSION}.tar.xz
sha256sum release-${GODOT_VERSION}/godot-${GODOT_VERSION}.tar.xz > release-${GODOT_VERSION}/godot-${GODOT_VERSION}.tar.xz.sha256

# Ubuntu-32
mkdir -p templates
rm -f templates/linux_x11_32*

cp out/linux/x86/templates/godot.x11.opt.debug.32 templates/linux_x11_32_debug
cp out/linux/x86/templates/godot.x11.opt.32 templates/linux_x11_32_release

mkdir -p release-${GODOT_VERSION}
rm -f release-${GODOT_VERSION}/*linux*32*

cp out/linux/x86/tools/godot.x11.opt.tools.32 Godot_v${GODOT_VERSION}_x11.32
zip -q -9 Godot_v${GODOT_VERSION}_x11.32.zip Godot_v${GODOT_VERSION}_x11.32
mv Godot_v${GODOT_VERSION}_x11.32.zip release-${GODOT_VERSION}
rm Godot_v${GODOT_VERSION}_x11.32

mkdir -p mono/release-${GODOT_VERSION}
rm -rf mono/release-${GODOT_VERSION}/*linux*32*

mkdir -p Godot_v${GODOT_VERSION}_mono_x11_32
cp out/linux/x86/tools-mono/godot.x11.opt.tools.32.mono Godot_v${GODOT_VERSION}_mono_x11_32/Godot_v${GODOT_VERSION}_mono_x11.32
cp -rp out/linux/x86/tools-mono/GodotSharp/ Godot_v${GODOT_VERSION}_mono_x11_32
cp -rp mono-glue/Api Godot_v${GODOT_VERSION}_mono_x11_32/GodotSharp/Api
zip -r -q -9 Godot_v${GODOT_VERSION}_mono_x11_32.zip Godot_v${GODOT_VERSION}_mono_x11_32
mv Godot_v${GODOT_VERSION}_mono_x11_32.zip mono/release-${GODOT_VERSION}
rm -rf Godot_v${GODOT_VERSION}_mono_x11_32

mkdir -p mono/templates
rm -rf mono/templates/*linux*32*

cp -rp out/linux/x86/templates-mono/data.mono.x11.32.* mono/templates/
cp out/linux/x86/templates-mono/godot.x11.opt.debug.32.mono mono/templates/linux_x11_32_debug
cp out/linux/x86/templates-mono/godot.x11.opt.32.mono mono/templates/linux_x11_32_release

# Ubuntu-64
mkdir -p templates
rm -f templates/linux_x11_64*

cp out/linux/x64/templates/godot.x11.opt.debug.64 templates/linux_x11_64_debug
cp out/linux/x64/templates/godot.x11.opt.64 templates/linux_x11_64_release

mkdir -p release-${GODOT_VERSION}
rm -f release-${GODOT_VERSION}/*linux*64*

cp out/linux/x64/tools/godot.x11.opt.tools.64 Godot_v${GODOT_VERSION}_x11.64
zip -q -9 Godot_v${GODOT_VERSION}_x11.64.zip Godot_v${GODOT_VERSION}_x11.64
mv Godot_v${GODOT_VERSION}_x11.64.zip release-${GODOT_VERSION}
rm Godot_v${GODOT_VERSION}_x11.64

mkdir -p mono/release-${GODOT_VERSION}
rm -rf mono/release-${GODOT_VERSION}/*linux*64*

mkdir -p Godot_v${GODOT_VERSION}_mono_x11_64
cp out/linux/x64/tools-mono/godot.x11.opt.tools.64.mono Godot_v${GODOT_VERSION}_mono_x11_64/Godot_v${GODOT_VERSION}_mono_x11.64
cp -rp out/linux/x64/tools-mono/GodotSharp Godot_v${GODOT_VERSION}_mono_x11_64
cp -rp mono-glue/Api Godot_v${GODOT_VERSION}_mono_x11_64/GodotSharp/Api
zip -r -q -9 Godot_v${GODOT_VERSION}_mono_x11_64.zip Godot_v${GODOT_VERSION}_mono_x11_64
mv Godot_v${GODOT_VERSION}_mono_x11_64.zip mono/release-${GODOT_VERSION}
rm -rf Godot_v${GODOT_VERSION}_mono_x11_64

mkdir -p mono/templates
rm -rf mono/templates/*linux*64*

cp -rp out/linux/x64/templates-mono/data.mono.x11.64.* mono/templates/
cp out/linux/x64/templates-mono/godot.x11.opt.debug.64.mono mono/templates/linux_x11_64_debug
cp out/linux/x64/templates-mono/godot.x11.opt.64.mono mono/templates/linux_x11_64_release

# Server

cp out/server/x64/templates/godot_server.x11.opt.64 Godot_v${GODOT_VERSION}_linux_server.64
zip -q -9 Godot_v${GODOT_VERSION}_linux_server.64.zip Godot_v${GODOT_VERSION}_linux_server.64
mv Godot_v${GODOT_VERSION}_linux_server.64.zip release-${GODOT_VERSION}
rm Godot_v${GODOT_VERSION}_linux_server.64

cp out/server/x64/tools/godot_server.x11.opt.tools.64 Godot_v${GODOT_VERSION}_linux_headless.64
zip -q -9 Godot_v${GODOT_VERSION}_linux_headless.64.zip Godot_v${GODOT_VERSION}_linux_headless.64
mv Godot_v${GODOT_VERSION}_linux_headless.64.zip release-${GODOT_VERSION}
rm Godot_v${GODOT_VERSION}_linux_headless.64

# UWP
mkdir -p templates 
rm -f templates/uwp*
rm -rf uwp_template_*

for arch in ARM Win32 x64; do
  cp -r git/misc/dist/uwp_template uwp_template_${arch}

  cp angle/winrt/10/src/Release_${arch}/libEGL.dll \
     angle/winrt/10/src/Release_${arch}/libGLESv2.dll \
     uwp_template_${arch}/
  cp -r uwp_template_${arch} uwp_template_${arch}_debug
done

cp out/uwp/arm/godot.uwp.opt.32.arm.exe uwp_template_ARM/godot.uwp.exe
cp out/uwp/arm/godot.uwp.opt.debug.32.arm.exe uwp_template_ARM_debug/godot.uwp.exe
sign uwp_template_ARM/godot.uwp.exe
sign uwp_template_ARM_debug/godot.uwp.exe
cd uwp_template_ARM && zip -q -9 -r ../templates/uwp_arm_release.zip * && cd ..
cd uwp_template_ARM_debug && zip -q -9 -r ../templates/uwp_arm_debug.zip * && cd ..

cp out/uwp/x86/godot.uwp.opt.32.x86.exe uwp_template_Win32/godot.uwp.exe
cp out/uwp/x86/godot.uwp.opt.debug.32.x86.exe uwp_template_Win32_debug/godot.uwp.exe
sign uwp_template_Win32/godot.uwp.exe
sign uwp_template_Win32_debug/godot.uwp.exe
cd uwp_template_Win32 && zip -q -9 -r ../templates/uwp_x86_release.zip * && cd ..
cd uwp_template_Win32_debug && zip -q -9 -r ../templates/uwp_x86_debug.zip * && cd ..

cp out/uwp/x64/godot.uwp.opt.64.x64.exe uwp_template_x64/godot.uwp.exe
cp out/uwp/x64/godot.uwp.opt.debug.64.x64.exe uwp_template_x64_debug/godot.uwp.exe
sign uwp_template_x64/godot.uwp.exe
sign uwp_template_x64_debug/godot.uwp.exe
cd uwp_template_x64 && zip -q -9 -r ../templates/uwp_x64_release.zip * && cd ..
cd uwp_template_x64_debug && zip -q -9 -r ../templates/uwp_x64_debug.zip * && cd ..

rm -rf uwp_template_*

# Windows

mkdir -p release-${GODOT_VERSION}
rm -f release-${GODOT_VERSION}/*win*zip

cp out/windows/x64/tools/godot.windows.opt.tools.64.exe Godot_v${GODOT_VERSION}_win64.exe
strip Godot_v${GODOT_VERSION}_win64.exe
sign Godot_v${GODOT_VERSION}_win64.exe
zip -q -9 Godot_v${GODOT_VERSION}_win64.exe.zip Godot_v${GODOT_VERSION}_win64.exe
mv Godot_v${GODOT_VERSION}_win64.exe.zip release-${GODOT_VERSION}
rm Godot_v${GODOT_VERSION}_win64.exe

cp out/windows/x86/tools/godot.windows.opt.tools.32.exe Godot_v${GODOT_VERSION}_win32.exe
strip Godot_v${GODOT_VERSION}_win32.exe
sign Godot_v${GODOT_VERSION}_win32.exe
zip -q -9 Godot_v${GODOT_VERSION}_win32.exe.zip Godot_v${GODOT_VERSION}_win32.exe
mv Godot_v${GODOT_VERSION}_win32.exe.zip release-${GODOT_VERSION}
rm Godot_v${GODOT_VERSION}_win32.exe

mkdir -p templates
rm -rf templates/*win*

cp out/windows/x64/templates/godot.windows.opt.64.exe templates/windows_64_release.exe
cp out/windows/x64/templates/godot.windows.opt.debug.64.exe templates/windows_64_debug.exe
cp out/windows/x86/templates/godot.windows.opt.32.exe templates/windows_32_release.exe
cp out/windows/x86/templates/godot.windows.opt.debug.32.exe templates/windows_32_debug.exe

strip templates/windows*.exe

sign templates/windows_64_release.exe
sign templates/windows_64_debug.exe
sign templates/windows_32_release.exe
sign templates/windows_32_debug.exe

mkdir -p mono/release-${GODOT_VERSION}
rm -rf mono/release-${GODOT_VERSION}/*win*

mkdir -p mono/templates
rm -rf mono/templates/*win*

mkdir -p Godot_v${GODOT_VERSION}_mono_win64
cp out/windows/x64/tools-mono/godot.windows.opt.tools.64.mono.exe Godot_v${GODOT_VERSION}_mono_win64/Godot_v${GODOT_VERSION}_mono_win64.exe
strip Godot_v${GODOT_VERSION}_mono_win64/Godot_v${GODOT_VERSION}_mono_win64.exe
sign Godot_v${GODOT_VERSION}_mono_win64/Godot_v${GODOT_VERSION}_mono_win64.exe
cp -rp out/windows/x64/tools-mono/GodotSharp Godot_v${GODOT_VERSION}_mono_win64
cp -rp mono-glue/Api Godot_v${GODOT_VERSION}_mono_win64/GodotSharp/Api
zip -r -q -9 Godot_v${GODOT_VERSION}_mono_win64.zip Godot_v${GODOT_VERSION}_mono_win64
mv Godot_v${GODOT_VERSION}_mono_win64.zip mono/release-${GODOT_VERSION}
rm -rf Godot_v${GODOT_VERSION}_mono_win64

cp -rp out/windows/x64/templates-mono/data.mono.windows.64.* mono/templates/
cp out/windows/x64/templates-mono/godot.windows.opt.debug.64.mono.exe mono/templates/windows_64_debug.exe
cp out/windows/x64/templates-mono/godot.windows.opt.64.mono.exe mono/templates/windows_64_release.exe

mkdir -p Godot_v${GODOT_VERSION}_mono_win32
cp out/windows/x86/tools-mono/godot.windows.opt.tools.32.mono.exe Godot_v${GODOT_VERSION}_mono_win32/Godot_v${GODOT_VERSION}_mono_win32.exe
strip Godot_v${GODOT_VERSION}_mono_win32/Godot_v${GODOT_VERSION}_mono_win32.exe
sign Godot_v${GODOT_VERSION}_mono_win32/Godot_v${GODOT_VERSION}_mono_win32.exe
cp -rp  out/windows/x86/tools-mono/GodotSharp Godot_v${GODOT_VERSION}_mono_win32
cp -rp mono-glue/Api Godot_v${GODOT_VERSION}_mono_win32/GodotSharp/Api
zip -r -q -9 Godot_v${GODOT_VERSION}_mono_win32.zip Godot_v${GODOT_VERSION}_mono_win32
mv Godot_v${GODOT_VERSION}_mono_win32.zip mono/release-${GODOT_VERSION}
rm -rf Godot_v${GODOT_VERSION}_mono_win32

cp -rp out/windows/x86/templates-mono/data.mono.windows.32.* mono/templates/
cp out/windows/x86/templates-mono/godot.windows.opt.debug.32.mono.exe mono/templates/windows_32_debug.exe
cp out/windows/x86/templates-mono/godot.windows.opt.32.mono.exe mono/templates/windows_32_release.exe

strip mono/templates/windows*.exe

sign mono/templates/windows_64_debug.exe
sign mono/templates/windows_64_release.exe
sign mono/templates/windows_32_debug.exe
sign mono/templates/windows_32_release.exe

# OSX

mkdir -p templates
rm -f templates/osx*

rm -rf osx_template
mkdir -p osx_template
cd osx_template

cp -r ../git/misc/dist/osx_template.app .
mkdir osx_template.app/Contents/MacOS

cp ../out/macosx/x64/templates/godot.osx.opt.64 osx_template.app/Contents/MacOS/godot_osx_release.64
cp ../out/macosx/x64/templates/godot.osx.opt.debug.64 osx_template.app/Contents/MacOS/godot_osx_debug.64
chmod +x osx_template.app/Contents/MacOS/godot_osx*
zip -q -9 -r osx.zip osx_template.app
cd ..

mv osx_template/osx.zip templates
rm -rf osx_template

mkdir -p release-${GODOT_VERSION}
rm -f release-${GODOT_VERSION}/*osx*

cp -r git/misc/dist/osx_tools.app Godot.app
mkdir -p Godot.app/Contents/MacOS
cp out/macosx/x64/tools/godot.osx.opt.tools.64 Godot.app/Contents/MacOS/Godot
chmod +x Godot.app/Contents/MacOS/Godot
zip -q -9 -r "release-${GODOT_VERSION}/Godot_v${GODOT_VERSION}_osx.64.zip" Godot.app
rm -rf Godot.app

mkdir -p mono/templates
rm -rf mono/templates/osx*

rm -rf osx_template
mkdir -p osx_template
cd osx_template

cp -r ../git/misc/dist/osx_template.app .
mkdir osx_template.app/Contents/MacOS

cp ../out/macosx/x64/templates-mono/godot.osx.opt.64.mono osx_template.app/Contents/MacOS/godot_osx_release.64
cp ../out/macosx/x64/templates-mono/godot.osx.opt.debug.64.mono osx_template.app/Contents/MacOS/godot_osx_debug.64
cp -rp ../out/macosx/x64/templates-mono/data.mono.osx.64.* osx_template.app/Contents/MacOS/
chmod +x osx_template.app/Contents/MacOS/godot_osx*
zip -q -9 -r osx.zip osx_template.app
cd ..

mv osx_template/osx.zip mono/templates
rm -rf osx_template

mkdir -p mono/release-${GODOT_VERSION}
rm -f mono/release-${GODOT_VERSION}/*osx*

cp -r git/misc/dist/osx_tools.app Godot_mono.app
mkdir -p Godot_mono.app/Contents/MacOS
cp out/macosx/x64/tools-mono/godot.osx.opt.tools.64.mono Godot_mono.app/Contents/MacOS/Godot
mkdir -p Godot_mono.app/Contents/{Frameworks,Resources}
mkdir -p Godot_mono.app/Contents/{Frameworks,Resources}/GodotSharp
mkdir -p Godot_mono.app/Contents/{Frameworks,Resources}/GodotSharp/Mono
cp -rp out/macosx/x64/tools-mono/GodotSharp/Mono/lib Godot_mono.app/Contents/Frameworks/GodotSharp/Mono
cp -rp out/macosx/x64/tools-mono/GodotSharp/Tools Godot_mono.app/Contents/Frameworks/GodotSharp
cp -rp mono-glue/Api Godot_mono.app/Contents/Frameworks/GodotSharp
cp -rp out/macosx/x64/tools-mono/GodotSharp/Mono/etc Godot_mono.app/Contents/Resources/GodotSharp/Mono
chmod +x Godot_mono.app/Contents/MacOS/Godot
zip -q -9 -r "mono/release-${GODOT_VERSION}/Godot_v${GODOT_VERSION}_mono_osx.64.zip" Godot_mono.app
rm -rf Godot_mono.app

# iOS

cp -r git/misc/dist/ios_xcode ios_xcode
cp out/ios/libgodot.iphone.opt.fat ios_xcode/libgodot.iphone.release.fat.a
cp out/ios/libgodot.iphone.opt.debug.fat ios_xcode/libgodot.iphone.debug.fat.a

chmod +x ios_xcode/libgodot.iphone.*
cd ios_xcode
zip -q -9 -r ../templates/iphone.zip *
cd ..
rm -rf ios_xcode

# Android
cp out/android/*.apk templates

# Javascript
cp out/javascript/godot.javascript.opt.zip templates/webassembly_release.zip
cp out/javascript/godot.javascript.opt.debug.zip templates/webassembly_debug.zip

exit 0
