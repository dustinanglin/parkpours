#!/usr/bin/env python3
"""Revoke the Apple Development certificate this build created.

Each TestFlight run starts on a clean machine, so Xcode's automatic signing
creates a new Apple Development certificate every time. Apple caps how many
an account may hold, and after a dozen or so builds the archive step fails
with "Your account has reached the maximum number of certificates".

This runs at the end of the job and revokes only the development
certificates found in this machine's keychain, matched to Apple's records
by serial number. On a GitHub-hosted runner the keychain starts empty, so
those are exactly the ones this run made. Distribution certificates, and
development certificates made anywhere else, are never touched.

Uses only the Python standard library plus the `security` and `openssl`
command-line tools that ship with macOS.

Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (the .p8 file).
"""

import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
DEVELOPMENT_TYPES = {"DEVELOPMENT", "IOS_DEVELOPMENT"}


def b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def der_to_raw_signature(der: bytes) -> bytes:
    """Convert openssl's DER ECDSA signature to the 64-byte form JWT needs."""
    if len(der) < 8 or der[0] != 0x30:
        raise ValueError("not a DER sequence")
    position = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    parts = []
    for _ in range(2):
        if der[position] != 0x02:
            raise ValueError("expected a DER integer")
        length = der[position + 1]
        value = der[position + 2 : position + 2 + length]
        parts.append(value.lstrip(b"\x00").rjust(32, b"\x00"))
        position += 2 + length
    return parts[0] + parts[1]


def make_token(key_id: str, issuer_id: str, key_path: str) -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {"iss": issuer_id, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    signing_input = (
        b64url(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + b64url(json.dumps(claims, separators=(",", ":")).encode())
    )
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input.encode(),
        capture_output=True,
        check=True,
    ).stdout
    return signing_input + "." + b64url(der_to_raw_signature(der))


def normalise(serial: str) -> str:
    return serial.strip().upper().lstrip("0")


def keychain_development_serials() -> set:
    """Serial numbers of the Apple Development certificates in the keychain."""
    found = subprocess.run(
        ["security", "find-certificate", "-a", "-c", "Apple Development", "-p"],
        capture_output=True,
        text=True,
    ).stdout
    serials = set()
    for pem in re.findall(r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", found, re.S):
        output = subprocess.run(
            ["openssl", "x509", "-noout", "-serial"],
            input=pem,
            capture_output=True,
            text=True,
        ).stdout
        match = re.search(r"serial=([0-9A-Fa-f]+)", output)
        if match:
            serials.add(normalise(match.group(1)))
    return serials


def call(method: str, url: str, token: str):
    request = urllib.request.Request(url, method=method, headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(request, timeout=60) as response:
        body = response.read()
        return json.loads(body) if body else {}


def main() -> int:
    key_id = os.environ.get("ASC_KEY_ID", "")
    issuer_id = os.environ.get("ASC_ISSUER_ID", "")
    key_path = os.environ.get("ASC_KEY_PATH", "")
    if not (key_id and issuer_id and os.path.exists(key_path)):
        print("::warning::Certificate clean-up skipped: App Store Connect key not available")
        return 0

    serials = keychain_development_serials()
    if not serials:
        print("No Apple Development certificate in this machine's keychain; nothing to revoke.")
        return 0

    token = make_token(key_id, issuer_id, key_path)
    revoked = 0
    url = API + "/certificates?limit=200"
    while url:
        page = call("GET", url, token)
        for certificate in page.get("data", []):
            attributes = certificate.get("attributes", {})
            if attributes.get("certificateType") not in DEVELOPMENT_TYPES:
                continue
            if normalise(attributes.get("serialNumber", "")) not in serials:
                continue
            call("DELETE", API + "/certificates/" + certificate["id"], token)
            revoked += 1
            print("Revoked this build's development certificate: " + attributes.get("name", "(unnamed)"))
        url = page.get("links", {}).get("next")

    if revoked == 0:
        print("::warning::Found a development certificate in the keychain but no match on the account; nothing revoked")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except urllib.error.HTTPError as error:
        print("::warning::Certificate clean-up failed: HTTP %s %s" % (error.code, error.read().decode()[:300]))
    except Exception as error:  # Never fail the build over clean-up.
        print("::warning::Certificate clean-up failed: %s" % error)
