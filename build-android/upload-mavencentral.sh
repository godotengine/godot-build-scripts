#/bin/bash

basedir="$(pwd)"

if [ ! -d "${basedir}/deps/keystore" ]; then
  echo "Couldn't find ${basedir}/deps/keystore. Make sure to run this from the root folder of the Git repository."
fi

source ${basedir}/deps/keystore/config.sh

# Release the Godot Android library to MavenCentral
${PODMAN} run -it --rm \
  -v ${basedir}/out/android/source:/root/godot -v ${basedir}/deps/keystore:/root/keystore \
  localhost/godot-android:${IMAGE_VERSION} bash -c \
    "source /root/keystore/config.sh && \
    cp -r /root/godot/.gradle /root && \
    cd /root/godot/platform/android/java && \
    ./gradlew publishTemplateReleasePublicationToSonatypeRepository --max-workers 1 closeAndReleaseSonatypeStagingRepository"
