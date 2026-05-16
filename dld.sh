#!/bin/sh

# SPDX-License-Identifier: Apache-2.0

############################################################################
# Licensed under the Apache License, Version 2.0 (the "License");          #
# you may not use this file except in compliance with the License.         #
# You may obtain a copy of the License at                                  #
#                                                                          #
# http://www.apache.org/licenses/LICENSE-2.0                               #
#                                                                          #
# Unless required by applicable law or agreed to in writing, software      #
# distributed under the License is distributed on an "AS IS" BASIS,        #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. #
# See the License for the specific language governing permissions and      #
# limitations under the License.                                           #
############################################################################


#######################################################################
#### A downloader utility wrapper around curl, wget, aria2 and     ####
#### megatools it can take links from a file and does a check to   ####
#### only allow http and ftp links to be passed onto the actual    ####
#### downloader programs.                                          ####
#######################################################################

dwld_retries=5

config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/dld"
config_file="${config_dir}/configrc"

# loading the config here means the user can overwrite any of the functions
if [ -f "$config_file" ]; then
    . "$config_file"
else
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
    fi
        cat << __HEREDOC__ > "$config_file"
# vim: ft=sh
# dld download wrapper config file

# number of tries for downloaders
dwld_retries=${dwld_retries}
__HEREDOC__
fi

myname="${0##*/}"

DryRun=""
Debug=""

return_normal=0
return_error=1

dld_separator=""
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
    printf '%s:\n' "Config"
    printf '\t%s\n' "The config file is located at ${config_file}"
    printf '\t%s\n' "you can use it to configurate the amount of retries"
    printf '\t%s\n' "used by all downloader commands."
    exit "$code"
}

# usage: check_cmd command
#     returns the command if it exists
check_cmd(){
    if [ "$(command -v "$1" 2>/dev/null)" ]; then
        printf '%s\n' "$1"
    else
        return $return_error
    fi
}

retry_cmd() {
    retries="$dwld_retries"
    r_delay=2
    rc=0
    until "$@"; do
        rc=$(( rc + 1 ))
        if [ "$rc" -ge "$retries" ]; then
            printf "Failed after %d attempts: %s\n" "$retries" "$*"
            return 1
        fi
        printf "Retrying (%d/%d)...\n" "$rc" "$retries"
        sleep "$r_delay"
    done
}

handler_megatools () {
    handler_header "megatools" "$1"
    if [ -z "$DryRun" ]; then
        megacmd="megatools"
        # do we have the megatools wrapper and is it actually a megatools wrapper
        if check_cmd mtw >/dev/null && mtw | grep -q "megatools"; then
            megacmd="mtw"
        fi
        retry_cmd "$megacmd" dl "$1"
        printf '\n'
    else
        printf '%s: %s\n' "download link" "$1"
    fi
}

handler_wget () {
    handler_header "wget" "$1"
    if [ -z "$DryRun" ]; then
        wget -c --content-disposition --tries="$dwld_retries" "$1"
    else
        printf '%s: %s\n' "download link" "$1"
    fi
    printf '\n'

}

handler_curl () {
    handler_header "curl" "$1"
    if [ -z "$DryRun" ]; then
        curl --retry "$dwld_retries" -O -C - "$1"
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
            --content-disposition-default-utf8 -m "$dwld_retries" "$1"
    else
        printf '%s: %s\n' "download link" "$1"
    fi
    printf '\n'
}

# Usage: link_dispatcher LINKS
#   LINKS: space separated list of links to handle
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
                *mega.nz*)
                    handler="megatools" ;;
                *.jpg*|*.jpeg*|*.iso*)
                    handler="cnw"       ;;
                *)
                    handler="aria"      ;;
            esac
            case "$handler" in
                megatools) handler_megatools "$link" ;;
                cnw)       handler_cnw       "$link" ;;
                aria)      handler_aria      "$link" ;;
                wget)      handler_wget      "$link" ;;
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
        # we want word splitting
        # shellcheck disable=SC2046
        link_dispatcher $(read_file "$1")
    else
        printf '%s: %s\n' "$myname" "argument ${1} is not a valid file!"
        exit "$return_error"
    fi
}

OPTIND=1
while getopts "hndf:" o; do case "${o}" in
    n) DryRun=1 ;;
    d) Debug=1 ;;
    f) file="$OPTARG" ;;
    h) show_help "$return_normal" ;;
    *) show_usage "$return_error" ;;
esac done
shift $(( OPTIND - 1 ))

[ -n "$Debug" ] && printf '%s\n' "arguments: $#"

if [ "$#" -eq 0 ] && [ -z "$file" ]; then
    show_usage "$return_error"
else
    if [ -n "$file" ]; then
        file_handler "$file"
    fi
    if [ "${#}" -gt 0 ]; then
        link_dispatcher "$@"
    fi
fi
