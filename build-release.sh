#!/bin/bash

set -e

# Config

# For signing keystore and password.
source ./config.sh

can_sign_windows=0
if [ ! -z "${SIGN_KEYSTORE}" ] && [ ! -z "${SIGN_PASSWORD}" ] && [[ $(type -P "osslsigncode") ]]; then
  can_sign_windows=1
else
  echo "Disabling Windows binary signing as config.sh does not define the required data (SIGN_KEYSTORE, SIGN_PASSWORD), or osslsigncode can't be found in PATH."
fi

sign_windows() {
  if [ $can_sign_windows == 0 ]; then
    return
  fi
  osslsigncode sign -pkcs12 ${SIGN_KEYSTORE} -pass "${SIGN_PASSWORD}" -n "${SIGN_NAME}" -i "${SIGN_URL}" -t http://timestamp.comodoca.com -in $1 -out $1-signed
  mv $1-signed $1
}

sign_macos() {
  if [ -z "${OSX_HOST}" ]; then
    return
  fi
  _macos_tmpdir=$(ssh "${OSX_HOST}" "mktemp -d")
  _reldir="$1"
  _binname="$2"
  _is_mono="$3"

  if [[ "${_is_mono}" == "1" ]]; then
    _appname="Godot_mono.app"
    _sharpdir="${_appname}/Contents/Resources/GodotSharp"
    _extra_files="${_sharpdir}/Mono/lib/*.dylib ${_sharpdir}/Tools/aot-compilers/*/*"
  else
    _appname="Godot.app"
  fi

  scp "${_reldir}/${_binname}.zip" "${OSX_HOST}:${_macos_tmpdir}"
  scp "${basedir}/git/misc/dist/macos/editor.entitlements" "${OSX_HOST}:${_macos_tmpdir}"
  ssh "${OSX_HOST}" "
            cd ${_macos_tmpdir} && \
            unzip ${_binname}.zip && \
            codesign --force --timestamp \
              --options=runtime --entitlements editor.entitlements \
              -s ${OSX_KEY_ID} -v ${_extra_files} ${_appname} && \
            zip -r ${_binname}_signed.zip ${_appname}"

  _request_uuid=$(ssh "${OSX_HOST}" "xcrun altool --notarize-app --primary-bundle-id \"${OSX_BUNDLE_ID}\" --username \"${APPLE_ID}\" --password \"${APPLE_ID_PASSWORD}\" --file ${_macos_tmpdir}/${_binname}_signed.zip")
  _request_uuid=$(echo ${_request_uuid} | sed -e 's/.*RequestUUID = //')
  ssh "${OSX_HOST}" "while xcrun altool --notarization-info ${_request_uuid} -u \"${APPLE_ID}\" -p \"${APPLE_ID_PASSWORD}\" | grep -q Status:\ in\ progress; do echo Waiting on Apple notarization...; sleep 30s; done"
  if ! ssh "${OSX_HOST}" "xcrun altool --notarization-info ${_request_uuid} -u \"${APPLE_ID}\" -p \"${APPLE_ID_PASSWORD}\" | grep -q Status:\ success"; then
    echo "Notarization failed."
    _notarization_log=$(ssh "${OSX_HOST}" "xcrun altool --notarization-info ${_request_uuid} -u \"${APPLE_ID}\" -p \"${APPLE_ID_PASSWORD}\"")
    echo "${_notarization_log}"
    ssh "${OSX_HOST}" "rm -rf ${_macos_tmpdir}"
    exit 1
  else
    ssh "${OSX_HOST}" "
            cd ${_macos_tmpdir} && \
            xcrun stapler staple ${_appname} && \
            zip -r ${_binname}_stapled.zip ${_appname}"
    scp "${OSX_HOST}:${_macos_tmpdir}/${_binname}_stapled.zip" "${_reldir}/${_binname}.zip"
    ssh "${OSX_HOST}" "rm -rf ${_macos_tmpdir}"
  fi
}

sign_macos_template() {
  if [ -z "${OSX_HOST}" ]; then
    return
  fi
  _macos_tmpdir=$(ssh "${OSX_HOST}" "mktemp -d")
  _reldir="$1"
  _is_mono="$2"

  if [[ "${_is_mono}" == "1" ]]; then
    _extra_files="macos_template.app/Contents/Resources/data.mono.*/Mono/lib/*.dylib"
  fi

  scp "${_reldir}/macos.zip" "${OSX_HOST}:${_macos_tmpdir}"
  ssh "${OSX_HOST}" "
            cd ${_macos_tmpdir} && \
            unzip macos.zip && \
            codesign --force -s - \
              --options=linker-signed \
              -v ${_extra_files} macos_template.app/Contents/MacOS/* && \
            zip -r macos_signed.zip macos_template.app"

  scp "${OSX_HOST}:${_macos_tmpdir}/macos_signed.zip" "${_reldir}/macos.zip"
  ssh "${OSX_HOST}" "rm -rf ${_macos_tmpdir}"
}

godot_version=""
templates_version=""
build_classical=1
build_mono=1

while getopts "h?v:t:b:" opt; do
  case "$opt" in
  h|\?)
    echo "Usage: $0 [OPTIONS...]"
    echo
    echo "  -v godot version (e.g: 3.2-stable) [mandatory]"
    echo "  -t templates version (e.g. 3.2.stable) [mandatory]"
    echo "  -b all|classical|mono (default: all)"
    echo
    exit 1
    ;;
  v)
    godot_version=$OPTARG
    ;;
  t)
    templates_version=$OPTARG
    ;;
  b)
    if [ "$OPTARG" == "classical" ]; then
      build_mono=0
    elif [ "$OPTARG" == "mono" ]; then
      build_classical=0
    fi
    ;;
  esac
done

if [ -z "${godot_version}" -o -z "${templates_version}" ]; then
  echo "Mandatory argument -v or -t missing."
  exit 1
elif [[ "{$templates_version}" == *"-"* ]]; then
  echo "Templates version (-t) shouldn't contain '-'. It should use a dot to separate version from status."
  exit 1
fi

export basedir=$(pwd)
export webdir="${basedir}/web/${templates_version}"
export reldir="${basedir}/releases/${godot_version}"
export reldir_mono="${reldir}/mono"
export tmpdir="${basedir}/tmp"
export templatesdir="${tmpdir}/templates"
export templatesdir_mono="${tmpdir}/mono/templates"

export godot_basename="Godot_v${godot_version}"

# Cleanup and setup

rm -rf ${webdir}
rm -rf ${reldir}
rm -rf ${tmpdir}

mkdir -p ${webdir}
mkdir -p ${reldir}
mkdir -p ${reldir_mono}
mkdir -p ${templatesdir}
mkdir -p ${templatesdir_mono}

# Tarball

zcat godot-${godot_version}.tar.gz | xz -c > ${reldir}/godot-${godot_version}.tar.xz
pushd ${reldir}
sha256sum godot-${godot_version}.tar.xz > godot-${godot_version}.tar.xz.sha256
popd

# Classical

if [ "${build_classical}" == "1" ]; then

  ## Linux (Classical) ##

  # Editor
  binname="${godot_basename}_linux.x86_64"
  cp out/linux/x86_64/tools/godot.linuxbsd.opt.tools.x86_64 ${binname}
  strip ${binname}
  zip -q -9 "${reldir}/${binname}.zip" ${binname}
  rm ${binname}

  binname="${godot_basename}_linux.x86_32"
  cp out/linux/x86_32/tools/godot.linuxbsd.opt.tools.x86_32 ${binname}
  strip ${binname}
  zip -q -9 "${reldir}/${binname}.zip" ${binname}
  rm ${binname}

  # Templates
  cp out/linux/x86_64/templates/godot.linuxbsd.opt.x86_64 ${templatesdir}/linux_release.x86_64
  cp out/linux/x86_64/templates/godot.linuxbsd.opt.debug.x86_64 ${templatesdir}/linux_debug.x86_64
  cp out/linux/x86_32/templates/godot.linuxbsd.opt.x86_32 ${templatesdir}/linux_release.x86_32
  cp out/linux/x86_32/templates/godot.linuxbsd.opt.debug.x86_32 ${templatesdir}/linux_debug.x86_32
  strip ${templatesdir}/linux*

  ## Windows (Classical) ##

  # Editor
  binname="${godot_basename}_win64.exe"
  batname="${godot_basename}_win64_console.cmd"
  cp out/windows/x86_64/tools/godot.windows.opt.tools.x86_64.exe ${binname}
  strip ${binname}
  sign_windows ${binname}
  echo "@echo off" > ${batname}
  echo ${binname} >> ${batname}
  echo "pause > nul" >> ${batname}
  zip -q -9 "${reldir}/${binname}.zip" ${binname} ${batname}
  rm ${binname} ${batname}

  binname="${godot_basename}_win32.exe"
  batname="${godot_basename}_win32_console.cmd"
  cp out/windows/x86_32/tools/godot.windows.opt.tools.x86_32.exe ${binname}
  strip ${binname}
  sign_windows ${binname}
  echo "@echo off" > ${batname}
  echo ${binname} >> ${batname}
  echo "pause > nul" >> ${batname}
  zip -q -9 "${reldir}/${binname}.zip" ${binname} ${batname}
  rm ${binname} ${batname}

  # Templates
  cp out/windows/x86_64/templates/godot.windows.opt.x86_64.exe ${templatesdir}/windows_release_x86_64.exe
  cp out/windows/x86_64/templates/godot.windows.opt.debug.x86_64.exe ${templatesdir}/windows_debug_x86_64.exe
  cp out/windows/x86_32/templates/godot.windows.opt.x86_32.exe ${templatesdir}/windows_release_x86_32.exe
  cp out/windows/x86_32/templates/godot.windows.opt.debug.x86_32.exe ${templatesdir}/windows_debug_x86_32.exe
  strip ${templatesdir}/windows*.exe

  ## macOS (Classical) ##

  # Editor
  binname="${godot_basename}_macos.universal"
  rm -rf Godot.app
  cp -r git/misc/dist/macos_tools.app Godot.app
  mkdir -p Godot.app/Contents/MacOS
  cp out/macos/tools/godot.macos.opt.tools.universal Godot.app/Contents/MacOS/Godot
  chmod +x Godot.app/Contents/MacOS/Godot
  zip -q -9 -r "${reldir}/${binname}.zip" Godot.app
  rm -rf Godot.app
  sign_macos ${reldir} ${binname} 0

  # Templates
  rm -rf macos_template.app
  cp -r git/misc/dist/macos_template.app .
  mkdir -p macos_template.app/Contents/MacOS

  cp out/macos/templates/godot.macos.opt.universal macos_template.app/Contents/MacOS/godot_macos_release.universal
  cp out/macos/templates/godot.macos.opt.debug.universal macos_template.app/Contents/MacOS/godot_macos_debug.universal
  chmod +x macos_template.app/Contents/MacOS/godot_macos*
  zip -q -9 -r "${templatesdir}/macos.zip" macos_template.app
  rm -rf macos_template.app
  sign_macos_template ${templatesdir} 0

#  ## Javascript (Classical) ##
#
#  # Editor
#  unzip out/javascript/tools/godot.javascript.opt.tools.threads.zip -d ${webdir}/
#  brotli --keep --force --quality=11 ${webdir}/*
#  binname="${godot_basename}_web_editor.zip"
#  cp out/javascript/tools/godot.javascript.opt.tools.threads.zip ${reldir}/${binname}
#
#  # Templates
#  cp out/javascript/templates/godot.javascript.opt.zip ${templatesdir}/webassembly_release.zip
#  cp out/javascript/templates/godot.javascript.opt.debug.zip ${templatesdir}/webassembly_debug.zip
#
#  cp out/javascript/templates/godot.javascript.opt.threads.zip ${templatesdir}/webassembly_threads_release.zip
#  cp out/javascript/templates/godot.javascript.opt.debug.threads.zip ${templatesdir}/webassembly_threads_debug.zip
#
#  cp out/javascript/templates/godot.javascript.opt.gdnative.zip ${templatesdir}/webassembly_gdnative_release.zip
#  cp out/javascript/templates/godot.javascript.opt.debug.gdnative.zip ${templatesdir}/webassembly_gdnative_debug.zip

  ## Android (Classical) ##

  # Lib for direct download
  cp out/android/templates/godot-lib.release.aar ${reldir}/godot-lib.${templates_version}.release.aar

  # Editor
  binname="${godot_basename}_android_editor.apk"
  cp out/android/tools/android_editor.apk ${reldir}/${binname}

  # Templates
  cp out/android/templates/*.apk ${templatesdir}/
  cp out/android/templates/android_source.zip ${templatesdir}/

  ## iOS (Classical) ##

  rm -rf ios_xcode
  cp -r git/misc/dist/ios_xcode ios_xcode
  cp out/ios/templates/libgodot.ios.simulator.a ios_xcode/libgodot.ios.release.xcframework/ios-arm64_x86_64-simulator/libgodot.a
  cp out/ios/templates/libgodot.ios.debug.simulator.a ios_xcode/libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a
  cp out/ios/templates/libgodot.ios.a ios_xcode/libgodot.ios.release.xcframework/ios-arm64/libgodot.a
  cp out/ios/templates/libgodot.ios.debug.a ios_xcode/libgodot.ios.debug.xcframework/ios-arm64/libgodot.a
  cp -r deps/vulkansdk-macos/MoltenVK/MoltenVK.xcframework ios_xcode/
  rm -rf ios_xcode/MoltenVK.xcframework/{macos,tvos}*
  cd ios_xcode
  zip -q -9 -r "${templatesdir}/ios.zip" *
  cd ..
  rm -rf ios_xcode

#  ## UWP (Classical) ##
#
#  if [ ! -d "deps/angle" ]; then
#    echo "Downloading ANGLE binaries from https://github.com/GodotBuilder/godot-builds/releases/tag/_tools"
#    mkdir -p deps && cd deps
#    curl -LO https://github.com/GodotBuilder/godot-builds/releases/download/_tools/angle.7z
#    7z x angle.7z && rm -f angle.7z
#    cd ..
#  fi
#
#  rm -rf uwp_template_*
#  for arch in ARM Win32 x64; do
#    cp -r git/misc/dist/uwp_template uwp_template_${arch}
#    cp deps/angle/winrt/10/src/Release_${arch}/libEGL.dll \
#      deps/angle/winrt/10/src/Release_${arch}/libGLESv2.dll \
#      uwp_template_${arch}/
#    cp -r uwp_template_${arch} uwp_template_${arch}_debug
#  done
#
#  cp out/uwp/arm/godot.uwp.opt.32.arm.exe uwp_template_ARM/godot.uwp.exe
#  cp out/uwp/arm/godot.uwp.opt.debug.32.arm.exe uwp_template_ARM_debug/godot.uwp.exe
#  cd uwp_template_ARM && zip -q -9 -r "${templatesdir}/uwp_arm_release.zip" * && cd ..
#  cd uwp_template_ARM_debug && zip -q -9 -r "${templatesdir}/uwp_arm_debug.zip" * && cd ..
#  rm -rf uwp_template_ARM*
#
#  cp out/uwp/x86/godot.uwp.opt.32.x86.exe uwp_template_Win32/godot.uwp.exe
#  cp out/uwp/x86/godot.uwp.opt.debug.32.x86.exe uwp_template_Win32_debug/godot.uwp.exe
#  cd uwp_template_Win32 && zip -q -9 -r "${templatesdir}/uwp_x86_release.zip" * && cd ..
#  cd uwp_template_Win32_debug && zip -q -9 -r "${templatesdir}/uwp_x86_debug.zip" * && cd ..
#  rm -rf uwp_template_Win32*
#
#  cp out/uwp/x64/godot.uwp.opt.64.x64.exe uwp_template_x64/godot.uwp.exe
#  cp out/uwp/x64/godot.uwp.opt.debug.64.x64.exe uwp_template_x64_debug/godot.uwp.exe
#  cd uwp_template_x64 && zip -q -9 -r "${templatesdir}/uwp_x64_release.zip" * && cd ..
#  cd uwp_template_x64_debug && zip -q -9 -r "${templatesdir}/uwp_x64_debug.zip" * && cd ..
#  rm -rf uwp_template_x64*

  ## Templates TPZ (Classical) ##

  echo "${templates_version}" > ${templatesdir}/version.txt
  pushd ${templatesdir}/..
  zip -q -9 -r -D "${reldir}/${godot_basename}_export_templates.tpz" templates/*
  popd

  ## SHA-512 sums (Classical) ##

  pushd ${reldir}
  sha512sum [Gg]* > SHA512-SUMS.txt
  mkdir -p ${basedir}/sha512sums/${godot_version}
  cp SHA512-SUMS.txt ${basedir}/sha512sums/${godot_version}/
  popd

fi

# Mono

if [ "${build_mono}" == "1" ]; then

  ## Linux (Mono) ##

  # Editor
  binbasename="${godot_basename}_mono_linux"
  mkdir -p ${binbasename}_x86_64
  cp out/linux/x86_64/tools-mono/godot.linuxbsd.opt.tools.x86_64.mono ${binbasename}_x86_64/${binbasename}.x86_64
  strip ${binbasename}_x86_64/${binbasename}.x86_64
  cp -rp out/linux/x86_64/tools-mono/GodotSharp ${binbasename}_x86_64/
  cp -rp out/aot-compilers ${binbasename}_x86_64/GodotSharp/Tools/
  zip -r -q -9 "${reldir_mono}/${binbasename}_x86_64.zip" ${binbasename}_x86_64
  rm -rf ${binbasename}_x86_64

  binbasename="${godot_basename}_mono_linux"
  mkdir -p ${binbasename}_x86_32
  cp out/linux/x86_32/tools-mono/godot.linuxbsd.opt.tools.x86_32.mono ${binbasename}_x86_32/${binbasename}.x86_32
  strip ${binbasename}_x86_32/${binbasename}.x86_32
  cp -rp out/linux/x86_32/tools-mono/GodotSharp/ ${binbasename}_x86_32/
  cp -rp out/aot-compilers ${binbasename}_x86_32/GodotSharp/Tools/
  zip -r -q -9 "${reldir_mono}/${binbasename}_x86_32.zip" ${binbasename}_x86_32
  rm -rf ${binbasename}_x86_32

  # Templates
  cp -rp out/linux/x86_64/templates-mono/data.mono.linuxbsd.x86_64.* ${templatesdir_mono}/
  cp out/linux/x86_64/templates-mono/godot.linuxbsd.opt.debug.x86_64.mono ${templatesdir_mono}/linux_debug.x86_64
  cp out/linux/x86_64/templates-mono/godot.linuxbsd.opt.x86_64.mono ${templatesdir_mono}/linux_release.x86_64
  cp -rp out/linux/x86_32/templates-mono/data.mono.linuxbsd.x86_32.* ${templatesdir_mono}/
  cp out/linux/x86_32/templates-mono/godot.linuxbsd.opt.debug.x86_32.mono ${templatesdir_mono}/linux_debug.x86_32
  cp out/linux/x86_32/templates-mono/godot.linuxbsd.opt.x86_32.mono ${templatesdir_mono}/linux_release.x86_32
  strip ${templatesdir_mono}/linux*

  mkdir -p ${templatesdir_mono}/bcl
  cp -r out/linux/x86_64/tools-mono/GodotSharp/Mono/lib/mono/4.5/ ${templatesdir_mono}/bcl/net_4_x

  ## Windows (Mono) ##

  # Editor
  binname="${godot_basename}_mono_win64"
  batname="${godot_basename}_mono_win64_console.cmd"
  mkdir -p ${binname}
  cp out/windows/x86_64/tools-mono/godot.windows.opt.tools.x86_64.mono.exe ${binname}/${binname}.exe
  strip ${binname}/${binname}.exe
  sign_windows ${binname}/${binname}.exe
  cp -rp out/windows/x86_64/tools-mono/GodotSharp ${binname}/
  cp -rp out/aot-compilers ${binname}/GodotSharp/Tools/
  echo "@echo off" > ${batname}
  echo ${binname}.exe >> ${batname}
  echo "pause > nul" >> ${batname}
  mv ${batname} ${binname}/
  zip -r -q -9 "${reldir_mono}/${binname}.zip" ${binname}
  rm -rf ${binname}

  binname="${godot_basename}_mono_win32"
  batname="${godot_basename}_mono_win32_console.cmd"
  mkdir -p ${binname}
  cp out/windows/x86_32/tools-mono/godot.windows.opt.tools.x86_32.mono.exe ${binname}/${binname}.exe
  strip ${binname}/${binname}.exe
  sign_windows ${binname}/${binname}.exe
  cp -rp out/windows/x86_32/tools-mono/GodotSharp ${binname}/
  cp -rp out/aot-compilers ${binname}/GodotSharp/Tools/
  echo "@echo off" > ${batname}
  echo ${binname}.exe >> ${batname}
  echo "pause > nul" >> ${batname}
  mv ${batname} ${binname}/
  zip -r -q -9 "${reldir_mono}/${binname}.zip" ${binname}
  rm -rf ${binname}

  # Templates
  cp -rp out/windows/x86_64/templates-mono/data.mono.windows.x86_64.* ${templatesdir_mono}/
  cp out/windows/x86_64/templates-mono/godot.windows.opt.debug.x86_64.mono.exe ${templatesdir_mono}/windows_debug_x86_64.exe
  cp out/windows/x86_64/templates-mono/godot.windows.opt.x86_64.mono.exe ${templatesdir_mono}/windows_release_x86_64.exe
  cp -rp out/windows/x86_32/templates-mono/data.mono.windows.x86_32.* ${templatesdir_mono}/
  cp out/windows/x86_32/templates-mono/godot.windows.opt.debug.x86_32.mono.exe ${templatesdir_mono}/windows_debug_x86_32.exe
  cp out/windows/x86_32/templates-mono/godot.windows.opt.x86_32.mono.exe ${templatesdir_mono}/windows_release_x86_32.exe
  strip ${templatesdir_mono}/windows*.exe

  mkdir -p ${templatesdir_mono}/bcl
  cp -r out/windows/x86_64/tools-mono/GodotSharp/Mono/lib/mono/4.5/ ${templatesdir_mono}/bcl/net_4_x_win

  ## macOS (Mono) ##

  # Editor
  binname="${godot_basename}_mono_macos.universal"
  rm -rf Godot_mono.app
  cp -r git/misc/dist/macos_tools.app Godot_mono.app
  mkdir -p Godot_mono.app/Contents/{MacOS,Resources}
  cp out/macos/tools-mono/godot.macos.opt.tools.universal.mono Godot_mono.app/Contents/MacOS/Godot
  cp -rp out/macos/tools-mono/GodotSharp Godot_mono.app/Contents/Resources/GodotSharp
  cp -rp out/aot-compilers Godot_mono.app/Contents/Resources/GodotSharp/Tools/
  chmod +x Godot_mono.app/Contents/MacOS/Godot
  zip -q -9 -r "${reldir_mono}/${binname}.zip" Godot_mono.app
  rm -rf Godot_mono.app
  sign_macos ${reldir_mono} ${binname} 1

  # Templates
  rm -rf macos_template.app
  cp -r git/misc/dist/macos_template.app .
  mkdir -p macos_template.app/Contents/{MacOS,Resources}
  cp out/macos/templates-mono/godot.macos.opt.debug.universal.mono macos_template.app/Contents/MacOS/godot_macos_debug.universal
  cp out/macos/templates-mono/godot.macos.opt.universal.mono macos_template.app/Contents/MacOS/godot_macos_release.universal
  cp -rp out/macos/templates-mono/data.mono.macos.* macos_template.app/Contents/Resources/
  chmod +x macos_template.app/Contents/MacOS/godot_macos*
  zip -q -9 -r "${templatesdir_mono}/macos.zip" macos_template.app
  rm -rf macos_template.app
  sign_macos_template ${templatesdir_mono} 1

#  ## Javascript (Mono) ##
#
#  # Templates
#  cp out/javascript/templates-mono/godot.javascript.opt.debug.mono.zip ${templatesdir_mono}/webassembly_debug.zip
#  cp out/javascript/templates-mono/godot.javascript.opt.mono.zip ${templatesdir_mono}/webassembly_release.zip
#
#  mkdir -p ${templatesdir_mono}/bcl
#  cp -r out/javascript/templates-mono/bcl/wasm ${templatesdir_mono}/bcl/

  ## Android (Mono) ##

  # Lib for direct download
  cp out/android/templates-mono/godot-lib.release.aar ${reldir_mono}/godot-lib.${templates_version}.mono.release.aar

  # Editor
  #binname="${godot_basename}_mono_android_editor.apk"
  #cp out/android/tools-mono/android_editor.apk ${reldir_mono}/${binname}

  # Templates
  cp out/android/templates-mono/*.apk ${templatesdir_mono}/
  cp out/android/templates-mono/android_source.zip ${templatesdir_mono}/

  mkdir -p ${templatesdir_mono}/bcl
  cp -r out/android/templates-mono/bcl/godot_android_ext ${templatesdir_mono}/bcl/
  cp -r out/android/templates-mono/bcl/monodroid ${templatesdir_mono}/bcl/

  ## iOS (Mono) ##

  rm -rf ios_xcode
  cp -r git/misc/dist/ios_xcode ios_xcode
  cp out/ios/templates-mono/libgodot.ios.simulator.a ios_xcode/libgodot.ios.release.xcframework/ios-arm64_x86_64-simulator/libgodot.a
  cp out/ios/templates-mono/libgodot.ios.debug.simulator.a ios_xcode/libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a
  cp out/ios/templates-mono/libgodot.ios.a ios_xcode/libgodot.ios.release.xcframework/ios-arm64/libgodot.a
  cp out/ios/templates-mono/libgodot.ios.debug.a ios_xcode/libgodot.ios.debug.xcframework/ios-arm64/libgodot.a
  cp -r deps/vulkansdk-macos/MoltenVK/MoltenVK.xcframework ios_xcode/
  rm -rf ios_xcode/MoltenVK.xcframework/{macos,tvos}*
  cd ios_xcode
  zip -q -9 -r "${templatesdir_mono}/ios.zip" *
  cd ..
  rm -rf ios_xcode

  mkdir -p ${templatesdir_mono}/bcl
  cp -r out/ios/templates-mono/bcl/monotouch* ${templatesdir_mono}/bcl/
  cp -r out/ios/templates-mono/ios-mono-libs ${templatesdir_mono}

#  ## UWP (Mono) ##
#
#  # Not supported yet.

  ## Templates TPZ (Mono) ##

  echo "${templates_version}.mono" > ${templatesdir_mono}/version.txt
  pushd ${templatesdir_mono}/..
  zip -q -9 -r -D "${reldir_mono}/${godot_basename}_mono_export_templates.tpz" templates/*
  popd

  ## SHA-512 sums (Mono) ##

  pushd ${reldir_mono}
  sha512sum [Gg]* >> SHA512-SUMS.txt
  mkdir -p ${basedir}/sha512sums/${godot_version}/mono
  cp SHA512-SUMS.txt ${basedir}/sha512sums/${godot_version}/mono/
  popd

fi

echo "All editor binaries and templates prepared successfully for release"
