#!/bin/sh
#
# Compile python from source on Debian or Debian derivative operating systems.
# Arguments:
#    - Download link of python.
#    - MD5 hexadecimal digest of pythons' compressed tarball.
#    - Existing Path to install python in.
###############################################################################

set -e -u

URL="$1"
DIGEST="$2"
INSTALL_PATH="$3"

# Essential dependency packages.
sudo apt-get update -y
sudo apt-get upgrade -y
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
    mkdir "${tempdir}"
fi

trap 'rm -rf -- "${tempdir}"' EXIT

cd "${tempdir}"

filename="${URL##*/}"
filename="${filename%%[?#]*}" # Remove parameters and fragment if exists

wget -nv -O "${filename}" "${URL}"
echo "${DIGEST} *${filename}" | md5sum -c

tar -x -a -f "${filename}"
cd "$(tar -t -f "${filename}" | head -n 1 | cut -d / -f 1)"

# Optimization flags
export LDFLAGS="-flto"
export CFLAGS="\
-O3 \
-flto \
-pipe \
-mtune=native \
-march=native \
"

./configure \
    --prefix="${INSTALL_PATH}" \
    --enable-optimizations \
    --with-lto=full \
    --with-computed-gotos

make -j "$(nproc || echo 1)"
make altinstall

echo "All Done!"
