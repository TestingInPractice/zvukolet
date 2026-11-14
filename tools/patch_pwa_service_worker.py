#!/usr/bin/env python3
"""Patch the Godot-exported PWA service worker so the app runs offline after a single online visit.

Godot's generated ``index.service.worker.js`` precaches only the small files on install and
caches ``index.wasm`` / ``index.pck`` on first fetch. Because it never calls
``clients.claim()`` during activate, the very first page load is not controlled by the worker,
so the large files are never cached on visit one and an offline reload shows the
"You are offline" page.

This patch appends two extra listeners (idempotently, guarded by a marker comment):

* ``install``: ``skipWaiting()`` so the new worker activates immediately.
* ``activate``: ``clients.claim()`` plus backfilling ``CACHEABLE_FILES`` (``index.wasm`` /
  ``index.pck``) into the cache, so a single online visit is enough for offline use.

The backfill fetch usually hits the HTTP cache (the page already downloaded the large files),
so it does not double the network transfer.

Usage::

    python3 tools/patch_pwa_service_worker.py <path-to-index.service.worker.js>
"""

import sys
from pathlib import Path

MARKER = "zvukolet-pwa-patch"

PATCH = """
// {marker}: make the app work offline after a single online visit.
self.addEventListener('install', () => {{ self.skipWaiting(); }});
self.addEventListener('activate', (event) => {{
	event.waitUntil(self.clients.claim().then(() => caches.open(CACHE_NAME).then((cache) =>
		Promise.all(CACHEABLE_FILES.map((name) => cache.match(name).then((hit) => hit ? null : cache.add(name).catch(() => null))))
	)));
}});
""".format(marker=MARKER)


def patch_file(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    if MARKER in text:
        return "already-patched"
    if "CACHEABLE_FILES" not in text or "CACHE_NAME" not in text:
        raise SystemExit(f"unexpected service worker format: {path}")
    path.write_text(text.rstrip("\n") + "\n" + PATCH, encoding="utf-8")
    return "patched"


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch_pwa_service_worker.py <index.service.worker.js>")
    path = Path(sys.argv[1])
    if not path.is_file():
        raise SystemExit(f"not found: {path}")
    result = patch_file(path)
    print(f"{result}: {path}")


if __name__ == "__main__":
    main()
