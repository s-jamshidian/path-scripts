#!/bin/sh
#
# Compile CPython from source on Debian-based systems.

set -e -u

PROG="${0##*/}"
N_ARGS=2

# Exit codes:
E_OK=0
E_USAGE=79

# File descriptors:
STDOUT=1
STDERR=2

# Write usage message to the specified file descriptor and exit the shell.
# Globals:
#   PROG
#   STDOUT
#   E_USAGE
# Arguments:
#   - File descriptor to write the usage message to. (Default: STDOUT)
#   - Exit the shell with this code. (Default: E_USAGE)
usage() {
    cat >&"${1:-"${STDOUT}"}" <<__END__
${PROG} - Compile CPython from source on Debian-based systems.

Usage:
    ${PROG} [OPTIONS...] <URL> <MD5_CHECKSUM>

Arguments:
    <URL>           Download URL for CPython source tarball.
    <MD5_CHECKSUM>  MD5 checksum of the CPython source tarball.

Options:
    -d <DIR>   Install directory.
    -h         Show this help and exit.

Exit Status:
    0   Success.
    79  Invalid option(s) or missing argument(s).
__END__

    exit "${2:-"${E_OK}"}"
}

install_path=''
while getopts ':hd:' option; do
    case "${option}" in
        d) install_path="${OPTARG}" ;;
        h) usage ;;
        *) usage "${STDERR}" "${E_USAGE}" ;;
    esac
done
shift $((OPTIND - 1))
[ "$#" -ne "${N_ARGS}" ] && usage "${STDERR}" "${E_USAGE}"
url="$1"
digest="$2"

# Essential dependency packages.
sudo apt-get update -y
sudo apt-get build-dep -y python3
# NOTE: libmpdec-dev removed from debian 12.
sudo apt-get install -y \
    wget \
    build-essential \
    gdb \
    lcov \
    pkg-config \
    libbz2-dev \
    libffi-dev \
    libgdbm-dev \
    libgdbm-compat-dev \
    liblzma-dev \
    libncurses5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    lzma \
    lzma-dev \
    tk-dev \
    uuid-dev \
    zlib1g-dev

if ! tempdir="$(mktemp -d 2>/dev/null)"; then
    tempdir="/tmp/$$"
    mkdir -- "${tempdir}"
fi
trap 'rm -r -f -- "${tempdir}"' EXIT
cd -- "${tempdir}"

filename="${url##*/}"
filename="${filename%%[?#]*}" # Strip URL parameters/fragments

wget -nv --show-progress -O "${filename}" -- "${url}"
echo "${digest} *${filename}" | md5sum -c

tar -x -a -f "${filename}"
extracted_dir="$(tar -t -f "${filename}" | head -n 1 | cut -d / -f 1)"
cd -- "${extracted_dir}"

# Optimization flags
export LDFLAGS="-flto"
export CFLAGS="-O3 -flto -pipe -mtune=native -march=native"

./configure \
    ${install_path:+--prefix="${install_path}"} \
    --enable-optimizations \
    --with-lto=full \
    --with-computed-gotos

make -j "$(nproc 2>/dev/null || echo 1)"
make altinstall

echo "All Done!"
