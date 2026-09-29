#!/usr/bin/env python3
"""Prepare and submit a Pickr version for App Store review, from the API.

The web UI flow is about 20 clicks; this is one command. Order matters and is
enforced here: export compliance on the build, then the version, then whatsNew on
the localization ASC already copied from the previous version, then attach the
build, then submit.

Credentials: /root/.hermes/credentials/asc.env (ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH).
See skill: software-development/api-integration -> references/appstore-connect-api.md

Usage:
  asc-submit.py status
  asc-submit.py submit --version 1.2 --build 3 --whats-new-file /path/to/whats-new.md
  asc-submit.py submit ... --dry-run
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

import jwt

ENV_PATH = Path("/root/.hermes/credentials/asc.env")
BASE = "https://api.appstoreconnect.apple.com/v1"
APP_ID = "6761876281"  # fractals.pickr
PLATFORM = "MAC_OS"
TOKEN_TTL = 900


def load_env():
    cfg = {}
    if ENV_PATH.exists():
        for line in ENV_PATH.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip()
    for k in ("ASC_ISSUER_ID", "ASC_KEY_ID", "ASC_KEY_PATH"):
        if os.environ.get(k):
            cfg[k] = os.environ[k]
    return cfg


CFG = load_env()


def token():
    return jwt.encode(
        {
            "iss": CFG["ASC_ISSUER_ID"],
            "iat": int(time.time()),
            "exp": int(time.time()) + TOKEN_TTL,
            "aud": "appstoreconnect-v1",
        },
        key=Path(CFG["ASC_KEY_PATH"]).read_bytes(),
        algorithm="ES256",
        headers={"kid": CFG["ASC_KEY_ID"]},
    )


def api(method, path, body=None):
    """Call ASC. Returns (status, parsed json or error text)."""
    data = json.dumps(body).encode() if body is not None else None
    req = Request(
        BASE + path,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token()}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urlopen(req, timeout=60) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else None)
    except HTTPError as e:
        raw = e.read().decode(errors="replace")
        try:
            errs = json.loads(raw).get("errors", [])
            detail = "; ".join(
                f"{x.get('code')}: {x.get('title')} {x.get('detail', '')[:200]}" for x in errs
            )
        except Exception:  # noqa: BLE001
            detail = raw[:400]
        return e.code, detail


def die(msg):
    print(f"FAILED: {msg}")
    sys.exit(1)


def versions():
    status, res = api("GET", f"/apps/{APP_ID}/appStoreVersions?limit=20")
    if status != 200:
        die(f"listing versions: HTTP {status} {res}")
    return res["data"]


def builds_for(app_version):
    """Builds for a marketing version.

    Uses the top-level /builds endpoint with filter[app]; the relationship endpoint
    /apps/{id}/builds rejects both `sort` and filter[preReleaseVersion.version] with
    PARAMETER_ERROR.ILLEGAL, so the marketing version is matched client-side from the
    included preReleaseVersion instead.
    """
    status, res = api(
        "GET",
        f"/builds?filter[app]={APP_ID}&include=preReleaseVersion&limit=50&sort=-uploadedDate",
    )
    if status != 200:
        die(f"listing builds: HTTP {status} {res}")
    marketing = {i["id"]: i["attributes"].get("version") for i in res.get("included", [])}
    out = []
    for b in res["data"]:
        pre = (b.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}).get("id")
        if marketing.get(pre) == app_version:
            out.append(b)
    return out


def cmd_status(_args):
    print("== versions ==")
    for v in versions():
        a = v["attributes"]
        print(f"  {a['versionString']:<8} {a['appStoreState']:<24} created {a['createdDate'][:10]}  id {v['id']}")
    latest = versions()[0]["attributes"]["versionString"]
    print(f"== builds for {latest} ==")
    for b in builds_for(latest):
        a = b["attributes"]
        print(
            f"  build {a['version']:<5} {a['processingState']:<12} "
            f"expired={a.get('expired')} uploaded {a.get('uploadedDate', '')[:19]}  id {b['id']}"
        )
    print(f"== review submissions ==")
    status, res = api("GET", f"/apps/{APP_ID}/reviewSubmissions?limit=5")
    if status == 200:
        for s in res["data"]:
            a = s["attributes"]
            print(f"  {a.get('state')}  submitted {a.get('submittedDate')}  id {s['id']}")


def cmd_submit(args):
    dry = args.dry_run
    target = args.version
    build_number = str(args.build)
    whats_new = Path(args.whats_new_file).read_text().strip()
    if not whats_new:
        die("whats-new file is empty; ASC rejects an update without whatsNew")

    # --- 1. the version, created if it is not there yet -------------------------
    existing = {v["attributes"]["versionString"]: v for v in versions()}
    if target in existing:
        version = existing[target]
        print(f"version {target} already exists ({version['attributes']['appStoreState']})")
    else:
        # copyright and releaseType come from the last version, so this cannot drift
        prior = existing[max(existing, key=lambda s: [int(p) for p in s.split(".")])]
        prior_attrs = prior["attributes"]
        body = {
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "platform": PLATFORM,
                    "versionString": target,
                    "copyright": prior_attrs.get("copyright", ""),
                    "releaseType": "AFTER_APPROVAL",
                },
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }
        }
        if dry:
            print(f"[dry-run] would create version {target} (copyright {prior_attrs.get('copyright', '')!r})")
            version = None
        else:
            status, res = api("POST", "/appStoreVersions", body)
            if status not in (200, 201):
                die(f"creating version {target}: HTTP {status} {res}")
            version = res["data"]
            print(f"created version {target}: {version['id']}")
    version_id = version["id"] if version else None

    # --- 2. whatsNew on the localization ASC copied from the previous version ----
    if not dry:
        status, res = api("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")
        if status != 200:
            die(f"reading localizations: HTTP {status} {res}")
        locs = res["data"]
        if not locs:
            die("no localization was copied from the previous version; en-US must exist before patching whatsNew")
        loc = next((l for l in locs if l["attributes"].get("locale") == "en-US"), locs[0])
        print(f"localization {loc['attributes']['locale']}: {loc['attributes'].get('whatsNew') or '(no whatsNew yet)'}")
        status, res = api(
            "PATCH",
            f"/appStoreVersionLocalizations/{loc['id']}",
            {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {"whatsNew": whats_new}}},
        )
        if status != 200:
            die(f"patching whatsNew: HTTP {status} {res}")
        print("whatsNew set")

    # --- 3. the build: export compliance, then attach ---------------------------
    candidates = builds_for(target)
    valid = [b for b in candidates if b["attributes"].get("processingState") == "VALID"]
    if not valid:
        states = ", ".join(
            f"{b['attributes']['version']}={b['attributes'].get('processingState')}" for b in candidates
        )
        die(f"no VALID build for {target} yet (seen: {states or 'none'}). Apple may still be processing the upload")
    build = next((b for b in valid if b["attributes"]["version"] == build_number), None)
    if build is None:
        die(f"no VALID build {build_number} for {target}; found {[b['attributes']['version'] for b in valid]}")
    build_id = build["id"]
    print(
        f"build {build_number} is VALID (id {build_id}, "
        f"usesNonExemptEncryption={build['attributes'].get('usesNonExemptEncryption')})"
    )

    if dry:
        print(f"[dry-run] would set export compliance on build {build_id}")
        print(f"[dry-run] would attach build {build_id} to version {version_id}")
        print("[dry-run] would submit for review")
        return

    if build["attributes"].get("usesNonExemptEncryption") is None:
        status, res = api(
            "PATCH",
            f"/builds/{build_id}",
            {"data": {"type": "builds", "id": build_id, "attributes": {"usesNonExemptEncryption": False}}},
        )
        if status != 200:
            die(f"setting export compliance: HTTP {status} {res}")
        print("export compliance answered: no non-exempt encryption")
    else:
        print("export compliance already answered")

    status, res = api(
        "PATCH",
        f"/appStoreVersions/{version_id}/relationships/build",
        {"data": {"type": "builds", "id": build_id}},
    )
    if status != 204:
        die(f"attaching build: HTTP {status} {res}")
    print(f"build {build_number} attached to {target}")

    # --- 4. submit ---------------------------------------------------------------
    status, res = api(
        "POST",
        "/reviewSubmissions",
        {
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": PLATFORM},
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }
        },
    )
    if status not in (200, 201):
        die(f"creating review submission: HTTP {status} {res}")
    sub_id = res["data"]["id"]
    print(f"review submission created: {sub_id}")

    status, res = api(
        "POST",
        "/reviewSubmissionItems",
        {
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                },
            }
        },
    )
    if status not in (200, 201):
        die(f"adding review item: HTTP {status} {res}")
    print("version added to the submission")

    status, res = api(
        "PATCH",
        f"/reviewSubmissions/{sub_id}",
        {"data": {"type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}},
    )
    if status != 200:
        die(f"submitting: HTTP {status} {res}")

    # --- 5. verify from the API, not from the response we just got ---------------
    status, res = api("GET", f"/reviewSubmissions/{sub_id}")
    sub_state = res["data"]["attributes"].get("state") if status == 200 else "?"
    status, res = api("GET", f"/appStoreVersions/{version_id}")
    ver_state = res["data"]["attributes"].get("appStoreState") if status == 200 else "?"
    print(f"\nsubmission state: {sub_state}")
    print(f"version state:    {ver_state}")
    if ver_state not in ("WAITING_FOR_REVIEW", "IN_REVIEW", "READY_FOR_SALE", "PENDING_DEVELOPER_RELEASE"):
        die(f"version did not reach a submitted state (got {ver_state})")
    print(f"\nPickr {target} (build {build_number}) is submitted.")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status").set_defaults(func=cmd_status)
    s = sub.add_parser("submit")
    s.add_argument("--version", required=True, help="marketing version, e.g. 1.2")
    s.add_argument("--build", required=True, help="CFBundleVersion of the uploaded build")
    s.add_argument("--whats-new-file", required=True)
    s.add_argument("--dry-run", action="store_true")
    s.set_defaults(func=cmd_submit)
    args = p.parse_args()
    if not CFG.get("ASC_ISSUER_ID") or not CFG.get("ASC_KEY_PATH"):
        die(f"credentials incomplete in {ENV_PATH}")
    args.func(args)


if __name__ == "__main__":
    main()
