#!/bin/bash
set -e 

OPTIND=1

registry="registry.prehensile-tales.com"
username=""
password=""
godot_version=""
template_version=""
git_treeish="master"
force_download=0
skip_download=0
skip_git_checkout=0

while getopts "h?r:u:p:v:t:g:fsc" opt; do
    case "$opt" in
    h|\?)
        echo "Usage: $0 [OPTIONS...]"
        echo
        echo "  -r registry"
        echo "  -u username"
        echo "  -p password"
        echo "  -v godot version (e.g: 3.1-alpha5) [mandatory]"
        echo "  -t template version (e.g 3.1.alpha) [mandatory]"
        echo "  -g git treeish (e.g: master)"
        echo "  -f force redownload of all images"
        echo "  -s skip downloading"
        echo "  -c skip checkout"
        echo
        exit 1
        ;;
    r)  registry=$OPTARG
        ;;
    u)  username=$OPTARG
        ;;
    p)  password=$OPTARG
        ;;
    v)  godot_version=$OPTARG
        ;;
    t)  template_version=$OPTARG
        ;;
    g)  git_treeish=$OPTARG
        ;;
    f)  force_download=1
        ;;
    s)  skip_download=1
        ;;
    c)  skip_git_checkout=1
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

if [ -z "${template_version}" ]; then
  echo "-t <version> is mandatory!"
  exit 1
fi

if [ ! -z "${username}" ] && [ ! -z "${password}" ]; then
  if ${podman} login ${registry} -u "${username}" -p "${password}"; then
    export logged_in=true
  fi
fi 

if [ $skip_download == 0 ]; then
  echo "Fetching images"
  for image in mono-glue windows ubuntu-32 ubuntu-64 javascript; do
    if [ ${force_download} == 1 ] || ! ${podman} image exists godot/$image; then
      if ! ${podman} pull ${registry}/godot/${image}; then
        echo "ERROR: image $image does not exist and can't be downloaded"
        exit 1
      fi
    fi
  done

  if [ ! -z "${logged_in}" ]; then
    echo "Fetching private images"

    for image in uwp macosx ios android; do
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
  git clean -fd
  git clean -fx
  git pull origin ${git_treeish}

  git archive --format=tar $git_treeish --prefix=godot-${godot_version}/ | gzip > ../godot.tar.gz
  popd
fi

export basedir="$(pwd)"
mkdir -p ${basedir}/out
mkdir -p ${basedir}/out/logs

mkdir -p ${basedir}/mono-glue
${podman} run -it --rm -v ${basedir}/godot.tar.gz:/root/godot.tar.gz -v ${basedir}/build-mono-glue:/root/build -v ${basedir}/mono-glue:/root/mono-glue -w /root/ ${registry}/godot/mono-glue:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/mono-glue

mkdir -p ${basedir}/out/windows
${podman} run -it --rm -v ${basedir}/godot.tar.gz:/root/godot.tar.gz -v ${basedir}/build-windows:/root/build -v ${basedir}/mono-glue:/root/mono-glue -v ${basedir}/out/windows:/root/out -w /root/ ${registry}/godot/windows:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/windows

mkdir -p ${basedir}/out/linux/x86
${podman} run -it --rm -v ${basedir}/godot.tar.gz:/root/godot.tar.gz -v ${basedir}/build-linux:/root/build -v ${basedir}/mono-glue:/root/mono-glue -v ${basedir}/out/linux/x86:/root/out -w /root/ ${registry}/godot/ubuntu-32:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/linux32

mkdir -p ${basedir}/out/linux/x64
${podman} run -it --rm -v ${basedir}/godot.tar.gz:/root/godot.tar.gz -v ${basedir}/build-linux:/root/build -v ${basedir}/mono-glue:/root/mono-glue -v ${basedir}/out/linux/x64:/root/out -w /root/ ${registry}/godot/ubuntu-64:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/linux64

mkdir -p ${basedir}/out/server/x64
${podman} run -it --rm -v ${basedir}/godot.tar.gz:/root/godot.tar.gz -v ${basedir}/build-server:/root/build -v ${basedir}/mono-glue:/root/mono-glue -v ${basedir}/out/server/x64:/root/out -w /root/ ${registry}/godot/ubuntu-64:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/server

mkdir -p ${basedir}/out/javascript
${podman} run -it --rm -v ${basedir}/godot.tar.gz:/root/godot.tar.gz -v ${basedir}/build-javascript:/root/build -v ${basedir}/mono-glue:/root/mono-glue -v ${basedir}/out/javascript:/root/out -w /root/ ${registry}/godot/javascript:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/javascript

mkdir -p ${basedir}/out/macosx/x64
${podman} run -it --rm -v ${basedir}/godot.tar.gz:/root/godot.tar.gz -v ${basedir}/build-macosx:/root/build -v ${basedir}/mono-glue:/root/mono-glue -v ${basedir}/out/macosx/x64:/root/out -w /root/ ${registry}/godot-private/macosx:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/macosx

mkdir -p ${basedir}/out/uwp
${podman} run --ulimit nofile=32768:32768 -it --rm -v ${basedir}/godot.tar.gz:/root/godot.tar.gz -v ${basedir}/build-uwp:/root/build -v ${basedir}/out/uwp:/root/out -w /root/ ${registry}/godot-private/uwp:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/uwp

mkdir -p ${basedir}/out/ios
${podman} run -it --rm -v ${basedir}/godot.tar.gz:/root/godot.tar.gz -v ${basedir}/build-ios:/root/build -v ${basedir}/out/ios:/root/out -w /root/ ${registry}/godot-private/ios:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/ios

mkdir -p ${basedir}/out/android
${podman} run -it --rm -v ${basedir}/godot.tar.gz:/root/godot.tar.gz -v ${basedir}/build-android:/root/build -v ${basedir}/out/android:/root/out -w /root/ ${registry}/godot-private/android:latest bash build/build.sh 2>&1 | tee ${basedir}/out/logs/android

if [ ! -z "$SUDO_UID" ]; then
  chown -R "${SUDO_UID}":"${SUDO_GID}" ${basedir}/out
fi

