#!/bin/bash

set -e

# Log output to a file automatically.
exec > >(tee -a "out/logs/publish-release") 2>&1

# Config

# For upload tools and signing/release keys.
source ./config.sh

godot_version=""
skip_stable=0
draft_arg=""

while getopts "h?v:sd" opt; do
  case "$opt" in
  h|\?)
    echo "Usage: $0 [OPTIONS...]"
    echo
    echo "  -v godot version (e.g: 3.2-stable) [mandatory]"
    echo "  -s don't run stable specific steps"
    echo "  -d publish as draft release on GitHub"
    echo
    exit 1
    ;;
  v)
    godot_version=$OPTARG
    ;;
  s)
    skip_stable=1
    ;;
  d)
    draft_arg="-d"
    ;;
  esac
done

if [ -z "${godot_version}" ]; then
  echo "Mandatory argument -v missing."
  exit 1
fi

basedir=$(pwd)
reldir=${basedir}/releases/${godot_version}

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

# Config checks for stable releases.

if [ "${status}" == "stable" -a "${skip_stable}" == "0" ]; then
  echo "Publishing a stable release. Checking that configuration is valid to perform stable release specific steps."

  read -p "Enter personal access token (GH_TOKEN) for godotengine/godot: " personal_gh_token
  if [[ "${personal_gh_token}" != "github_pat_"* ]]; then
    echo "Provided personal access token should start with 'github_pat', aborting."
    exit 1
  fi

  if ! gh api repos/godotengine/godot/git/refs/tags | grep -q ${godot_version}; then
    echo "The tag '${godot_version}' does not exist in godotengine/godot, aborting."
    echo "Push commits and create it manually before running this script."
    exit 1
  fi
fi

# Upload to GitHub godot-builds

echo "Uploading release to to godotengine/godot-builds repository."

if [ -z "${GODOT_BUILDS_PATH}" ]; then
  echo "Missing path to godotengine/godot-builds clone in config.sh, necessary to upload releases. Aborting."
  exit 1
fi

${GODOT_BUILDS_PATH}/tools/upload-github.sh -v ${version} -f ${status} ${draft_arg}

# Stable release only

if [ "${status}" == "stable" -a "${skip_stable}" == "0" ]; then
  namever=Godot_v${godot_version}

  echo "Uploading stable release to main GitHub repository."

  export GH_TOKEN=${personal_gh_token}
  pushd git
  # Get release details from existing godot-builds release.
  release_info=$(gh release view ${godot_version} --repo godotengine/godot-builds --json name,body)
  release_title=$(echo "$release_info" | jq -r '.name')
  release_desc=$(echo "$release_info" | jq -r '.body')

  gh release create ${godot_version} --repo godotengine/godot --title "$release_title" --notes "$release_desc" ${draft_arg}
  gh release upload ${godot_version} ${reldir}/[Gg]*
  # Concatenate SHA sums.
  cp ${reldir}/SHA512-SUMS.txt .
  gh release upload ${godot_version} SHA512-SUMS.txt
  rm SHA512-SUMS.txt
  popd

  echo "All stable release upload steps done."
fi

echo "All publishing steps done. Check out/logs/publish-release to double check that all steps succeeded."
