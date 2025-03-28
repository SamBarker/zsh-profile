pathmunge () {
    envvarvmunge PATH ${@}
}

#from https://unix.stackexchange.com/a/472058/88459
_var_expand() {
    if [ "$#" -ne 1 ] || [ -z "${1-}" ]; then
        printf '_var_expand: expected one non-empty argument\n' >&2;
        return 1;
    fi
    eval printf '%s' "\"\${$1?}\""
}

# From Centos / RHEL at https://pagure.io/setup/blob/master/f/profile
envvarvmunge () {
    env_var_name=${1}
    local candidate=${2}
    local env_var
    env_var=$(_var_expand "${env_var_name}")
    case ":${env_var}:" in
        *:"${candidate}":*)
            ;;
        *)
            if [ "$3" = "after" ] ; then
                eval "${env_var_name}"='${env_var}':'${candidate}'
            else
                eval "${env_var_name}"='${candidate}':'${env_var}'
            fi
    esac
    unset envarname
}
