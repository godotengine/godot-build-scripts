#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <version-name> <latest-stable>"
  exit 1
fi

VERSION_NAME="$1"
LATEST_STABLE="$2"

BASEDIR="$(pwd)"

source ${BASEDIR}/config.sh

TMPDIR=$(mktemp -d)
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

OVR_PLATFORM_UTIL_DOWNLOAD_URL="https://www.oculus.com/download_app/?id=5159709737372459"
OVR_PLATFORM_UTIL="$TMPDIR/ovr-platform-util"

APK_FILE="${BASEDIR}/out/android/tools/android_editor_horizonos.apk"
NDS_FILE="${BASEDIR}/out/android/tools/android_editor_native_debug_symbols.zip"
NDS_OUTPUT_DIR="$TMPDIR/nds"

STATUS=$(echo "$VERSION_NAME" | sed -e 's/^.*-\([a-z][a-z]*\)[0-9]*$/\1/')
if [ "$STATUS" = "stable" -a "$LATEST_STABLE" = "1" ]; then
  HORIZON_STORE_CHANNEL="LIVE"
elif [ "$STATUS" = "dev" ]; then
  HORIZON_STORE_CHANNEL="ALPHA"
elif [ "$STATUS" = "beta" ]; then
  HORIZON_STORE_CHANNEL="BETA"
elif [ "$STATUS" = "rc" ]; then
  HORIZON_STORE_CHANNEL="RC"
else
  echo "Unable to determine Horizon store channel from version status: $STATUS" >/dev/stderr
  exit 1
fi

mkdir -p "$NDS_OUTPUT_DIR"
(cd "$NDS_OUTPUT_DIR" && unzip "$NDS_FILE")

echo "Downloading ovr-platform-util..."
if ! curl -fL -o "$OVR_PLATFORM_UTIL" "$OVR_PLATFORM_UTIL_DOWNLOAD_URL"; then
  exit 1
fi

chmod +x "$OVR_PLATFORM_UTIL"

echo "Uploading $VERSION_NAME to Horizon store on channel $HORIZON_STORE_CHANNEL..."
if ! $OVR_PLATFORM_UTIL upload-quest-build --app-id "$GODOT_ANDROID_HORIZON_APP_ID" --app-secret "$GODOT_ANDROID_HORIZON_APP_SECRET" --apk "$APK_FILE" --channel "$HORIZON_STORE_CHANNEL" --debug-symbols-dir "$NDS_OUTPUT_DIR/arm64-v8a/" --debug-symbols-pattern '*.so'; then
  exit 1
fi
