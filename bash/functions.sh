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
rcp() {
    local str="$(whoami)@$(hostname -d):$(realpath $1)"
    local local_ip=$(echo $SSH_CLIENT | awk '{print $1}')
    ssh ${local_ip} "DISPLAY=:1 xclip -selection clipboard" <<< "$str"
    echo "Copied: $str"
}
rp() {
    local dest="${1:-.}"
    local src="$(xclip -selection clipboard -o)"
    rsync -avz "$src" "$dest"
}



