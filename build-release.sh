#!/bin/bash

set -e
export basedir=$(pwd)

# Config

# For signing keystore and password.
source ./config.sh

can_sign_windows=0
if [ ! -z "${WINDOWS_SIGN_NAME}" ] && [ ! -z "${WINDOWS_SIGN_URL}" ] && [[ $(type -P "osslsigncode") ]]; then
  can_sign_windows=1
else
  echo "Disabling Windows binary signing as config.sh does not define the required data (WINDOWS_SIGN_NAME, WINDOWS_SIGN_URL), or osslsigncode can't be found in PATH."
fi

sign_windows() {
  if [ $can_sign_windows == 0 ]; then
    return
  fi
  P11_KIT_SERVER_ADDRESS=unix:path=/run/p11-kit/p11kit.sock osslsigncode sign -pkcs11module /usr/lib64/pkcs11/p11-kit-client.so -pkcs11cert 'pkcs11:model=SimplySign%20C' -key 'pkcs11:model=SimplySign%20C' -t http://time.certum.pl/ -n "${WINDOWS_SIGN_NAME}" -i "${WINDOWS_SIGN_URL}" -in $1 -out $1-signed
  mv $1-signed $1
}

sign_macos() {
  if [ -z "${OSX_HOST}" ]; then
    return
  fi
  _macos_tmpdir=$(ssh "${OSX_HOST}" "mktemp -d")
  _reldir="$1"
  _binname="$2"
  _appname="Godot.app"

  scp "${_reldir}/${_binname}.zip" "${OSX_HOST}:${_macos_tmpdir}"
  ssh "${OSX_HOST}" "
            cd ${_macos_tmpdir} && \
            unzip ${_binname}.zip && \
            codesign --force --timestamp \
              --options=runtime \
              -s ${OSX_KEY_ID} -v ${_appname} && \
            zip -r ${_binname}_signed.zip ${_appname}"

  _request_uuid=$(ssh "${OSX_HOST}" "xcrun notarytool submit ${_macos_tmpdir}/${_binname}_signed.zip --team-id \"${APPLE_TEAM}\" --apple-id \"${APPLE_ID}\" --password \"${APPLE_ID_PASSWORD}\" --no-progress --output-format json")
  _request_uuid=$(echo ${_request_uuid} | sed -e 's/.*"id":"\([^"]*\)".*/\1/')
  if ! ssh "${OSX_HOST}" "xcrun notarytool wait ${_request_uuid} --team-id \"${APPLE_TEAM}\" --apple-id \"${APPLE_ID}\" --password \"${APPLE_ID_PASSWORD}\" | grep -q status:\ Accepted"; then
    echo "Notarization failed."
    _notarization_log=$(ssh "${OSX_HOST}" "xcrun notarytool log ${_request_uuid} --team-id \"${APPLE_TEAM}\" --apple-id \"${APPLE_ID}\" --password \"${APPLE_ID_PASSWORD}\"")
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

  scp "${_reldir}/osx.zip" "${OSX_HOST}:${_macos_tmpdir}"
  ssh "${OSX_HOST}" "
            cd ${_macos_tmpdir} && \
            unzip osx.zip && \
            codesign --force -s - \
              --options=linker-signed \
              -v osx_template.app/Contents/MacOS/* && \
            zip -r osx_signed.zip osx_template.app"

  scp "${OSX_HOST}:${_macos_tmpdir}/osx_signed.zip" "${_reldir}/osx.zip"
  ssh "${OSX_HOST}" "rm -rf ${_macos_tmpdir}"
}

godot_version=""
templates_version=""
do_cleanup=1
make_tarball=1

while getopts "h?v:t:n-:" opt; do
  case "$opt" in
  h|\?)
    echo "Usage: $0 [OPTIONS...]"
    echo
    echo "  -v godot version (e.g: 3.2-stable) [mandatory]"
    echo "  -t templates version (e.g. 3.2.stable) [mandatory]"
    echo "  --no-cleanup disable deleting pre-existing output folders (default: false)"
    echo "  --no-tarball disable generating source tarball (default: false)"
    echo
    exit 1
    ;;
  v)
    godot_version=$OPTARG
    ;;
  t)
    templates_version=$OPTARG
    ;;
  -)
    case "${OPTARG}" in
    no-cleanup)
      do_cleanup=0
      ;;
    no-tarball)
      make_tarball=0
      ;;
    *)
      if [ "$OPTERR" == 1 ] && [ "${optspec:0:1}" != ":" ]; then
        echo "Unknown option --${OPTARG}."
        exit 1
      fi
      ;;
    esac
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

export reldir="${basedir}/releases/${godot_version}"
export tmpdir="${basedir}/tmp"
export templatesdir="${tmpdir}/templates"

export godot_basename="Godot_v${godot_version}"

# Cleanup and setup

if [ "${do_cleanup}" == "1" ]; then

  rm -rf ${reldir}
  rm -rf ${tmpdir}

  mkdir -p ${reldir}
  mkdir -p ${templatesdir}

fi

# Tarball

if [ "${make_tarball}" == "1" ]; then

  zcat godot-${godot_version}.tar.gz | xz -c > ${reldir}/godot-${godot_version}.tar.xz
  pushd ${reldir}
  sha256sum godot-${godot_version}.tar.xz > godot-${godot_version}.tar.xz.sha256
  popd

fi

# Classical

if true; then

  ## Linux (Classical) ##

  # Editor
  binname="${godot_basename}_x11.64"
  cp out/linux/godot.x11.opt.tools.64 ${binname}
  zip -q -9 "${reldir}/${binname}.zip" ${binname}
  rm ${binname}

  binname="${godot_basename}_x11.32"
  cp out/linux/godot.x11.opt.tools.32 ${binname}
  zip -q -9 "${reldir}/${binname}.zip" ${binname}
  rm ${binname}

  # Templates
  cp out/linux/godot.x11.opt.64 ${templatesdir}/linux_x11_64_release
  cp out/linux/godot.x11.opt.debug.64 ${templatesdir}/linux_x11_64_debug
  cp out/linux/godot.x11.opt.32 ${templatesdir}/linux_x11_32_release
  cp out/linux/godot.x11.opt.debug.32 ${templatesdir}/linux_x11_32_debug

  ## Windows (Classical) ##

  # Editor
  binname="${godot_basename}_win64.exe"
  cp out/windows/godot.windows.opt.tools.64.exe ${binname}
  sign_windows ${binname}
  zip -q -9 "${reldir}/${binname}.zip" ${binname}
  rm ${binname}

  binname="${godot_basename}_win32.exe"
  cp out/windows/godot.windows.opt.tools.32.exe ${binname}
  sign_windows ${binname}
  zip -q -9 "${reldir}/${binname}.zip" ${binname}
  rm ${binname}

  # Templates
  cp out/windows/godot.windows.opt.64.exe ${templatesdir}/windows_64_release.exe
  cp out/windows/godot.windows.opt.debug.64.exe ${templatesdir}/windows_64_debug.exe
  cp out/windows/godot.windows.opt.32.exe ${templatesdir}/windows_32_release.exe
  cp out/windows/godot.windows.opt.debug.32.exe ${templatesdir}/windows_32_debug.exe

  ## macOS (Classical) ##

  # Editor
  binname="${godot_basename}_osx64"
  rm -rf Godot.app
  cp -r git/tools/Godot.app Godot.app
  mkdir -p Godot.app/Contents/MacOS
  cp out/osx/godot.osx.opt.tools.64 Godot.app/Contents/MacOS/Godot
  chmod +x Godot.app/Contents/MacOS/Godot
  zip -q -9 -r "${reldir}/${binname}.zip" Godot.app
  rm -rf Godot.app
  sign_macos ${reldir} ${binname}

  # Templates
  rm -rf osx_template.app
  cp -r git/tools/osx_template.app .
  mkdir -p osx_template.app/Contents/MacOS

  cp out/osx/godot.osx.opt.64 osx_template.app/Contents/MacOS/godot_osx_release.64
  cp out/osx/godot.osx.opt.debug.64 osx_template.app/Contents/MacOS/godot_osx_debug.64
  chmod +x osx_template.app/Contents/MacOS/godot_osx*
  zip -q -9 -r "${templatesdir}/osx.zip" osx_template.app
  rm -rf osx_template.app
  sign_macos_template ${templatesdir}

  ## Server (Classical) ##

  # Headless (editor)
  binname="${godot_basename}_linux_server.64"
  cp out/linux/godot_server.server.opt.tools.64 ${binname}
  strip ${binname}
  zip -q -9 "${reldir}/${binname}.zip" ${binname}
  rm ${binname}

  # Templates
  cp out/linux/godot_server.server.opt.64 ${templatesdir}/linux_server_64
  cp out/linux/godot_server.server.opt.32 ${templatesdir}/linux_server_32

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

echo "All editor binaries and templates prepared successfully for release"
