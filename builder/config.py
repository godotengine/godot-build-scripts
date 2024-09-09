import json, os

class Config:

    # Registry for build containers.
    # The default registry is the one used for official Godot builds.
    # Note that some of its images are private and only accessible to selected
    # contributors.
    # You can build your own registry with scripts at
    # https://github.com/godotengine/build-containers
    registry = "registry.prehensile-tales.com"

    # Registry username
    username = ""

    # Registry password
    password = ""

    # Public image path
    public_path = "godot"

    # Private image path
    private_path = "godot-private"

    # Default build name used to distinguish between official and custom builds.
    build_name = "custom_build"

    # Default number of parallel cores for each build.
    num_core = os.cpu_count()

    # Set up your own signing keystore and relevant details below.
    # If you do not fill all SIGN_* fields, signing will be skipped.

    # Path to pkcs12 archive.
    sign_keystore = ""

    # Password for the private key.
    sign_password = ""

    # Name and URL of the signed application.
    # Use your own when making a thirdparty build.
    sign_name = ""
    sign_url = ""

    # Hostname or IP address of an OSX host (Needed for signing)
    # eg "user@10.1.0.10"
    osx_host = ""
    # ID of the Apple certificate used to sign
    osx_key_id = ""
    # Bundle id for the signed app
    osx_bundle_id = ""
    # Username/password for Apple's signing APIs (used for atltool)
    apple_id = ""
    apple_id_password = ""


def write_config(stream):
    config = {}
    for k in dir(Config):
        if k.startswith("_"):
            continue
        config[k] = getattr(Config, k)
    json.dump(config, stream, indent=4, sort_keys=True)


def load_config(path):
    with open(path, 'r') as f:
        d = json.load(f)
        for k,v in d.items():
            if not k.startswith("_") and hasattr(Config, k):
                setattr(Config, k, v)

try:
    load_config(os.path.join(os.getcwd(), 'config.json'))
except:
    # No default config
    pass
