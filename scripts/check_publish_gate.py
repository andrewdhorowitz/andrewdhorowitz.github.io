#!/usr/bin/env python3
"""Publish gate — fail the build if a page links a declared-private host.

Reads every publish manifest in the fleet-kit registry copy
(publish-registry/*.json), builds the denylist from each manifest's
`private_hosts`, and scans the portfolio's HTML for hrefs to them.
A private host may be declared as a bare host (matches that host
exactly) or as a URL prefix (matches hrefs starting with it).

This checks PERMISSION, not liveness — the Lychee job already checks
that links resolve; a gated live URL resolves fine and must still
never be linked. (Spec: PUBLISH-MANIFEST-SPEC §4, fleet records.)

Usage:
    check_publish_gate.py --registry <dir> [--root <dir>]

Exit 0: no violations. Exit 1: at least one violation (each printed
with its page, href, and the manifest that forbids it).
"""

import argparse
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

HREF_RE = re.compile(r"""href\s*=\s*["']([^"']+)["']""", re.I)


def load_denylist(registry_dir):
    entries = []  # (host, prefix_or_none, project, repo_file)
    manifests = sorted(Path(registry_dir).glob("*.json"))
    if not manifests:
        raise SystemExit(f"no manifests found in {registry_dir}")
    for path in manifests:
        if path.name == "publish.schema.json":
            continue
        doc = json.loads(path.read_text())
        for raw in doc.get("private_hosts") or []:
            if "://" in raw:
                parsed = urlparse(raw)
                entries.append((parsed.netloc, raw.rstrip("/"), doc["project"], path.name))
            else:
                entries.append((raw, None, doc["project"], path.name))
    return entries


def denied(href, entries):
    try:
        parsed = urlparse(href)
    except ValueError:
        return None
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        return None
    for host, prefix, project, source in entries:
        if prefix is not None:
            if href.rstrip("/") == prefix or href.startswith(prefix + "/"):
                return (project, source)
        elif parsed.netloc == host:
            return (project, source)
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--registry", required=True, help="dir of registry manifests")
    ap.add_argument("--root", default=".", help="dir of built HTML to scan")
    args = ap.parse_args()

    entries = load_denylist(args.registry)
    pages = sorted(Path(args.root).rglob("*.html"))
    violations = []
    checked = 0
    for page in pages:
        text = page.read_text(encoding="utf-8", errors="replace")
        for href in HREF_RE.findall(text):
            checked += 1
            hit = denied(href, entries)
            if hit:
                violations.append((str(page), href, hit[0], hit[1]))
    for page, href, project, source in violations:
        print(f"VIOLATION {page}: href {href!r} is forbidden by {project} ({source})")
    if violations:
        print(f"publish gate: FAIL — {len(violations)} forbidden link(s)")
        return 1
    hosts = sorted({h for h, _, _, _ in entries})
    print(
        f"publish gate: PASS — {checked} hrefs across {len(pages)} pages, "
        f"none to the {len(hosts)} declared-private host(s): {', '.join(hosts)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
