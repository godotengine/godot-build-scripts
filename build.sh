#!/bin/bash

set -e

OPTIND=1

export basedir="$(pwd)"
mkdir -p ${basedir}/out
mkdir -p ${basedir}/out/logs

# Log output to a file automatically.
exec > >(tee -a "out/logs/build") 2>&1

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
build_uwp=0

while getopts "h?r:u:p:v:g:b:fscw" opt; do
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
    echo "  -w build UWP templates"
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
  w)
    build_uwp=1
    ;;
  esac
done

export podman=${PODMAN}

if [ $UID != 0 ] && grep -qv sudo <<< "${podman}"; then
  echo "WARNING: Running as non-root may cause problems for the uwp build"
fi

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

if [ ! -z "${username}" ] && [ ! -z "${password}" ]; then
  if ${podman} login ${registry} -u "${username}" -p "${password}"; then
    export logged_in=true
  fi
fi

if [ $skip_download == 0 ]; then
  echo "Fetching images"
  for image in mono-glue windows linux javascript; do
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

# Keystore for Android editor signing
# Optional - the config.sh will be copied but if it's not filled in,
# it will do an unsigned build.
if [ ! -d "deps/keystore" ]; then
  mkdir -p deps/keystore
  cp config.sh deps/keystore/
  if [ ! -z "$GODOT_ANDROID_SIGN_KEYSTORE" ]; then
    cp "$GODOT_ANDROID_SIGN_KEYSTORE" deps/keystore/
    sed -i deps/keystore/config.sh -e "s@$GODOT_ANDROID_SIGN_KEYSTORE@/root/keystore/$GODOT_ANDROID_SIGN_KEYSTORE@"
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

  sh misc/scripts/make_tarball.sh -v ${godot_version} -g ${git_treeish}
  popd
fi

export podman_run="${podman} run -it --rm --env BUILD_NAME=${BUILD_NAME} --env GODOT_VERSION_STATUS=${GODOT_VERSION_STATUS} --env NUM_CORES=${NUM_CORES} --env CLASSICAL=${build_classical} --env MONO=${build_mono} -v ${basedir}/godot-${godot_version}.tar.gz:/root/godot.tar.gz -v ${basedir}/mono-glue:/root/mono-glue -w /root/"
export img_version=$IMAGE_VERSION

# Get AOT compilers from their containers.
mkdir -p ${basedir}/out/aot-compilers
${podman} run -it --rm -w /root -v ${basedir}/out/aot-compilers:/root/out localhost/godot-ios:${img_version} bash -c "cp -r /root/aot-compilers/* /root/out && chmod +x /root/out/*/*"

mkdir -p ${basedir}/mono-glue
${podman_run} -v ${basedir}/build-mono-glue:/root/build localhost/godot-mono-glue:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/mono-glue

mkdir -p ${basedir}/out/windows
${podman_run} -v ${basedir}/build-windows:/root/build -v ${basedir}/out/windows:/root/out localhost/godot-windows:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/windows

mkdir -p ${basedir}/out/linux
${podman_run} -v ${basedir}/build-linux:/root/build -v ${basedir}/out/linux:/root/out localhost/godot-linux:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/linux

mkdir -p ${basedir}/out/javascript
${podman_run} -v ${basedir}/build-javascript:/root/build -v ${basedir}/out/javascript:/root/out localhost/godot-javascript:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/javascript

mkdir -p ${basedir}/out/macosx
${podman_run} -v ${basedir}/build-macosx:/root/build -v ${basedir}/out/macosx:/root/out localhost/godot-osx:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/macosx

mkdir -p ${basedir}/out/android
${podman_run} -v ${basedir}/build-android:/root/build -v ${basedir}/out/android:/root/out -v ${basedir}/deps/keystore:/root/keystore localhost/godot-android:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/android

mkdir -p ${basedir}/out/ios
${podman_run} -v ${basedir}/build-ios:/root/build -v ${basedir}/out/ios:/root/out localhost/godot-ios:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/ios

mkdir -p ${basedir}/out/server
${podman_run} -v ${basedir}/build-server:/root/build -v ${basedir}/out/server:/root/out localhost/godot-linux:${img_version} bash build/build.sh 2>&1 | tee ${basedir}/out/logs/server

if [ "${build_uwp}" == "1" ]; then
  mkdir -p ${basedir}/out/uwp
  ${podman_run} --ulimit nofile=32768:32768 -v ${basedir}/build-uwp:/root/build -v ${basedir}/out/uwp:/root/out ${registry}/godot-private/uwp:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/uwp
fi

uid=$(id -un)
gid=$(id -gn)
if [ ! -z "$SUDO_UID" ]; then
  uid="${SUDO_UID}"
  gid="${SUDO_GID}"
fi
chown -R -f $uid:$gid ${basedir}/git ${basedir}/out ${basedir}/mono-glue ${basedir}/godot*.tar.gz
