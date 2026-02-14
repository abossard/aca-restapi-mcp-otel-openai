#!/usr/bin/env python3
"""
End-to-end Azure AI Search verification.

What this verifies:
1) Entra ID auth works for data-plane calls (DefaultAzureCredential)
2) The configured index exists and accepts writes
3) Full-text search can retrieve newly indexed content
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
import uuid

from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient


def _load_azd_env() -> None:
    """Best-effort load of azd environment values into process env."""
    if not shutil_which("azd"):
        return
    try:
        proc = subprocess.run(
            ["azd", "env", "get-values"],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return

    if proc.returncode != 0:
        return

    for line in proc.stdout.splitlines():
        if "=" not in line:
            continue
        key, raw = line.split("=", 1)
        value = raw.strip()
        if value.startswith('"') and value.endswith('"') and len(value) >= 2:
            value = value[1:-1]
        if key and value and key not in os.environ:
            os.environ[key] = value


def shutil_which(cmd: str) -> str | None:
    for path in os.environ.get("PATH", "").split(os.pathsep):
        full = os.path.join(path, cmd)
        if os.path.isfile(full) and os.access(full, os.X_OK):
            return full
    return None


def _require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify Azure AI Search end-to-end.")
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=120,
        help="Max wait time for query visibility after upload (default: 120).",
    )
    parser.add_argument(
        "--poll-seconds",
        type=int,
        default=5,
        help="Polling interval while waiting for search visibility (default: 5).",
    )
    parser.add_argument(
        "--keep-document",
        action="store_true",
        help="Do not delete the test document at the end.",
    )
    args = parser.parse_args()

    _load_azd_env()

    endpoint = _require_env("AZURE_SEARCH_ENDPOINT")
    index_name = _require_env("AZURE_SEARCH_INDEX")

    run_id = uuid.uuid4().hex[:12]
    chunk_id = f"e2e-{run_id}"
    marker = f"e2e-marker-{run_id}"
    doc = {
        "chunk_id": chunk_id,
        "parent_id": f"parent-{run_id}",
        "title": f"E2E Search Probe {run_id}",
        "content": f"This is an end-to-end search probe. Marker: {marker}",
        "source": "e2e://scripts/e2e_verify_search.py",
    }

    credential = DefaultAzureCredential()
    client = SearchClient(endpoint=endpoint, index_name=index_name, credential=credential)

    print(f"[e2e] endpoint={endpoint}")
    print(f"[e2e] index={index_name}")
    print(f"[e2e] uploading chunk_id={chunk_id}")

    try:
        upload_results = client.upload_documents(documents=[doc])
        if not upload_results or not upload_results[0].succeeded:
            raise RuntimeError(f"Upload failed: {upload_results}")

        deadline = time.monotonic() + args.timeout_seconds
        found = False
        while time.monotonic() < deadline:
            results = client.search(search_text=marker, top=5, select=["chunk_id", "title", "content"])
            for row in results:
                if row.get("chunk_id") == chunk_id:
                    found = True
                    break
            if found:
                break
            print(f"[e2e] not visible yet, retrying in {args.poll_seconds}s...")
            time.sleep(args.poll_seconds)

        if not found:
            raise RuntimeError(
                f"Document {chunk_id} was not found by search within {args.timeout_seconds}s."
            )

        print("[e2e] success: document is searchable")
        return 0
    finally:
        if not args.keep_document:
            try:
                client.delete_documents(documents=[{"chunk_id": chunk_id}])
                print(f"[e2e] cleanup: deleted {chunk_id}")
            except Exception as cleanup_error:
                print(f"[e2e] cleanup warning: {cleanup_error}", file=sys.stderr)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[e2e] failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
