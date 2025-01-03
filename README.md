# Godot in-container build scripts

***Godot 1.0 Legacy Edition***

Build scripts used for official Godot Engine releases using containers
built from https://github.com/godotengine/build-containers

**This is a heavily modified version of the main build scripts specifically
for the purpose of building the 2014 release of Godot 1.0 a decade later.**
Check the `main` branch for the current scripts used in production for actively
maintained Godot versions.

## Disclaimer

This repository is **not** intended for end users, and thus not
supported. It's only public as a way to document our build workflow,
and for anyone to use as reference for their own buildsystems.

We will eventually release a public build script that integrates all
this in a simple and user-friendly interface.

## Usage

- Build containers using https://github.com/godotengine/build-containers
- Copy `config.sh.in` as `config.sh` and configure it as you want. Note in
  particular the `IMAGE_VERSION` field which should match the containers you
  built.
- Build with `build.sh` (check `--help` for usage).
- Package binaries with `build-release.sh` (check `--help` for usage).

Example that builds Godot 1.0-stable (from the `1.0` branch which had a few
extra fixes for recent compilers):
```
./build.sh -v 1.0-stable -g 1.0
./build-release.sh -v 1.0-stable -t 1.0.stable
```

Again, this is intended for release managers and usability is not the
main focus. Tweak the build scripts to match your own requirements if
you want to use this until we provide a better, user-friendly
interface.
