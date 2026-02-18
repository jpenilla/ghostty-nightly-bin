#!/usr/bin/env python3
import json
import sys

ASSET_NAME = "ghostty-nightly-version.txt"


def main() -> int:
    raw = sys.stdin.read()
    if not raw.strip():
        print("empty JSON input", file=sys.stderr)
        return 1

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        print("invalid JSON input", file=sys.stderr)
        return 1

    for asset in data.get("assets", []):
        if asset.get("name") == ASSET_NAME:
            url = asset.get("browser_download_url")
            if url:
                print(url)
            break

    return 0


if __name__ == "__main__":
    sys.exit(main())
