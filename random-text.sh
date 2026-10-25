#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  AuraFetch · a daily spark for your fastfetch
#  https://github.com/patriq128/Random_text-fastfetch
#
#  Self-contained quote engine. fastfetch calls it once per fetch; it prints
#  one quote, styled to taste. It also works as a standalone CLI (see --help).
#
#  No runtime dependencies: bash, date, cksum, mkdir. Python is only needed by
#  install.sh to patch the fastfetch config.
# ─────────────────────────────────────────────────────────────────────────────

AURA_VERSION="2.0.0"

set -uo pipefail

# The card is drawn with Unicode and bash counts characters (not bytes) only in
# a UTF-8 locale. If the fetch environment is C/POSIX, quietly pick a UTF-8
# locale when one is available so the box stays aligned.
_aura_locale=${LC_ALL:-${LC_CTYPE:-${LANG:-}}}
case $_aura_locale in
    *UTF-8*|*utf-8*|*UTF8*|*utf8*) ;;
    *)
        if command -v locale >/dev/null 2>&1; then
            _aura_utf8=$(locale -a 2>/dev/null \
                | grep -iE '\.utf-?8$' | head -n 1 || true)
            if [[ -n ${_aura_utf8:-} ]]; then
                LC_ALL=$_aura_utf8
                export LC_ALL
            fi
        fi
        ;;
esac

# ── where am I? ──────────────────────────────────────────────────────────────
# Resolve symlinks so an `aura` symlink in ~/.local/bin still finds aura.conf
# and quotes.local.txt next to the real script.
_resolve_self() {
    local src=${BASH_SOURCE[0]} resolved dir
    if command -v readlink >/dev/null 2>&1; then
        resolved=$(readlink -f -- "$src" 2>/dev/null || true)
        if [[ -n $resolved ]]; then
            printf '%s' "$resolved"
            return
        fi
        # Portable fallback for systems whose readlink has no -f.
        while [[ -L $src ]]; do
            dir=$(CDPATH= cd -- "$(dirname -- "$src")" 2>/dev/null && pwd -P) \
                || break
            src=$(readlink -- "$src") || break
            [[ $src != /* ]] && src="$dir/$src"
        done
    fi
    printf '%s' "$src"
}

SELF_PATH=$(_resolve_self)
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$SELF_PATH")" 2>/dev/null && pwd -P) \
    || SCRIPT_DIR=$(dirname -- "$SELF_PATH")

# ── defaults (overridden by aura.conf, then by CLI flags) ────────────────────
STYLE="card"
MODE="daily"
CATEGORIES="all"
ACCENT="#5EEAD4"
ACCENT2="#3B82F6"
WIDTH="46"
ANIMATE="0"

# ── normalise --flag=value into --flag value ─────────────────────────────────
_norm=()
for _arg in "$@"; do
    case $_arg in
        --*=*) _norm+=("${_arg%%=*}" "${_arg#*=}") ;;
        *)     _norm+=("$_arg") ;;
    esac
done
set -- ${_norm[@]+"${_norm[@]}"}

# ── locate the config directory (pre-scan, settings load needs it) ──────────
CONFIG_DIR="${AURA_CONFIG_DIR:-}"
_argv=("$@")
_i=0
while (( _i < ${#_argv[@]} )); do
    case ${_argv[_i]} in
        --config-dir)
            CONFIG_DIR=${_argv[_i + 1]:-}
            (( _i += 2 ))
            continue
            ;;
    esac
    (( _i++ ))
done

if [[ -z $CONFIG_DIR ]]; then
    CONFIG_DIR=$SCRIPT_DIR
else
    case $CONFIG_DIR in
        /*) ;;
        *)  CONFIG_DIR="$PWD/$CONFIG_DIR" ;;
    esac
fi

SETTINGS_FILE="$CONFIG_DIR/aura.conf"
LOCAL_QUOTES_FILE="$CONFIG_DIR/quotes.local.txt"

# ── tiny helpers ─────────────────────────────────────────────────────────────
die() {
    printf 'aura: %s\n' "$*" >&2
    exit 2
}

# A soft warning: quiet when fastfetch captures stderr.
_warn() {
    [[ -t 2 ]] && printf 'aura: %s\n' "$*" >&2
    return 0
}

_trim() {
    local s=$1
    s=${s#"${s%%[![:space:]]*}"}
    s=${s%"${s##*[![:space:]]}"}
    printf '%s' "$s"
}

_repeat_char() {
    local n=$1 c=$2 out="" i
    for (( i = 0; i < n; i++ )); do out+=$c; done
    printf '%s' "$out"
}

_has_cat() {
    [[ $CATEGORIES == all ]] && return 0
    [[ ",$CATEGORIES," == *",$1,"* ]]
}

category_meta() {
    case $1 in
        stoic)      ICON="◆"; CNAME="STOIC" ;;
        philosophy) ICON="∞"; CNAME="PHILOSOPHY" ;;
        zen)        ICON="○"; CNAME="ZEN" ;;
        tech)       ICON="λ"; CNAME="TECH" ;;
        code)       ICON="</>"; CNAME="CODE" ;;
        life)       ICON="✦"; CNAME="LIFE" ;;
        humor)      ICON=":)"; CNAME="HUMOR" ;;
        cinema)     ICON="▸"; CNAME="CINEMA" ;;
        chaos)      ICON="!"; CNAME="CHAOS" ;;
        literature) ICON="¶"; CNAME="LITERATURE" ;;
        space)      ICON="✧"; CNAME="COSMOS" ;;
        folk)       ICON="§"; CNAME="FOLK" ;;
        *)          ICON="•"; CNAME=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
                    CNAME=${CNAME:0:12} ;;
    esac
}

# ── load aura.conf ───────────────────────────────────────────────────────────
if [[ -r $SETTINGS_FILE ]]; then
    while IFS='=' read -r _k _v; do
        _k=$(_trim "$_k")
        [[ -z $_k || $_k == \#* ]] && continue
        _v=$(_trim "$_v")
        case $_v in
            \"*)
                _v=${_v#\"}
                _v=${_v%%\"*}
                ;;
            \'*)
                _v=${_v#\'}
                _v=${_v%%\'*}
                ;;
            *)
                _v=${_v%%[[:space:]]#*}
                _v=$(_trim "$_v")
                ;;
        esac
        case $_k in
            STYLE)      STYLE=$_v ;;
            MODE)       MODE=$_v ;;
            CATEGORIES) CATEGORIES=$_v ;;
            ACCENT)     ACCENT=$_v ;;
            ACCENT2)    ACCENT2=$_v ;;
            WIDTH)      WIDTH=$_v ;;
            ANIMATE)    ANIMATE=$_v ;;
        esac
    done < "$SETTINGS_FILE"
fi

# ── CLI state ────────────────────────────────────────────────────────────────
COLOR_FORCE=-1          # -1 auto · 1 always · 0 never
STYLE_FROM_CLI=0
MODE_FROM_CLI=0
WIDTH_FROM_CLI=0
JSON_MODE=0
LIST_MODE=0
LIST_PACK=""
PACKS_MODE=0
ADD_MODE=0
ADD_TEXT=""
ADD_AUTHOR="Unknown"
ADD_CAT="custom"
SEED_OVERRIDE=""

usage() {
    cat <<'HELP'
AuraFetch 2.0.0 — a daily spark for your fastfetch

USAGE
  aura [options]          (installed symlink)
  random-text.sh [options]

DISPLAY
  --style card|line|minimal   card (default), one-liner, or bare quote
  --mode daily|random         same quote all day, or a new one each run
  --pack NAMES                comma-separated packs (default: all)
  --width N                   card width, 30-100 (default: 46)
  --accent #RRGGBB            border color for direct terminal output
  --accent2 #RRGGBB           secondary color for the gradient
  --animate, -A               typewriter effect (direct terminal only)
  --color / --no-color        force color on/off (default: auto)
  --seed VALUE                deterministic pick (great for screenshots)
  --json                      print the chosen quote as JSON

QUOTES
  --packs                     machine-readable pack list
  --list [PACK]               list packs, or every quote in PACK
  --add TEXT                  add a custom quote
    --author NAME             author for --add (default: Unknown)
    --category SLUG           category for --add (default: custom)

OTHER
  --config-dir DIR            directory holding aura.conf and local quotes
  -h, --help                  this help
  -V, --version               version

EXAMPLES
  aura --animate
  aura --mode random --style line
  aura --list stoic
  aura --add "Ship it." --author "You" --category code
  aura --seed 2026 --style card --no-color
HELP
}

# ── parse CLI flags ──────────────────────────────────────────────────────────
while (( $# > 0 )); do
    case $1 in
        -h|--help)    usage; exit 0 ;;
        -V|--version) printf 'AuraFetch %s\n' "$AURA_VERSION"; exit 0 ;;
        --style)
            [[ $# -ge 2 ]] || die "--style needs a value"
            STYLE=$2; STYLE_FROM_CLI=1; shift 2 ;;
        --mode)
            [[ $# -ge 2 ]] || die "--mode needs a value"
            MODE=$2; MODE_FROM_CLI=1; shift 2 ;;
        --pack|--categories)
            [[ $# -ge 2 ]] || die "$1 needs a value"
            CATEGORIES=$2; shift 2 ;;
        --width)
            [[ $# -ge 2 ]] || die "--width needs a value"
            WIDTH=$2; WIDTH_FROM_CLI=1; shift 2 ;;
        --accent)
            [[ $# -ge 2 ]] || die "--accent needs a value"
            ACCENT=$2; shift 2 ;;
        --accent2)
            [[ $# -ge 2 ]] || die "--accent2 needs a value"
            ACCENT2=$2; shift 2 ;;
        --seed)
            [[ $# -ge 2 ]] || die "--seed needs a value"
            SEED_OVERRIDE=$2; shift 2 ;;
        --color|--colour)       COLOR_FORCE=1; shift ;;
        --no-color|--no-colour) COLOR_FORCE=0; shift ;;
        --animate|-A)           ANIMATE=1; shift ;;
        --no-animate)           ANIMATE=0; shift ;;
        --json)                 JSON_MODE=1; shift ;;
        --list|-l)
            LIST_MODE=1
            if [[ $# -ge 2 && ${2:-} != -* ]]; then
                LIST_PACK=$2; shift 2
            else
                shift
            fi
            ;;
        --packs)      PACKS_MODE=1; shift ;;
        --add|-a)
            [[ $# -ge 2 ]] || die "--add needs the quote text"
            ADD_MODE=1; ADD_TEXT=$2; shift 2 ;;
        --author)
            [[ $# -ge 2 ]] || die "--author needs a value"
            ADD_AUTHOR=$2; shift 2 ;;
        --category)
            [[ $# -ge 2 ]] || die "--category needs a value"
            ADD_CAT=$2; shift 2 ;;
        --config-dir)
            [[ $# -ge 2 ]] || die "--config-dir needs a value"
            shift 2 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *)  die "unexpected argument: $1 (try --help)" ;;
    esac
done

# ── colour values from settings / CLI ───────────────────────────────────────
# Sanitise these before any colour code is built; --add / --list / --packs
# should still work even if the rest of aura.conf was hand-edited badly.
[[ $ACCENT =~ ^#[0-9A-Fa-f]{6}$ ]]  || ACCENT="#5EEAD4"
[[ $ACCENT2 =~ ^#[0-9A-Fa-f]{6}$ ]] || ACCENT2="#3B82F6"

# ── quote data ───────────────────────────────────────────────────────────────
# format: category|author|quote
BASE_QUOTES=$(cat <<'AURA_QUOTES_EOF'
stoic|Marcus Aurelius|You have power over your mind — not outside events. Realize this, and you will find strength.
stoic|Marcus Aurelius|The happiness of your life depends upon the quality of your thoughts.
stoic|Marcus Aurelius|Waste no more time arguing what a good man should be. Be one.
stoic|Marcus Aurelius|The impediment to action advances action. What stands in the way becomes the way.
stoic|Marcus Aurelius|When you arise in the morning, think of what a precious privilege it is to be alive.
stoic|Seneca|We suffer more often in imagination than in reality.
stoic|Seneca|It is not that we have a short time to live, but that we waste a lot of it.
stoic|Seneca|Luck is what happens when preparation meets opportunity.
stoic|Epictetus|It's not what happens to you, but how you react to it that matters.
stoic|Epictetus|No man is free who is not master of himself.
stoic|Epictetus|First say to yourself what you would be; and then do what you have to do.
stoic|Zeno of Citium|Well-being is realized by small steps, but is truly no small thing.
stoic|Musonius Rufus|If you accomplish something good with hard work, the labor passes quickly, but the good endures.
philosophy|Socrates|The unexamined life is not worth living.
philosophy|Socrates|Wonder is the beginning of wisdom.
philosophy|Plato|The beginning is the most important part of the work.
philosophy|Plato|Courage is knowing what not to fear.
philosophy|Aristotle|The whole is more than the sum of its parts.
philosophy|Friedrich Nietzsche|He who has a why to live can bear almost any how.
philosophy|Søren Kierkegaard|Life can only be understood backwards; but it must be lived forwards.
philosophy|Albert Camus|In the depth of winter, I finally learned that within me there lay an invincible summer.
philosophy|Jean-Paul Sartre|Freedom is what you do with what's been done to you.
philosophy|Laozi|A journey of a thousand miles begins with a single step.
philosophy|Heraclitus|No man ever steps in the same river twice, for it's not the same river and he's not the same man.
philosophy|Ludwig Wittgenstein|The limits of my language mean the limits of my world.
philosophy|Rainer Maria Rilke|Be patient toward all that is unsolved in your heart and try to love the questions themselves.
philosophy|Blaise Pascal|The heart has its reasons of which reason knows nothing.
philosophy|Epicurus|Do not spoil what you have by desiring what you have not.
zen|Zen proverb|Sitting quietly, doing nothing, spring comes, and the grass grows by itself.
zen|Zen proverb|Before enlightenment: chop wood, carry water. After enlightenment: chop wood, carry water.
zen|Zen proverb|The obstacle is the path.
zen|Zen proverb|Let go, or be dragged.
zen|Pema Chödrön|You are the sky. Everything else is just the weather.
zen|Pema Chödrön|Nothing ever goes away until it has taught us what we need to know.
zen|Thich Nhat Hanh|Smile, breathe, and go slowly.
zen|Thich Nhat Hanh|Feelings come and go like clouds in a windy sky. Conscious breathing is my anchor.
zen|Ram Dass|The quieter you become, the more you can hear.
zen|Eckhart Tolle|Wherever you are, be there totally.
tech|Alan Turing|We can only see a short distance ahead, but we can see plenty there that needs to be done.
tech|Grace Hopper|The most dangerous phrase in the language is, 'We've always done it this way.'
tech|Edsger Dijkstra|Simplicity is prerequisite for reliability.
tech|Edsger Dijkstra|Program testing can be used to show the presence of bugs, but never to show their absence!
tech|Donald Knuth|Premature optimization is the root of all evil.
tech|Kent Beck|Make it work, make it right, make it fast.
tech|Linus Torvalds|Talk is cheap. Show me the code.
tech|Rob Pike|Fancy algorithms are slow when n is small, and n is usually small.
tech|Martin Fowler|Any fool can write code that a computer can understand. Good programmers write code that humans can understand.
tech|Brian Kernighan|Debugging is twice as hard as writing the code in the first place.
tech|Bjarne Stroustrup|There are only two kinds of languages: the ones people complain about and the ones nobody uses.
tech|Alan Kay|The best way to predict the future is to invent it.
tech|Alan Kay|Simple things should be simple, complex things should be possible.
tech|John A. Shedd|A ship in port is safe, but that's not what ships are built for.
tech|Reid Hoffman|If you are not embarrassed by the first version of your product, you've launched too late.
tech|Damian Conway|Documentation is a love letter that you write to your future self.
tech|Antoine de Saint-Exupéry|Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away.
code|Unknown|It works on my machine.
code|Unknown|// TODO: fix this later
code|Unknown|99 little bugs in the code, 99 little bugs. Take one down, patch it around, 127 little bugs in the code.
code|Unknown|The code is fine. The tests are wrong.
code|Unknown|I don't always test my code, but when I do, I do it in production.
code|Unknown|A SQL query walks into a bar, walks up to two tables and asks: 'Can I join you?'
code|Unknown|There is no place like 127.0.0.1.
code|Unknown|To understand recursion, you must first understand recursion.
code|Robert A. Heinlein|One man's magic is another man's engineering.
code|Unknown|Real programmers count from 0.
code|Unknown|It compiles — ship it.
code|Unknown|There are 10 types of people: those who understand binary and those who don't.
code|Unknown|I would tell you a UDP joke, but you might not get it.
code|Unknown|The 'S' in IoT stands for security.
life|Theodore Roosevelt|Do what you can, with what you have, where you are.
life|Arthur Ashe|Start where you are. Use what you have. Do what you can.
life|Wayne Gretzky|You miss 100% of the shots you don't take.
life|Henry Ford|Whether you think you can or you think you can't, you're right.
life|John Lennon|Life is what happens when you're busy making other plans.
life|Robert Frost|The only way out is through.
life|Helen Keller|When one door of happiness closes, another opens.
life|George Addair|Everything you've ever wanted is on the other side of fear.
life|C.S. Lewis|You are never too old to set another goal or to dream a new dream.
life|Theodore Roosevelt|Comparison is the thief of joy.
life|Navy SEAL proverb|Slow is smooth, smooth is fast.
life|Jim Rohn|Either you run the day or the day runs you.
life|Maya Angelou|If you don't like something, change it. If you can't change it, change your attitude.
life|Kurt Vonnegut|I urge you to please notice when you are happy, and exclaim or murmur or think at some point, 'If this isn't nice, I don't know what is.'
humor|Unknown|I am not lazy, I am on energy saving mode.
humor|Unknown|My brain has too many tabs open.
humor|Unknown|I'm not procrastinating. I'm prioritizing my future self's problems.
humor|Unknown|Coffee: because adulting is hard.
humor|Unknown|I followed my heart, and it led me to the fridge.
humor|Unknown|I don't need a therapist. I need a nap and a snack.
humor|Unknown|I'm not antisocial. I'm just not interested.
humor|Unknown|Error 404: motivation not found.
humor|Unknown|Today's forecast: 100% chance of procrastination.
humor|Unknown|I'm on a seafood diet. I see food and I eat it.
humor|Unknown|My wallet is like an onion: opening it makes me cry.
humor|Unknown|I plan to be spontaneous tomorrow.
cinema|Star Wars|May the Force be with you.
cinema|The Dark Knight|Why so serious?
cinema|Yoda, The Empire Strikes Back|Do, or do not. There is no try.
cinema|The Terminator|I'll be back.
cinema|Casablanca|Here's looking at you, kid.
cinema|Forrest Gump|Life is like a box of chocolates. You never know what you're gonna get.
cinema|Spider-Man|With great power comes great responsibility.
cinema|The Sixth Sense|I see dead people.
cinema|Apollo 13|Houston, we have a problem.
cinema|Finding Nemo|Just keep swimming.
cinema|Dead Poets Society|Carpe diem. Seize the day, boys. Make your lives extraordinary.
cinema|Casablanca|This is the beginning of a beautiful friendship.
cinema|Fight Club|The first rule of Fight Club is: you do not talk about Fight Club.
cinema|The Mandalorian|This is the Way.
cinema|Obi-Wan Kenobi|Hello there.
chaos|Unknown|They burn my house to the ground...
chaos|KC Green|This is fine.
chaos|Unknown|It was at this moment he knew: he messed up.
chaos|Unknown|But wait, there's more!
chaos|Unknown|Expectation: flawless. Reality: 3 AM debugging.
chaos|Ancient Aliens|I'm not saying it was aliens, but it was aliens.
chaos|Thanos|Reality is often disappointing.
chaos|Unknown|Task failed successfully.
chaos|Unknown|Hold my coffee.
literature|J.R.R. Tolkien|Not all those who wander are lost.
literature|William Shakespeare|There is nothing either good or bad, but thinking makes it so.
literature|William Shakespeare|We are such stuff as dreams are made on.
literature|William Shakespeare|All the world's a stage, and all the men and women merely players.
literature|William Shakespeare|To be, or not to be, that is the question.
literature|Charles Dickens|It was the best of times, it was the worst of times.
literature|William Shakespeare|The readiness is all.
literature|Kurt Vonnegut|So it goes.
literature|Kurt Vonnegut|We are what we pretend to be, so we must be careful about what we pretend to be.
literature|Charlotte Brontë|I am no bird; and no net ensnares me.
literature|Emily Brontë|Whatever our souls are made of, his and mine are the same.
literature|Maya Angelou|There is no greater agony than bearing an untold story inside you.
literature|Harper Lee|You never really understand a person until you consider things from his point of view.
literature|J.K. Rowling|It does not do to dwell on dreams and forget to live.
literature|Stephen King|Books are a uniquely portable magic.
space|Carl Sagan|The cosmos is within us. We are made of star-stuff.
space|Carl Sagan|Somewhere, something incredible is waiting to be known.
space|Carl Sagan|We are a way for the cosmos to know itself.
space|Carl Sagan|If you wish to make an apple pie from scratch, you must first invent the universe.
space|Carl Sagan|For small creatures such as we, the vastness is bearable only through love.
space|Neil deGrasse Tyson|The universe is under no obligation to make sense to you.
space|Konstantin Tsiolkovsky|The Earth is the cradle of humanity, but one cannot live in a cradle forever.
space|Alan Shepard|It's a very sobering feeling to be up in space and realize that one's safety factor was determined by the lowest bidder on a government contract.
space|Arthur C. Clarke|Two possibilities exist: either we are alone in the universe or we are not. Both are equally terrifying.
space|Unknown|The stars are the streetlights of eternity.
space|Carl Sagan|The nitrogen in our DNA, the calcium in our teeth, the iron in our blood, the carbon in our apple pies were made in the interiors of collapsing stars.
space|Unknown|Space is hard.
folk|Slovak proverb|Nádej umiera posledná.
folk|Slovak proverb|Bez práce nie sú koláče.
folk|Slovak proverb|Kto skoro ráno vstáva, tomu Pán Boh dáva.
folk|Slovak proverb|Aká matka, taká Katka.
folk|Slovak proverb|Kto druhému jamu kope, sám do nej spadne.
folk|Slovak proverb|Všetko zlé je na niečo dobré.
folk|Slovak proverb|Trikrát meraj, raz strihaj.
folk|Slovak proverb|Čo môžeš urobiť dnes, neodkladaj na zajtra.
folk|Japanese proverb|Fall seven times, stand up eight.
folk|English proverb|A smooth sea never made a skilled sailor.
folk|Chinese proverb|The best time to plant a tree was twenty years ago. The second best time is now.
folk|Buddhist proverb|When the student is ready, the teacher appears.
folk|Japanese proverb|The nail that sticks out gets hammered down.
folk|Chinese proverb|Do not be afraid of growing slowly; be afraid only of standing still.
folk|Irish blessing|May the road rise up to meet you.
folk|Latin proverb|Fortune favors the bold.
AURA_QUOTES_EOF
)

Q_CAT=()
Q_AUTHOR=()
Q_TEXT=()

_load_quote_line() {
    local line=$1 c a t
    [[ -z $line || $line == \#* ]] && return
    IFS='|' read -r c a t <<< "$line"
    c=$(_trim "${c:-}")
    c=$(printf '%s' "$c" | tr '[:upper:]' '[:lower:]')
    a=$(_trim "${a:-}")
    t=$(_trim "${t:-}")
    [[ -z $c || -z $t ]] && return
    [[ -z $a ]] && a="Unknown"
    Q_CAT+=("$c")
    Q_AUTHOR+=("$a")
    Q_TEXT+=("$t")
}

while IFS= read -r _line; do
    _load_quote_line "$_line"
done <<< "$BASE_QUOTES"

if [[ -r $LOCAL_QUOTES_FILE ]]; then
    while IFS= read -r _line || [[ -n $_line ]]; do
        _load_quote_line "$_line"
    done < "$LOCAL_QUOTES_FILE"
fi

if (( ${#Q_TEXT[@]} == 0 )); then
    Q_CAT=("life"); Q_AUTHOR=("Unknown")
    Q_TEXT=("The only way out is through.")
fi

# ── --add ────────────────────────────────────────────────────────────────────
if (( ADD_MODE )); then
    _text=$ADD_TEXT
    _author=${ADD_AUTHOR:-Unknown}
    _cat=$ADD_CAT
    [[ -n $_text ]] || die "quote text is empty"
    [[ $_text == *$'\n'* || $_text == *$'\r'* ]] && die "quote text must be one line"
    [[ $_text == *$'\t'* ]] && die "quote text cannot contain tabs"
    [[ $_author == *'|'* ]] && die "author cannot contain '|'"
    [[ $_cat == *'|'* ]] && die "category cannot contain '|'"
    _cat=$(printf '%s' "$_cat" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    [[ $_cat =~ ^[a-z0-9][a-z0-9_-]*$ ]] \
        || die "category must be a simple slug (a-z, 0-9, '-' or '_')"
    mkdir -p "$CONFIG_DIR" 2>/dev/null || die "cannot create $CONFIG_DIR"
    if [[ ! -f $LOCAL_QUOTES_FILE ]]; then
        printf '# AuraFetch custom quotes — format: category|author|quote\n' \
            > "$LOCAL_QUOTES_FILE" || die "cannot write $LOCAL_QUOTES_FILE"
    fi
    printf '%s|%s|%s\n' "$_cat" "$_author" "$_text" >> "$LOCAL_QUOTES_FILE" \
        || die "cannot append to $LOCAL_QUOTES_FILE"
    printf '✓ added to %s\n' "$LOCAL_QUOTES_FILE"
    printf '  %s|%s|%s\n' "$_cat" "$_author" "$_text"
    [[ $MODE == daily ]] && printf 'daily mode is on — it may not show up until tomorrow\n'
    exit 0
fi

# ── unique packs, in data order ──────────────────────────────────────────────
PACK_NAMES=()
_pack_seen=","
for (( _j = 0; _j < ${#Q_TEXT[@]}; _j++ )); do
    _pc=${Q_CAT[_j]}
    [[ $_pack_seen == *",$_pc,"* ]] && continue
    _pack_seen="$_pack_seen$_pc,"
    PACK_NAMES+=("$_pc")
done

_pack_count() {
    local want=$1 i n=0
    for (( i = 0; i < ${#Q_TEXT[@]}; i++ )); do
        [[ ${Q_CAT[i]} == "$want" ]] && (( n++ ))
    done
    printf '%s' "$n"
}

# ── --packs (machine readable) ──────────────────────────────────────────────
if (( PACKS_MODE )); then
    for _pc in "${PACK_NAMES[@]}"; do
        category_meta "$_pc"
        printf '%s|%s|%s|%s\n' "$_pc" "$(_pack_count "$_pc")" "$ICON" "$CNAME"
    done
    exit 0
fi

# ── colour setup ─────────────────────────────────────────────────────────────
USE_COLOR=0
if (( COLOR_FORCE == 1 )); then
    USE_COLOR=1
elif (( COLOR_FORCE == 0 )); then
    USE_COLOR=0
elif [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    USE_COLOR=1
fi

hex_rgb() {
    local h=${1#\#}
    HR=$(( 16#${h:0:2} ))
    HG=$(( 16#${h:2:2} ))
    HB=$(( 16#${h:4:2} ))
}
hex_rgb "$ACCENT";  AR=$HR AG=$HG AB=$HB
hex_rgb "$ACCENT2"; BR=$HR BG=$HG BB=$HB

C_RESET=$'\033[0m'
C_BORDER=""
C_ACCENT2=""
C_AUTHOR=""
C_QUOTE=""
if (( USE_COLOR )); then
    C_BORDER=$(printf '\033[38;2;%d;%d;%dm' "$AR" "$AG" "$AB")
    C_ACCENT2=$(printf '\033[38;2;%d;%d;%dm' "$BR" "$BG" "$BB")
    C_AUTHOR=$C_ACCENT2
fi

_gradient_text() {
    local text=$1
    local n=${#text} i den r g b
    den=$(( n > 1 ? n - 1 : 1 ))
    for (( i = 0; i < n; i++ )); do
        r=$(( AR + (BR - AR) * i / den ))
        g=$(( AG + (BG - AG) * i / den ))
        b=$(( AB + (BB - AB) * i / den ))
        printf '\033[38;2;%d;%d;%dm%s' "$r" "$g" "$b" "${text:i:1}"
    done
    printf '%s' "$C_RESET"
}

_print_animated_words() {
    local text=$1 color=$2
    local -a words
    local w first=1
    read -ra words <<< "$text"
    for w in "${words[@]}"; do
        (( first )) || printf ' '
        first=0
        if (( USE_COLOR )); then
            printf '%s%s%s' "$color" "$w" "$C_RESET"
        else
            printf '%s' "$w"
        fi
        sleep "${AURA_TYPE_DELAY:-0.045}" 2>/dev/null || true
    done
}

_wrap_text() {
    local text=$1 width=$2
    local -a words
    local word line=""
    WRAP_RESULT=()
    read -ra words <<< "$text"
    for word in "${words[@]}"; do
        while (( ${#word} > width )); do
            [[ -n $line ]] && { WRAP_RESULT+=("$line"); line=""; }
            WRAP_RESULT+=("${word:0:width}")
            word=${word:width}
        done
        if [[ -z $line ]]; then
            line=$word
        elif (( ${#line} + 1 + ${#word} <= width )); then
            line+=" $word"
        else
            WRAP_RESULT+=("$line")
            line=$word
        fi
    done
    [[ -n $line ]] && WRAP_RESULT+=("$line")
    (( ${#WRAP_RESULT[@]} == 0 )) && WRAP_RESULT=("")
}

# ── --list ───────────────────────────────────────────────────────────────────
if (( LIST_MODE )); then
    LIST_PACK=$(printf '%s' "$LIST_PACK" | tr '[:upper:]' '[:lower:]')
    if [[ -z $LIST_PACK ]]; then
        printf 'AuraFetch packs · %d quotes in %d packs\n\n' \
            "${#Q_TEXT[@]}" "${#PACK_NAMES[@]}"
        for _pc in "${PACK_NAMES[@]}"; do
            category_meta "$_pc"
            _n=$(_pack_count "$_pc")
            if (( USE_COLOR )); then
                printf '  %s%-3s%s %-14s %s%3d%s quotes\n' \
                    "$C_ACCENT2" "$ICON" "$C_RESET" "$CNAME" \
                    "$C_ACCENT2" "$_n" "$C_RESET"
            else
                printf '  %-3s %-14s %3d quotes\n' "$ICON" "$CNAME" "$_n"
            fi
        done
        exit 0
    fi

    _found=0
    _n=0
    for _pc in "${PACK_NAMES[@]}"; do
        [[ $_pc == "$LIST_PACK" ]] && _found=1
    done
    if (( ! _found )); then
        printf 'aura: no such pack: %s\n' "$LIST_PACK" >&2
        printf 'available: %s\n' "${PACK_NAMES[*]}" >&2
        exit 1
    fi
    category_meta "$LIST_PACK"
    printf '%s %s\n\n' "$ICON" "$CNAME"
    for (( _j = 0; _j < ${#Q_TEXT[@]}; _j++ )); do
        [[ ${Q_CAT[_j]} == "$LIST_PACK" ]] || continue
        (( _n++ ))
        if (( USE_COLOR )); then
            printf '  %2d. %s“%s”%s %s— %s%s\n' \
                "$_n" "" "${Q_TEXT[_j]}" "$C_RESET" \
                "$C_ACCENT2" "${Q_AUTHOR[_j]}" "$C_RESET"
        else
            printf '  %2d. “%s” — %s\n' \
                "$_n" "${Q_TEXT[_j]}" "${Q_AUTHOR[_j]}"
        fi
    done
    exit 0
fi

# ── validate display settings (only needed for rendering) ───────────────────
# Bad values in aura.conf fall back to defaults so a typo can't break your
# fetch; bad values passed on the command line still error out.
STYLE=$(printf '%s' "${STYLE:-card}" | tr '[:upper:]' '[:lower:]')
MODE=$(printf '%s' "${MODE:-daily}" | tr '[:upper:]' '[:lower:]')
case $STYLE in
    card|line|minimal) ;;
    *)
        if (( STYLE_FROM_CLI )); then
            die "unknown style '$STYLE' (use card, line, or minimal)"
        fi
        _warn "unknown style '$STYLE' in aura.conf; using card"
        STYLE=card
        ;;
esac
case $MODE in
    daily|random) ;;
    *)
        if (( MODE_FROM_CLI )); then
            die "unknown mode '$MODE' (use daily or random)"
        fi
        _warn "unknown mode '$MODE' in aura.conf; using daily"
        MODE=daily
        ;;
esac

if [[ $WIDTH =~ ^[0-9]+$ ]]; then
    WIDTH=$(( 10#$WIDTH ))
    if (( WIDTH < 30 || WIDTH > 100 )); then
        if (( WIDTH_FROM_CLI )); then
            die "width must be between 30 and 100"
        fi
        _warn "width $WIDTH out of range in aura.conf; using 46"
        WIDTH=46
    fi
else
    if (( WIDTH_FROM_CLI )); then
        die "width must be a number"
    fi
    _warn "invalid width '$WIDTH' in aura.conf; using 46"
    WIDTH=46
fi

ANIMATE=$(printf '%s' "$ANIMATE" | tr '[:upper:]' '[:lower:]')
case $ANIMATE in
    1|true|yes|on) ANIMATE=1 ;;
    *)             ANIMATE=0 ;;
esac

CATEGORIES=$(printf '%s' "${CATEGORIES:-all}" \
    | tr '[:upper:]' '[:lower:]' | tr -d ' ')
[[ -z $CATEGORIES ]] && CATEGORIES=all

ANIMATE_ON=0
if [[ $ANIMATE == 1 && -t 1 ]]; then
    ANIMATE_ON=1
fi

# ── pick a quote ─────────────────────────────────────────────────────────────
M_IDX=()
for (( _j = 0; _j < ${#Q_TEXT[@]}; _j++ )); do
    _has_cat "${Q_CAT[_j]}" && M_IDX+=("$_j")
done

if (( ${#M_IDX[@]} == 0 )); then
    if [[ $CATEGORIES != all ]]; then
        # Keep stderr clean when fastfetch captures the output.
        [[ -t 2 ]] && printf 'aura: no quotes in pack(s) "%s"; using all packs.\n' \
            "$CATEGORIES" >&2
        CATEGORIES=all
    fi
    M_IDX=()
    for (( _j = 0; _j < ${#Q_TEXT[@]}; _j++ )); do
        M_IDX+=("$_j")
    done
fi

if [[ $MODE == daily ]]; then
    _seed=${SEED_OVERRIDE:-$(date +%F)}
    _hash=$(printf '%s|%s|%s' "$_seed" "$CATEGORIES" "aurafetch" \
        | LC_ALL=C cksum | cut -d' ' -f1)
    _pick=$(( _hash % ${#M_IDX[@]} ))
    IDX=${M_IDX[_pick]}
else
    if [[ $SEED_OVERRIDE =~ ^[0-9]+$ ]]; then
        RANDOM=$(( 10#$SEED_OVERRIDE % 32768 ))
    fi
    _pick=$(( RANDOM % ${#M_IDX[@]} ))
    IDX=${M_IDX[_pick]}

    # avoid showing the same quote twice in a row in random mode
    # (an explicit --seed means "reproduce this", so skip the history)
    if [[ -z $SEED_OVERRIDE ]]; then
        _cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/aurafetch"
        _state="$_cache_dir/last"
        _last=""
        [[ -r $_state ]] && { IFS= read -r _last < "$_state" || true; }
        if (( ${#M_IDX[@]} > 1 )) && [[ $_last =~ ^[0-9]+$ ]] \
            && (( _last == IDX )); then
            IDX=${M_IDX[((_pick + 1) % ${#M_IDX[@]})]}
        fi
        if mkdir -p "$_cache_dir" 2>/dev/null; then
            printf '%s\n' "$IDX" > "$_state" 2>/dev/null || true
        fi
    fi
fi

QUOTE=${Q_TEXT[IDX]}
AUTHOR=${Q_AUTHOR[IDX]}
QCAT=${Q_CAT[IDX]}

# ── --json ───────────────────────────────────────────────────────────────────
_json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

if (( JSON_MODE )); then
    category_meta "$QCAT"
    printf '{"category":"%s","author":"%s","quote":"%s","icon":"%s","mode":"%s","style":"%s"}\n' \
        "$(_json_escape "$QCAT")" \
        "$(_json_escape "$AUTHOR")" \
        "$(_json_escape "$QUOTE")" \
        "$(_json_escape "$ICON")" \
        "$(_json_escape "$MODE")" \
        "$(_json_escape "$STYLE")"
    exit 0
fi

# ── render ───────────────────────────────────────────────────────────────────
_render_card() {
    local quote=$1 author=$2 cat=$3
    local icon name card_w line atext pad leftpad
    category_meta "$cat"
    icon=$ICON; name=$CNAME
    card_w=$(( WIDTH - 4 ))

    _wrap_text "“$quote”" "$card_w"

    # top: ╭─ ◆ STOIC ─────────────╮
    local prefix="╭─ "
    local label="$icon $name"
    local head="$prefix$label "
    local max_label=$(( WIDTH - 8 ))
    (( max_label < 4 )) && max_label=4
    (( ${#label} > max_label )) && label=${label:0:max_label}
    head="$prefix$label "
    local fill=$(( WIDTH - ${#head} - 1 ))
    (( fill < 1 )) && fill=1
    local dashes
    dashes=$(_repeat_char "$fill" "─")

    if (( USE_COLOR )); then
        printf '%s%s' "$C_BORDER" "$prefix"
        printf '\033[1m%s%s\033[0m' "$C_ACCENT2" "$label"
        printf '%s %s╮%s\n' "$C_BORDER" "$dashes" "$C_RESET"
    else
        printf '%s%s %s╮\n' "$prefix" "$label" "$dashes"
    fi

    # quote lines
    for line in "${WRAP_RESULT[@]}"; do
        pad=$(( card_w - ${#line} ))
        (( pad < 0 )) && pad=0
        if (( USE_COLOR )); then printf '%s│ %s' "$C_BORDER" "$C_RESET"
        else printf '│ '; fi
        if (( ANIMATE_ON )); then
            _print_animated_words "$line" "$C_QUOTE"
        else
            if (( USE_COLOR )); then printf '%s%s%s' "$C_QUOTE" "$line" "$C_RESET"
            else printf '%s' "$line"; fi
        fi
        printf '%*s' "$pad" ''
        if (( USE_COLOR )); then printf '%s │%s\n' "$C_BORDER" "$C_RESET"
        else printf ' │\n'; fi
    done

    # breathing room
    if (( USE_COLOR )); then
        printf '%s│ %s%*s%s │%s\n' \
            "$C_BORDER" "$C_RESET" "$card_w" '' "$C_BORDER" "$C_RESET"
    else
        printf '│ %*s │\n' "$card_w" ''
    fi

    # author, right aligned
    atext="— $author"
    if (( ${#atext} > card_w )); then
        atext="${atext:0:$(( card_w - 1 ))}…"
    fi
    pad=$(( card_w - ${#atext} ))
    (( pad < 0 )) && pad=0
    leftpad=$(_repeat_char "$pad" " ")
    if (( USE_COLOR )); then printf '%s│ %s' "$C_BORDER" "$C_RESET"
    else printf '│ '; fi
    if (( USE_COLOR )); then printf '%s%s%s' "$C_AUTHOR" "$leftpad$atext" "$C_RESET"
    else printf '%s' "$leftpad$atext"; fi
    if (( USE_COLOR )); then printf '%s │%s\n' "$C_BORDER" "$C_RESET"
    else printf ' │\n'; fi

    # bottom: ╰─────────────────────╯
    local bottom="╰$(_repeat_char $(( WIDTH - 2 )) '─')╯"
    if (( USE_COLOR )); then
        _gradient_text "$bottom"
        printf '\n'
    else
        printf '%s\n' "$bottom"
    fi
}

_render_line() {
    local quote=$1 author=$2 cat=$3 minimal=$4
    local icon name
    category_meta "$cat"
    icon=$ICON; name=$CNAME

    if (( ! minimal )); then
        if (( USE_COLOR )); then printf '%s%s%s ' "$C_ACCENT2" "$icon" "$C_RESET"
        else printf '%s ' "$icon"; fi
    fi

    if (( ANIMATE_ON )); then
        printf '“'
        _print_animated_words "$quote" "$C_QUOTE"
        printf '”'
    else
        if (( USE_COLOR )); then printf '%s“%s”%s' "$C_QUOTE" "$quote" "$C_RESET"
        else printf '“%s”' "$quote"; fi
    fi

    if (( USE_COLOR )); then printf ' %s— %s%s\n' "$C_AUTHOR" "$author" "$C_RESET"
    else printf ' — %s\n' "$author"; fi
}

case $STYLE in
    card)    _render_card "$QUOTE" "$AUTHOR" "$QCAT" ;;
    line)    _render_line "$QUOTE" "$AUTHOR" "$QCAT" 0 ;;
    minimal) _render_line "$QUOTE" "$AUTHOR" "$QCAT" 1 ;;
esac
