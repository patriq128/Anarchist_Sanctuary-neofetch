#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
SCRIPT="$CONFIG_DIR/random-text.sh"

# --------------------------------------------------
# Check dependencies
# --------------------------------------------------

if ! command -v fastfetch >/dev/null 2>&1; then
    echo "Error: Fastfetch is not installed."
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: Python 3 is not installed."
    exit 1
fi

mkdir -p "$CONFIG_DIR"

# --------------------------------------------------
# Find or generate Fastfetch configuration
# --------------------------------------------------

CONFIG=""

for file in "$CONFIG_DIR/config.jsonc" "$CONFIG_DIR/config.json"; do
    if [[ -f "$file" ]]; then
        CONFIG="$file"
        break
    fi
done

if [[ -z "$CONFIG" ]]; then
    fastfetch --gen-config >/dev/null 2>&1 || true

    for file in "$CONFIG_DIR/config.jsonc" "$CONFIG_DIR/config.json"; do
        if [[ -f "$file" ]]; then
            CONFIG="$file"
            break
        fi
    done
fi

if [[ -z "$CONFIG" ]]; then
    CONFIG="$CONFIG_DIR/config.jsonc"
    printf '{\n  "modules": []\n}\n' > "$CONFIG"
fi

# --------------------------------------------------
# Welcome
# --------------------------------------------------

clear

echo
echo "  ========================================"
echo "       FASTFETCH RANDOM TEXT INSTALLER"
echo "  ========================================"
echo
echo "  Create your own random text module!"
echo

# --------------------------------------------------
# Module label
# --------------------------------------------------

while true; do
    read -r -p "Module label (e.g. Ⓐ, Quote, Meme): " MODULE_LABEL

    if [[ -n "${MODULE_LABEL//[[:space:]]/}" ]]; then
        break
    fi

    echo "Please enter a module label."
done

# --------------------------------------------------
# Color selector
# --------------------------------------------------

echo
echo "Choose your output color:"
echo

printf '  1) \033[41m   \033[0m Red\n'
printf '  2) \033[42m   \033[0m Green\n'
printf '  3) \033[43m   \033[0m Yellow\n'
printf '  4) \033[44m   \033[0m Blue\n'
printf '  5) \033[45m   \033[0m Magenta\n'
printf '  6) \033[46m   \033[0m Cyan\n'
printf '  7) \033[47m   \033[0m White\n'

echo

while true; do
    read -r -p "Select a color [1-7]: " COLOR_CHOICE

    case "$COLOR_CHOICE" in
        1) OUTPUT_COLOR="red";     break ;;
        2) OUTPUT_COLOR="green";   break ;;
        3) OUTPUT_COLOR="yellow";  break ;;
        4) OUTPUT_COLOR="blue";    break ;;
        5) OUTPUT_COLOR="magenta"; break ;;
        6) OUTPUT_COLOR="cyan";    break ;;
        7) OUTPUT_COLOR="white";   break ;;
        *) echo "Invalid selection. Choose a number from 1 to 7." ;;
    esac
done

# --------------------------------------------------
# Custom texts
# --------------------------------------------------

echo
echo "Enter the texts you want Fastfetch to display."
echo "Separate each text with a comma."
echo
echo "Example:"
echo "hello world, nice, skibidi toilet"
echo

while true; do
    read -r -p "Your texts: " TEXT_INPUT

    if [[ -n "${TEXT_INPUT//[[:space:]]/}" ]]; then
        break
    fi

    echo "Please enter at least one text."
done

# --------------------------------------------------
# Create the random text script
# --------------------------------------------------

python3 - "$SCRIPT" "$TEXT_INPUT" <<'PY'
import shlex
import sys
from pathlib import Path

script_path = Path(sys.argv[1])
raw_texts = sys.argv[2]

texts = [
    item.strip()
    for item in raw_texts.split(",")
    if item.strip()
]

if not texts:
    raise SystemExit("Error: No valid texts were provided.")

content = """#!/usr/bin/env bash
set -euo pipefail

texts=(
"""

for item in texts:
    content += f"    {shlex.quote(item)}\n"

content += """)
printf '%s\\n' "${texts[RANDOM % ${#texts[@]}]}"
"""

script_path.write_text(content, encoding="utf-8")
script_path.chmod(0o755)

print()
print(f"Random text script created: {script_path}")
print(f"Available texts: {len(texts)}")
PY

# --------------------------------------------------
# Add or update the Fastfetch module
# --------------------------------------------------

python3 - "$CONFIG" "$SCRIPT" "$MODULE_LABEL" "$OUTPUT_COLOR" <<'PY'
import json
import re
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
script_path = sys.argv[2]
module_label = sys.argv[3]
output_color = sys.argv[4]

config = config_path.read_text(encoding="utf-8")

# Find the modules array.
match = re.search(r'"modules"\s*:\s*\[', config)

if not match:
    raise SystemExit(
        'Error: Could not find the "modules" array. '
        "The configuration was not modified."
    )

start = match.end()

# Find the closing bracket, respecting strings and comments.
depth = 1
i = start
in_string = False
escaped = False
line_comment = False
block_comment = False

while i < len(config):
    c = config[i]
    nxt = config[i + 1] if i + 1 < len(config) else ""

    if line_comment:
        if c == "\n":
            line_comment = False
    elif block_comment:
        if c == "*" and nxt == "/":
            block_comment = False
            i += 1
    elif in_string:
        if escaped:
            escaped = False
        elif c == "\\":
            escaped = True
        elif c == '"':
            in_string = False
    elif c == "/" and nxt == "/":
        line_comment = True
        i += 1
    elif c == "/" and nxt == "*":
        block_comment = True
        i += 1
    elif c == '"':
        in_string = True
    elif c == "[":
        depth += 1
    elif c == "]":
        depth -= 1
        if depth == 0:
            break

    i += 1
else:
    raise SystemExit(
        "Error: The modules array has no closing bracket."
    )

array_end = i

# Parse top-level module objects.
objects = []
obj_start = None
brace_depth = 0
in_string = False
escaped = False
line_comment = False
block_comment = False

j = start

while j < array_end:
    c = config[j]
    nxt = config[j + 1] if j + 1 < array_end else ""

    if line_comment:
        if c == "\n":
            line_comment = False
    elif block_comment:
        if c == "*" and nxt == "/":
            block_comment = False
            j += 1
    elif in_string:
        if escaped:
            escaped = False
        elif c == "\\":
            escaped = True
        elif c == '"':
            in_string = False
    elif c == "/" and nxt == "/":
        line_comment = True
        j += 1
    elif c == "/" and nxt == "*":
        block_comment = True
        j += 1
    elif c == '"':
        in_string = True
    elif c == "{":
        if brace_depth == 0:
            obj_start = j
        brace_depth += 1
    elif c == "}":
        brace_depth -= 1
        if brace_depth == 0 and obj_start is not None:
            objects.append((obj_start, j + 1))
            obj_start = None

    j += 1

# Build the module.
module_data = {
    "type": "command",
    "key": module_label,
    "text": script_path,
    "format": "{result}",
    "outputColor": output_color,
}

module = json.dumps(
    module_data,
    ensure_ascii=False,
    indent=4,
)

module = "\n".join(
    "        " + line
    for line in module.splitlines()
)

# Locate an existing installation of this script.
script_json = json.dumps(script_path, ensure_ascii=False)

script_pattern = re.compile(
    r'"text"\s*:\s*' + re.escape(script_json)
)

existing_module = next(
    (
        (obj_start, obj_end)
        for obj_start, obj_end in objects
        if script_pattern.search(config[obj_start:obj_end])
    ),
    None,
)

if existing_module:
    obj_start, obj_end = existing_module

    config = (
        config[:obj_start]
        + module
        + config[obj_end:]
    )

    action = "updated"
else:
    # Insert immediately after the title module.
    title_module = next(
        (
            (obj_start, obj_end)
            for obj_start, obj_end in objects
            if re.search(
                r'"type"\s*:\s*"title"',
                config[obj_start:obj_end]
            )
        ),
        None,
    )

    if title_module:
        _, title_end = title_module
        insert_at = title_end
        separator = ","
    else:
        insert_at = start
        separator = "," if config[start:array_end].strip() else ""

    config = (
        config[:insert_at]
        + separator
        + "\n"
        + module
        + config[insert_at:]
    )

    action = "added"

config_path.write_text(config, encoding="utf-8")

print()
print(f"Module '{module_label}' was {action}.")
print(f"Output color: {output_color}")
print(f"Configuration: {config_path}")
PY

# --------------------------------------------------
# Finished
# --------------------------------------------------

echo
echo "  ========================================"
echo "       INSTALLATION COMPLETED!"
echo "  ========================================"
echo
echo "  Module: $MODULE_LABEL"
echo "  Color:  $OUTPUT_COLOR"
echo "  Texts:  configured successfully"
echo
echo "  Run 'fastfetch' to see your new module."
echo