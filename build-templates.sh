#!/bin/bash

set -e

godot_version=""
templates_version=""
build_classical=1
build_mono=1

while getopts "h?v:t:b:" opt; do
  case "$opt" in
  h|\?)
    echo "Usage: $0 [OPTIONS...]"
    echo
    echo "  -v public version (e.g. 3.2-stable) [mandatory]"
    echo "  -t templates version (e.g. 3.2.stable) [mandatory]"
    echo "  -b all|classical|mono (default: all)"
    echo
    exit 1
    ;;
  v)
    godot_version=$OPTARG
    ;;
  t)
    templates_version=$OPTARG
    ;;
  b)
    if [ "$OPTARG" == "classical" ]; then
      build_mono=0
    elif [ "$OPTARG" == "mono" ]; then
      build_classical=0
    fi
    ;;
  esac
done

if [ -z "${godot_version}" -o -z "${templates_version}" ]; then
  echo "Mandatory argument -v or -t missing."
  exit 1
fi

export basedir=$(pwd)
export reldir="${basedir}/releases/${godot_version}"
export reldir_mono="${reldir}/mono"
export tmpdir="${basedir}/tmp"
export templatesdir="${tmpdir}/templates"
export templatesdir_mono="${templatesdir}-mono"

export godot_basename="Godot_v${godot_version}"

# Classical

if [ "${build_classical}" == "1" ]; then
  echo "${templates_version}" > ${templatesdir}/version.txt

  mkdir -p ${reldir}
  zip -q -9 -r -D "${reldir}/${godot_basename}_export_templates.tpz" ${templatesdir}
fi

# Mono

if [ "${build_mono}" == "1" ]; then
  echo "${templates_version}.mono" > ${templatesdir_mono}/version.txt

  mkdir -p ${reldir_mono}
  zip -q -9 -r -D "${reldir_mono}/${godot_basename}_mono_export_templates.tpz" ${templatesdir_mono}
fi

echo "Templates archives generated successfully"
