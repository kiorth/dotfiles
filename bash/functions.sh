grep_jq() {
    if [[ "$1" == "-h" || "$1" == "--help" || $# -eq 0 ]]; then
        cat <<'HELP'
grep_jq - extract a JSON key's value from multiple files and optionally sort

Usage:
  grep_jq <keyword> <file_pattern> [options]

Arguments:
  keyword         JSON key to extract (dot notation for nested keys,
                   e.g. energy or results.energy)
  file_pattern    Quoted glob pattern of files to search, e.g. "*.json"

Options:
  --sort          Sort results descending (largest first)
  --sort-asc      Sort results ascending (smallest first)
  -n <N>          Number of results to show (default: 10)
  --head <N>      Shorthand for --sort -n <N>
  --tail <N>      Shorthand for --sort-asc -n <N>
  -h, --help      Show this help message

Examples:
  grep_jq energy "*.json" --sort -n 10
  grep_jq energy "*.json" --head 10
  grep_jq energy "*.json" --tail 5
  grep_jq results.energy "*.djrepo"
HELP
        return 0
    fi

    local keyword="$1"
    local pattern="$2"
    shift 2

    local order="none"
    local n=10

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sort)     order="desc"; shift ;;
            --sort-asc) order="asc"; shift ;;
            -n)         n="$2"; shift 2 ;;
            --head)     order="desc"; n="$2"; shift 2 ;;
            --tail)     order="asc";  n="$2"; shift 2 ;;
            -h|--help)
                grep_jq --help
                return 0
                ;;
            *) shift ;;
        esac
    done

    local jqfilter=".${keyword#.}"
    local results=""

    for f in $pattern; do
        [[ -f "$f" ]] || continue
        val=$(jq -r "$jqfilter" "$f" 2>/dev/null)
        [[ -z "$val" || "$val" == "null" ]] && continue
        results+="$val $f"$'\n'
    done

    if [[ "$order" == "desc" ]]; then
        echo "$results" | sort -rn | head -n "$n"
    elif [[ "$order" == "asc" ]]; then
        echo "$results" | sort -n | head -n "$n"
    else
        echo "$results"
    fi
}


nano() {
    printf 'Open with vim instead? [Y/n] '
    read -n 1 -r reply
    echo
    if [[ "$reply" =~ ^[Nn]$ ]]; then
        command nano "$@"
    else
        vim "$@"
    fi
}
Env() {
    local ENV_DIR="$PYTHON_ENVS"
    local envs=()
    local i=1

    for d in "$ENV_DIR"/*/; do
        if [ -f "$d/bin/activate" ]; then
            envs+=("$d")
            echo "[$i] $(basename "$d")"
            ((i++))
        fi
    done

    if [ ${#envs[@]} -eq 0 ]; then
        echo "No environments found in $ENV_DIR"
        return 1
    fi

    printf "Select environment: "
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#envs[@]}" ]; then
        source "${envs[$((choice - 1))]}/bin/activate"
        echo "Activated $(basename "${envs[$((choice - 1))]}")"
    else
        echo "Invalid selection"
        return 1
    fi
}
