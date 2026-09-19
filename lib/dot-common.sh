#!/usr/bin/env bash
# Shared library for the dot-* family (LINK-ONLY model).
#
# Model: the dotfiles repo is the SOURCE OF TRUTH. Each managed file lives at
# managed/home/<path> and $HOME/<path> is a SYMLINK to it. Editing the live
# file edits the repo file (same inode). "Backup" = verify links + secret scan
# + commit + push. There is no copy-out step.
#
# Sourced-only by dot-backup/restore/status/verify/bootstrap via
# "$HOME/bin/lib/dot-common.sh". Not meant to run directly.
set -euo pipefail

# ---- USER CONFIG (override via env vars if you want) ----
DOT_REPO="${DOT_REPO:-/Users/patrickgunerud/repos/github/PatrickGunerud/patrick.my.dotfiles}"
DOT_MANIFEST="${DOT_MANIFEST:-$HOME/.dotfiles-manifest}"
DOT_STORE_DIR="${DOT_STORE_DIR:-$DOT_REPO/managed}"      # repo content root
DOT_HOME_DIR="${DOT_HOME_DIR:-$DOT_STORE_DIR/home}"      # managed/home == $HOME mirror
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
  These tools read the manifest to know which files are managed (link mode).

How to fix (one path per line; optional leading mode token, default "link"):
  cat > "$DOT_MANIFEST" <<'EOF'
  ~/.zshrc
  ~/.gitconfig
  ~/.ssh/*.pub
  EOF

Then run:
  dot-restore --dry-run
EOM
    exit 2
  fi
  # Validate modes in the MAIN shell so a bad mode token aborts the whole
  # command (a die() inside a <(...) process substitution would only kill the
  # subshell, letting callers run on a partial manifest — that is a footgun).
  read_manifest_patterns >/dev/null
}

# Robust expand_path: handles leading ~, ~/..., and accidental $HOME/~/... artifacts.
expand_path() {
  local p="$1"
  # Patterns below match a LITERAL leading tilde from the manifest, not shell
  # tilde-expansion, so SC2088 is a false positive here.
  # shellcheck disable=SC2088
  case "$p" in
    "~")    p="$HOME" ;;
    "~/"*)  p="$HOME/${p#~/}" ;;
  esac
  p="${p/#$HOME\/~\//$HOME/}"
  p="${p/#$HOME\/~/$HOME}"
  printf '%s\n' "$p"
}

ensure_repo() {
  need_dir "$DOT_REPO"
  need_dir "$DOT_REPO/.git"
  mkdir -p "$DOT_STORE_DIR"
  mkdir -p "$DOT_HOME_DIR"
  mkdir -p "$DOT_BACKUP_DIR"
}

# $HOME/x  -> managed/home/x ; other abs path -> managed/abs/<path>
repo_target_for() {
  local abs="$1"
  if [[ "$abs" == "$HOME"* ]]; then
    printf '%s\n' "$DOT_HOME_DIR${abs#"$HOME"}"
  else
    printf '%s\n' "$DOT_STORE_DIR/abs${abs}"
  fi
}

sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }

# Emit "mode<TAB>pattern" per manifest line (tilde-expanded, GLOB NOT expanded).
# Optional leading mode token; default "link"; any other mode is a hard error.
read_manifest_patterns() {
  # NOTE: callers must have run ensure_manifest first (guarantees the file
  # exists). ensure_manifest itself calls this to validate modes — do NOT add
  # an ensure_manifest call here or it recurses.
  local raw mode
  while IFS= read -r raw; do
    raw="${raw#"${raw%%[![:space:]]*}"}"   # ltrim
    raw="${raw%"${raw##*[![:space:]]}"}"   # rtrim
    [[ -z "$raw" ]] && continue
    [[ "$raw" == \#* ]] && continue

    mode="link"
    # A leading bare word (not starting with / or ~) followed by whitespace is a mode token.
    if [[ "$raw" =~ ^([^[:space:]/~][^[:space:]]*)[[:space:]]+(.+)$ ]]; then
      mode="${BASH_REMATCH[1]}"
      raw="${BASH_REMATCH[2]}"
    fi
    case "$mode" in
      link) : ;;
      *) die "Unsupported manifest mode '$mode' — only 'link' is implemented (line: $raw)" ;;
    esac

    printf '%s\t%s\n' "$mode" "$(expand_path "$raw")"
  done < "$DOT_MANIFEST"
}

# Emit "mode<TAB>abspath" per manifest entry, expanding globs against the LIVE fs.
# If a glob matches nothing, emits the literal pattern so callers can report it missing.
read_manifest_expanded() {
  local mode pat m
  while IFS=$'\t' read -r mode pat; do
    shopt -s nullglob
    # shellcheck disable=SC2206  # intentional glob expansion of a trusted manifest pattern
    local matches=($pat)
    shopt -u nullglob
    if [[ ${#matches[@]} -gt 0 ]]; then
      for m in "${matches[@]}"; do printf '%s\t%s\n' "$mode" "$m"; done
    else
      printf '%s\t%s\n' "$mode" "$pat"
    fi
  done < <(read_manifest_patterns)
}

# Safety belt (LINK-ONLY, broadened): return 0 (true) when a path must never be
# touched/committed. True when EITHER:
#   1. path is under ~/.ssh and is NOT one of: *.pub, config, known_hosts*
#   2. the file's content contains a PEM "PRIVATE KEY" header
is_ssh_private_key() {
  local abs="$1"
  if [[ "$abs" == "$HOME/.ssh/"* ]]; then
    case "$abs" in
      *.pub) : ;;
      "$HOME/.ssh/config") : ;;
      "$HOME/.ssh/known_hosts"*) : ;;
      *) return 0 ;;
    esac
  fi
  if [[ -f "$abs" ]] && LC_ALL=C grep -qs 'PRIVATE KEY' "$abs" 2>/dev/null; then
    return 0
  fi
  return 1
}

# Classify a live path against its expected repo target. Echoes exactly one of:
#   REPO-MISSING LIVE-MISSING BROKEN LINK-OK WRONG-TARGET NOT-A-LINK
classify_entry() {
  local abs="$1" tgt
  tgt="$(repo_target_for "$abs")"

  if [[ ! -e "$tgt" && ! -L "$tgt" ]]; then
    printf 'REPO-MISSING'; return
  fi
  if [[ -L "$abs" ]]; then
    if [[ ! -e "$abs" ]]; then printf 'BROKEN'; return; fi   # dangling symlink
    local dst; dst="$(readlink "$abs")"
    if [[ "$dst" == "$tgt" ]]; then printf 'LINK-OK'; else printf 'WRONG-TARGET'; fi
    return
  fi
  if [[ -e "$abs" ]]; then printf 'NOT-A-LINK'; return; fi
  printf 'LIVE-MISSING'
}

# List tracked files under managed/home/ that are NOT covered by any manifest
# pattern (orphans). Prints repo-relative paths, one per line.
find_orphans() {
  local -a patterns=()
  local mode pat
  while IFS=$'\t' read -r mode pat; do patterns+=("$pat"); done < <(read_manifest_patterns)

  local f rel home matched p
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel="${f#managed/home/}"
    home="$HOME/$rel"
    matched=0
    for p in "${patterns[@]}"; do
      # shellcheck disable=SC2254  # $p is a trusted manifest glob, matched intentionally
      case "$home" in
        $p) matched=1; break ;;
      esac
    done
    (( matched )) || printf '%s\n' "$f"
  done < <(git -C "$DOT_REPO" ls-files -- managed/home 2>/dev/null)
}

# Shared per-entry checker used by dot-status and dot-verify.
# Prints one line per manifest entry + orphan report + summary.
# Returns 0 only if every entry is LINK-OK (or a skipped secret) and no orphans.
dot_check_all() {
  ensure_repo
  local mode abs status rc=0
  local total=0 linkok=0 skipped=0 bad=0

  while IFS=$'\t' read -r mode abs; do
    total=$((total+1))
    if is_ssh_private_key "$abs"; then
      warn "[skip] protected (private/secret), not managed: $abs"
      skipped=$((skipped+1))
      continue
    fi
    status="$(classify_entry "$abs")"
    case "$status" in
      LINK-OK)
        log "LINK-OK      $abs"
        linkok=$((linkok+1)) ;;
      NOT-A-LINK)
        local tgt h1 h2 detail
        tgt="$(repo_target_for "$abs")"
        if [[ -f "$abs" && -f "$tgt" ]]; then
          h1="$(sha256_of "$abs")"; h2="$(sha256_of "$tgt")"
          [[ "$h1" == "$h2" ]] && detail="content MATCHES repo" || detail="content DIFFERS from repo"
        else
          detail="content not comparable (dir or non-regular)"
        fi
        warn "NOT-A-LINK   $abs  ($detail)"
        bad=$((bad+1)); rc=1 ;;
      WRONG-TARGET)
        warn "WRONG-TARGET $abs  -> $(readlink "$abs")  (expected $(repo_target_for "$abs"))"
        bad=$((bad+1)); rc=1 ;;
      BROKEN)
        warn "BROKEN       $abs  -> $(readlink "$abs")  (target missing)"
        bad=$((bad+1)); rc=1 ;;
      LIVE-MISSING)
        warn "LIVE-MISSING $abs"
        bad=$((bad+1)); rc=1 ;;
      REPO-MISSING)
        warn "REPO-MISSING $abs  (expected $(repo_target_for "$abs"))"
        bad=$((bad+1)); rc=1 ;;
    esac
  done < <(read_manifest_expanded)

  local orphans; orphans="$(find_orphans)"
  local orphan_n=0
  if [[ -n "$orphans" ]]; then
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      warn "ORPHAN       $f  (tracked under managed/home/ but not in manifest)"
      orphan_n=$((orphan_n+1)); rc=1
    done <<< "$orphans"
  fi

  log ""
  log "Total: $total | LINK-OK: $linkok | Problems: $bad | Skipped(secret): $skipped | Orphans: $orphan_n"
  return $rc
}
