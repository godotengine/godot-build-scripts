#!/bin/bash

set -e

if [ "${DOTNET}" != "1" ]; then
  exit 0
fi

dnf install -y clang python-unversioned-command

git clone https://github.com/raulsntos/godot-dotnet
cd godot-dotnet
git checkout upgrade-assistant-plus-source-code-plugin-wip

echo "Building and generating .NET extension..."

# TODO: Get rid of this when we fix all these trimming warnings in godot-dotnet.
cat << EOF >> .editorconfig
# Disable trimming warnings because it spams the output too much.
dotnet_diagnostics.IL2111.severity = none
EOF

prerelease_label="${GODOT_VERSION#*-}"
version_prefix="${GODOT_VERSION%-*}"

if [[ "${prerelease_label}" == "${GODOT_VERSION}" ]]; then
  prerelease_label=""
fi

# TODO: Ensure we don't accidentally make stable releases. We can remove this when we're ready for a stable release.
if [[ -z "$prerelease_label" ]]; then
  echo "YOU ARE NOT SUPPOSED TO MAKE A STABLE RELEASE WITH THIS"
  exit -1
fi

version_component_count=$(grep -o "\." <<< "$version_prefix" | wc -l)

if [ "$version_component_count" -eq 0 ]; then
  version_prefix="${version_prefix}.0.0"
elif [ "$version_component_count" -eq 1 ]; then
  version_prefix="${version_prefix}.0"
fi

if [[ -n "$prerelease_label" ]]; then
  if [[ "$prerelease_label" =~ ^dev ]]; then
    prerelease_label="${prerelease_label/dev/alpha}"
  fi

  prerelease_label=$(echo "$prerelease_label" | sed -E 's/([^0-9])([0-9])/\1.\2/g')
fi

echo "Building Godot .NET version ${version_prefix} (prerelease: '${prerelease_label}')"

dotnet --info

build_id="$(date +%Y%m%d).1"
final_version_kind="release"
if [[ -n "$prerelease_label" ]]; then
  final_version_kind="prerelease"
fi

./build.sh --productBuild --ci --warnAsError false \
    /p:GenerateGodotBindings=true \
    /p:VersionPrefix=${version_prefix} \
    /p:OfficialBuildId=${build_id} \
    /p:FinalVersionKind=${final_version_kind} \
    /p:PreReleaseVersionLabel=${prerelease_label}

cp -r artifacts/packages/Release/Shipping/* /root/out/

echo ".NET bindings generated successfully"
