#!/bin/bash

set -e

# Config

dnf install -y clang python-unversioned-command

git clone https://github.com/raulsntos/godot-dotnet
cd godot-dotnet
git checkout upgrade-assistant-plus-source-code-plugin-wip

./build.sh --productBuild --warnAsError false /p:GenerateGodotBindings=true

cp -r artifacts/packages/Release/Shipping/* /root/out/

echo ".NET bindings generated successfully"
