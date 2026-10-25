# ✦ AuraFetch

**A daily spark for your `fastfetch`.** 162 curated quotes, twelve packs, eight
themes, and a card that makes your terminal feel like it has a personality.

> The cooler remake of `Random_text-fastfetch`.

```
╭─ ◆ STOIC ──────────────────────────────────╮
│ “You have power over your mind — not       │
│ outside events. Realize this, and you will │
│ find strength.”                            │
│                                            │
│                          — Marcus Aurelius │
╰────────────────────────────────────────────╯
```

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/patriq128/Random_text-fastfetch/main/install.sh)
```

The installer walks you through theme, style, mode and quote packs. To skip the
questions and take the defaults:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/patriq128/Random_text-fastfetch/main/install.sh) --yes
```

Already cloned the repo?

```bash
bash install.sh
```

Then run:

```bash
fastfetch
```

**Requirements:** `bash` and `fastfetch`; `python3` for the installer (it patches
your fastfetch config safely). No runtime dependencies — the quote engine is a
single bash script.

## What you get

- **162 hand-picked quotes** across 12 packs — stoic, philosophy, zen, tech,
  code, life, humor, cinema, chaos, literature, cosmos and folk (including
  Slovak proverbs).
- **A quote of the day** that changes at midnight, or a **fresh random quote**
  on every fetch. Random mode even avoids repeating itself twice in a row.
- **Three styles** — a framed card, a compact one-liner, or just the words.
- **Eight themes** — each theme tints the card in your terminal and picks the
  nearest named colour for `fastfetch`.
- **Your own quotes** with `aura --add`, no file editing required.
- **A real CLI** — list packs, preview styles, print JSON, animate the text.
- **Safe installs** — config backups, JSONC-aware patching, validation, and an
  idempotent re-run. Uninstall leaves your own quotes and logo alone.

## The command

The installer symlinks the engine to `~/.local/bin/aura` (if it can) and adds the
quote module to your fastfetch config.

```bash
aura                          # today's quote
aura --animate                # typewriter mode
aura --mode random            # surprise me
aura --style line             # compact
aura --pack stoic,tech        # only these packs
aura --list                   # all packs and counts
aura --list folk              # every folk quote
aura --add "Ship it." --author "You" --category code
aura --json                   # machine-readable output
aura --seed 2026              # deterministic pick
aura --packs                  # pipe-separated pack list
```

Flags override `aura.conf`; everything is optional.

### Packs

| pack | quotes | vibe |
| --- | ---: | --- |
| `stoic` ◆ | 13 | Marcus Aurelius, Seneca, Epictetus |
| `philosophy` ∞ | 15 | Socrates to Camus |
| `zen` ○ | 10 | breathe, let go, chop wood |
| `tech` λ | 17 | Turing, Hopper, Dijkstra, Knuth |
| `code` `</>` | 14 | bugs, recursion, and `127.0.0.1` |
| `life` ✦ | 14 | courage, habits, small steps |
| `humor` `:)` | 12 | too many tabs open |
| `cinema` ▸ | 15 | Yoda, Casablanca, Fight Club |
| `chaos` ! | 9 | "This is fine." |
| `literature` ¶ | 15 | Shakespeare to Vonnegut |
| `cosmos` ✧ | 12 | mostly Carl Sagan |
| `folk` § | 16 | proverbs, including Slovak ones |

### Themes

| theme | colour | fastfetch |
| --- | --- | --- |
| `aura` | `#5EEAD4` | cyan |
| `cyber` | `#FF3CAC` | magenta |
| `matrix` | `#4ADE80` | green |
| `dracula` | `#BD93F9` | magenta |
| `gruvbox` | `#FABD2F` | yellow |
| `ice` | `#38BDF8` | blue |
| `ember` | `#F87171` | red |
| `mono` | `#E5E7EB` | white |

Direct terminal output uses truecolor and a subtle gradient. Inside `fastfetch`
the script stays plain, and fastfetch colours the whole card with the theme's
named colour — no broken escape codes.

## Your own quotes

```bash
aura --add "The best way out is always through." \
  --author "Robert Frost" \
  --category life
```

That appends to `~/.config/fastfetch/quotes.local.txt`:

```
category|author|quote
```

You can edit that file by hand. Blank lines and lines starting with `#` are
ignored. Custom categories show up automatically in `aura --list` and
`aura --packs`.

> Daily mode picks one quote per day, so a new addition may not appear until
> tomorrow. Use `aura --mode random` to see it immediately.

## Installer options

| flag | meaning |
| --- | --- |
| `--theme NAME` | `aura`, `cyber`, `matrix`, `dracula`, `gruvbox`, `ice`, `ember`, `mono` |
| `--style NAME` | `card`, `line`, `minimal` |
| `--mode NAME` | `daily`, `random` |
| `--packs LIST` | e.g. `stoic,tech` or `all` |
| `--width N` | card width, 30–100 (default `46`) |
| `--key TEXT` | module key; defaults to hidden (`" "`) |
| `--config PATH` | patch a specific fastfetch config |
| `--engine PATH` | use a local `random-text.sh` instead of downloading |
| `--no-link` | don't create `~/.local/bin/aura` |
| `--dry-run` | print the patched config, write nothing |
| `--no-run` | don't launch fastfetch after installing |
| `--yes` | accept the defaults, no prompts |
| `--uninstall` | remove the module and AuraFetch files |
| `--no-color` | plain installer output (also honours `NO_COLOR`) |

Examples:

```bash
bash install.sh --theme cyber --style card --mode random --packs all
bash install.sh --dry-run --theme matrix
bash install.sh --uninstall
```

## What gets installed

```
~/.config/fastfetch/
├── random-text.sh      the quote engine
├── aura.conf           style / mode / packs / colours
├── quotes.local.txt    your additions
├── logo.txt            only if you didn't already have one
└── config.jsonc        patched; a timestamped .bak is created first
~/.local/bin/aura       symlink to the engine
```

The installer never overwrites an existing logo, and re-running it updates the
module in place instead of adding duplicates.

## Customising by hand

`aura.conf` is plain `key="value"`:

```ini
STYLE="card"            # card | line | minimal
MODE="daily"            # daily | random
CATEGORIES="all"        # all, or stoic,tech,folk
ACCENT="#5EEAD4"        # direct-terminal border colour
ACCENT2="#3B82F6"       # gradient colour
WIDTH="46"              # card width
ANIMATE="0"             # 1 = typewriter when run directly
```

Prefer a different module position? Move the command entry in your fastfetch
config. Want a visible key? Set `"key": "✦"` — but keep it hidden (`" "`) for the
card style, otherwise the key is printed on every card line.

## Uninstall

```bash
bash install.sh --uninstall
```

This removes the module from your fastfetch config (with a backup), deletes the
engine and settings, removes the `aura` symlink if it points at AuraFetch, and
**keeps** `quotes.local.txt` and `logo.txt`.

## Troubleshooting

**`aura: command not found`** — add `~/.local/bin` to your `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

**The quote doesn't change.** Daily mode is doing its job. Set
`MODE="random"` in `aura.conf`, run `aura --mode random`, or wait for midnight.

**No colour in `fastfetch`.** That is intentional: fastfetch's `outputColor`
colours the card. Run `aura` directly in a terminal for the full truecolor
gradient.

**The card wraps awkwardly.** Lower the card width:

```bash
bash install.sh --width 40
```

**A backup?** Every config edit creates `config.jsonc.bak.YYYYMMDD-HHMMSS`
next to your config.

## Slovensky

Rýchly štart:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/patriq128/Random_text-fastfetch/main/install.sh)
```

Inštalátor sa spýta na tému, štýl, režim a balíčky citátov. Potom stačí spustiť
`fastfetch`. Cez terminál máš aj príkaz `aura`:

```bash
aura --animate          # písací efekt
aura --mode random      # náhodný citát pri každom spustení
aura --list             # zoznam balíčkov
aura --add "Text" --author "Autor" --category life
```

Vlastné citáty sa ukladajú do `~/.config/fastfetch/quotes.local.txt` v tvare
`kategória|autor|citát`. Odinštalovanie: `bash install.sh --uninstall`.

## License

MIT © ZiDi
