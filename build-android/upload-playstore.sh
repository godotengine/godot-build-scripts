#!/bin/bash

BASEDIR="$(pwd)"
VENV_DIR="${BASEDIR}/venv"
PYTHON_SCRIPT="${BASEDIR}/build-android/upload_playstore_script.py"
AAB_FILE="${BASEDIR}/out/tools/android_editor.aab"
NDS_FILE="${BASEDIR}/out/tools/android_editor_native_debug_symbols.zip"
JSON_KEY_FILE="${BASEDIR}/deps/playstore_key.json"

echo "Creating virtual environment"
rm -rf "$VENV_DIR"
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

echo "Installing google-api-python-client"
pip install --upgrade google-api-python-client

python3 "$PYTHON_SCRIPT" "$AAB_FILE" "$NDS_FILE" "$JSON_KEY_FILE"
