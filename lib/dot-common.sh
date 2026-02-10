#!/usr/bin/env bash
set -euo pipefail

# ---- USER CONFIG (override via env vars if you want) ----
DOT_REPO="${DOT_REPO:-/Users/patrickgunerud/repos/github/PatrickGunerud/patrick.my.dotfiles}"
DOT_MANIFEST="${DOT_MANIFEST:-$HOME/.dotfiles-manifest}"
DOT_STORE_DIR="${DOT_STORE_DIR:-$DOT_REPO/managed}"   # where files are copied inside repo
DOT_BACKUP_DIR="${DOT_BACKUP_DIR:-$HOME/.dotfiles-backups}"
# --------------------------------------------------------

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_dir() { [[ -d "$1" ]] || die "Missing dir: $1"; }

ensure_manifest() {
  if [[ ! -f "$DOT_MANIFEST" ]]; then
    cat >&2 <<EOM
ERROR: Dotfiles manifest not found: $DOT_MANIFEST

Why this matters:
  These tools read the manifest to know which files to back up/restore.

How to fix:
  cat > "$DOT_MANIFEST" <<'EOF'
  ~/.gitconfig
  ~/.ssh/*.pub
  ~/.vscode/extensions.json
  ~/.vscode/settings.json
  ~/.zshrc
  EOF

Then run:
  dot-backup --commit
EOM
    exit 2
  fi
}

# Correct tilde expansion:
# - Only expands leading "~" or "~/"
# Robust expand_path: handles leading ~, ~/..., and accidental $HOME/~/... artifacts.
expand_path() {
  local p="$1"

  # 1) Expand a leading tilde:
  case "$p" in
    "~")    p="$HOME" ;;
    "~/"*)  p="$HOME/${p#~/}" ;;
  esac

  # 2) Normalize the common broken form "$HOME/~/..." -> "$HOME/..."
  #    e.g. "/Users/me/~/.gitconfig"  -> "/Users/me/.gitconfig"
  # Note: use prefix replacement so only the leading "$HOME/~/" is affected.
  p="${p/#$HOME\/~\//$HOME/}"   # if it starts with "$HOME/~/", remove that extra "~/"
  p="${p/#$HOME\/~/$HOME}"      # handle the edge of "$HOME/~" with no trailing slash

  printf '%s\n' "$p"
}



ensure_repo() {
  need_dir "$DOT_REPO"
  need_dir "$DOT_REPO/.git"
  mkdir -p "$DOT_STORE_DIR"
  mkdir -p "$DOT_BACKUP_DIR"
}

repo_target_for() {
  local abs="$1"
  if [[ "$abs" == "$HOME"* ]]; then
    printf '%s\n' "$DOT_STORE_DIR/home${abs#"$HOME"}"
  else
    printf '%s\n' "$DOT_STORE_DIR/abs${abs}"
  fi
}

# Reads ~/.dotfiles-manifest, expands globs, prints one absolute path per line.
# If a glob matches nothing, prints the literal path so callers can report missing.
read_manifest_expanded() {
  ensure_manifest

  while IFS= read -r raw; do
    # trim whitespace
    raw="${raw#"${raw%%[![:space:]]*}"}"
    raw="${raw%"${raw##*[![:space:]]}"}"
    [[ -z "$raw" ]] && continue
    [[ "$raw" == \#* ]] && continue

    local p
    p="$(expand_path "$raw")"

    shopt -s nullglob
    local matches=($p)
    shopt -u nullglob

    if [[ ${#matches[@]} -gt 0 ]]; then
      for m in "${matches[@]}"; do
        printf '%s\n' "$m"
      done
    else
      printf '%s\n' "$p"
    fi
  done < "$DOT_MANIFEST"
}

sha256_of() {
  shasum -a 256 "$1" | awk '{print $1}'
}

# Safety belt: never touch SSH private keys.
is_ssh_private_key() {
  local abs="$1"
  [[ "$abs" == "$HOME/.ssh/id_"* && "$abs" != *.pub ]]
}
