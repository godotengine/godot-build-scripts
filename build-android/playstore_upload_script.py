import sys, socket
from google.oauth2 import service_account
from googleapiclient.discovery import build

PACKAGE_NAME = "org.godotengine.editor.v4"
TRACK = "alpha"
RELEASE_NAME = "Automated Release"
RELEASE_NOTES = "Automated closed testing release"

def main(aab_path, nds_path, key_path):
    scopes = ["https://www.googleapis.com/auth/androidpublisher"]
    credentials = service_account.Credentials.from_service_account_file(key_path, scopes=scopes)
    initial_timeout = socket.getdefaulttimeout()
    socket.setdefaulttimeout(900)
    service = build("androidpublisher", "v3", credentials=credentials)

    print("Creating a new edit")
    edit_request = service.edits().insert(body={}, packageName=PACKAGE_NAME)
    edit = edit_request.execute()
    edit_id = edit["id"]

    print(f"Uploading {aab_path}")
    upload_request = service.edits().bundles().upload(
        editId=edit_id,
        packageName=PACKAGE_NAME,
        media_body=aab_path,
        media_mime_type="application/octet-stream"
    )
    bundle_response = upload_request.execute()
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

    print(f"Assigning version {version_code} to {TRACK} track")
    service.edits().tracks().update(
        editId=edit_id,
        packageName=PACKAGE_NAME,
        track=TRACK,
        body={
            "releases": [{
                "name": f"{RELEASE_NAME} v{version_code}",
                "versionCodes": [str(version_code)],
                "status": "completed",
                "releaseNotes": [{
                    "language": "en-US",
                    "text": RELEASE_NOTES
                }]
            }]
        }
    ).execute()

    service.edits().commit(editId=edit_id, packageName=PACKAGE_NAME).execute()
    print("Release uploaded and published successfully!")
    socket.setdefaulttimeout(initial_timeout)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 upload_playstore.py <aab-path> <native-debug-symbols-path> <json-key-path>")
        sys.exit(1)
    aab_path = sys.argv[1]
    nds_path = sys.argv[2]
    key_path = sys.argv[3]
    main(aab_path, nds_path, key_path)
