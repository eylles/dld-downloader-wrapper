#!/bin/sh

#######################################################################
#### A downloader utility wrapper around curl, wget, aria2 and     ####
#### megatools it can take links from a file and does a check to   ####
#### only allow http and ftp links to be passed onto the actual    ####
#### downloader programs.                                          ####
#######################################################################

myname="${0##*/}"

DryRun=""
Debug=""

sep_char="#"
cols=$(tput cols)
count=8
while [ "$count" -lt "$cols" ]; do
    dld_separator="${dld_separator}${sep_char}"
    count=$(( count + 1 ))
done

# usage: handler_header "handler name" "link"
handler_header () {
    printf '    %s\n' "$dld_separator"
    printf '%12s: %s\n\n' "$1" "$2"
}

show_usage () {
    printf '%s:\n' "Usage"
    printf '\t%s\n' "${myname}: [-hnd] [-f <links file>] <links>"
    if [ -n "$1" ]; then
        exit "$1"
    fi

}

# return type: string
get_header_comment () {
    sed -n '/^#### /p' "$0" | sed 's/^#### /\t/ ; s/ ####$//'
}

show_help () {
    code=0
    if [ -n "$1" ]; then
        code="$1"
    fi
    printf '%s:\n' "$myname"
    get_header_comment
    show_usage
    printf '\t%s\n' "Use single quotes to quote the links to protect from shell"
    printf '\t%s\n' "expansion of characters."
    printf '\t%s\t%s\n' "-f" "read links from file."
    printf '\t-n\tdry run.\n\t-d\tdebug messages.\n\t-h\tshow this help.\n'
    exit "$code"
}

# usage: check_cmd command
#     returns the command if it exists
check_cmd(){
    [ "$(command -v "$1" 2>/dev/null)" ] && printf '%s\n' "$1"
}

handler_megatools () {
    handler_header "megatools" "$1"
    if [ -z "$DryRun" ]; then
        # do we have the megatools wrapper?
        MegatoolsWrpPath=$(command -v mtw)
        [ -n "$MegatoolsWrpPath" ] && mtw_avail=1
        if [ -n "$mtw_avail" ]; then
            # is it actually a megatools wrapper
            if mtw | grep -q "megatools"; then
                mtw_valid=1
            fi
        fi
        if [ -n "$mtw_valid" ]; then
            mtw dl "$1"
        else
            megatools dl "$1"
        fi
        printf '\n'
    else
        printf '%s: %s\n' "download link" "$1"
    fi
}

handler_wget () {
    handler_header "wget" "$1"
    if [ -z "$DryRun" ]; then
        wget -c --content-disposition "$1"
    else
        printf '%s: %s\n' "download link" "$1"
    fi
    printf '\n'

}

handler_curl () {
    handler_header "curl" "$1"
    if [ -z "$DryRun" ]; then
        curl -O -C - "$1"
    else
        printf '%s: %s\n' "download link" "$1"
    fi
    printf '\n'
}

# wrap curl and wget handlers, prefer curl
handler_cnw () {
    [ -z "$cnw_cmd" ] && cnw_cmd=$(check_cmd "curl")
    [ -z "$cnw_cmd" ] && cnw_cmd=$(check_cmd "wget")

    case "$cnw_cmd" in
        "curl") handler_curl "$1" ;;
        "wget") handler_wget "$1" ;;
    esac
}

handler_aria () {
    handler_header "aria" "$1"
    if [ -z "$DryRun" ]; then
        aria2c -c --file-allocation=falloc -x 8 -s 8 \
            --content-disposition-default-utf8 "$1"
    else
        printf '%s: %s\n' "download link" "$1"
    fi
    printf '\n'
}

link_dispatcher () {
    for link in "$@"; do
        safeprot=""
        case "${link}" in
            http://*) safeprot=1 ;;
            https://*) safeprot=1 ;;
            ftp://*) safeprot=1 ;;
            ftps://*) safeprot=1 ;;
        esac
        if [ "$safeprot" -eq 1 ]; then
            handler=""
            case "${link}" in
                *mega.nz*) handler="megatools" ;;
                *.jpg*)    handler="cnw"       ;;
                *)         handler="aria"      ;;
            esac
            case "$handler" in
                megatools) handler_megatools "$link" ;;
                cnw)       handler_cnw       "$link" ;;
                aria)      handler_aria      "$link" ;;
            esac
        else
            printf '%s: %s\n' "Ignoring potentially unsafe url" "$link"
        fi
    done
}

# Usage: read_file file
#
# Return: string 'line'
read_file() {
    while read -r FileLine
    do
        printf '%s\n' "$FileLine"
    done < "$1"
}

file_handler () {
    if [ -f "$1" ]; then
        link_dispatcher $(read_file "$1")
    else
        printf '%s: %s\n' "$myname" "argument ${1} is not a valid file!"
        exit 1
    fi
}

OPTIND=1
while getopts "hndf:" o; do case "${o}" in
    n) DryRun=1 ;;
    d) Debug=1 ;;
    f) file="$OPTARG" ;;
    h) show_help 0 ;;
    *) show_usage 1 ;;
esac done
shift $(( OPTIND - 1 ))

[ -n "$Debug" ] && printf '%s\n' "arguments: ${#}"

if [ "${#}" -eq 0 ] && [ -z "$file" ]; then
    show_usage 1
else
    if [ -n "$file" ]; then
        file_handler "$file"
    fi
    if [ "${#}" -gt 0 ]; then
        link_dispatcher "$@"
    fi
fi
