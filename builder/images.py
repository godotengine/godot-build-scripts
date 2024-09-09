
class ImageConfig:

    def __getattr__(self, name):
        try:
            return self.__class__.getattr(name)
        except AttributeError as e:
            return super().__getattr__(name)

    out_dir = None
    dirs = ["out"]
    extra_opts = []
    cmd = ["bash", "/root/build/build.sh"]
    mounts = {}
    image_version = "3.3-mono-6.12.0.114"
    log = None


class AOTCompilersConfig:
    out_dir = "aot-compilers"
    image = "localhost/godot-ios"
    cmd = ["bash", "-c", "'cp -r /root/aot-compilers/* /root/out'"]


class MonoGlueConfig(ImageConfig):
    dirs = ["mono-glue"]
    mounts = {"build-mono-glue": "build"}
    image = "godot-mono-glue"
    log = "mono-glue"


class WindowsConfig(ImageConfig):
    out_dir = "windows"
    mounts = {"build-windows": "build"}
    image = "godot-windows"
    log = "windows"


class Linux64Config(ImageConfig):
    out_dir = "linux/x64"
    mounts = {"build-linux": "build"}
    image = "godot-ubuntu-64"
    log = "linux64"

class Linux32Config(ImageConfig):
    out_dir = "linux/x86"
    mounts = {"build-linux": "build"}
    image = "godot-ubuntu-32"
    log = "linux32"


class JavaScriptConfig(ImageConfig):
    out_dir = "javascript"
    mounts = {"build-javascript": "build"}
    image = "godot-javascript"
    log = "javascript"


class MacOSXConfig(ImageConfig):
    out_dir = "macosx"
    mounts = {"build-macosx": "build"}
    image = "godot-osx"
    log = "macosx"


class AndroidConfig(ImageConfig):
    out_dir = "android"
    mounts = {"build-android": "build"}
    image = "godot-android"
    log = "android"


class IOSConfig(ImageConfig):
    out_dir = "ios"
    mounts = {"build-ios": "build"}
    image = "godot-ios"
    log = "ios"


class ServerConfig(ImageConfig):
    out_dir = "server/x64"
    mounts = {"build-server": "build"}
    image = "godot-ubuntu-64"
    log = "server"


class UWPConfig(ImageConfig):
    out_dir = "uwp"
    extra_opts = ["--ulimit", "nofile=32768:32768"]
    cmd = ["bash", "/root/build/build.sh"]
    mounts = {"build-uwp": "build"}
    image = "uwp"
    log = "uwp"


configs = ImageConfig.__subclasses__()
