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
    envvarname=${1}
    local candidate=${2}
    local envvar=$(_var_expand "${envvarname}")
    case ":${envvar}:" in
        *:"${candidate}":*)
            ;;
        *)
            if [ "$3" = "after" ] ; then
                eval ${envvarname}=${envvar}:${candidate}
            else
                eval ${envvarname}=${candidate}:${envvar}
            fi
    esac
    unset envarname
}
