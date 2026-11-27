#!/usr/bin/env bash
#{{{
#  Conky NextGen Framework — Arch Linux Repository Publisher
#  Author: István Molnár <molnari811023@gmail.com>
#  Description: Collects the latest .pkg.tar.zst packages from pkg/,
#               builds the pacman repo database via repo-add, and pushes
#               to https://github.com/molnari811023/arch-repo (GitHub Pages).
#}}}
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_NAME="${ARCH_REPO_NAME:-molnar-repo}"
GH_REPO="${ARCH_GH_REPO:-molnari811023/arch-repo}"
GH_URL="https://github.com/${GH_REPO}.git"
PAGES_URL="https://molnari811023.github.io/arch-repo"
STAGE_DIR="/tmp/arch-repo-stage"

if ! command -v repo-add >/dev/null 2>&1; then
    echo "[error] 'repo-add' not found (install pacman)."
    exit 1
fi

# Pick the newest .pkg.tar.zst for each package base name
declare -A LATEST_PKG
while IFS= read -r -d '' pkgfile; do
    fname="$(basename "$pkgfile")"
    # Strip -<pkgver>-<pkgrel>-<arch>.pkg.tar.zst (e.g. conky-nextgen-git-1.1.0...-1-any.pkg.tar.zst)
    # Match known prefixes cleanly, fallback to stripping last 3 dash segments
    case "$fname" in
        conky-nextgen-git-*)   key="conky-nextgen-git" ;;
        conky-mng-*)           key="conky-mng" ;;
        python-pyicloud-*)     key="python-pyicloud" ;;
        googlefindmytools-git-*) key="googlefindmytools-git" ;;
        *)                     key="$(echo "$fname" | sed -E 's/-[^-]+-[^-]+-[^-]+\.pkg\.tar\.zst$//')" ;;
    esac
    # Keep newest by mtime
    if [ -z "${LATEST_PKG[$key]:-}" ] || [ "$pkgfile" -nt "${LATEST_PKG[$key]}" ]; then
        LATEST_PKG["$key"]="$pkgfile"
    fi
done < <(find "$SCRIPT_DIR" -maxdepth 2 -name "*.pkg.tar.zst" -print0)

if [ ${#LATEST_PKG[@]} -eq 0 ]; then
    echo "[error] No .pkg.tar.zst packages found under $SCRIPT_DIR"
    exit 1
fi

echo "==> Selected latest packages for [$REPO_NAME]:"
for k in $(printf '%s\n' "${!LATEST_PKG[@]}" | sort); do
    echo "    - $k: $(basename "${LATEST_PKG[$k]}")"
done

rm -rf "$STAGE_DIR"
if ! GIT_TERMINAL_PROMPT=0 git clone "$GH_URL" "$STAGE_DIR" 2>/dev/null; then
    mkdir -p "$STAGE_DIR"
    git -C "$STAGE_DIR" init -b main
    git -C "$STAGE_DIR" remote add origin "$GH_URL"
fi

mkdir -p "$STAGE_DIR/x86_64"
rm -f "$STAGE_DIR/x86_64"/*.pkg.tar.zst "$STAGE_DIR/x86_64"/*.db* "$STAGE_DIR/x86_64"/*.files*

for k in "${!LATEST_PKG[@]}"; do
    cp -f "${LATEST_PKG[$k]}" "$STAGE_DIR/x86_64/"
done

echo "==> Running repo-add for $REPO_NAME..."
(
    cd "$STAGE_DIR/x86_64"
    repo-add "${REPO_NAME}.db.tar.gz" *.pkg.tar.zst
    # GitHub Pages / static HTTP servers do not serve symlinks reliably as pacman expects
    rm -f "${REPO_NAME}.db" "${REPO_NAME}.files"
    cp -f "${REPO_NAME}.db.tar.gz" "${REPO_NAME}.db"
    cp -f "${REPO_NAME}.files.tar.gz" "${REPO_NAME}.files"
)

PKG_LIST_MD=""
PKG_LIST_HTML=""
for k in $(printf '%s\n' "${!LATEST_PKG[@]}" | sort); do
    fn="$(basename "${LATEST_PKG[$k]}")"
    PKG_LIST_MD+="- \`$fn\`"$'\n'
    PKG_LIST_HTML+="<li><code>${fn}</code></li>"$'\n'
done

cat > "$STAGE_DIR/README.md" << EOF
# $REPO_NAME — Personal Arch Linux Repository

Arch Linux \`pacman\` repository hosting packages for **Conky NextGen** and its companion tools.

## Setup (\`/etc/pacman.conf\`)

Add the following section to \`/etc/pacman.conf\`:

\`\`\`ini
[$REPO_NAME]
SigLevel = Optional TrustAll
Server = $PAGES_URL/\$arch
\`\`\`

Then refresh and install:

\`\`\`bash
sudo pacman -Sy
sudo pacman -S conky-nextgen-git conky-mng python-pyicloud googlefindmytools-git
\`\`\`

## Included Packages

$PKG_LIST_MD
EOF

cat > "$STAGE_DIR/index.html" << EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>$REPO_NAME — Arch Linux Repository</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 760px; margin: 2rem auto; padding: 0 1rem; background: #1e2227; color: #eceff4; }
    pre, code { background: #2b3038; padding: 0.15rem 0.35rem; border-radius: 4px; }
    pre { padding: 0.9rem; overflow-x: auto; }
    a { color: #56b6c2; }
  </style>
</head>
<body>
  <h1>$REPO_NAME — Arch Linux Repository</h1>
  <p>Add this to <code>/etc/pacman.conf</code>:</p>
  <pre>[$REPO_NAME]
SigLevel = Optional TrustAll
Server = $PAGES_URL/\$arch</pre>
  <h2>Packages</h2>
  <ul>
$PKG_LIST_HTML
  </ul>
</body>
</html>
EOF

# Ensure .nojekyll so GitHub Pages serves dotfiles/archives cleanly
touch "$STAGE_DIR/.nojekyll"

git -C "$STAGE_DIR" add -A
if git -C "$STAGE_DIR" diff --cached --quiet; then
    echo "==> No changes to publish."
else
    git -C "$STAGE_DIR" -c user.name="Molnár István" -c user.email="molnari811023@gmail.com" \
        commit -m "chore(repo): publish latest Arch packages ($(date +%Y-%m-%d))"
    GIT_TERMINAL_PROMPT=0 git -C "$STAGE_DIR" push -u origin main
    echo "==> Published to $GH_URL"
fi

rm -rf "$STAGE_DIR"
