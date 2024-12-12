# I need functions to manage my environment
# this cannot be done in a program because it would fork and not be able to
# modify the environment
typeset -ga _PRENV=()
typeset -g _PRENV_SCRIPT="$0"
typeset -g VERSION=1.3.0

function prenv() {
    case "$1" in
        help|-h|--help)
               _prenv-help ;;
        list)
            shift
            _prenv-list $*
            ;;
        on)
            shift
            _prenv-on $*
            ;;
        off)
            shift
            _prenv-off $*
            ;;
        show)  _prenv-list -vf ;;
        clear) _prenv-clear ;;
        cat) _prenv-cat ;;
        edit) _prenv-edit ;;
        *)     _prenv-help; return 1 ;;
    esac
}

function _prenv-help() {
    cat <<-EOF
prenv [COMMAND] [OPTIONS]
Version: $VERSION

COMMANDS:
    list [-v] [-f]      # list all projects
        # -v will show environment variable and if they are set
        #    * variable is set but has another value than in config, e.g. because of variable
        #    ** variable is set and has the same value as in config
        # -f to filter for active project(s)
    on [-p] [PROJECT]   # activate a project
        # run \`prenv off\` for active project(s), set environment variables, trigger on hook(s)
        # -p will persist active project(s) and not run \`prenv off\` for active project(s)
        # omitting project will set environment variable of active project(s) and trigger on hook(s)
        # when \`project.directory\` is set, change directory
    off [PROJECT]       # deactivate project(s)
        # unset environment variables, trigger off hook(s)
        # omitting PROJECT will do it for currently active project(s)
    clear
        # unset any environment variable defined in the config, run clear hooks
    cat
        # print config to stdout
    edit
        # edit config with ${EDITOR:-editor}
    show
        # same as \`prenv list -v -f\`
    help
        # show this message
EOF
}


function _prenv-list() {
    # set options
    local verbose=0
    local filter=0
    while getopts "vf" opt; do
        case "$opt" in
            v) verbose=1 ;;
            f) filter=1 ;;
        esac
    done

    local project env_project
    local -a projects=("${(@f)$(yq -r '. // {} |keys |.[]' ~/.config/prenv.yaml)}")
    for project in ${(@)projects}; do
        if [[ ${#_PRENV[@]} -gt 0 && ${_PRENV[(Ie)$project]} -gt 0 ]]; then
            sed "s/${project}/${project} */" <<<$project
        else
            if [[ "$filter" == "1" ]]; then
                continue
            fi
            echo $project
        fi

        # show environment variables, if set (*) and if as in config (**)
        if [[ "$verbose" == "1" ]]; then
            local project_envs=$(yq -r '.["'$project'"].env // {} |keys |"  " + .[]' ~/.config/prenv.yaml)
            while read -u 4 project_env; do
                if [[ $(yq -r '.["'$project'"].env["'$project_env'"]' ~/.config/prenv.yaml) == "${(P)project_env}" ]]; then
                    # variable as in config
                    echo "  $project_env **"
                elif [[ -v "${project_env}" ]]; then
                    # variable set but different (could be due to variable in variable)
                    echo "  $project_env *"
                else
                    # variable not set
                    echo "  $project_env"
                fi
            done 4<<<$project_envs
        fi
    done

    for project in ${(@)_PRENV}; do
        if [[ ${projects[(Ie)$project]} -eq 0 ]]; then
            echo "$project # not in config"
        fi
    done
}

function _prenv-on() {
    # remember _PRENV in case it gets off
    local -a _local_PRENV=(${(@)_PRENV})
    # deactivate old project(s) unless explicitly
    if [[ "$1" == "-p" ]]; then
        # skip deactivating projects
        shift
    else
        # deactivate projects before activating them again
        if [[ ${#_PRENV[@]} -gt 0 ]]; then
            _prenv-off
        fi
    fi

    local project on_project
    on_project="${1}"
    if [[ "${on_project}" == "" ]]; then
        # reactivate current project(s)
        # _local_PRENV in case _PRENV was emptied by `prenv off`s (without -p)
        for project in ${(@)_local_PRENV}; do
            prenv on -p "$project"
        done
        return
    fi

    # check if project if defined in configuration
    if [[ ${(@f)$(yq -r '. // {} |keys |.[]' ~/.config/prenv.yaml)[(Ie)${on_project}]} -eq 0 ]]; then
        echo "Project \"${on_project}\" not in config file ~/.config/prenv.yaml" >&2
        return 1
    fi

    # set environment variables
    eval $(yq '.["'${on_project}'"].env // ""' ~/.config/prenv.yaml \
           |grep -v '^$' \
           |sed 's/^/export /; s/: /=/')

    # trigger on hook
    eval "$(yq -r '.["'${on_project}'"].hooks.on // ""' ~/.config/prenv.yaml)"

    # cd into directory unless we are in a subdirectory
    local cd_dir="$(yq -r '.["'${on_project}'"].directory // ""' ~/.config/prenv.yaml)"
    if [[ -n ${~cd_dir}  &&  "$PWD" != ${~cd_dir}* ]]; then
        # quoting the following will break it
        cd ${~cd_dir}
    fi

    # add project to _PRENV if not already in the list
    if [[ ${_PRENV[(Ie)${on_project}]} -eq 0 ]]; then
        _PRENV+=("${on_project}")
    fi
}

function _prenv-off() {
    local project off_project
    off_project="${1}"
    if [[ -n "${off_project}" ]]; then
        # check if project is active
        if [[ ${_PRENV[(Ie)${off_project}]} -eq 0 ]]; then
            echo "$off_project not active. Cannot deactivate" >&2
            return 1
        fi

        local -a projects=("${(@f)$(yq -r '. // {} |keys |.[]' ~/.config/prenv.yaml)}")

        # check if project if defined in configuration
        if [[ ${projects[(Ie)${off_project}]} -eq 0 ]]; then
            echo "$off_project not in config. "\
                "$off_project will be removed from list of active projects" >&2
            # trying to remove the project in case it is active
            _PRENV=(${(@)_PRENV:#${off_project}})
            return 1
        fi

        # unset environment variables
        local env_keys
        env_keys="$(yq -r '.["'${off_project}'"].env // {} |keys |.[]' ~/.config/prenv.yaml)"
        if [[ -n "$env_keys" ]]; then
            unset $(xargs <<<"$env_keys")
        fi

        # trigger off hook
        eval "$(yq -r '.["'${off_project}'"].hooks.off // ""' ~/.config/prenv.yaml)"

        _PRENV=(${(@)_PRENV:#${off_project}})

    elif [[ ${#_PRENV[@]} -gt 0 ]]; then
        # deactivate all projects in reverse order
        for project in ${(@Oa)_PRENV}; do
            _prenv-off "$project"
        done

    else
        echo No prenv active >&2
        return 1
    fi
}

function _prenv-clear() {
    local project
    # loop over all projects and unset all environments
    for project in $(yq -r '. // {} |keys |.[]' ~/.config/prenv.yaml); do
        # unset environment variables
        local env_keys
        env_keys="$(yq -r '.["'$project'"].env // {} |keys |.[]' ~/.config/prenv.yaml)"
        if [[ -n "$env_keys" ]]; then
            unset $(xargs <<<"$env_keys")
        fi

        # trigger clear hooks
        eval "$(yq -r '.["'$project'"].hooks.clear // ""' ~/.config/prenv.yaml)"

        _PRENV=(${(@)_PRENV:#${project}})
    done

    # clear _PRENV in case the is a project that is not in the configuration
    typeset -ga _PRENV=()
}

_prenv-cat() {
    cat ~/.config/prenv.yaml
}

_prenv-edit() {
    for possible_editor in "${EDITOR:-editor}" vim vi nano; do
        if command -v "${possible_editor}" >/dev/null; then
            ${possible_editor} ~/.config/prenv.yaml
            return
        fi
    done
}
