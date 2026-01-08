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

  if [ ! -d "${UPLOAD_STEAM_PATH}" ]; then
    echo "Invalid config.sh: UPLOAD_STEAM_PATH is not a directory, aborting."
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
  gh release upload ${godot_version} ${reldir}/[Gg]* ${reldir}/mono/[Gg]*
  # Concatenate SHA sums.
  cp ${reldir}/SHA512-SUMS.txt .
  cat ${reldir}/mono/SHA512-SUMS.txt >> SHA512-SUMS.txt
  gh release upload ${godot_version} SHA512-SUMS.txt
  rm SHA512-SUMS.txt
  popd

  echo "Uploading stable release to Steam."

  pushd ${UPLOAD_STEAM_PATH}
  rm -rf content/bin/[Gg]*
  rm -rf content/editor_data/templates/*
  cp -f ${basedir}/git/*.{md,txt,png,svg} content/
  pushd content/bin/
  unzip ${reldir}/${namever}_x11.64.zip
  unzip ${reldir}/${namever}_x11.32.zip
  unzip ${reldir}/${namever}_win64.exe.zip
  unzip ${reldir}/${namever}_win32.exe.zip
  unzip ${reldir}/${namever}_osx.universal.zip
  mv ${namever}_x11.64 godot.x11.opt.tools.64
  mv ${namever}_x11.32 godot.x11.opt.tools.32
  mv ${namever}_win64.exe godot.windows.opt.tools.64.exe
  mv ${namever}_win32.exe godot.windows.opt.tools.32.exe
  popd
  unzip ${reldir}/${namever}_export_templates.tpz -d content/editor_data/templates/
  mv content/editor_data/templates/{templates,${template_version}}
  steam_build/build.sh
  popd

  echo "All stable release upload steps done."
fi

# Upload to S3 Bucket

upload_bucket() {
  local file_path=$(realpath $1)
  local upload_key=${godot_version}/$(basename $file_path)
  echo "Uploading $upload_key..."
  local json_data=$(curl -s -S -f -H "Authorization: Bearer $S3_API_KEY" https://storage.godotengine.org/api/v1/request_upload_url/2/${upload_key})
  curl -s -S -f \
    -F key="$upload_key" \
    -F ACL=$(echo $json_data | jq '.fields.ACL') \
    -F policy=$(echo $json_data | jq '.fields.policy') \
    -F x-amz-algorithm=$(echo $json_data | jq '.fields."x-amz-algorithm"') \
    -F x-amz-credential=$(echo $json_data | jq '.fields."x-amz-credential"') \
    -F x-amz-date=$(echo $json_data | jq '.fields."x-amz-date"') \
    -F x-amz-signature=$(echo $json_data | jq '.fields."x-amz-signature"') \
    -F file="@$file_path" \
    $(echo $json_data | jq -r '.url')
}

if [ ! -z "${S3_API_KEY}" ]; then
  echo "Uploading release to S3 Bucket..."
  for path in $reldir/Godot_v* $reldir/mono/Godot_v*; do
    upload_bucket $path
  done
else
  echo "Disabling S3 Bucket publishing as no valid API key was found."
fi

# Web editor

echo "Uploading web editor... (with retry logic as it can be flaky)"

MAX_RETRIES=5
delay=5

retry_command() {
    local attempt=1
    local cmd=$1
    while [ ${attempt} -le ${MAX_RETRIES} ]; do
        echo "Attempt ${attempt}: Running command..."
        eval "${cmd}" && return 0  # Success

        echo "Command failed. Retrying in ${delay} seconds..."
        sleep ${delay}
        ((attempt++))
        delay=$((delay * 2))  # Exponential backoff
    done

    echo "❌ Command failed after ${MAX_RETRIES} attempts."
    return 1
}

command="sudo mv /home/akien/web_editor/${template_version} /var/www/editor.godotengine.org/public/releases/"
command="${command}; cd /var/www/editor.godotengine.org; sudo chown -R www-data:www-data public/releases/${template_version}"
command="${command}; sudo ./create-symlinks.sh -v ${template_version}"

retry_command "scp -P 22 -r web/${template_version} ${WEB_EDITOR_HOSTNAME}:/home/akien/web_editor/"
sleep 2
retry_command "ssh -p 22 ${WEB_EDITOR_HOSTNAME} '${command}'"

echo "All publishing steps done. Check out/logs/publish-release to double check that all steps succeeded."
