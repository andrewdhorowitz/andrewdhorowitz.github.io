#!/usr/bin/env python3
"""Generate projects-data.js for the public showcase by PULLING each
card project's publish.json from its own repo (one project = one
repo, Andrew's rule, Oct 29, 2026) and deriving its freshness badge
with fleet-kit's ONE derivation function (scripts/publish_view.py).

Why this exists: the public page is one static index.html with no
build step, so its cards cannot compute anything at serve time.
The freshness badges (Publish Properties' derived display data) are
therefore produced here, into a small generated data include the
page loads: `projects-data.js` maps card id -> the raw badge value
fleet-kit's derivation computed from the project's own manifest
(release_state + first_released/last_released against the
generation date). CI regenerates the file daily (the workflow
.github/workflows/generate-public.yml) and on relevant pushes, so
badges appear and expire on their own — nobody hand-types a badge
or removes a stale "New" by hand. The page's inline script only
maps a raw value to its display label and pill tone; whether a
badge exists is never decided in the page.

Cards are THIS display's own choices — the card-id -> repo mapping
below lives here, exactly as the private section's generator keeps
its own repo list; everything displayed about a project comes from
that project's own repo. The four featured-project cards are:

- routines-and-streaks -> routines-and-streaks (the card IS that
  project: its links are the app and its repo)
- aimf -> aimf-protocol (the card's links are the AIMF site/repo)
- family-cards -> family-cards-demo: the public card's own links
  (Live demo, Repository) are the DEMO project's surfaces — it is
  the demo's card. The live Family Cards project is private-tier
  (Tier=Private, Sanitized=None) and is never rendered on the
  public page.
- this-website -> andrewdhorowitz.github.io (the site itself)

fleet-kit and repo-template carry no card on the public page, so
they get no entry here (fleet-kit is public-tier but simply not
carded; repo-template is private-tier and must not be surfaced).

FAIL-CLOSED inclusion: a card earns an entry only when the derived
view passes publish_view.public_facing() — Tier=Public AND
Sanitized=True from a FRESH sanitize-overlay result (the overlay's
recorded manifest SHA must equal the manifest SHA just pulled; a
stale or missing result derives Sanitized=None and excludes the
card, with the reason printed). A gate FAIL excludes the card the
same way, with the gate's quoted matches printed — the exclusion is
loud in the generation log, never silent. The overlay is fleet-kit's
GENERATED publish-registry/sanitize-overlay.json, pulled at
generation time like the derivation module; neither is copied here,
so no second derivation and no stale gate copy can drift in.

Auth: every input is a public repo (the four card projects,
fleet-kit), pulled unauthenticated; a token (FLEET_PULL_TOKEN or
GITHUB_TOKEN) is used when present only to raise the API rate
limit. This public repo's CI never needs to read a private repo —
the same property the publish gate is built on.
"""

import base64
import json
import os
import sys
import types
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
API = "https://api.github.com"
OWNER_ACCOUNT = "andrewdhorowitz"

# card id (index.html's data-card-id) -> the repo whose publish.json
# the card speaks for. This display's own choices; see the docstring.
CARDS = [
    ("routines-and-streaks", "routines-and-streaks"),
    ("aimf", "aimf-protocol"),
    ("family-cards", "family-cards-demo"),
    ("this-website", "andrewdhorowitz.github.io"),
]


def fetch_json(url, token):
    """(status, parsed body or None). Factored so tests and local
    drivers can substitute an authenticated transport."""
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            **({"Authorization": f"Bearer {token}"} if token else {}),
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, None


def pull_manifest(repo_slug, token):
    """Fetch one project's publish.json from its own repo.
    Returns (manifest, manifest_blob_sha)."""
    status, doc = fetch_json(
        f"{API}/repos/{OWNER_ACCOUNT}/{repo_slug}/contents/publish.json", token
    )
    if status != 200 or not doc or not doc.get("content"):
        raise SystemExit(
            f"pull failed for {repo_slug}: publish.json HTTP {status}. "
            "Every fleet project carries its manifest at its repo root."
        )
    try:
        manifest = json.loads(base64.b64decode(doc["content"]))
    except Exception as e:
        raise SystemExit(f"pull failed for {repo_slug}: manifest unparsable: {e}")
    return manifest, doc["sha"]


def pull_overlay(token):
    """fleet-kit's GENERATED sanitize-overlay.json.
    Returns (overlay, overlay_blob_sha). A missing overlay is a loud
    stop, not a silent pass: without a gate result no card can prove
    Sanitized=True, so nothing may render."""
    status, doc = fetch_json(
        f"{API}/repos/{OWNER_ACCOUNT}/fleet-kit/contents/"
        "publish-registry/sanitize-overlay.json",
        token,
    )
    if status != 200 or not doc or not doc.get("content"):
        raise SystemExit(
            f"sanitize overlay unavailable (HTTP {status}); refusing to "
            "generate — a public badge requires a gate result."
        )
    try:
        return json.loads(base64.b64decode(doc["content"])), doc["sha"]
    except Exception as e:
        raise SystemExit(f"sanitize overlay unparsable ({e}); refusing to generate")


def pull_publish_view(token):
    """fleet-kit's derivation module, scripts/publish_view.py — the
    fleet's ONE derivation function. Pulled (never copied) so the
    badges are computed by the same code every consumer reads.
    Unlike display-only pulls elsewhere this one is NOT fail-soft:
    without the derivation there is nothing legitimate to emit."""
    status, doc = fetch_json(
        f"{API}/repos/{OWNER_ACCOUNT}/fleet-kit/contents/scripts/publish_view.py",
        token,
    )
    if status != 200 or not doc or not doc.get("content"):
        raise SystemExit(
            f"publish_view.py unavailable (HTTP {status}); refusing to "
            "generate — badges are never derived by a second implementation."
        )
    try:
        source = base64.b64decode(doc["content"]).decode()
        module = types.ModuleType("publish_view")
        # The module resolves its own path at import time (for the
        # schema/overlay loaders, which this consumer never calls);
        # give it the path it holds in its own repo.
        module.__file__ = "/fleet-kit/scripts/publish_view.py"
        exec(compile(source, "publish_view.py (fleet-kit)", "exec"), module.__dict__)
        if not callable(getattr(module, "derive", None)):
            raise AttributeError("module has no derive()")
        if not callable(getattr(module, "public_facing", None)):
            raise AttributeError("module has no public_facing()")
    except Exception as e:
        raise SystemExit(f"publish_view.py unusable ({e}); refusing to generate")
    return module, doc["sha"]


def main():
    token = os.environ.get("FLEET_PULL_TOKEN") or os.environ.get("GITHUB_TOKEN")
    publish_view, publish_view_sha = pull_publish_view(token)
    overlay, overlay_sha = pull_overlay(token)
    overlay_entries = (overlay or {}).get("entries") or {}

    badges = {}
    sources = []
    for card_id, repo_slug in CARDS:
        manifest, sha = pull_manifest(repo_slug, token)
        view, warnings = publish_view.derive(
            manifest, overlay_entries.get(repo_slug), sha
        )
        for warning in warnings:
            print(f"warning: {repo_slug}: {warning}")
        if not publish_view.public_facing(view):
            print(
                f"EXCLUDED {card_id} ({repo_slug}): not public-facing — "
                f"Tier={view['Tier']} Sanitized={view['Sanitized']}; "
                "no badge is emitted for this card."
            )
            ov = overlay_entries.get(repo_slug) or {}
            if ov.get("status") == "fail":
                print(
                    f"  sanitization gate FAIL for {repo_slug} "
                    f"({manifest.get('project')}):"
                )
                for m in ov.get("matches") or []:
                    print(f"    {m['file']}:{m['line']}  [{m['label']}]  …{m['quote']}…")
            continue
        sources.append(f"{repo_slug}@{sha[:8]}")
        if view["Freshness"]:
            badges[card_id] = view["Freshness"]
            print(f"badge {card_id} ({repo_slug}): {view['Freshness']}")
        else:
            print(f"no badge {card_id} ({repo_slug}): Freshness=None")

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out = (
        "// GENERATED by scripts/generate_public.py — do not edit by hand.\n"
        "// Each badge was derived by fleet-kit's ONE derivation function\n"
        "// (scripts/publish_view.py) from the card project's own\n"
        "// publish.json, fail-closed: a card appears here only at\n"
        "// Tier=Public with a fresh Sanitized=True gate result.\n"
        f"// Sources: {', '.join(sources)}\n"
        f"// Sanitize overlay: fleet-kit sanitize-overlay.json@"
        f"{overlay_sha[:8]}, generated {overlay.get('generated_at')}\n"
        f"// Freshness: fleet-kit scripts/publish_view.py@"
        f"{publish_view_sha[:8]} vs the generation date {today} (UTC);\n"
        "// CI regenerates this file daily, so badges expire on their own.\n"
        f"window.PUBLIC_CARD_BADGES = {json.dumps(badges, indent=2, sort_keys=True)};\n"
    )
    (HERE / "projects-data.js").write_text(out)
    print(f"projects-data.js: {len(badges)} badge(s) for {len(CARDS)} cards")


if __name__ == "__main__":
    main()
