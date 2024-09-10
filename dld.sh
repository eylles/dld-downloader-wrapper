#!/bin/sh

myname="${0##*/}"

DryRun=""
Debug=""

help () {
    code=0
    if [ -n "$1" ]; then
        code="$1"
    fi
    printf '%s: %s\n' "$myname" "downloader utility"
    printf '%s:\n' "Usage"
    printf '\t%s\n' "${myname}: -f <links file> | <links>"
    printf '\t%s\n' "Use single quotes to quote the links to protect from shell"
    printf '\t%s\n' "expansion of characters."
    printf '\t%s\t%s\n' "-f" "read links from file."
    printf '\t-n\tdry run.\n\t-d\tdebug messages.\n\t-h\tshow this help.\n'
    exit "$code"
}

handler_megatools () {
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

handler_curl () {
    if [ -z "$DryRun" ]; then
        curl -O -C - "$1"
    else
        printf '%s: %s\n' "download link" "$1"
    fi
    printf '\n'
}

handler_aria () {
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
                *.jpg*)    handler="curl"      ;;
                *)         handler="aria"      ;;
            esac
            printf '%12s: %s\n' "$handler" "$link"
            case "$handler" in
                megatools) handler_megatools "$link" ;;
                curl)      handler_curl      "$link" ;;
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
    *) help ;;
esac done
shift $(( OPTIND - 1 ))

[ -n "$Debug" ] && printf '%s\n' "arguments: ${#}"

if [ "${#}" -eq 0 ] && [ -z "$file" ]; then
    help 1
else
    if [ -n "$file" ]; then
        file_handler "$file"
    else
        link_dispatcher "$@"
    fi
fi
