prompt_penv() {
    [[ -n "${#PENV[@]}" ]] \
        && p10k segment -f 197 -t "$PENV"
}
