#!/bin/bash

set -e

OPTIND=1

# Config

# For default registry and number of cores.
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

registry="${REGISTRY}"
username=""
password=""
godot_version=""
git_treeish="master"
build_classical=1
build_mono=1
force_download=0
skip_download=1
skip_git_checkout=0

while getopts "h?r:u:p:v:g:b:fsc" opt; do
  case "$opt" in
  h|\?)
    echo "Usage: $0 [OPTIONS...]"
    echo
    echo "  -r registry"
    echo "  -u username"
    echo "  -p password"
    echo "  -v godot version (e.g. 3.1-alpha5) [mandatory]"
    echo "  -g git treeish (e.g. master)"
    echo "  -b all|classical|mono (default: all)"
    echo "  -f force redownload of all images"
    echo "  -s skip downloading"
    echo "  -c skip checkout"
    echo
    exit 1
    ;;
  r)
    registry=$OPTARG
    ;;
  u)
    username=$OPTARG
    ;;
  p)
    password=$OPTARG
    ;;
  v)
    godot_version=$OPTARG
    ;;
  g)
    git_treeish=$OPTARG
    ;;
  b)
    if [ "$OPTARG" == "classical" ]; then
      build_mono=0
    elif [ "$OPTARG" == "mono" ]; then
      build_classical=0
    fi
    ;;
  f)
    force_download=1
    ;;
  s)
    skip_download=1
    ;;
  c)
    skip_git_checkout=1
    ;;
  esac
done

export podman=none
if which podman > /dev/null; then
  export podman=podman
elif which docker > /dev/null; then
  export podman=docker
fi

if [ "${podman}" == "none" ]; then
  echo "Either podman or docker needs to be installed"
  exit 1
fi

if [ $UID != 0 ]; then
  echo "WARNING: Running as non-root may cause problems for the uwp build"
fi

if [ -z "${godot_version}" ]; then
  echo "-v <version> is mandatory!"
  exit 1
fi

if [ ! -z "${username}" ] && [ ! -z "${password}" ]; then
  if ${podman} login ${registry} -u "${username}" -p "${password}"; then
    export logged_in=true
  fi
fi

if [ $skip_download == 0 ]; then
  echo "Fetching images"
  for image in mono-glue windows ubuntu-64 ubuntu-32 javascript; do
    if [ ${force_download} == 1 ] || ! ${podman} image exists godot/$image; then
      if ! ${podman} pull ${registry}/godot/${image}; then
        echo "ERROR: image $image does not exist and can't be downloaded"
        exit 1
      fi
    fi
  done

  if [ ! -z "${logged_in}" ]; then
    echo "Fetching private images"

    for image in macosx android ios uwp; do
      if [ ${force_download} == 1 ] || ! ${podman} image exists godot-private/$image; then
        if ! ${podman} pull ${registry}/godot-private/${image}; then
          echo "ERROR: image $image does not exist and can't be downloaded"
          exit 1
        fi
      fi
    done
  fi
fi

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
if hasattr(version, "patch"):
  git_version = f"{version.major}.{version.minor}.{version.patch}-{version.status}"
else:
  git_version = f"{version.major}.{version.minor}-{version.status}"
print(git_version == "${godot_version}")
EOF
  )
  if [[ "$correct_version" != "True" ]]; then
    echo "Version in version.py doesn't match the passed ${godot_version}."
    exit 0
  fi

  git archive --format=tar $git_treeish --prefix=godot-${godot_version}/ | gzip > ../godot.tar.gz
  popd
fi

export basedir="$(pwd)"
mkdir -p ${basedir}/out
mkdir -p ${basedir}/out/logs

export podman_run="${podman} run -it --rm --env BUILD_NAME --env NUM_CORES --env CLASSICAL=${build_classical} --env MONO=${build_mono} -v ${basedir}/godot.tar.gz:/root/godot.tar.gz -v ${basedir}/mono-glue:/root/mono-glue -w /root/"
export img_version=3.2-mono-6.12.0.114

# Get AOT compilers from their containers.
mkdir -p ${basedir}/out/aot-compilers
${podman} run -it --rm -w /root -v ${basedir}/out/aot-compilers:/root/out localhost/godot-ios:${img_version} bash -c "cp -r /root/aot-compilers/* /root/out"
chmod +x ${basedir}/out/aot-compilers/*/*

mkdir -p ${basedir}/mono-glue
${podman_run} -v ${basedir}/build-mono-glue:/root/build localhost/godot-mono-glue:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/mono-glue

mkdir -p ${basedir}/out/windows
${podman_run} -v ${basedir}/build-windows:/root/build -v ${basedir}/out/windows:/root/out localhost/godot-windows:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/windows

mkdir -p ${basedir}/out/linux/x64
${podman_run} -v ${basedir}/build-linux:/root/build -v ${basedir}/out/linux/x64:/root/out localhost/godot-ubuntu-64:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/linux64

mkdir -p ${basedir}/out/linux/x86
${podman_run} -v ${basedir}/build-linux:/root/build -v ${basedir}/out/linux/x86:/root/out localhost/godot-ubuntu-32:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/linux32

mkdir -p ${basedir}/out/javascript
${podman_run} -v ${basedir}/build-javascript:/root/build -v ${basedir}/out/javascript:/root/out localhost/godot-javascript:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/javascript

mkdir -p ${basedir}/out/macosx
${podman_run} -v ${basedir}/build-macosx:/root/build -v ${basedir}/out/macosx:/root/out localhost/godot-osx:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/macosx

mkdir -p ${basedir}/out/android
${podman_run} -v ${basedir}/build-android:/root/build -v ${basedir}/out/android:/root/out localhost/godot-android:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/android

mkdir -p ${basedir}/out/ios
${podman_run} -v ${basedir}/build-ios:/root/build -v ${basedir}/out/ios:/root/out localhost/godot-ios:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/ios

mkdir -p ${basedir}/out/server/x64
${podman_run} -v ${basedir}/build-server:/root/build -v ${basedir}/out/server/x64:/root/out localhost/godot-ubuntu-64:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/server

mkdir -p ${basedir}/out/uwp
${podman_run} --ulimit nofile=32768:32768 -v ${basedir}/build-uwp:/root/build -v ${basedir}/out/uwp:/root/out ${registry}/godot-private/uwp:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/uwp

if [ ! -z "$SUDO_UID" ]; then
  chown -R "${SUDO_UID}":"${SUDO_GID}" ${basedir}/out
fi
