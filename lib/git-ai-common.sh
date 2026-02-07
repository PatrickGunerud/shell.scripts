# git-ai-common.sh — shared library for git-ai-* tools
# Source this file; do not execute it.
[[ "${BASH_SOURCE[0]}" == "$0" ]] && { echo "Source this file; do not execute it." >&2; exit 1; }

# ── A. Backend env var defaults ──────────────────────────────────────────────

AI_BACKEND="${AI_BACKEND:-codex}"

CODEX_CMD="${CODEX_CMD:-codex}"
CODEX_ARGS="${CODEX_ARGS:-exec --color never -}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"
CLAUDE_ARGS="${CLAUDE_ARGS:--p}"

AI_MAX_CHARS="${AI_MAX_CHARS:-120000}"

# ── B. Core utilities ────────────────────────────────────────────────────────

die() { echo "ERROR: $*" >&2; exit 1; }

truncate() {
  local s="$1"
  if (( ${#s} > AI_MAX_CHARS )); then
    printf "%s\n\n[TRUNCATED to %s chars]\n" "${s:0:AI_MAX_CHARS}" "$AI_MAX_CHARS"
  else
    printf "%s\n" "$s"
  fi
}

# ── C. TTY & color helpers (stderr-based) ────────────────────────────────────

is_tty() { [[ -t 2 ]]; }
tput_ok() { command -v tput >/dev/null 2>&1 && tput sgr0 >/dev/null 2>&1; }

COLOR_ON=0
if is_tty && tput_ok; then
  COLOR_ON=1
fi

c() { # c <tput-seq> <text>
  local seq="$1"; shift
  if (( COLOR_ON == 1 )); then
    printf "%s%s%s" "$(tput ${seq})" "$*" "$(tput sgr0)"
  else
    printf "%s" "$*"
  fi
}

info() { # dimmed informational line to stderr
  if (( COLOR_ON == 1 )); then
    printf "  %s\n" "$(tput setaf 8)$*$(tput sgr0)" >&2
  else
    printf "  %s\n" "$*" >&2
  fi
}

step() { # bold step label to stderr
  if (( COLOR_ON == 1 )); then
    printf "%s\n" "$(tput bold)$*$(tput sgr0)" >&2
  else
    printf "%s\n" "$*" >&2
  fi
}

# ── D. Platform detection & install help ─────────────────────────────────────

detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "macos"; return ;;
  esac
  # Linux — parse /etc/os-release
  if [[ -f /etc/os-release ]]; then
    local id="" id_like=""
    id="$(. /etc/os-release && echo "${ID:-}")"
    id_like="$(. /etc/os-release && echo "${ID_LIKE:-}")"
    case "$id" in
      debian|ubuntu|linuxmint|pop|raspbian) echo "debian"; return ;;
      fedora)                               echo "fedora"; return ;;
      rhel|centos|rocky|almalinux|amzn)     echo "rhel";   return ;;
      arch|manjaro|endeavouros)             echo "arch";   return ;;
      alpine)                               echo "alpine"; return ;;
    esac
    case "$id_like" in
      *debian*) echo "debian"; return ;;
      *fedora*) echo "fedora"; return ;;
      *rhel*)   echo "rhel";   return ;;
      *arch*)   echo "arch";   return ;;
    esac
  fi
  echo "unknown"
}

# install_help <platform> <cmd> — prints install instruction for one tool
install_help() {
  local platform="$1" cmd="$2"
  local pkg=""
  case "$cmd" in
    git)  pkg="git" ;;
    jq)   pkg="jq" ;;
    grep) pkg="grep" ;;
    perl) pkg="perl" ;;
    awk)  pkg="gawk" ;;
    head) pkg="coreutils" ;;
    gh)
      case "$platform" in
        arch|alpine) pkg="github-cli" ;;
        *)           pkg="gh" ;;
      esac
      ;;
    *) pkg="$cmd" ;;
  esac

  case "$platform" in
    macos)   echo "  brew install $pkg" ;;
    debian)  echo "  sudo apt-get install -y $pkg" ;;
    fedora)  echo "  sudo dnf install -y $pkg" ;;
    rhel)    echo "  sudo yum install -y $pkg" ;;
    arch)    echo "  sudo pacman -S --noconfirm $pkg" ;;
    alpine)  echo "  sudo apk add $pkg" ;;
    *)       echo "  Install '$pkg' using your platform's package manager." ;;
  esac
}

# preflight_check <cmd>... — checks ALL commands; reports all missing at once
preflight_check() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if (( ${#missing[@]} == 0 )); then
    return 0
  fi

  local platform
  platform="$(detect_platform)"

  echo "ERROR: Required command(s) not found:" >&2
  echo "" >&2
  for cmd in "${missing[@]}"; do
    echo "  - $cmd" >&2
  done
  echo "" >&2
  echo "Install:" >&2
  for cmd in "${missing[@]}"; do
    install_help "$platform" "$cmd" >&2
  done
  exit 1
}

# require_cmd <cmd> — lazy/late single-command check (e.g., AI backend)
require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    local platform
    platform="$(detect_platform)"
    echo "ERROR: Required command not found: $cmd" >&2
    echo "" >&2
    echo "Install:" >&2
    install_help "$platform" "$cmd" >&2
    exit 127
  }
}

# ── E. AI runner ─────────────────────────────────────────────────────────────

run_ai() {
  local prompt="$1"
  case "$AI_BACKEND" in
    codex)
      require_cmd "$CODEX_CMD"
      # shellcheck disable=SC2086
      printf "%s" "$prompt" | "$CODEX_CMD" $CODEX_ARGS
      ;;
    claude)
      require_cmd "$CLAUDE_CMD"
      # shellcheck disable=SC2086
      printf "%s" "$prompt" | "$CLAUDE_CMD" $CLAUDE_ARGS
      ;;
    *)
      die "Unsupported AI_BACKEND='$AI_BACKEND' (expected 'codex' or 'claude')"
      ;;
  esac
}

# ── F. Output cleanup ───────────────────────────────────────────────────────

# Cleans AI tool output:
# - Drops leading banner line exactly "codex"/"claude"
# - Drops everything after first "tokens used" marker (case-insensitive)
# - Drops everything after "Rollback/Operational Notes:" (case-insensitive)
# - Trims trailing whitespace (replaces separate perl call)
clean_ai_output() {
  local raw="$1"
  awk '
    BEGIN { drop=0; line=0 }
    {
      line++
      s=$0

      if (line==1) {
        t=s
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
        if (tolower(t)=="codex" || tolower(t)=="claude") next
      }

      t=s
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
      tl=tolower(t)

      if (tl ~ /tokens[[:space:]]+used/) drop=1
      if (tl ~ /^rollback\/operational[[:space:]]+notes:/) drop=1

      if (!drop) print $0
    }
  ' <<<"$raw" | perl -0777 -pe 's/\s+\z/\n/s'
}
