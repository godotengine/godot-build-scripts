# Godot in-container build scripts

Build scripts used for official Godot Engine releases using containers
built from https://github.com/godotengine/build-containers

## Disclaimer

This repository is **not** intended for end users, and thus not
supported. It's only public as a way to document our build workflow,
and for anyone to use as reference for their own buildsystems.

We will eventually release a public build script that integrates all
this in a simple and user-friendly interface.

## Usage

- Build containers using https://github.com/godotengine/build-containers
- Copy `config.sh.in` as `config.sh` and configure it as you want.
- Edit `build.sh` to properly reference those containers if local, or
  use `config.sh` to point to your own registry if you uploaded
  containers.
- Build with `build.sh` (check `--help` for usage).
- Package binaries with `build-release.sh` (check `--help` for usage).

Example that builds Godot 3.2-stable Classical (not Mono):
```
./build.sh -v 3.2-stable -g 3.2-stable -b classical
./build-release.sh -v 3.2-stable -t 3.2.stable -b classical
```

Again, this is intended for release managers and usability is not the
main focus. Tweak the build scripts to match your own requirements if
you want to use this until we provide a better, user-friendly
interface.
