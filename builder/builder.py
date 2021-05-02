#!/usr/python

import logging
import os
import subprocess
import sys

from .config import Config
from .runner import RunError, Runner, run_simple


def which(what):
    return run_simple(["which", what]).stdout.strip()


def ensure_dir(dirname):
    os.makedirs(dirname, exist_ok=True)


class PodmanRunner(Runner):
    IMAGES = ["mono-glue", "windows", "ubuntu-64", "ubuntu-32", "javascript"]
    IMAGES_PRIVATE = ["macosx", "android", "ios", "uwp"]

    @staticmethod
    def get_images():
        return PodmanRunner.IMAGES + PodmanRunner.IMAGES_PRIVATE

    def get_image_path(self, image, version="latest", local=False):
        if local:
            return f"localhost/{image}:{version}"
        path = Config.private_path if image in PodmanRunner.IMAGES_PRIVATE else Config.public_path
        return f"{Config.registry}/{path}/{image}:{version}"

    def __init__(self, base_dir, dry_run=False):
        self.base_dir = base_dir
        self.dry_run = dry_run
        self.logged_in = False
        self._podman = self._detect_podman()

    def _detect_podman(self):
        podman = which("podman")
        if not podman:
            podman = which("docker")
        if not podman:
            print("Either podman or docker needs to be installed")
            sys.exit(1)
        return podman

    def login(self):
        if Config.username == "" or Config.password == "":
            logging.debug("Skipping login, missing username or password")
            return
        self.logged_in = run_simple(self._podman, "login", Config.regitry, "-u", Config.username, "-p", Config.password).returncode == 0

    def image_exists(self, image):
        return run_simple([self._podman, "image", "exists", image]).returncode == 0

    def fetch_image(self, image, force=False):
        exists = not force and self.image_exists(image)
        if not exists:
            self.run([self._podman, "pull", "%s/%s" % (Config.registry, image)])

    def fetch_images(self, images=[], **kwargs):
        if len(images) == 0:
            images = PodmanRunner.get_images()
        for image in images:
            if image in PodmanRunner.IMAGES:
                self.fetch_image("%s/%s" % (Config.public_path, image), **kwargs)
            elif image in PodmanRunner.IMAGES_PRIVATE:
                if not self.logged_in:
                    print("Can't fetch image: %s. Not logged in" % image)
                    continue
                self.fetch_image("%s/%s" % (Config.private_path, image), **kwargs)

    def podrun(self, run_config, classical=False, mono=False, local=False, interactive=False, **kwargs):
        def env(env_vars):
            for k, v in env_vars.items():
                yield("--env")
                yield(f"{k}={v}")

        def mount(mount_points):
            for k, v in mount_points.items():
                yield("-v")
                yield(f"{self.base_dir}/{k}:/root/{v}")

        for d in run_config.dirs:
            ensure_dir(os.path.join(self.base_dir, d))

        cores = os.environ.get('NUM_CORES', os.cpu_count())
        cmd = [self._podman, "run", "--rm", "-w", "/root/"]
        cmd += env({
            "BUILD_NAME": os.environ.get("BUILD_NAME", "custom_build"),
            "NUM_CORES": os.environ.get("NUM_CORES", os.cpu_count()),
            "CLASSICAL": 1 if classical else 0,
            "MONO": 1 if mono else 0,
        })
        cmd += mount({
            "mono-glue": "mono-glue",
            "godot.tar.gz": "godot.tar.gz",
        })
        cmd += mount(run_config.mounts)
        if run_config.out_dir is not None:
            out_dir = f"out/{run_config.out_dir}"
            ensure_dir(f"{self.base_dir}/{out_dir}")
            cmd += mount({
                out_dir: "out"
            })
        cmd += run_config.extra_opts

        image_path = self.get_image_path(run_config.image, version=run_config.image_version, local=local)
        if interactive:
            if self.dry_run:
                print(" ".join(cmd + ["-it", image_path, "bash"]))
                return
            return subprocess.run(cmd + ["-it", image_path, "bash"])

        cmd += [image_path] + run_config.cmd
        if run_config.log and not 'log' in kwargs:
            ensure_dir(f"{self.base_dir}/out/logs")
            with open(os.path.join(self.base_dir, "out", "logs", run_config.log), "w") as log:
                return self.run(cmd, log=log, **kwargs)
        else:
            return self.run(cmd, **kwargs)


class GitRunner(Runner):

    def __init__(self, base_dir, dry_run=False):
        self.dry_run = dry_run
        self.base_dir = base_dir

    def git(self, *args, can_fail=False):
        return self.run(["git"] + list(args), can_fail)

    def check_version(self, godot_version):
        if self.dry_run:
            print("Skipping version check in dry run mode (would likely fail)")
            return
        import importlib.util
        version_file = os.path.join("git", "version.py")
        spec = importlib.util.spec_from_file_location("version", version_file)
        version = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(version)
        if hasattr(version, "patch"):
            version_string = f"{version.major}.{version.minor}.{version.patch}-{version.status}"
        else:
            version_string = f"{version.major}.{version.minor}-{version.status}"
        ok = version_string == godot_version
        if not ok:
            print(f"Version mismatch, expected: {godot_version}, got: {version_string}")
            sys.exit(1)

    def checkout(self, ref):
        repo = "https://github.com/godotengine/godot"
        dest = os.path.join(self.base_dir, "git")
        self.git("clone", dest, can_fail=True)
        self.git("-C", dest, "fetch", "--all")
        self.git("-C", dest, "checkout", "--detach", ref)

    def tgz(self, version, ref="HEAD"):
        source = os.path.join(self.base_dir, "git")
        dest = os.path.join(self.base_dir, "godot.tar.gz")
        self.git("-C", source, "archive", f"--prefix=godot-{version}/", "-o", dest, ref)
