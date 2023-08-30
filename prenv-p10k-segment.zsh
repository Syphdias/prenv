prompt_prenv() {
    [[ -n "${#_PRENV[@]}" ]] \
        && p10k segment -f 197 -t "$_PRENV"
}
