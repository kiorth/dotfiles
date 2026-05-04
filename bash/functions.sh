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
