#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  AuraFetch installer · a daily spark for your fastfetch
#  https://github.com/patriq128/Random_text-fastfetch
#
#  One-liner:
#    bash <(curl -fsSL https://raw.githubusercontent.com/patriq128/Random_text-fastfetch/main/install.sh)
#
#  Local checkout:
#    bash install.sh
#
#  Needs: bash, curl (only for remote installs), python3 (config patching).
# ─────────────────────────────────────────────────────────────────────────────

AURA_VERSION="2.0.0"
REPO_RAW="${AURA_REPO_RAW:-https://raw.githubusercontent.com/patriq128/Random_text-fastfetch/main}"

set -uo pipefail

# ── pretty output ────────────────────────────────────────────────────────────
UI_COLOR=0
if [[ -t 1 && -z ${NO_COLOR:-} ]]; then UI_COLOR=1; fi

RESET=""; BOLD=""; DIM=""
ACCENT=""; ACCENT2=""; MUTED=""; GREEN=""; YELLOW=""; RED=""
if (( UI_COLOR )); then
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    ACCENT=$'\033[38;2;94;234;212m'
    ACCENT2=$'\033[38;2;59;130;246m'
    MUTED=$'\033[38;2;148;163;184m'
    GREEN=$'\033[38;2;74;222;128m'
    YELLOW=$'\033[38;2;250;204;21m'
    RED=$'\033[38;2;248;113;113m'
fi

hr()      { printf '%s%s%s\n' "$MUTED" "──────────────────────────────────────────────────────────────" "$RESET"; }
section() { printf '\n%s%s%s%s\n' "$BOLD" "$ACCENT" "$1" "$RESET"; }
ok()      { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
warn()    { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
note()    { printf '  %s%s%s\n' "$MUTED" "$1" "$RESET"; }
die()     { printf '\n  %s✗ %s%s\n\n' "$RED" "$1" "$RESET" >&2; exit 1; }

header() {
    printf '\n'
    printf '%s      ✦  A U R A F E T C H  ✦%s\n' "$BOLD$ACCENT" "$RESET"
    printf '%s          a daily spark for your terminal%s\n' "$MUTED" "$RESET"
    printf '%s                    v%s%s\n' "$DIM" "$AURA_VERSION" "$RESET"
    hr
}

usage() {
    cat <<'HELP'
AuraFetch 2.0.0 — installer

USAGE
  bash install.sh [options]

THE LOOK
  --theme NAME       aura, cyber, matrix, dracula, gruvbox, ice, ember, mono
  --style NAME       card, line, minimal
  --mode NAME        daily or random
  --packs LIST       comma-separated packs, or "all"  (e.g. stoic,tech,folk)
  --width N          card width, 30-100 (default: 46)
  --key TEXT         module key; " " hides it (default: hidden)
  --color            keep installer colors even when piped
  --no-color         disable installer colors

PATHS
  --config PATH      fastfetch config to patch
  --engine PATH      use a local random-text.sh instead of downloading
  --no-link          don't create the ~/.local/bin/aura symlink

OTHER
  -y, --yes          accept all defaults, no prompts
  --dry-run          show the config preview, write nothing
  --no-run           don't launch fastfetch at the end
  --uninstall        remove AuraFetch from the config and delete its files
  -h, --help         this help
  -V, --version      version

EXAMPLES
  bash install.sh
  bash install.sh --yes --theme cyber --style card --packs all
  bash install.sh --dry-run --theme matrix
  bash install.sh --uninstall

Skip everything and just use defaults:
  bash <(curl -fsSL https://raw.githubusercontent.com/patriq128/Random_text-fastfetch/main/install.sh) --yes
HELP
}

# ── arguments ────────────────────────────────────────────────────────────────
_norm=()
for _arg in "$@"; do
    case $_arg in
        --*=*) _norm+=("${_arg%%=*}" "${_arg#*=}") ;;
        *)     _norm+=("$_arg") ;;
    esac
done
set -- ${_norm[@]+"${_norm[@]}"}

ASSUME_YES=0
DRY_RUN=0
NO_RUN=0
NO_LINK=0
UNINSTALL=0
UI_COLOR_FORCE=-1
CONFIG_OVERRIDE=""
ENGINE_OVERRIDE=""
THEME_NAME="";  THEME_SET=0
STYLE_NAME="";  STYLE_SET=0
MODE_NAME="";   MODE_SET=0
PACKS_NAME="";  PACKS_SET=0
WIDTH_SETTING=""
KEY_SETTING=" "
KEY_SET=0

while (( $# > 0 )); do
    case $1 in
        -h|--help)    usage; exit 0 ;;
        -V|--version) printf 'AuraFetch installer %s\n' "$AURA_VERSION"; exit 0 ;;
        -y|--yes)     ASSUME_YES=1; shift ;;
        --dry-run)    DRY_RUN=1; shift ;;
        --no-run)     NO_RUN=1; shift ;;
        --no-link)    NO_LINK=1; shift ;;
        --uninstall)  UNINSTALL=1; shift ;;
        --color)      UI_COLOR_FORCE=1; shift ;;
        --no-color)   UI_COLOR_FORCE=0; shift ;;
        --theme)      [[ $# -ge 2 ]] || die "--theme needs a value";  THEME_NAME=$2; THEME_SET=1; shift 2 ;;
        --style)      [[ $# -ge 2 ]] || die "--style needs a value";  STYLE_NAME=$2; STYLE_SET=1; shift 2 ;;
        --mode)       [[ $# -ge 2 ]] || die "--mode needs a value";   MODE_NAME=$2;  MODE_SET=1;  shift 2 ;;
        --packs|--pack)
                      [[ $# -ge 2 ]] || die "--packs needs a value"; PACKS_NAME=$2; PACKS_SET=1; shift 2 ;;
        --width)      [[ $# -ge 2 ]] || die "--width needs a value";  WIDTH_SETTING=$2; shift 2 ;;
        --key)        [[ $# -ge 2 ]] || die "--key needs a value";    KEY_SETTING=$2; KEY_SET=1; shift 2 ;;
        --config)     [[ $# -ge 2 ]] || die "--config needs a value"; CONFIG_OVERRIDE=$2; shift 2 ;;
        --engine)     [[ $# -ge 2 ]] || die "--engine needs a value"; ENGINE_OVERRIDE=$2; shift 2 ;;
        --) shift; break ;;
        *) die "unknown option: $1  (try --help)" ;;
    esac
done

if (( UI_COLOR_FORCE == 0 )); then
    UI_COLOR=0
    RESET=""; BOLD=""; DIM=""; ACCENT=""; ACCENT2=""; MUTED=""
    GREEN=""; YELLOW=""; RED=""
elif (( UI_COLOR_FORCE == 1 )); then
    UI_COLOR=1
    RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
    ACCENT=$'\033[38;2;94;234;212m'; ACCENT2=$'\033[38;2;59;130;246m'
    MUTED=$'\033[38;2;148;163;184m'; GREEN=$'\033[38;2;74;222;128m'
    YELLOW=$'\033[38;2;250;204;21m'; RED=$'\033[38;2;248;113;113m'
fi

INTERACTIVE=0
(( ASSUME_YES == 0 )) && [[ -t 0 && -t 1 ]] && INTERACTIVE=1

# ── temp cleanup ─────────────────────────────────────────────────────────────
DL_DIR=""
PREVIEW_DIR=""
cleanup() {
    [[ -n $DL_DIR && -d $DL_DIR ]] && rm -rf -- "$DL_DIR"
    [[ -n $PREVIEW_DIR && -d $PREVIEW_DIR ]] && rm -rf -- "$PREVIEW_DIR"
}
trap cleanup EXIT INT TERM

# ── where does this installer live? ─────────────────────────────────────────
SELF="${BASH_SOURCE[0]}"
SELF_DIR=""
if [[ -f $SELF ]]; then
    SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$SELF")" 2>/dev/null && pwd -P) || SELF_DIR=""
fi

# ── resolve the fastfetch config ────────────────────────────────────────────
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
if [[ -n $CONFIG_OVERRIDE ]]; then
    CONFIG=$CONFIG_OVERRIDE
elif [[ -f $CONFIG_DIR/config.jsonc ]]; then
    CONFIG="$CONFIG_DIR/config.jsonc"
elif [[ -f $CONFIG_DIR/config.json ]]; then
    CONFIG="$CONFIG_DIR/config.json"
else
    CONFIG="$CONFIG_DIR/config.jsonc"
fi
CONFIG_DIR=$(cd -- "$(dirname -- "$CONFIG")" 2>/dev/null && pwd -P) \
    || CONFIG_DIR=$(dirname -- "$CONFIG")
CONFIG="$CONFIG_DIR/$(basename -- "$CONFIG")"

SCRIPT_DST="$CONFIG_DIR/random-text.sh"
SETTINGS_DST="$CONFIG_DIR/aura.conf"
QUOTES_LOCAL="$CONFIG_DIR/quotes.local.txt"
LOGO_DST="$CONFIG_DIR/logo.txt"
BIN_DIR="$HOME/.local/bin"
BIN_LINK="$BIN_DIR/aura"

# ── themes ───────────────────────────────────────────────────────────────────
THEME_NAMES=(aura cyber matrix dracula gruvbox ice ember mono)
THEME_HEX=("#5EEAD4" "#FF3CAC" "#4ADE80" "#BD93F9" "#FABD2F" "#38BDF8" "#F87171" "#E5E7EB")
THEME_HEX2=("#3B82F6" "#7C3AED" "#16A34A" "#FF79C6" "#FB923C" "#818CF8" "#FBBF24" "#9CA3AF")
THEME_FF=(cyan magenta green magenta yellow blue red white)
THEME_DESC=("cool cyan" "hot neon" "terminal green" "violet dusk" "warm amber" "glacier blue" "ember red" "clean mono")

find_theme_index() {
    local want
    want=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    local i
    for (( i = 0; i < ${#THEME_NAMES[@]}; i++ )); do
        [[ ${THEME_NAMES[i]} == "$want" ]] && { printf '%s' "$i"; return 0; }
    done
    return 1
}

hex_rgb() {
    local h=${1#\#}
    HR=$(( 16#${h:0:2} ))
    HG=$(( 16#${h:2:2} ))
    HB=$(( 16#${h:4:2} ))
}

swatch_for() {
    local hex=$1
    if (( UI_COLOR )); then
        hex_rgb "$hex"
        printf '\033[38;2;%d;%d;%dm██████%s' "$HR" "$HG" "$HB" "$RESET"
    else
        printf '      '
    fi
}

print_theme_menu() {
    section "1 · theme"
    note "Pick the accent. Direct CLI output uses the truecolor hex;"
    note "fastfetch uses the nearest named colour."
    printf '\n'
    local i
    for (( i = 0; i < ${#THEME_NAMES[@]}; i++ )); do
        printf '   %s%2d)%s %-8s %s  %-15s %s%s%s\n' \
            "$ACCENT2" "$(( i + 1 ))" "$RESET" \
            "${THEME_NAMES[i]}" "$(swatch_for "${THEME_HEX[i]}")" \
            "${THEME_DESC[i]}" "$DIM" "${THEME_HEX[i]}" "$RESET"
    done
}

select_theme() {
    if (( ! INTERACTIVE )); then
        THEME_NAME=${THEME_NAME:-aura}
        THEME_IDX=$(find_theme_index "$THEME_NAME") \
            || die "unknown theme: $THEME_NAME (try: ${THEME_NAMES[*]})"
        return
    fi
    if (( THEME_SET )); then
        THEME_IDX=$(find_theme_index "$THEME_NAME") \
            || die "unknown theme: $THEME_NAME (try: ${THEME_NAMES[*]})"
        printf '\n%s1 · theme%s  %s%s%s\n' "$BOLD$ACCENT" "$RESET" "$ACCENT2" "${THEME_NAMES[THEME_IDX]}" "$RESET"
        return
    fi
    print_theme_menu
    local ans idx
    while :; do
        printf '\n   theme %s[1-%d or name]%s (aura): ' "$DIM" "${#THEME_NAMES[@]}" "$RESET"
        read -r ans 2>/dev/null || ans=""
        ans=${ans:-aura}
        idx=""
        if [[ $ans =~ ^[0-9]+$ ]]; then
            (( ans >= 1 && ans <= ${#THEME_NAMES[@]} )) && idx=$(( ans - 1 ))
        else
            idx=$(find_theme_index "$ans" || true)
        fi
        if [[ -n $idx ]]; then THEME_IDX=$idx; return; fi
        warn "pick 1-${#THEME_NAMES[@]} or a theme name"
    done
}

# ── config preview helpers ──────────────────────────────────────────────────
# The engine is resolved later for installs; uninstall doesn't need it.
PREVIEW_COLOR_FLAG="--no-color"
(( UI_COLOR )) && PREVIEW_COLOR_FLAG="--color"

# ── uninstall ───────────────────────────────────────────────────────────────
do_uninstall() {
    header
    section "uninstall"
    printf '  config   %s\n' "$CONFIG"
    printf '  engine   %s\n' "$SCRIPT_DST"

    if (( INTERACTIVE && ! ASSUME_YES && ! DRY_RUN )); then
        local ans
        printf '\n   Remove AuraFetch from this config? %s[y/N]%s ' "$DIM" "$RESET"
        read -r ans 2>/dev/null || ans=""
        case $ans in
            y|Y|yes|YES) ;;
            *) printf '\n   cancelled — nothing changed.\n\n'; exit 0 ;;
        esac
    fi

    if (( ! DRY_RUN )); then
        mkdir -p "$CONFIG_DIR"
    fi

    local backup=""
    if [[ -f $CONFIG ]]; then
        command -v python3 >/dev/null 2>&1 \
            || die "python3 is required to edit the fastfetch config"
        if (( ! DRY_RUN )); then
            backup="$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
            cp -L -- "$CONFIG" "$backup" || die "could not back up $CONFIG"
        fi
        if ! AURA_CONFIG="$CONFIG" AURA_ACTION=uninstall AURA_DRY_RUN="$DRY_RUN" \
            python3 - <<'PY'
import json, os, sys
from pathlib import Path

config_path = Path(os.environ["AURA_CONFIG"]).resolve()
dry = os.environ.get("AURA_DRY_RUN") == "1"

def strip_jsonc(src):
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c == '"':
            out.append(c)
            i += 1
            while i < n:
                out.append(src[i])
                if src[i] == "\\":
                    i += 1
                    if i < n:
                        out.append(src[i])
                elif src[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and nxt == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        if c == ",":
            j = i + 1
            while j < n and src[j].isspace():
                j += 1
            if j < n and src[j] in "]}":
                i += 1
                continue
        out.append(c)
        i += 1
    return "".join(out)

def skip_ws_comments(src, i, limit):
    n = limit
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c.isspace():
            i += 1
        elif c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                i += 1
        elif c == "/" and nxt == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
        else:
            break
    return i

def find_modules(src):
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and nxt == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        if c == '"':
            j = i + 1
            esc = False
            while j < n:
                if esc:
                    esc = False
                elif src[j] == "\\":
                    esc = True
                elif src[j] == '"':
                    break
                j += 1
            token = src[i + 1:j]
            if token == "modules":
                k = j + 1
                while k < n and src[k].isspace():
                    k += 1
                if k < n and src[k] == ":":
                    k += 1
                    while k < n and src[k].isspace():
                        k += 1
                    if k < n and src[k] == "[":
                        start = k
                        depth = 0
                        m = k
                        in_str = False
                        esc2 = False
                        while m < n:
                            ch = src[m]
                            nx = src[m + 1] if m + 1 < n else ""
                            if in_str:
                                if esc2:
                                    esc2 = False
                                elif ch == "\\":
                                    esc2 = True
                                elif ch == '"':
                                    in_str = False
                            elif ch == '"':
                                in_str = True
                            elif ch == "/" and nx == "/":
                                while m < n and src[m] != "\n":
                                    m += 1
                            elif ch == "/" and nx == "*":
                                m += 2
                                while m + 1 < n and not (src[m] == "*" and src[m + 1] == "/"):
                                    m += 1
                                m += 1
                            elif ch == "[":
                                depth += 1
                            elif ch == "]":
                                depth -= 1
                                if depth == 0:
                                    return start, m
                            m += 1
                        return start, None
            i = j + 1
            continue
        i += 1
    return None, None

def split_elements(src, start, end):
    elems = []
    i = start + 1
    tok = None
    depth = 0
    in_str = False
    esc = False
    line = False
    block = False
    while i < end:
        c = src[i]
        nxt = src[i + 1] if i + 1 < end else ""
        if line:
            if c == "\n":
                line = False
            i += 1
            continue
        if block:
            if c == "*" and nxt == "/":
                block = False
                i += 2
            else:
                i += 1
            continue
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == "/" and nxt == "/":
            line = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            block = True
            i += 2
            continue
        if c == '"':
            if tok is None:
                tok = i
            in_str = True
            i += 1
            continue
        if c in "[{":
            if tok is None:
                tok = i
            depth += 1
            i += 1
            continue
        if c in "]}":
            if depth > 0:
                depth -= 1
            i += 1
            continue
        if c == "," and depth == 0:
            if tok is not None:
                elems.append((tok, i))
                tok = None
            i += 1
            continue
        if tok is None and not c.isspace():
            tok = i
        i += 1
    if tok is not None:
        elems.append((tok, end))
    return elems

def remove_element(src, start, end, span):
    s, e = span
    j = skip_ws_comments(src, e, end)
    if j < end and src[j] == ",":
        comma = j
        ls = src.rfind("\n", 0, s) + 1
        rm_start = ls if src[ls:s].strip() == "" else s
        rm_end = comma + 1
        k = rm_end
        while k < len(src) and src[k] in " \t":
            k += 1
        if k < len(src) and src[k] == "\n":
            k += 1
        return src[:rm_start] + src[k:]
    j = s - 1
    while j >= 0 and src[j].isspace():
        j -= 1
    if j >= 0 and src[j] == ",":
        comma = j
        ls = src.rfind("\n", 0, comma) + 1
        rm_start = ls if src[ls:comma].strip() == "" else comma
        k = e
        while k < len(src) and src[k] in " \t":
            k += 1
        if k < len(src) and src[k] == "\n":
            k += 1
        return src[:rm_start] + src[k:]
    return src[:s] + src[e:]

def drop_trailing_comma(src):
    start, end = find_modules(src)
    if start is None or end is None:
        return src
    spans = split_elements(src, start, end)
    if not spans:
        return src
    s, e = spans[-1]
    j = skip_ws_comments(src, e, end)
    if j < end and src[j] == ",":
        return src[:j] + src[j + 1:]
    return src

config = config_path.read_text(encoding="utf-8")
removed = 0
while True:
    start, end = find_modules(config)
    if start is None:
        break
    spans = split_elements(config, start, end)
    ours = [sp for sp in spans if "random-text.sh" in config[sp[0]:sp[1]]]
    if not ours:
        break
    config = remove_element(config, start, end, ours[0])
    removed += 1

config = drop_trailing_comma(config)

try:
    json.loads(strip_jsonc(config))
except Exception as exc:
    print(f"aura: resulting config is not valid JSONC: {exc}", file=sys.stderr)
    sys.exit(1)

if dry:
    sys.stdout.write(config)
else:
    config_path.write_text(config, encoding="utf-8")
    print(f"removed {removed} module(s)", file=sys.stderr)
PY
        then
            [[ -n $backup ]] && cp -L -- "$backup" "$CONFIG"
            die "config update failed — your backup is untouched"
        fi
        if (( DRY_RUN )); then
            printf '\n   dry run — nothing was written.\n\n'
            exit 0
        fi
        ok "module removed from $CONFIG"
        [[ -n $backup ]] && note "backup: $backup"
    else
        warn "no config found at $CONFIG"
    fi

    if (( DRY_RUN )); then
        printf '\n   dry run — nothing was written.\n\n'
        exit 0
    fi

    if [[ -L $BIN_LINK ]] && [[ $(readlink -- "$BIN_LINK" 2>/dev/null) == "$SCRIPT_DST" ]]; then
        rm -f -- "$BIN_LINK" && ok "removed $BIN_LINK"
    fi
    if [[ -f $SCRIPT_DST ]]; then rm -f -- "$SCRIPT_DST" && ok "removed $SCRIPT_DST"; fi
    if [[ -f $SETTINGS_DST ]]; then rm -f -- "$SETTINGS_DST" && ok "removed $SETTINGS_DST"; fi
    [[ -f $QUOTES_LOCAL ]] && note "kept your custom quotes: $QUOTES_LOCAL"
    [[ -f $LOGO_DST ]] && note "kept logo: $LOGO_DST"

    printf '\n  %sAuraFetch removed.%s\n\n' "$GREEN" "$RESET"
    exit 0
}

if (( UNINSTALL )); then
    do_uninstall
fi

# ── dependency checks ────────────────────────────────────────────────────────
header

if ! command -v python3 >/dev/null 2>&1; then
    die "python3 is required to patch the fastfetch config"
fi

HAS_FASTFETCH=0
command -v fastfetch >/dev/null 2>&1 && HAS_FASTFETCH=1

command -v curl >/dev/null 2>&1 && HAS_CURL=1 || HAS_CURL=0
if (( ! HAS_FASTFETCH )); then
    warn "fastfetch was not found — the config will still be prepared"
fi
if [[ ! -f $CONFIG ]]; then
    note "no config yet — a fresh one will be created at $CONFIG"
fi

# ── find the engine ─────────────────────────────────────────────────────────
ENGINE_SRC=""
SOURCE_LABEL=""
if [[ -n $ENGINE_OVERRIDE ]]; then
    [[ -f $ENGINE_OVERRIDE ]] || die "engine not found: $ENGINE_OVERRIDE"
    ENGINE_SRC=$ENGINE_OVERRIDE
    SOURCE_LABEL="local engine"
elif [[ -n $SELF_DIR && -f "$SELF_DIR/random-text.sh" ]]; then
    ENGINE_SRC="$SELF_DIR/random-text.sh"
    SOURCE_LABEL="local checkout"
else
    (( HAS_CURL )) || die "curl is required for a remote install (or pass --engine PATH)"
    DL_DIR=$(mktemp -d 2>/dev/null) || die "could not create a temp directory"
    ENGINE_SRC="$DL_DIR/random-text.sh"
    SOURCE_LABEL="github · main"
    if ! curl -fsSL --max-time 30 "$REPO_RAW/random-text.sh" -o "$ENGINE_SRC"; then
        die "could not download random-text.sh — check your connection"
    fi
fi

[[ -s $ENGINE_SRC ]] || die "engine is empty: $ENGINE_SRC"
bash -n "$ENGINE_SRC" 2>/dev/null || die "engine failed the syntax check"

# ── read the packs from the engine ──────────────────────────────────────────
PACK_OUT=$(AURA_CONFIG_DIR="$CONFIG_DIR" bash "$ENGINE_SRC" --packs 2>/dev/null) \
    || die "the quote engine could not list its packs"

PACK_KEY=(); PACK_N=(); PACK_ICON=(); PACK_LABEL=()
PACK_TOTAL=0
while IFS='|' read -r _pk _pn _pi _pl; do
    [[ -z ${_pk:-} ]] && continue
    PACK_KEY+=("$_pk")
    PACK_N+=("${_pn:-0}")
    PACK_ICON+=("${_pi:-•}")
    PACK_LABEL+=("${_pl:-$_pk}")
    PACK_TOTAL=$(( PACK_TOTAL + ${_pn:-0} ))
done <<< "$PACK_OUT"

(( ${#PACK_KEY[@]} > 0 )) || die "the engine reported no quote packs"

# ── choose a theme ──────────────────────────────────────────────────────────
select_theme
THEME=${THEME_NAMES[THEME_IDX]}
THEME_COLOR=${THEME_HEX[THEME_IDX]}
THEME_COLOR2=${THEME_HEX2[THEME_IDX]}
THEME_FFCOLOR=${THEME_FF[THEME_IDX]}

# ── card width (validate before previews so they match the final result) ────
WIDTH=${WIDTH_SETTING:-46}
[[ $WIDTH =~ ^[0-9]+$ ]] || die "width must be a number"
WIDTH=$(( 10#$WIDTH ))
(( WIDTH >= 30 && WIDTH <= 100 )) || die "width must be between 30 and 100"

# ── preview the three styles ────────────────────────────────────────────────
PREVIEW_DIR=$(mktemp -d 2>/dev/null) || die "could not create a preview directory"

preview_style() {
    local style=$1
    AURA_CONFIG_DIR="$PREVIEW_DIR" bash "$ENGINE_SRC" \
        --style "$style" --pack "${PREVIEW_PACK:-stoic}" \
        --seed "${PREVIEW_SEED:-17}" --width "${WIDTH:-46}" \
        --accent "$THEME_COLOR" --accent2 "$THEME_COLOR2" \
        "$PREVIEW_COLOR_FLAG" --no-animate 2>/dev/null \
        | sed 's/^/     /'
}

PREVIEW_PACK=${PACK_KEY[0]}
PREVIEW_SEED=$(( $(date +%s) % 97 ))

print_style_menu() {
    section "2 · style"
    note "Three ways to wear a quote."
    printf '\n   %s1) card%s — framed quote card, the main character\n' "$ACCENT2" "$RESET"
    preview_style card
    printf '\n   %s2) line%s — compact one-liner with a pack icon\n' "$ACCENT2" "$RESET"
    preview_style line
    printf '\n   %s3) minimal%s — just the words\n' "$ACCENT2" "$RESET"
    preview_style minimal
}

select_style() {
    if (( ! INTERACTIVE )); then
        STYLE_NAME=${STYLE_NAME:-card}
        case $STYLE_NAME in card|line|minimal) ;; *) die "unknown style: $STYLE_NAME" ;; esac
        return
    fi
    if (( STYLE_SET )); then
        case $STYLE_NAME in card|line|minimal) ;; *) die "unknown style: $STYLE_NAME" ;; esac
        printf '\n%s2 · style%s  %s%s%s\n' "$BOLD$ACCENT" "$RESET" "$ACCENT2" "$STYLE_NAME" "$RESET"
        return
    fi
    print_style_menu
    local ans
    while :; do
        printf '\n   style %s[1-3]%s (card): ' "$DIM" "$RESET"
        read -r ans 2>/dev/null || ans=""
        ans=${ans:-card}
        case $ans in
            1|card)    STYLE_NAME=card;    return ;;
            2|line)    STYLE_NAME=line;    return ;;
            3|minimal) STYLE_NAME=minimal; return ;;
            *) warn "pick 1, 2, 3 or a style name" ;;
        esac
    done
}

select_style

# ── choose a mode ───────────────────────────────────────────────────────────
select_mode() {
    if (( ! INTERACTIVE )); then
        MODE_NAME=${MODE_NAME:-daily}
        case $MODE_NAME in daily|random) ;; *) die "unknown mode: $MODE_NAME" ;; esac
        return
    fi
    if (( MODE_SET )); then
        case $MODE_NAME in daily|random) ;; *) die "unknown mode: $MODE_NAME" ;; esac
        printf '\n%s3 · mode%s  %s%s%s\n' "$BOLD$ACCENT" "$RESET" "$ACCENT2" "$MODE_NAME" "$RESET"
        return
    fi
    section "3 · mode"
    printf '\n   %s1) daily%s  — one quote all day, new at midnight\n' "$ACCENT2" "$RESET"
    printf '   %s2) random%s — a fresh quote every fetch\n' "$ACCENT2" "$RESET"
    local ans
    while :; do
        printf '\n   mode %s[1-2]%s (daily): ' "$DIM" "$RESET"
        read -r ans 2>/dev/null || ans=""
        ans=${ans:-daily}
        case $ans in
            1|daily)  MODE_NAME=daily;  return ;;
            2|random) MODE_NAME=random; return ;;
            *) warn "pick 1, 2, daily or random" ;;
        esac
    done
}
select_mode

# ── choose packs ────────────────────────────────────────────────────────────
print_pack_menu() {
    section "4 · packs"
    note "Pick the flavours you want. All of them is a fine answer."
    printf '\n'
    local i
    for (( i = 0; i < ${#PACK_KEY[@]}; i++ )); do
        printf '   %s%2d)%s %-3s %-12s %s%3d%s quotes\n' \
            "$ACCENT2" "$(( i + 1 ))" "$RESET" "${PACK_ICON[i]}" \
            "${PACK_LABEL[i]}" "$DIM" "${PACK_N[i]}" "$RESET"
    done
}

# map a name or number to a pack key; empty output on failure
pack_token_to_key() {
    local tok
    tok=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    [[ -z $tok ]] && return 1
    if [[ $tok =~ ^[0-9]+$ ]]; then
        (( tok >= 1 && tok <= ${#PACK_KEY[@]} )) && { printf '%s' "${PACK_KEY[tok - 1]}"; return 0; }
        return 1
    fi
    local i
    for (( i = 0; i < ${#PACK_KEY[@]}; i++ )); do
        [[ ${PACK_KEY[i]} == "$tok" ]] && { printf '%s' "${PACK_KEY[i]}"; return 0; }
    done
    return 1
}

resolve_packs() {
    local input=$1 out="" tok key seen=","
    input=$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    if [[ -z $input || $input == all ]]; then
        SELECTED_PACKS=all
        SELECTED_COUNT=$PACK_TOTAL
        return 0
    fi
    case ",$input," in
        *,all,*) SELECTED_PACKS=all; SELECTED_COUNT=$PACK_TOTAL; return 0 ;;
    esac
    local IFS=','
    for tok in $input; do
        [[ -z $tok ]] && continue
        key=$(pack_token_to_key "$tok") || return 1
        [[ $seen == *",$key,"* ]] && continue
        seen="$seen$key,"
        out="${out:+$out,}$key"
    done
    [[ -z $out ]] && return 1
    SELECTED_PACKS=$out
    SELECTED_COUNT=0
    local k i
    while IFS= read -r k; do
        [[ -z $k ]] && continue
        for (( i = 0; i < ${#PACK_KEY[@]}; i++ )); do
            [[ ${PACK_KEY[i]} == "$k" ]] && (( SELECTED_COUNT += PACK_N[i] ))
        done
    done < <(printf '%s\n' "$out" | tr ',' '\n')
    return 0
}

select_packs() {
    if (( PACKS_SET )); then
        resolve_packs "$PACKS_NAME" \
            || die "unknown pack list: $PACKS_NAME (try: ${PACK_KEY[*]})"
        if (( INTERACTIVE )); then
            printf '\n%s4 · packs%s  %s%s%s\n' "$BOLD$ACCENT" "$RESET" "$ACCENT2" "$SELECTED_PACKS" "$RESET"
        fi
        return
    fi
    if (( ! INTERACTIVE )); then
        resolve_packs "all"
        return
    fi
    print_pack_menu
    local ans
    while :; do
        printf '\n   packs %s[numbers/names, or all]%s (all): ' "$DIM" "$RESET"
        read -r ans 2>/dev/null || ans=""
        ans=${ans:-all}
        if resolve_packs "$ans"; then return; fi
        warn "could not read that pack list — try 1,3,5 or stoic,tech"
    done
}
select_packs

# ── module key ──────────────────────────────────────────────────────────────
MODULE_KEY=${KEY_SETTING:- }
if [[ $STYLE_NAME == card && $MODULE_KEY != " " ]]; then
    warn "a key would be printed on every card line — hiding it"
    MODULE_KEY=" "
fi

# ── final preview ───────────────────────────────────────────────────────────
PREVIEW_PACK=${PACK_KEY[0]}
if [[ $SELECTED_PACKS != all ]]; then
    PREVIEW_PACK=${SELECTED_PACKS%%,*}
fi
PREVIEW_SEED=$(( $(date +%s) % 97 ))

section "preview"
printf '\n'
AURA_CONFIG_DIR="$PREVIEW_DIR" bash "$ENGINE_SRC" \
    --style "$STYLE_NAME" --mode "$MODE_NAME" --pack "$PREVIEW_PACK" \
    --seed "$PREVIEW_SEED" --width "$WIDTH" \
    --accent "$THEME_COLOR" --accent2 "$THEME_COLOR2" \
    "$PREVIEW_COLOR_FLAG" --no-animate \
    | sed 's/^/   /' || die "the preview failed — the engine may be broken"

# ── summary ─────────────────────────────────────────────────────────────────
section "5 · install"
printf '   %-10s %s%s%s  %s%s%s\n' "theme" "$ACCENT2" "$THEME" "$RESET" "$DIM" "$THEME_COLOR" "$RESET"
printf '   %-10s %s\n' "style" "$STYLE_NAME"
printf '   %-10s %s\n' "mode" "$MODE_NAME"
_pack_word=quotes
(( SELECTED_COUNT == 1 )) && _pack_word=quote
printf '   %-10s %s %s(%d %s)%s\n' "packs" "$SELECTED_PACKS" "$DIM" "$SELECTED_COUNT" "$_pack_word" "$RESET"
printf '   %-10s %s\n' "engine" "$SCRIPT_DST"
printf '   %-10s %s\n' "config" "$CONFIG"
[[ -n $SOURCE_LABEL ]] && printf '   %-10s %s\n' "source" "$SOURCE_LABEL"
hr

if (( INTERACTIVE && ! ASSUME_YES && ! DRY_RUN )); then
    local_ans=""
    printf '\n   install now? %s[Y/n]%s ' "$DIM" "$RESET"
    read -r local_ans 2>/dev/null || local_ans=""
    case $local_ans in
        n|N|no|NO) printf '\n   cancelled — nothing changed.\n\n'; exit 0 ;;
    esac
fi

# ── dry run ─────────────────────────────────────────────────────────────────
AURA_CREATE=0
[[ -f $CONFIG ]] || AURA_CREATE=1

run_patcher() {
    AURA_CONFIG="$CONFIG" \
    AURA_SCRIPT="$SCRIPT_DST" \
    AURA_COLOR="$THEME_FFCOLOR" \
    AURA_LOGO_PATH="$LOGO_DST" \
    AURA_KEY="$MODULE_KEY" \
    AURA_ACTION=install \
    AURA_DRY_RUN="$DRY_RUN" \
    AURA_CREATE="$AURA_CREATE" \
    python3 - <<'PY'
import json, os, shlex, sys
from pathlib import Path

config_path = Path(os.environ["AURA_CONFIG"]).resolve()
script = os.environ["AURA_SCRIPT"]
color = os.environ.get("AURA_COLOR", "cyan")
logo = os.environ.get("AURA_LOGO_PATH", "")
key = os.environ.get("AURA_KEY", " ")
action = os.environ.get("AURA_ACTION", "install")
dry = os.environ.get("AURA_DRY_RUN") == "1"
create = os.environ.get("AURA_CREATE") == "1"

MODULE = {
    "type": "command",
    "key": key,
    "text": shlex.quote(script),
    "splitLines": True,
    "useOutput": "stdout",
    "outputColor": color,
}

# ── JSONC helpers ───────────────────────────────────────────────────────────
def strip_jsonc(src):
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c == '"':
            out.append(c)
            i += 1
            while i < n:
                out.append(src[i])
                if src[i] == "\\":
                    i += 1
                    if i < n:
                        out.append(src[i])
                elif src[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and nxt == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        if c == ",":
            j = i + 1
            while j < n and src[j].isspace():
                j += 1
            if j < n and src[j] in "]}":
                i += 1
                continue
        out.append(c)
        i += 1
    return "".join(out)

def skip_ws_comments(src, i, limit):
    while i < limit:
        c = src[i]
        nxt = src[i + 1] if i + 1 < limit else ""
        if c.isspace():
            i += 1
        elif c == "/" and nxt == "/":
            while i < limit and src[i] != "\n":
                i += 1
        elif c == "/" and nxt == "*":
            i += 2
            while i + 1 < limit and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
        else:
            break
    return i

def find_modules(src):
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and nxt == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        if c == '"':
            j = i + 1
            esc = False
            while j < n:
                if esc:
                    esc = False
                elif src[j] == "\\":
                    esc = True
                elif src[j] == '"':
                    break
                j += 1
            if src[i + 1:j] == "modules":
                k = j + 1
                while k < n and src[k].isspace():
                    k += 1
                if k < n and src[k] == ":":
                    k += 1
                    while k < n and src[k].isspace():
                        k += 1
                    if k < n and src[k] == "[":
                        start = k
                        depth = 0
                        m = k
                        in_str = False
                        esc2 = False
                        while m < n:
                            ch = src[m]
                            nx = src[m + 1] if m + 1 < n else ""
                            if in_str:
                                if esc2:
                                    esc2 = False
                                elif ch == "\\":
                                    esc2 = True
                                elif ch == '"':
                                    in_str = False
                            elif ch == '"':
                                in_str = True
                            elif ch == "/" and nx == "/":
                                while m < n and src[m] != "\n":
                                    m += 1
                            elif ch == "/" and nx == "*":
                                m += 2
                                while m + 1 < n and not (src[m] == "*" and src[m + 1] == "/"):
                                    m += 1
                                m += 1
                            elif ch == "[":
                                depth += 1
                            elif ch == "]":
                                depth -= 1
                                if depth == 0:
                                    return start, m
                            m += 1
                        return start, None
            i = j + 1
            continue
        i += 1
    return None, None

def split_elements(src, start, end):
    elems = []
    i = start + 1
    tok = None
    depth = 0
    in_str = False
    esc = False
    line = False
    block = False
    while i < end:
        c = src[i]
        nxt = src[i + 1] if i + 1 < end else ""
        if line:
            if c == "\n":
                line = False
            i += 1
            continue
        if block:
            if c == "*" and nxt == "/":
                block = False
                i += 2
            else:
                i += 1
            continue
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == "/" and nxt == "/":
            line = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            block = True
            i += 2
            continue
        if c == '"':
            if tok is None:
                tok = i
            in_str = True
            i += 1
            continue
        if c in "[{":
            if tok is None:
                tok = i
            depth += 1
            i += 1
            continue
        if c in "]}":
            if depth > 0:
                depth -= 1
            i += 1
            continue
        if c == "," and depth == 0:
            if tok is not None:
                elems.append((tok, i))
                tok = None
            i += 1
            continue
        if tok is None and not c.isspace():
            tok = i
        i += 1
    if tok is not None:
        elems.append((tok, end))
    return elems

def remove_element(src, start, end, span):
    s, e = span
    j = skip_ws_comments(src, e, end)
    if j < end and src[j] == ",":
        comma = j
        ls = src.rfind("\n", 0, s) + 1
        rm_start = ls if src[ls:s].strip() == "" else s
        rm_end = comma + 1
        k = rm_end
        while k < len(src) and src[k] in " \t":
            k += 1
        if k < len(src) and src[k] == "\n":
            k += 1
        return src[:rm_start] + src[k:]
    j = s - 1
    while j >= 0 and src[j].isspace():
        j -= 1
    if j >= 0 and src[j] == ",":
        comma = j
        ls = src.rfind("\n", 0, comma) + 1
        rm_start = ls if src[ls:comma].strip() == "" else comma
        k = e
        while k < len(src) and src[k] in " \t":
            k += 1
        if k < len(src) and src[k] == "\n":
            k += 1
        return src[:rm_start] + src[k:]
    return src[:s] + src[e:]

def is_title(raw):
    s = raw.strip()
    if s == '"title"':
        return True
    try:
        obj = json.loads(strip_jsonc(s))
        return isinstance(obj, dict) and obj.get("type") == "title"
    except Exception:
        return False

def drop_trailing_comma(src):
    start, end = find_modules(src)
    if start is None or end is None:
        return src
    spans = split_elements(src, start, end)
    if not spans:
        return src
    s, e = spans[-1]
    j = skip_ws_comments(src, e, end)
    if j < end and src[j] == ",":
        return src[:j] + src[j + 1:]
    return src

def line_indent(src, pos):
    ls = src.rfind("\n", 0, pos) + 1
    prefix = src[ls:pos]
    return prefix if prefix.strip() == "" else ""

def insert_module(src, start, end, spans, module_json):
    indent = ""
    if spans:
        indent = line_indent(src, spans[0][0])
    if not indent:
        indent = "    "
    outer = line_indent(src, end) or ""

    mod = module_json.replace("\n", "\n" + indent)

    title = None
    for sp in spans:
        if is_title(src[sp[0]:sp[1]]):
            title = sp
            break

    if title is None:
        inner = src[start + 1:end]
        if inner.strip() == "":
            return src[:start + 1] + "\n" + indent + mod + "\n" + outer + src[end:]
        return src[:start + 1] + "\n" + indent + mod + "," + src[start + 1:]

    s, e = title
    j = skip_ws_comments(src, e, end)
    if j < end and src[j] == ",":
        # Insert at the start of the next line so a trailing comment on the
        # title line stays where the user put it.
        nl = src.find("\n", j, end)
        if nl != -1 and "/*" not in src[j + 1:nl]:
            return src[:nl] + "\n" + indent + mod + "," + src[nl:]
        return src[:j + 1] + "\n" + indent + mod + "," + src[j + 1:]
    return src[:e] + ",\n" + indent + mod + src[e:]

def write_checked(path, text):
    try:
        json.loads(strip_jsonc(text))
    except Exception as exc:
        print(f"aura: config is not valid JSONC: {exc}", file=sys.stderr)
        sys.exit(1)
    if dry:
        sys.stdout.write(text)
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".aurafetch.tmp")
    tmp.write_text(text, encoding="utf-8")
    try:
        mode = path.stat().st_mode
        os.chmod(tmp, mode)
    except OSError:
        pass
    os.replace(tmp, path)

# ── uninstall path is handled by the caller ────────────────────────────────
if action != "install":
    sys.exit(0)

if create or not config_path.exists():
    modules = [
        "title",
        MODULE,
        {"type": "separator", "string": "─"},
        "os", "host", "kernel", "uptime", "packages", "shell",
        "de", "wm", "theme", "icons", "font", "terminal",
        "cpu", "cpuusage", "gpu", "memory", "swap", "disk",
        "localip", "battery", "poweradapter", "locale",
        "break", "colors",
    ]
    config_obj = {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json",
        "logo": {
            "type": "file",
            "source": logo,
            "color": {"1": color},
            "padding": {"top": 1, "left": 2},
        },
        "display": {"separator": "  "},
        "modules": modules,
    }
    text = json.dumps(config_obj, ensure_ascii=False, indent=4) + "\n"
    write_checked(config_path, text)
    sys.exit(0)

config = config_path.read_text(encoding="utf-8")
start, end = find_modules(config)
if start is None or end is None:
    print('aura: no "modules" array found in the config', file=sys.stderr)
    sys.exit(1)

# drop any previous AuraFetch module(s), including the old installer's
while True:
    spans = split_elements(config, start, end)
    ours = [sp for sp in spans if "random-text.sh" in config[sp[0]:sp[1]]]
    if not ours:
        break
    config = remove_element(config, start, end, ours[0])
    start, end = find_modules(config)
    if start is None or end is None:
        print('aura: lost the "modules" array while patching', file=sys.stderr)
        sys.exit(1)

spans = split_elements(config, start, end)
module_json = json.dumps(MODULE, ensure_ascii=False, indent=4)
config = insert_module(config, start, end, spans, module_json)
config = drop_trailing_comma(config)
write_checked(config_path, config)

# sanity: exactly one module refers to our engine
parsed = json.loads(strip_jsonc(config))
mods = parsed.get("modules", [])
count = sum(1 for m in mods if isinstance(m, dict) and "random-text.sh" in str(m.get("text", "")))
if count != 1:
    print(f"aura: expected 1 module, found {count}", file=sys.stderr)
    sys.exit(1)
PY
}

if (( DRY_RUN )); then
    printf '\n   %sdry run — config preview below, nothing written.%s\n\n' "$YELLOW" "$RESET"
    run_patcher || die "the config preview failed"
    printf '\n'
    exit 0
fi

# ── write files ─────────────────────────────────────────────────────────────
mkdir -p "$CONFIG_DIR" || die "could not create $CONFIG_DIR"

CONFIG_EXISTED=0
BACKUP=""
if [[ -f $CONFIG ]]; then
    CONFIG_EXISTED=1
    BACKUP="$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
    cp -L -- "$CONFIG" "$BACKUP" || die "could not back up $CONFIG"
fi

# engine
if [[ $ENGINE_SRC != "$SCRIPT_DST" ]]; then
    install -m 755 -- "$ENGINE_SRC" "$SCRIPT_DST" 2>/dev/null \
        || { cp -- "$ENGINE_SRC" "$SCRIPT_DST" && chmod 755 "$SCRIPT_DST"; } \
        || die "could not install $SCRIPT_DST"
    ok "engine → $SCRIPT_DST"
else
    chmod 755 "$SCRIPT_DST" 2>/dev/null || true
    ok "engine kept at $SCRIPT_DST"
fi

# settings
SETTINGS_TMP="$SETTINGS_DST.tmp.$$"
cat > "$SETTINGS_TMP" <<EOF
# AuraFetch settings — re-run install.sh to regenerate.
# style: card | line | minimal
STYLE="$STYLE_NAME"
# mode: daily | random
MODE="$MODE_NAME"
# packs: all, or a comma-separated list (stoic,tech,folk,...)
CATEGORIES="$SELECTED_PACKS"
# truecolor accents used when aura is run directly in a terminal
ACCENT="$THEME_COLOR"
ACCENT2="$THEME_COLOR2"
# fastfetch colour name used for this module
ACCENT_NAME="$THEME_FFCOLOR"
# width of the quote card in characters
WIDTH="$WIDTH"
# typewriter animation when run directly: 0 or 1
ANIMATE="0"
EOF
mv -f -- "$SETTINGS_TMP" "$SETTINGS_DST" || die "could not write $SETTINGS_DST"
ok "theme → $THEME ($THEME_COLOR, $THEME_FFCOLOR)"

# custom quote file
if [[ ! -f $QUOTES_LOCAL ]]; then
    printf '# AuraFetch custom quotes — format: category|author|quote\n' > "$QUOTES_LOCAL" \
        && ok "custom quotes → $QUOTES_LOCAL"
fi

# logo, only if there isn't one already
if [[ ! -f $LOGO_DST ]]; then
    if [[ -n $SELF_DIR && -f "$SELF_DIR/logo.txt" ]]; then
        cp -- "$SELF_DIR/logo.txt" "$LOGO_DST" || die "could not write $LOGO_DST"
    else
        cat > "$LOGO_DST" <<'LOGO'
        ▄▄███████▄▄
      ▄███▀     ▀███▄
     ███▀    ◉    ▀███
     ███           ███
     ▀███         ███▀
      ▀███▄     ▄███▀
        ▀▀███████▀▀
LOGO
    fi
    ok "logo → $LOGO_DST"
fi

# patch the config
if ! run_patcher; then
    if (( CONFIG_EXISTED == 0 )); then rm -f -- "$CONFIG"; fi
    [[ -n $BACKUP ]] && cp -L -- "$BACKUP" "$CONFIG"
    die "config patch failed — nothing was lost"
fi
if (( CONFIG_EXISTED )); then
    ok "config → $CONFIG"
    note "backup: $BACKUP"
else
    ok "fresh config → $CONFIG"
fi

# engine self-test from its final home
if ! bash "$SCRIPT_DST" --json --seed 1 >/dev/null 2>&1; then
    if (( CONFIG_EXISTED == 0 )); then rm -f -- "$CONFIG"; fi
    [[ -n $BACKUP ]] && cp -L -- "$BACKUP" "$CONFIG"
    die "engine self-test failed — config restored"
fi
ok "self-test passed"

# aura command
if (( NO_LINK )); then
    note "skipped ~/.local/bin/aura (--no-link)"
elif [[ -e $BIN_LINK || -L $BIN_LINK ]]; then
    if [[ -L $BIN_LINK && $(readlink -- "$BIN_LINK" 2>/dev/null) == "$SCRIPT_DST" ]]; then
        ok "command → $BIN_LINK (already linked)"
    else
        warn "$BIN_LINK already exists — leaving it alone"
    fi
else
    if mkdir -p "$BIN_DIR" 2>/dev/null && ln -s -- "$SCRIPT_DST" "$BIN_LINK" 2>/dev/null; then
        ok "command → $BIN_LINK"
        case ":$PATH:" in
            *":$BIN_DIR:"*) ;;
            *) warn "add ~/.local/bin to PATH to use the aura command" ;;
        esac
    else
        warn "could not create $BIN_LINK"
    fi
fi

printf '\n'
hr
printf '  %sAuraFetch is installed.%s\n' "$BOLD$GREEN" "$RESET"
printf '  %srun%s  fastfetch\n' "$MUTED" "$RESET"
printf '  %stry%s  aura --animate\n' "$MUTED" "$RESET"
printf '  %sadd%s  aura --add "Your quote" --author "You"\n' "$MUTED" "$RESET"
hr
printf '\n'

if (( HAS_FASTFETCH && ! NO_RUN )) && [[ -t 1 ]]; then
    printf '  %slaunching fastfetch…%s\n\n' "$DIM" "$RESET"
    fastfetch || warn "fastfetch exited with an error"
fi
