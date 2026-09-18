#!/usr/bin/env bash
set -euo pipefail

repo="jpenilla/ghostty-nightly-bin"
release_tag="nightly"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

version_url="https://github.com/${repo}/releases/download/${release_tag}/ghostty-nightly-version.txt"

curl -fsSL --retry 3 --retry-all-errors "$version_url" -o "$tmpdir/version.txt"
pkgver=$(tr -d '\n\r' < "$tmpdir/version.txt")

if [[ -z "${pkgver}" ]]; then
  echo "error: could not determine nightly version" >&2
  exit 1
fi

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
  curl -fsSL --retry 3 --retry-all-errors "$url" -o "$tmpdir/$asset"
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
