#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.request


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        print(f"missing {name}", file=sys.stderr)
        sys.exit(2)
    return value


def main() -> int:
    token = require_env("GH_TOKEN")
    run_id = require_env("RUN_ID")
    repo = require_env("REPO")

    retries = int(os.environ.get("RETRIES", "10"))
    interval = int(os.environ.get("INTERVAL_SECONDS", "6"))

    api_url = f"https://api.github.com/repos/{repo}/actions/runs/{run_id}/artifacts"

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "ghostty-nightly-bin",
    }

    for _ in range(retries):
        req = urllib.request.Request(api_url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
        except Exception:
            raw = ""

        if raw:
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                data = {}
            for a in data.get("artifacts", []):
                if a.get("name") == "build-info" and not a.get("expired", False):
                    url = a.get("archive_download_url")
                    if url:
                        print(url)
                        return 0
                    break

        time.sleep(interval)

    print(f"build-info artifact not found for run {run_id}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
