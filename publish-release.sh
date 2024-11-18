#!/bin/bash

set -e

# Config

# For signing keys, and path to godot-builds repo.
source ./config.sh

godot_version=""
web_editor_latest=0

while getopts "h?v:l" opt; do
  case "$opt" in
  h|\?)
    echo "Usage: $0 [OPTIONS...]"
    echo
    echo "  -v godot version (e.g: 3.2-stable) [mandatory]"
    echo "  -l mark web editor as latest"
    echo
    exit 1
    ;;
  v)
    godot_version=$OPTARG
    ;;
  l)
    web_editor_latest=1
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
if [ $web_editor_latest == 1 ]; then
  command="${command} -l"
fi
ssh -P 22 ${WEB_EDITOR_HOSTNAME} "${command}"

# NuGet packages

publish_nuget_packages() {
  for pkg in "$@"; do
    dotnet nuget push $pkg --source "${NUGET_SOURCE}" --api-key "${NUGET_API_KEY}" --skip-duplicate
  done
}

if [ ! -z "${NUGET_SOURCE}" ] && [ ! -z "${NUGET_API_KEY}" ] && [[ $(type -P "dotnet") ]]; then
  echo "Publishing NuGet packages..."
  publish_nuget_packages out/linux/x86_64/tools-mono/GodotSharp/Tools/nupkgs/*.nupkg
else
  echo "Disabling NuGet package publishing as config.sh does not define the required data (NUGET_SOURCE, NUGET_API_KEY), or dotnet can't be found in PATH."
fi

# Godot Android library

if [ -d "deps/keystore" ]; then
  echo "Publishing Android library to MavenCentral..."
  sh build-android/upload-mavencentral.sh
else
  echo "Disabling Android library publishing as deps/keystore doesn't exist."
fi

# Stable release only

if [ "${status}" == "stable" ]; then
  echo "NOTE: This script doesn't handle yet uploading stable releases to the main GitHub repository, Steam, EGS, and itch.io."
fi
