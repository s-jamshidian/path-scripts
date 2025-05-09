#!/bin/bash
#
# Find duplicate files.
# NOTE: This script is POSIX-compliant, but it utilizes new POSIX features like
# 'set -o pipefail' and 'read -d', which aren't yet available in dash or yash,
# hence the usage of bash.

set -e -u -o pipefail

readonly E_USAGE=79
readonly PROG="${0##*/}"

hash_cmd='md5sum'
cksum_len=32
grouping=''
nul_in=''
nul_out=''

# Write usage to stdout and exit the shell.
# Globals:
#   PROG
# Arguments:
#   - Exit the shell with this code. (Default: 0)
usage() {
    cat <<__EOF__
${PROG} - Read file names from stdin and output duplicates to stdout.

Usage:
  ${PROG} [OPTIONS...]

Options:
  -a <ALGO>  Hash algorithm {md5|sha1|sha256|blake2b} (Default: md5).
  -g         Group duplicates; Separate groups by additional line delimiter.
  -z         Use ASCII NUL delimiter for input instead of newline.
  -Z         Use ASCII NUL delimiter for output instead of newline.
  -h         Show this help and exit.

Exit Status:
  0   Success.
  79  Invalid option(s).
__EOF__
    exit "${1:-0}"
}

rm_uniq() {
    local printed prev_key prev_name current_key current_name

    printed=''
    IFS=' ' read -d '' prev_key prev_name
    while IFS=' ' read -r -d '' current_key current_name; do
        if [ "${prev_key}" = "${current_key}" ]; then
            printf '%s\0' "${current_name}"
            if [ -z "${printed}" ]; then
                printf '%s\0' "${prev_name}"
                printed=1
            fi
        else
            prev_key="${current_key}"
            prev_name="${current_name}"
        fi
    done

}

while getopts ':a:gzZh' opt; do
    case "${opt}" in
        a) case "${OPTARG}" in
            md5)
                hash_cmd="md5sum"
                cksum_len=32
                ;;
            sha1)
                hash_cmd="sha1sum"
                cksum_len=40
                ;;
            sha256)
                hash_cmd="sha256sum"
                cksum_len=64
                ;;
            blake2b)
                hash_cmd="b2sum"
                cksum_len=128
                ;;
            *) usage "${E_USAGE}" ;;
        esac ;;
        g) grouping="1" ;;
        z) nul_in="1" ;;
        Z) nul_out="1" ;;
        h) usage ;;
        *) usage "${E_USAGE}" ;;
    esac
done

xargs ${nul_in:+'-0'} stat --printf='%s %n\0' |
    sort -z -k 1,1 |
    rm_uniq |
    xargs -0 "${hash_cmd}" -z -b |
    sort -z -k 1,1 |
    uniq -z -w "${cksum_len}" -D ${grouping:+'--all-repeated=separate'} |
    cut -z -c "$((cksum_len + 3))-" | # Account for space and star characters
    if [ -z "${nul_out}" ]; then
        tr '\0' '\n'
    else
        cat
    fi
