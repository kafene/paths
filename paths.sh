#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# NB: For lack of better terms I herein refer to the concatenated
#     path variable as "path" and each component thereof as "dir"
# ---
# TO-DO: path-remove <path> <dir>...
#        add --filter flag to auto-filter resulting path.
#        or  --check flag to enforce existence of dirs.

# enable extended glob matching
shopt -s extglob

helptext='
  \033[1;4mpaths.sh\033[0m

    A Bash utility for manipulating paths ($PATH, $MANPATH, $INFOPATH, etc.)
    Copyright (c) 2017 kafene software (https://kafene.org/), MIT Licensed.
    Latest version available at <https://github.com/kafene/paths.sh>.

  \033[1mUsage\033[0m:
    paths [--help]
          [normalize-dir] <dir>
          [normalize]     <path>
          [filter]        <path>
          [has]           <path> <dir>
          [prepend]       <path> <dir>...
          [append]        <path> <dir>...

  \033[1mnormalize-dir\033[0m - Normalize a dir.
    $ paths normalize-dir "//foo//bar/baz///"
    > /foo/bar/baz

  \033[1mnormalize\033[0m - Normalize a path.
    $ paths normalize ":/bin/::/usr/bin"
    > /bin:/usr/bin

  \033[1mfilter\033[0m - Removes duplicates and non-existent dirs.
    $ paths filter "/bin:/usr/bin:/usr/fake:/opt/atom"
    > /bin:/usr/bin:/opt/atom

  \033[1mhas\033[0m - Check if the given dir appears in the given path.
    $ paths has "/bin:/usr/bin/" "/usr/bin"; echo $?;
    > 0

  \033[1mprepend\033[0m - Prepend the given dir(s) to the path.
    $ paths prepend "/bin" "/usr/bin" "/usr/share/go/bin"
    > /usr/share/go/bin:/usr/bin:/bin

  \033[1mappend\033[0m - Append the given dir(s) to the path.
    $ paths append "/bin" "/usr/bin/" "/usr/fake" "/opt/atom"
    > /bin:/usr/bin:/usr/fake:/opt/atom
'

# @param $1 The dir to normalize.
function dir-normalize {
    local dir="$1"

    # remove any surrounding whitespace
    dir="${dir#"${dir%%[![:space:]]*}"}"
    dir="${dir%"${dir##*[![:space:]]}"}"

    # replace repeated slashes with a single slash
    dir="${dir//+(\/)/\/}"

    # remove trailing slash
    dir="${dir%/}"

    # ... but don't force a leading slash
    # dir="/${dir#/}"

    echo "${dir}"
}

# @param $1 The path to normalize.
function path-normalize {
    local path="$1"
    local result=''

    # normalize each path component
    while IFS= read -r -d ':' p || [[ -n "$p" ]]; do
        result="${result}:$(dir-normalize "$p")"
    done <<< "$path"

    # replace repeated colons with a single colon
    result="${result//+(:)/:}"

    # remove leading or trailing colons
    result="${result%:}"
    result="${result#:}"

    echo "${result}"
}

# @param $1 The path to filter
function path-filter {
    local path="$(path-normalize "$1")"
    local result=''

    # normalize each path component
    while IFS= read -r -d ':' p || [[ -n "$p" ]]; do
        p="$(dir-normalize "$p")"

        if [[ -d "$p" ]]; then
            # && (! path-has "$result" "$p")
            result="${result}:${p}"
        fi
    done <<< "$path"

    # remove leading or trailing colons
    result="${result%:}"
    result="${result#:}"

    echo "${result}"
}

# @param $1 The path to match against.
# @param $2 The dir to look for.
function path-has {
    local path="$(path-normalize "$1")"
    local dir="$(dir-normalize "$2")"
    local p

    # compare each path component
    while IFS= read -r -d ':' p; do
        if [[ -n "$p" ]] && [[ "$p" = "$dir" ]]; then
            return 0
        fi
    done <<< "${path}:"

    return 1
}

# @param $1 The path to prepend to.
# @param ... The dir(s) to prepend.
function path-prepend {
    local dir
    local path="$(path-normalize "$1")"
    shift

    while (( $# > 0 )); do
        dir="$(dir-normalize "$1")"
        shift

        if (! path-has "$path" "$dir"); then
            path="${dir}:${path}"
            path="${path##:}"
            path="${path%%:}"
        fi
    done

    echo "${path}"
}

# @param $1 The path to append to.
# @param ... The dir(s) to append.
function path-append {
    local dir
    local path="$(path-normalize "$1")"
    shift

    while (( $# > 0 )); do
        dir="$(dir-normalize "$1")"
        shift

        if (! path-has "$path" "$dir"); then
            path="${path}:${dir}"
            path="${path##:}"
            path="${path%%:}"
        fi
    done

    echo "${path}"
}

### Parse the arguments
case "${1:-}" in
    normalize-dir)
        shift
        dir-normalize "$@"
        ;;
    normalize)
        shift
        path-normalize "$@"
        ;;
    filter)
        shift
        path-filter "$@"
        ;;
    has)
        shift
        path-has "$@"
        ;;
    prepend)
        shift
        path-prepend "$@"
        ;;
    append)
        shift
        path-append "$@"
        ;;
    help|--help|-help|-h)
        echo -e "$helptext"
        exit 0
        ;;
    *)
        echo -e "$helptext"
        exit 1
        ;;
esac
