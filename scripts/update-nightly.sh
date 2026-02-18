#!/usr/bin/env bash
set -euo pipefail

repo="jpenilla/ghostty-nightly-bin"
release_tag="nightly"

api_url="https://api.github.com/repos/${repo}/releases/tags/${release_tag}"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

json="$tmpdir/release.json"

curl -fsSL "$api_url" -o "$json"

version_url=$(python3 - "$json" <<'PY'
import json,sys
path=sys.argv[1]
with open(path,"r",encoding="utf-8") as f:
  data=json.load(f)
for a in data.get("assets",[]):
  if a.get("name") == "ghostty-nightly-version.txt":
    print(a.get("browser_download_url"))
    break
PY
)

if [[ -z "${version_url}" ]]; then
  echo "error: ghostty-nightly-version.txt not found in release assets" >&2
  exit 1
fi

pkgver=$(curl -fsSL "$version_url" | tr -d '\n' | tr -d '\r')

current_pkgver=$(awk -F= '/^pkgver=/{print $2}' PKGBUILD)
current_pkgrel=$(awk -F= '/^pkgrel=/{print $2}' PKGBUILD)
if [[ -z "${current_pkgrel:-}" || ! "$current_pkgrel" =~ ^[0-9]+$ ]]; then
  current_pkgrel=0
fi

if [[ "$pkgver" == "$current_pkgver" ]]; then
  pkgrel=$((current_pkgrel + 1))
else
  pkgrel=1
fi

assets=(
  ghostty-nightly-bin-x86_64.tar.zst
  ghostty-terminfo-nightly-bin-x86_64.tar.zst
  ghostty-shell-integration-nightly-bin-x86_64.tar.zst
)

sha256sums=()
sha_cmd=sha256sum
if ! command -v sha256sum >/dev/null 2>&1; then
  sha_cmd="shasum -a 256"
fi
for asset in "${assets[@]}"; do
  url="https://github.com/${repo}/releases/download/${release_tag}/${asset}"
  curl -fsSL "$url" -o "$tmpdir/$asset"
  sha256sums+=("$($sha_cmd "$tmpdir/$asset" | awk '{print $1}')")
done

awk -v pkgver="$pkgver" \
    -v pkgrel="$pkgrel" \
    -v s1="${sha256sums[0]}" \
    -v s2="${sha256sums[1]}" \
    -v s3="${sha256sums[2]}" \
'BEGIN{changed=0}
/^pkgver=/{print "pkgver=" pkgver; changed=1; next}
/^pkgrel=/{print "pkgrel=" pkgrel; changed=1; next}
/^sha256sums=\(/{print; getline; print "  '\''" s1 "'\''"; getline; print "  '\''" s2 "'\''"; getline; print "  '\''" s3 "'\''"; while(getline){ if($0 ~ /\)/){print; break;} } changed=1; next}
{print}
END{if(!changed) exit 2}
' PKGBUILD > "$tmpdir/PKGBUILD"

mv "$tmpdir/PKGBUILD" PKGBUILD

if command -v makepkg >/dev/null 2>&1; then
  makepkg --printsrcinfo > .SRCINFO
else
  echo "warn: makepkg not found; .SRCINFO not updated" >&2
fi
