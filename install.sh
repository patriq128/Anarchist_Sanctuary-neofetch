
#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/fastfetch"
SCRIPT="$CONFIG_DIR/random-text.sh"

fastfetch --gen-config

# 1. Nájdeme alebo vytvoríme Fastfetch konfiguráciu
if ! command -v fastfetch >/dev/null 2>&1; then
    echo "Fastfetch nie je nainštalovaný."
    exit 1
fi

mkdir -p "$CONFIG_DIR"

CONFIG=""
for file in "$CONFIG_DIR/config.jsonc" "$CONFIG_DIR/config.json"; do
    if [[ -f "$file" ]]; then
        CONFIG="$file"
        break
    fi
done

if [[ -z "$CONFIG" ]]; then
    CONFIG="$CONFIG_DIR/config.jsonc"
    printf '{\n  "modules": []\n}\n' > "$CONFIG"
fi

# 2. Vytvoríme generátor náhodných textov
cat > "$SCRIPT" <<'EOF'
#!/usr/bin/env bash

texts=(
    "They burn my house to the ground..."
    "Insert your random text here."
    "Linux is not an operating system, it's a lifestyle."
)

printf '%s\n' "${texts[RANDOM % ${#texts[@]}]}"
EOF

chmod +x "$SCRIPT"

# 3. Pridáme modul do existujúcej konfigurácie
python3 - "$CONFIG" "$SCRIPT" <<'PY'
import sys
import re
from pathlib import Path

path = Path(sys.argv[1])
script = Path(sys.argv[2])

config = path.read_text()

# Modul už existuje? Nepridávame ho druhýkrát.
if re.search(r'"key"\s*:\s*"Ⓐ"', config):
    print("Modul Ⓐ už existuje, konfiguráciu nemením.")
    sys.exit(0)

# Nájdeme začiatok poľa modules.
match = re.search(r'"modules"\s*:\s*\[', config)
if not match:
    raise SystemExit(
        'Nenašlo sa pole "modules". Konfiguráciu som nezmenil.'
    )

start = match.end()
depth = 1
i = start
in_string = False
escaped = False
line_comment = False
block_comment = False

# Nájdeme správnu uzatváraciu hranatú zátvorku.
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
    raise SystemExit("Pole modules nemá uzatváraciu zátvorku.")

# Overíme, či pole obsahuje aspoň jeden modul.
existing = config[start:i].strip()
prefix = "" if not existing else ","

module = f'''
        {{
            "type": "command",
            "key": "Ⓐ",
            "text": "{script}",
            "format": "{{result}}",
            "outputColor": "red"
        }}'''

updated = config[:i] + prefix + module + "\n    " + config[i:]
path.write_text(updated)

print(f"Modul Ⓐ bol pridaný do {path}")
PY

echo "Hotovo! Spusti fastfetch a skontroluj výsledok."
