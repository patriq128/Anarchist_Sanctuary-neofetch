#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
RANDOM_SCRIPT="$CONFIG_DIR/random-text.sh"

# Farby na ukážku
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
MAGENTA=$'\033[35m'
CYAN=$'\033[36m'
WHITE=$'\033[37m'
RESET=$'\033[0m'

echo -e "${CYAN}╭────────────────────────────────────╮${RESET}"
echo -e "${CYAN}│   Fastfetch Random Text Installer  │${RESET}"
echo -e "${CYAN}╰────────────────────────────────────╯${RESET}"
echo

# Kontrola závislostí
if ! command -v fastfetch >/dev/null 2>&1; then
    echo -e "${RED}Chyba:${RESET} Fastfetch nie je nainštalovaný."
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}Chyba:${RESET} Python 3 nie je nainštalovaný."
    exit 1
fi

mkdir -p "$CONFIG_DIR"

# Nájdeme konfiguráciu alebo vygenerujeme novú
if [[ -f "$CONFIG_DIR/config.jsonc" ]]; then
    CONFIG="$CONFIG_DIR/config.jsonc"
elif [[ -f "$CONFIG_DIR/config.json" ]]; then
    CONFIG="$CONFIG_DIR/config.json"
else
    echo "Konfigurácia sa nenašla. Generujem novú..."
    fastfetch --gen-config

    if [[ -f "$CONFIG_DIR/config.jsonc" ]]; then
        CONFIG="$CONFIG_DIR/config.jsonc"
    elif [[ -f "$CONFIG_DIR/config.json" ]]; then
        CONFIG="$CONFIG_DIR/config.json"
    else
        echo -e "${RED}Chyba:${RESET} Fastfetch nevytvoril konfiguračný súbor."
        echo "Skontroluj príkaz: fastfetch --gen-config"
        exit 1
    fi
fi

echo -e "Konfigurácia: ${CYAN}$CONFIG${RESET}"
echo

# Zadanie názvu modulu
read -r -p "Názov modulu (napr. Nice): " MODULE_KEY
MODULE_KEY="${MODULE_KEY:-Random}"

echo
echo "Dostupné farby:"

echo -e "  ${RED}red${RESET}       ${GREEN}green${RESET}     ${YELLOW}yellow${RESET}    ${BLUE}blue${RESET}"
echo -e "  ${MAGENTA}magenta${RESET}   ${CYAN}cyan${RESET}      ${WHITE}white${RESET}     default"

echo
read -r -p "Farba textu [yellow]: " COLOR
COLOR="${COLOR:-yellow}"

case "$COLOR" in
    red|green|yellow|blue|magenta|cyan|white|default) ;;
    *)
        echo -e "${RED}Neznáma farba:${RESET} $COLOR"
        exit 1
        ;;
esac

case "$COLOR" in
    red)     COLOR_CODE="$RED" ;;
    green)   COLOR_CODE="$GREEN" ;;
    yellow)  COLOR_CODE="$YELLOW" ;;
    blue)    COLOR_CODE="$BLUE" ;;
    magenta) COLOR_CODE="$MAGENTA" ;;
    cyan)    COLOR_CODE="$CYAN" ;;
    white)   COLOR_CODE="$WHITE" ;;
    default) COLOR_CODE="" ;;
esac

echo
echo "Zadaj texty oddelené čiarkou."
echo "Príklad: Hello world, Have a nice day, Linux forever"
read -r -p "Texty: " TEXT_INPUT

if [[ -z "${TEXT_INPUT//[[:space:]]/}" ]]; then
    echo -e "${RED}Chyba:${RESET} Musíš zadať aspoň jeden text."
    exit 1
fi

# Záloha existujúcej konfigurácie
BACKUP="$CONFIG.bak"
cp -a "$CONFIG" "$BACKUP"
echo
echo -e "Záloha konfigurácie: ${GREEN}$BACKUP${RESET}"

# Vytvorenie skriptu a úprava konfigurácie
export CONFIG RANDOM_SCRIPT MODULE_KEY COLOR TEXT_INPUT

python3 <<'PYTHON'
import json
import os
import re
import shlex
import sys
from pathlib import Path

config_path = Path(os.environ["CONFIG"])
script_path = Path(os.environ["RANDOM_SCRIPT"])
module_key = os.environ["MODULE_KEY"]
color = os.environ["COLOR"]
text_input = os.environ["TEXT_INPUT"]

# Čiarkou oddelené texty
texts = [item.strip() for item in text_input.split(",") if item.strip()]

if not texts:
    sys.exit("Chyba: Nebol zadaný žiadny platný text.")

# Vygenerovanie bezpečného Bash skriptu
lines = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "",
    "texts=(",
]

for item in texts:
    lines.append("    " + shlex.quote(item))

lines.extend([
    ")",
    "",
    'printf "%s\\n" "${texts[RANDOM % ${#texts[@]}]}"',
    "",
])

script_path.write_text("\n".join(lines), encoding="utf-8")
script_path.chmod(0o755)

# Farba Fastfetchu
module = {
    "type": "command",
    "key": module_key,
    "text": str(script_path),
    "format": "{result}",
}

if color != "default":
    module["outputColor"] = color

module_json = json.dumps(module, ensure_ascii=False, indent=4)

config = config_path.read_text(encoding="utf-8")

# Nájdeme pole "modules", pričom rešpektujeme reťazce a komentáre JSONC.
key_match = re.search(r'"modules"\s*:', config)
if not key_match:
    sys.exit('Chyba: V konfigurácii sa nenašlo pole "modules".')

i = key_match.end()
while i < len(config) and config[i].isspace():
    i += 1

if i >= len(config) or config[i] != "[":
    sys.exit('Chyba: Pole "modules" nemá platný začiatok "[".')

array_start = i
i += 1
depth = 1
in_string = False
escaped = False
in_line_comment = False
in_block_comment = False
array_end = None

while i < len(config):
    ch = config[i]
    nxt = config[i + 1] if i + 1 < len(config) else ""

    if in_line_comment:
        if ch == "\n":
            in_line_comment = False
        i += 1
        continue

    if in_block_comment:
        if ch == "*" and nxt == "/":
            in_block_comment = False
            i += 2
        else:
            i += 1
        continue

    if in_string:
        if escaped:
            escaped = False
        elif ch == "\\":
            escaped = True
        elif ch == '"':
            in_string = False
        i += 1
        continue

    if ch == "/" and nxt == "/":
        in_line_comment = True
        i += 2
        continue

    if ch == "/" and nxt == "*":
        in_block_comment = True
        i += 2
        continue

    if ch == '"':
        in_string = True
    elif ch == "[":
        depth += 1
    elif ch == "]":
        depth -= 1
        if depth == 0:
            array_end = i
            break

    i += 1

if array_end is None:
    sys.exit('Chyba: Pole "modules" nemá uzatváraciu zátvorku "]".')

# Rozdelíme pole na položky najvyššej úrovne.
# Funguje pre reťazce ("title"), objekty ({...}) aj vnorené polia.
def get_elements(source, start, end):
    elements = []
    i = start + 1
    token_start = None
    depth_stack = []
    in_string = False
    escaped = False
    line_comment = False
    block_comment = False

    while i < end:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < end else ""

        if line_comment:
            if ch == "\n":
                line_comment = False
            i += 1
            continue

        if block_comment:
            if ch == "*" and nxt == "/":
                block_comment = False
                i += 2
            else:
                i += 1
            continue

        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            i += 1
            continue

        if ch == "/" and nxt == "/":
            line_comment = True
            i += 2
            continue

        if ch == "/" and nxt == "*":
            block_comment = True
            i += 2
            continue

        if ch == '"':
            if token_start is None:
                token_start = i
            in_string = True
            i += 1
            continue

        if ch in "[{":
            if token_start is None:
                token_start = i
            depth_stack.append("]" if ch == "[" else "}")
            i += 1
            continue

        if ch in "]}":
            if depth_stack:
                depth_stack.pop()
                i += 1
                continue

            # Klamra zamykająca samo pole modules.
            break

        if ch == "," and not depth_stack:
            if token_start is not None:
                token_end = i
                while token_end > token_start and source[token_end - 1].isspace():
                    token_end -= 1
                if token_start < token_end:
                    elements.append((token_start, token_end))
                token_start = None
            i += 1
            continue

        if token_start is None and not ch.isspace():
            token_start = i

        i += 1

    if token_start is not None:
        token_end = end
        while token_end > token_start and source[token_end - 1].isspace():
            token_end -= 1
        if token_start < token_end:
            elements.append((token_start, token_end))

    return elements

elements = get_elements(config, array_start, array_end)

# Odstránime osamelú úvodnú čiarku po "[" z poškodenej konfigurácie,
# napríklad: "modules": [, "title", ...
between = config[array_start + 1:array_end]
cleaned_between = re.sub(r"^(\s*),", r"\1", between, count=1)

if cleaned_between != between:
    config = config[:array_start + 1] + cleaned_between + config[array_end:]
    # Prepočítame koniec po oprave
    array_end += len(cleaned_between) - len(between)
    elements = get_elements(config, array_start, array_end)

# Ak už náš modul existuje, nahradíme ho namiesto vytvárania duplicity.
existing = None
for start, end in elements:
    item = config[start:end]
    if item.startswith("{") and str(script_path) in item:
        existing = (start, end)
        break

if existing:
    start, end = existing
    config = config[:start] + module_json + config[end:]
    config_path.write_text(config, encoding="utf-8")
    print("Existujúci random-text modul bol aktualizovaný.")
    sys.exit(0)

# Nájdeme reťazcové moduly title a separator.
def is_module_string(item, name):
    try:
        return json.loads(item) == name
    except (json.JSONDecodeError, ValueError):
        return False

title_item = next(
    ((start, end) for start, end in elements
     if is_module_string(config[start:end], "title")),
    None,
)
separator_item = next(
    ((start, end) for start, end in elements
     if is_module_string(config[start:end], "separator")),
    None,
)

# Zachováme odsadenie podľa konfigurácie.
indent = "    "
if title_item:
    line_start = config.rfind("\n", 0, title_item[0]) + 1
    existing_indent = config[line_start:title_item[0]]
    if existing_indent.strip() == "":
        indent = existing_indent

# Pred separator, teda za title, vložíme nový objekt.
if separator_item:
    insert_at = separator_item[0]
    insertion = module_json + ",\n" + indent
    config = config[:insert_at] + insertion + config[insert_at:]

elif title_item:
    # Ak separator chýba, vložíme modul za title.
    _, title_end = title_item
    cursor = title_end

    while cursor < array_end and config[cursor].isspace():
        cursor += 1

    if cursor < array_end and config[cursor] == ",":
        # Čiarka už oddeľuje title od nasledujúcej položky.
        cursor += 1
        config = config[:cursor] + "\n" + indent + module_json + "," + config[cursor:]
    else:
        # Title je posledná položka.
        config = config[:title_end] + ",\n" + indent + module_json + config[title_end:]

else:
    # Ak title neexistuje, pridáme modul na začiatok poľa.
    insert_at = array_start + 1
    config = config[:insert_at] + "\n" + indent + module_json + "," + config[insert_at:]

config_path.write_text(config, encoding="utf-8")
print("Random-text modul bol pridaný do konfigurácie.")
PYTHON

echo
echo -e "${GREEN}Hotovo!${RESET}"
echo -e "Skript: ${CYAN}$RANDOM_SCRIPT${RESET}"
echo -e "Konfigurácia: ${CYAN}$CONFIG${RESET}"
echo
echo -e "Ukážka vybranej farby: ${COLOR_CODE}Random text module${RESET}"
echo
echo "Spúšťam Fastfetch..."
fastfetch
