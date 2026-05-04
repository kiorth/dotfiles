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
    ENV_DIR="$PYTHON_ENVS"
    local envs=()
    local i=1
    
    for d in "ENV_DIR"/*; do
        if [ -f "$d/bin/activate" ]; then 
            envs+=("$d")
            echo "[$i] $(basename "$d")"
            ((i++))
        fi 
    done
    if [ ${#envs[@]} -eq 0 ]; then 
        echo "No environments found"
        return 1
    fi 
    source "${envs[$((choice - 1))]}/bin/activate"
}
