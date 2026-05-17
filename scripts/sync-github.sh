#!/usr/bin/env bash
set -uo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
WORK_REMOTE="https://github.com/ephemeris-void/Work.git"
RESEARCH_REMOTE="https://github.com/ephemeris-void/research-.git"
WORK_DIR="$HOME/github_work"
RESEARCH_DIR="$HOME/github_research"
LOG_FILE="$HOME/.sync_log"
LAST_SYNC="$HOME/.last_sync"
PUSHED_FILES="$HOME/.pushed_files"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)

WATCH_DIRS=("$HOME/lab" "$HOME/work" "$HOME/notes" "$HOME/re" "$HOME/new_cast" "$HOME/tools" "$HOME/tool")

SAFE_EXT=(c cc cpp cxx h hh hpp hxx py sh bash zsh rs go js ts json yaml yml toml xml md txt rst tex html css java csv cmake asm s S)
SAFE_NAMES=(Makefile CMakeLists.txt README LICENSE package.xml .gitignore)

BLOCK_EXT=(o out a so pyc class iso img qcow2 db sqlite pem key p12 pfx tar gz zip 7z bin exe deb rpm)
BLOCK_NAMES=(.env .git-credentials .netrc id_rsa id_ed25519 id_ecdsa id_dsa .bash_history .zsh_history)
BLOCK_DIRS=(build install log .cache __pycache__ .git devel node_modules dist)

SECRET_RE='(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[A-Za-z0-9_-]{35}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|password[[:space:]]*=[[:space:]]*[^[:space:]#]{4,}|passwd[[:space:]]*=[[:space:]]*[^[:space:]#]{4,}|secret[[:space:]]*=[[:space:]]*[^[:space:]#]{4,}|api_key[[:space:]]*=[[:space:]]*[^[:space:]#]{4,}|Authorization:[[:space:]]*Bearer[[:space:]]+[^[:space:]]{8,})'

R='\033[1;31m' G='\033[1;32m' Y='\033[1;33m' C='\033[1;36m' W='\033[1;37m' D='\033[0m'

# ── GLOBALS ───────────────────────────────────────────────────────────────────
declare -a FOLDER_PATHS=()
declare -a FOLDER_FILELISTS=()
declare -a ALL_FILES=()
declare -a SELECTED_FILES=()
declare -a COMMIT_FILES=()
declare -a COMMIT_MSGS=()
declare -a REPO_SUBDIRS=()
declare -a NAV=()

STEP=1
SEL_IDX=-1
SEL_PATH=""
TARGET_REPO_DIR="" TARGET_REMOTE="" TARGET_LABEL="" TARGET_SUBFOLDER="" TARGET_FULL=""

# ── NAV ───────────────────────────────────────────────────────────────────────
nav_push() { NAV+=("$STEP"); }
nav_back() {
    if [[ ${#NAV[@]} -eq 0 ]]; then exit 0; fi
    STEP="${NAV[-1]}"
    unset 'NAV[-1]'
}
hint() { echo -e "  ${Y}[b]${D} back   ${Y}[q]${D} quit\n"; }
hdr() {
    clear
    echo -e "${W}═══════════════════════════════════════════════════${D}"
    echo -e "${W}  SECURE GITHUB SYNC   $DATE  $TIME${D}"
    echo -e "${W}═══════════════════════════════════════════════════${D}\n"
}

# ── SECURITY ──────────────────────────────────────────────────────────────────
_safe_ext() {
    local base ext f="$1"
    base=$(basename "$f")
    local n
    for n in "${SAFE_NAMES[@]}"; do
        [[ "$base" == "$n" ]] && return 0
    done
    [[ "$base" != *.* ]] && return 1
    ext="${base##*.}"
    local s
    for s in "${SAFE_EXT[@]}"; do
        [[ "$ext" == "$s" ]] && return 0
    done
    return 1
}

_blocked_name() {
    local base f="$1"
    base=$(basename "$f")
    [[ "$base" == .* ]] && return 0
    local n
    for n in "${BLOCK_NAMES[@]}"; do
        [[ "$base" == "$n" ]] && return 0
    done
    local e="${base##*.}"
    local x
    for x in "${BLOCK_EXT[@]}"; do
        [[ "$e" == "$x" ]] && return 0
    done
    return 1
}

_blocked_path() {
    local f="$1" d
    for d in "${BLOCK_DIRS[@]}"; do
        [[ "$f" == *"/$d/"* || "$f" == *"/$d" ]] && return 0
    done
    return 1
}

_binary() {
    local mime
    mime=$(file --mime-type -b "$1" 2>/dev/null || echo "application/octet-stream")
    case "$mime" in
        text/*|application/json|application/xml|application/x-sh) return 1 ;;
    esac
    return 0
}

_secret() {
    grep -Eiq "$SECRET_RE" "$1" 2>/dev/null
}

scan() {
    local f="$1"
    if _blocked_name "$f"; then
        echo -e "  ${R}✗ BLOCK${D}  $(basename "$f")  — blocked filename/extension"
        return 1
    fi
    if _blocked_path "$f"; then
        echo -e "  ${R}✗ BLOCK${D}  $(basename "$f")  — blocked directory"
        return 1
    fi
    if ! _safe_ext "$f"; then
        echo -e "  ${R}✗ BLOCK${D}  $(basename "$f")  — extension not whitelisted"
        return 1
    fi
    if _binary "$f"; then
        echo -e "  ${R}✗ BLOCK${D}  $(basename "$f")  — binary file"
        return 1
    fi
    if _secret "$f"; then
        echo -e "  ${R}✗ BLOCK${D}  $(basename "$f")  — secret/token found inside"
        return 1
    fi
    echo -e "  ${G}✓ PASS${D}   $(basename "$f")"
    return 0
}

# ── DETECT ────────────────────────────────────────────────────────────────────
detect_folders() {
    FOLDER_PATHS=()
    FOLDER_FILELISTS=()

    local since_flag=()
    if [[ -f "$LAST_SYNC" ]]; then
        since_flag=(-newer "$LAST_SYNC")
    else
        touch -d "7 days ago" /tmp/.sync_ref 2>/dev/null || true
        since_flag=(-newer /tmp/.sync_ref)
    fi

    local exclude=()
    local d
    for d in "${BLOCK_DIRS[@]}"; do
        exclude+=(-not -path "*/$d/*" -not -path "*/$d")
    done
    exclude+=(-not -path "$WORK_DIR/*" -not -path "$RESEARCH_DIR/*")

    local f dir found i
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if [[ -f "$PUSHED_FILES" ]] && grep -qF "$f|$(stat -c %Y "$f")" "$PUSHED_FILES"; then
            continue
        fi
        dir=$(dirname "$f")
        found=-1
        for i in "${!FOLDER_PATHS[@]}"; do
            if [[ "${FOLDER_PATHS[$i]}" == "$dir" ]]; then
                found=$i
                break
            fi
        done
        if [[ $found -eq -1 ]]; then
            FOLDER_PATHS+=("$dir")
            FOLDER_FILELISTS+=("$f"$'\n')
        else
            FOLDER_FILELISTS[$found]+="$f"$'\n'
        fi
    done < <(find "${WATCH_DIRS[@]}" -type f "${since_flag[@]}" "${exclude[@]}" 2>/dev/null | sort)
}

# ── LAST SYNC ─────────────────────────────────────────────────────────────────
show_last_sync() {
    [[ ! -f "$LOG_FILE" ]] && return
    local last_date
    last_date=$(tail -1 "$LOG_FILE" | cut -d'|' -f1 | xargs 2>/dev/null || true)
    [[ -z "$last_date" ]] && return
    echo -e "${W}── LAST SYNC  $last_date ──────────────────${D}"
    grep "^$last_date" "$LOG_FILE" | while IFS='|' read -r d file msg target repo; do
        printf "  %-28s %-22s  ${C}%s${D}\n" \
            "$(echo "$file" | xargs)" \
            "\"$(echo "$msg" | xargs)\"" \
            "$(echo "$target" | xargs)"
    done
    echo ""
}

# ── STEP 1: FOLDER ────────────────────────────────────────────────────────────
step_folder() {
    while true; do
        hdr
        show_last_sync
        if [[ ${#FOLDER_PATHS[@]} -eq 0 ]]; then
            echo -e "${Y}  no modified files found${D}"
            touch "$LAST_SYNC"
            rm -f "$PUSHED_FILES"
            exit 0
        fi
        echo -e "${W}  modified folders:${D}\n"
        local i count
        for i in "${!FOLDER_PATHS[@]}"; do
            count=$(printf '%s' "${FOLDER_FILELISTS[$i]}" | grep -c '[^[:space:]]' || true)
            printf "  ${C}%2d${D}  %-48s  ${Y}%d file(s)${D}\n" \
                "$((i+1))" "${FOLDER_PATHS[$i]/#$HOME/~}" "$count"
        done
        echo ""
        hint
        read -r sel
        case "$sel" in
            q|Q) exit 0 ;;
            b|B) exit 0 ;;
        esac
        if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#FOLDER_PATHS[@]} )); then
            SEL_IDX=$((sel-1))
            SEL_PATH="${FOLDER_PATHS[$SEL_IDX]}"
            nav_push; STEP=2; return
        fi
    done
}

# ── STEP 2: FILES ─────────────────────────────────────────────────────────────
step_files() {
    while true; do
        hdr
        ALL_FILES=()
        echo -e "${W}  files in ${SEL_PATH/#$HOME/~}:${D}\n"
        local i=1 f
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            ALL_FILES+=("$f")
            printf "  ${C}%2d${D}  %s\n" "$i" "$(basename "$f")"
            i=$((i+1))
        done < <(printf '%s' "${FOLDER_FILELISTS[$SEL_IDX]}")
        echo ""
        echo -e "${W}  select: all / 1,2,3${D}"
        hint
        read -r sel
        case "$sel" in
            q|Q) exit 0 ;;
            b|B) nav_back; return ;;
        esac
        SELECTED_FILES=()
        if [[ "$sel" == "all" ]]; then
            SELECTED_FILES=("${ALL_FILES[@]}")
        else
            local nums n
            IFS=',' read -ra nums <<< "$sel"
            for n in "${nums[@]}"; do
                n=$(echo "$n" | tr -d ' ')
                if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#ALL_FILES[@]} )); then
                    SELECTED_FILES+=("${ALL_FILES[$((n-1))]}")
                fi
            done
        fi
        [[ ${#SELECTED_FILES[@]} -eq 0 ]] && continue
        nav_push; STEP=3; return
    done
}

# ── STEP 3: SCAN ──────────────────────────────────────────────────────────────
step_scan() {
    hdr
    echo -e "${W}  security scan:${D}\n"
    COMMIT_FILES=()
    local blocked=0 f
    for f in "${SELECTED_FILES[@]}"; do
        if scan "$f"; then
            COMMIT_FILES+=("$f")
        else
            blocked=$((blocked+1))
        fi
    done
    echo ""
    [[ $blocked -gt 0 ]] && echo -e "  ${R}$blocked file(s) blocked — not pushed${D}\n"
    if [[ ${#COMMIT_FILES[@]} -eq 0 ]]; then
        echo -e "  ${R}no safe files to commit${D}"
        sleep 2; nav_back; return
    fi
    echo -e "  ${G}${#COMMIT_FILES[@]} file(s) cleared${D}\n"
    echo -e "  continue? [y]"
    hint
    read -r sel
    case "$sel" in
        q|Q) exit 0 ;;
        b|B) nav_back; return ;;
        y|Y) nav_push; STEP=4; return ;;
    esac
}

# ── STEP 4: MESSAGES ──────────────────────────────────────────────────────────
step_messages() {
    while true; do
        hdr
        echo -e "${W}  commit messages:${D}\n"
        echo -e "  ${C}o${D}  one message for all"
        echo -e "  ${C}i${D}  individual per file\n"
        hint
        read -r mode
        case "$mode" in
            q|Q) exit 0 ;;
            b|B) nav_back; return ;;
            o|O|i|I) ;;
            *) continue ;;
        esac

        COMMIT_MSGS=()
        local f msg ok=1

        if [[ "$mode" == "o" || "$mode" == "O" ]]; then
            while true; do
                echo -e "\n  message for all: "
                read -r msg
                case "$msg" in
                    b|B) nav_back; return ;;
                    q|Q) exit 0 ;;
                esac
                [[ -z "$msg" ]] && echo -e "  ${R}cannot be empty${D}" && continue
                break
            done
            for f in "${COMMIT_FILES[@]}"; do
                COMMIT_MSGS+=("$msg")
            done
        else
            for f in "${COMMIT_FILES[@]}"; do
                while true; do
                    printf "  %-30s " "$(basename "$f")"
                    read -r msg
                    case "$msg" in
                        b|B) nav_back; return ;;
                        q|Q) exit 0 ;;
                    esac
                    [[ -z "$msg" ]] && msg="update $(basename "$f")"
                    break
                done
                COMMIT_MSGS+=("$msg")
            done
        fi

        nav_push; STEP=5; return
    done
}

# ── STEP 5: TARGET ────────────────────────────────────────────────────────────
step_target() {
    while true; do
        hdr
        echo -e "${W}  target repo:${D}\n"
        echo -e "  ${C}1${D}  work"
        echo -e "  ${C}2${D}  research\n"
        hint
        read -r sel
        case "$sel" in
            q|Q) exit 0 ;;
            b|B) nav_back; return ;;
            1) TARGET_REPO_DIR="$WORK_DIR"; TARGET_REMOTE="$WORK_REMOTE"; TARGET_LABEL="work" ;;
            2) TARGET_REPO_DIR="$RESEARCH_DIR"; TARGET_REMOTE="$RESEARCH_REMOTE"; TARGET_LABEL="research" ;;
            *) continue ;;
        esac

        if [[ ! -d "$TARGET_REPO_DIR/.git" ]]; then
            echo -e "${Y}  cloning $TARGET_LABEL...${D}"
            git clone "$TARGET_REMOTE" "$TARGET_REPO_DIR" || { sleep 2; continue; }
        fi

        while true; do
            hdr
            echo -e "${W}  subfolder in $TARGET_LABEL:${D}\n"
            mapfile -t REPO_SUBDIRS < <(
                find "$TARGET_REPO_DIR" -mindepth 1 -maxdepth 2 -type d \
                    ! -path '*/.git*' ! -path '*/.*' \
                | sed "s|$TARGET_REPO_DIR/||" | sort
            )
            local i
            for i in "${!REPO_SUBDIRS[@]}"; do
                printf "  ${C}%2d${D}  %s\n" "$((i+1))" "${REPO_SUBDIRS[$i]}"
            done
            echo -e "  ${C} n${D}  new folder\n"
            hint
            read -r fsel
            case "$fsel" in
                q|Q) exit 0 ;;
                b|B) break ;;
                n|N)
                    while true; do
                        read -rp "  folder name: " TARGET_SUBFOLDER
                        [[ -n "$TARGET_SUBFOLDER" ]] && break
                        echo -e "  ${R}cannot be empty${D}"
                    done
                    TARGET_FULL="$TARGET_REPO_DIR/$TARGET_SUBFOLDER"
                    nav_push; STEP=6; return ;;
                *)
                    if [[ "$fsel" =~ ^[0-9]+$ ]] && \
                       (( fsel >= 1 && fsel <= ${#REPO_SUBDIRS[@]} )); then
                        TARGET_SUBFOLDER="${REPO_SUBDIRS[$((fsel-1))]}"
                        TARGET_FULL="$TARGET_REPO_DIR/$TARGET_SUBFOLDER"
                        nav_push; STEP=6; return
                    fi ;;
            esac
        done
    done
}

# ── STEP 6: PREVIEW ───────────────────────────────────────────────────────────
step_preview() {
    while true; do
        hdr
        echo -e "${W}── PREVIEW ─────────────────────────────────────${D}\n"
        local i
        for i in "${!COMMIT_FILES[@]}"; do
            printf "  %-28s  %-22s  ${C}%s${D}\n" \
                "$(basename "${COMMIT_FILES[$i]}")" \
                "\"${COMMIT_MSGS[$i]}\"" \
                "$TARGET_LABEL/$TARGET_SUBFOLDER"
        done
        echo -e "\n  push? [y]"
        hint
        read -r sel
        case "$sel" in
            y|Y) STEP=7; return ;;
            q|Q) exit 0 ;;
            b|B) nav_back; return ;;
        esac
    done
}

# ── STEP 7: PUSH ──────────────────────────────────────────────────────────────
do_push() {
    hdr
    cd "$TARGET_REPO_DIR" || { echo -e "${R}  cannot cd${D}"; exit 1; }
    local BRANCH
    BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")

    echo -e "${W}  pulling...${D}"
    git pull --rebase origin "$BRANCH" 2>&1 | sed 's/^/  /' || true
    echo ""

    mkdir -p "$TARGET_FULL"
    local pushed=0 failed=0 i f rel

    for i in "${!COMMIT_FILES[@]}"; do
        f="${COMMIT_FILES[$i]}"
        rel=$(basename "$f")

        if ! cp "$f" "$TARGET_FULL/$rel"; then
            echo -e "  ${R}✗${D}  $rel  — copy failed"
            failed=$((failed+1))
            continue
        fi

        git add "$TARGET_SUBFOLDER/$rel"

        if git commit -m "${COMMIT_MSGS[$i]}" 2>&1 | grep -v '^$' | sed 's/^/  /'; then
            echo -e "  ${G}✓${D}  $rel"
            pushed=$((pushed+1))
            echo "$f|$(stat -c %Y "$f")" >> "$PUSHED_FILES"
        else
            echo -e "  ${R}✗${D}  $rel  — commit failed"
            failed=$((failed+1))
        fi
    done

    [[ $pushed -eq 0 ]] && { echo -e "\n  ${R}nothing pushed${D}"; exit 1; }

    echo -e "\n${W}  pushing...${D}"
    local ok=0 attempt
    for attempt in 1 2 3; do
        git push origin "$BRANCH" 2>&1 | sed 's/^/  /' && ok=1 && break
        echo -e "  ${Y}retry $attempt/3...${D}"; sleep 2
    done
    [[ $ok -eq 0 ]] && { echo -e "  ${R}push failed${D}"; exit 1; }

    for i in "${!COMMIT_FILES[@]}"; do
        echo "$DATE | $(basename "${COMMIT_FILES[$i]}") | ${COMMIT_MSGS[$i]} | $TARGET_SUBFOLDER | $TARGET_LABEL" >> "$LOG_FILE"
    done

    echo -e "\n${G}── DONE ────────────────────────────────────────${D}"
    echo -e "  repo    : github.com/ephemeris-void/$TARGET_LABEL"
    echo -e "  folder  : $TARGET_SUBFOLDER"
    echo -e "  branch  : $BRANCH"
    echo -e "  pushed  : $pushed file(s)"
    [[ $failed -gt 0 ]] && echo -e "  ${R}failed  : $failed${D}"
    echo -e "  time    : $TIME\n"
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
hdr
echo -e "${W}  scanning for modified files...${D}\n"
detect_folders

while true; do
    case "$STEP" in
        1) step_folder ;;
        2) step_files ;;
        3) step_scan ;;
        4) step_messages ;;
        5) step_target ;;
        6) step_preview ;;
        7) do_push; STEP=1; detect_folders ;;
    esac
done
