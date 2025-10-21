import sys, socket
from google.oauth2 import service_account
from googleapiclient.discovery import build

PACKAGE_NAME = "org.godotengine.editor.v4"

def main(aab_path, nds_path, key_path, version_name):
    version_base = version_name.split("-")[0]
    version_parts = version_base.split(".")
    major = version_parts[0]
    minor = version_parts[1]
    patch = int(version_parts[2]) if len(version_parts) > 2 else 0
    channel = version_name.split("-")[1]

    release_note = f"Godot Engine {version_name} has arrived!\nNote: This is a pre-release piece of software so be sure to make backups."
    track = "alpha"

    if "stable" in channel:
        if patch == 0:
            release_url = f"https://godotengine.org/releases/{major}.{minor}/"
        else:
            release_url = f"https://godotengine.org/article/maintenance-release-godot-{major}-{minor}-{patch}/"
        release_note = f"Godot Engine {version_name} has arrived!\nRelease page: {release_url}"
        track = "beta"
    elif "rc" in channel:
        channel_url = channel.replace("rc", "rc-")
        if patch == 0:
            release_url = f"https://godotengine.org/article/release-candidate-godot-{major}-{minor}-{channel_url}/"
        else:
            release_url = f"https://godotengine.org/article/release-candidate-godot-{major}-{minor}-{patch}-{channel_url}/"
        release_note += f"\nRelease page: {release_url}"
    else:
        # No need to handle patch versions here: maintenance releases go straight to RC and stable.
        # There are no 4.5.1-dev or 4.5.1-beta builds.
        if "beta" in channel:
            channel_url = channel.replace("beta", "beta-")
        else:
            channel_url = channel.replace("dev", "dev-")
        release_url = f"https://godotengine.org/article/dev-snapshot-godot-{major}-{minor}-{channel_url}/"
        release_note += f"\nRelease page: {release_url}"

    scopes = ["https://www.googleapis.com/auth/androidpublisher"]
    credentials = service_account.Credentials.from_service_account_file(key_path, scopes=scopes)

    initial_timeout = socket.getdefaulttimeout()
    socket.setdefaulttimeout(900)
    service = build("androidpublisher", "v3", credentials=credentials)

    print("Creating a new edit")
    edit = service.edits().insert(body={}, packageName=PACKAGE_NAME).execute()
    edit_id = edit["id"]

    print(f"Uploading {aab_path}")
    bundle_response = service.edits().bundles().upload(
        editId=edit_id,
        packageName=PACKAGE_NAME,
        media_body=aab_path,
        media_mime_type="application/octet-stream"
    ).execute()

    version_code = bundle_response["versionCode"]
    print(f"Uploaded AAB with versionCode: {version_code}")

    print(f"Uploading native debug symbols {nds_path}")
    service.edits().deobfuscationfiles().upload(
        editId=edit_id,
        packageName=PACKAGE_NAME,
        apkVersionCode=version_code,
        deobfuscationFileType="nativeCode",
        media_body=nds_path,
        media_mime_type="application/octet-stream"
    ).execute()

    release_name = f"v{version_name} ({version_code})"
    print(f"Assigning {release_name} to {track} track")

    service.edits().tracks().update(
        editId=edit_id,
        packageName=PACKAGE_NAME,
        track=track,
        body={
            "releases": [{
                "name": release_name,
                "versionCodes": [str(version_code)],
                "status": "completed",
                "releaseNotes": [{
                    "language": "en-US",
                    "text": release_note
                }]
            }]
        }
    ).execute()

    service.edits().commit(editId=edit_id, packageName=PACKAGE_NAME).execute()
    print("Release uploaded and published successfully!")
    socket.setdefaulttimeout(initial_timeout)

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python3 upload_playstore.py <aab-path> <native-debug-symbols-path> <json-key-path> <version-name>")
        print("version-name format: <major>.<minor>[.<patch>]-<channel> (e.g. 4.4.1-stable, 4.5-stable, 4.6-dev1)")
        sys.exit(1)

    aab_path = sys.argv[1]
    nds_path = sys.argv[2]
    key_path = sys.argv[3]
    version_name = sys.argv[4]

    main(aab_path, nds_path, key_path, version_name)
