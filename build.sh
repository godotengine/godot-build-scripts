#!/bin/bash

set -e

OPTIND=1

export basedir="$(pwd)"
mkdir -p ${basedir}/out
mkdir -p ${basedir}/out/logs

# Log output to a file automatically.
exec > >(tee -a "out/logs/build") 2>&1

# Config

if [ ! -e config.sh ]; then
  echo "No config.sh, copying default values from config.sh.in."
  cp config.sh.in config.sh
fi
source ./config.sh

if [ -z "${BUILD_NAME}" ]; then
  export BUILD_NAME="custom_build"
fi

if [ -z "${NUM_CORES}" ]; then
  export NUM_CORES=16
fi

godot_version=""
git_treeish="master"
build_classical=1
force_download=0
skip_git_checkout=0

while getopts "h?v:g:fc" opt; do
  case "$opt" in
  h|\?)
    echo "Usage: $0 [OPTIONS...]"
    echo
    echo "  -v godot version (e.g. 2.1.7-stable) [mandatory]"
    echo "  -g git treeish (e.g. master)"
    echo "  -f force redownload of all images"
    echo "  -c skip checkout"
    echo
    exit 1
    ;;
  v)
    godot_version=$OPTARG
    ;;
  g)
    git_treeish=$OPTARG
    ;;
  f)
    force_download=1
    ;;
  c)
    skip_git_checkout=1
    ;;
  esac
done

export podman=${PODMAN}

if [ -z "${godot_version}" ]; then
  echo "-v <version> is mandatory!"
  exit 1
fi

IFS=- read version status <<< "$godot_version"
echo "Building Godot ${version} ${status} from commit or branch ${git_treeish}."
read -p "Is this correct (y/n)? " choice
case "$choice" in
  y|Y ) echo "yes";;
  n|N ) echo "No, aborting."; exit 0;;
  * ) echo "Invalid choice, aborting."; exit 1;;
esac
export GODOT_VERSION_STATUS="${status}"

if [ "${skip_git_checkout}" == 0 ]; then
  git clone https://github.com/godotengine/godot git || /bin/true
  pushd git
  git checkout -b ${git_treeish} origin/${git_treeish} || git checkout ${git_treeish}
  git reset --hard
  git clean -fdx
  git pull origin ${git_treeish} || /bin/true

  # Validate version
  correct_version=$(python3 << EOF
import version;
if hasattr(version, "patch") and version.patch != 0:
  git_version = f"{version.major}.{version.minor}.{version.patch}"
else:
  git_version = f"{version.major}.{version.minor}"
print(git_version == "${version}")
EOF
  )
  if [[ "$correct_version" != "True" ]]; then
    echo "Version in version.py doesn't match the passed ${version}."
    exit 1
  fi

  sh ../make_tarball.sh -v ${godot_version} -g ${git_treeish}
  popd
fi

export podman_run="${podman} run -it --rm --env BUILD_NAME=${BUILD_NAME} --env GODOT_VERSION_STATUS=${GODOT_VERSION_STATUS} --env NUM_CORES=${NUM_CORES} --env CLASSICAL=${build_classical} -v ${basedir}/godot-${godot_version}.tar.gz:/root/godot.tar.gz -w /root/"
export img_version=$IMAGE_VERSION

mkdir -p ${basedir}/out/windows
${podman_run} -v ${basedir}/build-windows:/root/build -v ${basedir}/out/windows:/root/out --env STEAM=${build_steam} localhost/godot-windows:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/windows

mkdir -p ${basedir}/out/linux
${podman_run} -v ${basedir}/build-linux:/root/build -v ${basedir}/out/linux:/root/out localhost/godot-linux:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/linux

mkdir -p ${basedir}/out/web
${podman_run} -v ${basedir}/build-web:/root/build -v ${basedir}/out/web:/root/out localhost/godot-web:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/web

mkdir -p ${basedir}/out/macos
${podman_run} -v ${basedir}/build-macos:/root/build -v ${basedir}/out/macos:/root/out localhost/godot-osx:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/macos

mkdir -p ${basedir}/out/android
${podman_run} -v ${basedir}/build-android:/root/build -v ${basedir}/out/android:/root/out localhost/godot-android:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/android

mkdir -p ${basedir}/out/ios
${podman_run} -v ${basedir}/build-ios:/root/build -v ${basedir}/out/ios:/root/out localhost/godot-ios:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/ios

uid=$(id -un)
gid=$(id -gn)
if [ ! -z "$SUDO_UID" ]; then
  uid="${SUDO_UID}"
  gid="${SUDO_GID}"
fi
chown -R -f $uid:$gid ${basedir}/git ${basedir}/out ${basedir}/godot*.tar.gz

echo "All builds completed. Check `out/logs/` to validate that they all succeeded (e.g. `tail -n 1 out/logs/*`)."
