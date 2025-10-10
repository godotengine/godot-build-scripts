#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version-name>"
  exit 1
fi

VERSION_NAME="$1"

BASEDIR="$(pwd)"

source ${BASEDIR}/config.sh

VENV_DIR="${BASEDIR}/venv"
PYTHON_SCRIPT="${BASEDIR}/build-android/playstore_upload_script.py"
AAB_FILE="${BASEDIR}/out/android/tools/android_editor.aab"
NDS_FILE="${BASEDIR}/out/android/tools/android_editor_native_debug_symbols.zip"
JSON_KEY_FILE="${BASEDIR}/${GODOT_ANDROID_UPLOAD_JSON_KEY}"

echo "Creating virtual environment"
rm -rf "$VENV_DIR"
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

echo "Installing google-api-python-client"
pip install --upgrade google-api-python-client

python3 "$PYTHON_SCRIPT" "$AAB_FILE" "$NDS_FILE" "$JSON_KEY_FILE" "$VERSION_NAME"
