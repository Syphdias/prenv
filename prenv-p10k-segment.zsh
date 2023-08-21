prompt_prenv() {
    [[ -n "${#PRENV[@]}" ]] \
        && p10k segment -f 197 -t "$PRENV"
}
