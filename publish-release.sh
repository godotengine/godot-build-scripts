#!/bin/bash

set -e

# Config

# For signing keys, and path to godot-builds repo.
source ./config.sh

godot_version=""

while getopts "h?v:" opt; do
  case "$opt" in
  h|\?)
    echo "Usage: $0 [OPTIONS...]"
    echo
    echo "  -v godot version (e.g: 3.2-stable) [mandatory]"
    echo
    exit 1
    ;;
  v)
    godot_version=$OPTARG
    ;;
  esac
done

if [ -z "${godot_version}" ]; then
  echo "Mandatory argument -v missing."
  exit 1
fi

# Confirm

IFS=- read version status <<< "${godot_version}"
echo "Publishing Godot ${version} ${status}."
read -p "Is this correct (y/n)? " choice
case "$choice" in
  y|Y ) echo "yes";;
  n|N ) echo "No, aborting."; exit 0;;
  * ) echo "Invalid choice, aborting."; exit 1;;
esac
template_version=${version}.${status}

# Upload to GitHub godot-builds

if [ -z "${GODOT_BUILDS_PATH}" ]; then
  echo "Missing path to godotengine/godot-builds clone in config.sh, necessary to upload releases. Aborting."
  exit 1
fi

${GODOT_BUILDS_PATH}/tools/upload-github.sh -v ${version} -f ${status}

# Web editor

scp -P 22 -r web/${template_version} ${WEB_EDITOR_HOSTNAME}:/home/akien/web_editor/
sleep 2
command="sudo mv /home/akien/web_editor/${template_version} /var/www/editor.godotengine.org/public/releases/"
command="${command}; cd /var/www/editor.godotengine.org; sudo chown -R www-data:www-data public/releases/${template_version}"
command="${command}; sudo ./create-symlinks.sh -v ${template_version}"
ssh -P 22 ${WEB_EDITOR_HOSTNAME} "${command}"

# Stable release only

if [ "${status}" == "stable" ]; then
  echo "NOTE: This script doesn't handle yet uploading stable releases to the main GitHub repository, Steam, EGS, and itch.io."
fi
