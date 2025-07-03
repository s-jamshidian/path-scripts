#!/bin/sh

set -eu

EX_USAGE=79
EX_NOTDIR=80

PROG="${0##*/}"
CR="$(printf '\r')"
RE_PROTOCOL='^proto[[:blank:]]+([[:alnum:]]+)'"${CR}"'?$'
RE_REMOTE='^remote[[:blank:]]+([[:alnum:]._-]+)[[:blank:]]+([[:digit:]]+)'"${CR}"'?$'

readonly EX_USAGE EX_NOTDIR PROG CR RE_PROTOCOL RE_REMOTE

usage() {
    cat <<__END__
${PROG} - Extract VpnGate OpenVPN configs from CSV stdin.

Usage:
    ${PROG} [OPTIONS]

Input:
    CSV data (columns 7=short country, 15=Base64-encoded config) read from stdin.

Options:
    -d <DIR>  Base destination directory to store configs (default: CWD).
    -c        Add country to filenames.
    -o        Organize configs by country.
    -v        Verbose.
    -h        Show this help.

Exit Status:
    0         Success.
    ${EX_USAGE}        Invalid option(s) or argument(s).
    ${EX_NOTDIR}        Destination does not exist or is not a directory.

Examples:
    curl -s "https://www.vpngate.net/api/iphone/" | ${PROG} -ocd ~/vpngate
__END__
}

base_dir='.'
add_country=''
organize=''
verbose=''
while getopts ':d:covh' option; do
    case "${option}" in
        d) base_dir="${OPTARG}" ;;
        c) add_country='true' ;;
        o) organize='true' ;;
        v) verbose='true' ;;
        h)
            usage
            exit
            ;;
        *)
            usage >&2
            exit "${EX_USAGE}"
            ;;
    esac
done

if [ ! -d "${base_dir}" ]; then
    usage >&2
    exit "${EX_NOTDIR}"
fi

sed -E '/^[*#]/d' | # Skip header and footer
    cut -d ',' -f 7,15 |
    while IFS=',' read -r country ovpn_base64; do
        country="$(printf '%s' "${country}" | tr '[:upper:]' '[:lower:]')"
        # Make sure country name is sanitized:
        if
            ! printf '%s' "${country}" |
                grep -E '^[[:lower:]]+$' >/dev/null 2>&1
        then
            country='unknown'
        fi
        if [ -n "${organize}" ]; then
            out_dir="${base_dir}/${country}"
            mkdir -p ${verbose:+-v} -- "${out_dir}" >&2 # Use stderr for consistency
        else
            out_dir="${base_dir}"
        fi

        ovpn_cfg="$(printf '%s' "${ovpn_base64}" | base64 -d -i)"
        # Immediately exit sed after finding the first occurrence:
        protocol="$(printf '%s' "${ovpn_cfg}" |
            sed -E -n "/^proto/{s/${RE_PROTOCOL}/\1/p;Q}")"
        remote="$(printf '%s' "${ovpn_cfg}" |
            sed -E -n "/^remote/{s/${RE_REMOTE}/\1_\2/p;Q}")"

        if [ -n "${add_country}" ]; then
            cfg_name="${country}_${protocol}_${remote}.ovpn"
        else
            cfg_name="${protocol}_${remote}.ovpn"
        fi

        full_path="${out_dir}/${cfg_name}"
        printf '%s' "${ovpn_cfg}" >"${full_path}"
        [ -n "${verbose}" ] && printf "%s: saved config '%s'\n" "${PROG}" "${full_path}" >&2
    done
