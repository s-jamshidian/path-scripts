#!/bin/sh

set -eu

##########################################
# Safe to experiment with these constants.
##########################################
readonly LOWER_BOUND=0
readonly UPPER_BOUND=9 # Must be >= lower bound.

# Skip repetitive products (e.g., 3×9 and 9×3 both yield 27).
readonly SKIP_REDUNDANT='true' # Valid values: 'true' or 'false'.

# Alternate colors by row or column.
readonly ALT_COLOR_BY='column' # Valid values: 'row' or 'column'.

readonly CSI='\033['
readonly RESET="${CSI}0m"
readonly BOLD="${CSI}1m"
readonly HEADER_COLOR="${CSI}97m"
readonly COLOR1="${CSI}91m"
readonly COLOR2="${CSI}96m"
##########################################

readonly MAX_PRODUCT=$((UPPER_BOUND * UPPER_BOUND))
readonly COL_OFFSET="${#UPPER_BOUND}"
readonly COL_WIDTH=$((${#MAX_PRODUCT} + 1))

factors="$(seq "${LOWER_BOUND}" "${UPPER_BOUND}")"
printf '%b' "${BOLD}" "${HEADER_COLOR}" # Use bold font throughout the table
printf '%*s' "${COL_OFFSET}" ''
printf "%${COL_WIDTH}d" ${factors}

for row in ${factors}; do
    printf '%b\n%*d' "${HEADER_COLOR}" "${COL_OFFSET}" "${row}"
    for column in ${factors}; do
        # Proxy variable intentionally left unquoted.
        if [ $((${ALT_COLOR_BY} & 1)) -eq 1 ]; then
            color="${COLOR1}"
        else
            color="${COLOR2}"
        fi
        if [ "${SKIP_REDUNDANT}" = 'true' ] && [ "${column}" -lt "${row}" ]; then
            printf '%*s' "${COL_WIDTH}" ''
        else
            printf "%b%*d" "${color}" "${COL_WIDTH}" $((row * column))
        fi
    done
done
printf "%b\n" "${RESET}"
