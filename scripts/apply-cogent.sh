#!/bin/bash

set -exuo pipefail

# Source common functions
DIR="${BASH_SOURCE%/*}"
test -d "$DIR" || DIR=$PWD
# shellcheck source=utils/common.sh
. "$DIR/utils/common.sh"

# Where will cogent libraries go
: "${COGENT_DIR:=/usr/local/cogent}"

as_root tee /etc/apt/sources.list.d/cabal.list > /dev/null << EOF
deb http://downloads.haskell.org/debian buster main
EOF
as_root apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys BA3CBA3FFE22B574
as_root apt-get update -q
as_root apt-get install -y --no-install-recommends \
    cabal-install-3.2 \
    ghc-8.6.5 \
    # end of list

echo "export PATH=\"\$PATH:/opt/ghc/bin:/opt/cabal/bin\"" >> "$HOME/.bashrc"
export PATH="$PATH:/opt/ghc/bin:/opt/cabal/bin"

# Do cabal things
cabal v1-update
cabal v1-install \
    happy \
    alex \
    # end of list

try_nonroot_first git clone --depth=1 https://github.com/NICTA/cogent.git "$COGENT_DIR" || chown_dir_to_user "$COGENT_DIR"
(
    cd "$COGENT_DIR/cogent/"
    cabal v1-sandbox init --sandbox="$HOME/.cogent-sandbox"
    cp misc/cabal.config.d/cabal.config-8.6.5 cabal.config
    cabal v1-sandbox add-source ../isa-parser --sandbox="$HOME/.cogent-sandbox"
    make 
    as_root ln -s "$HOME/.cogent-sandbox/bin/cogent" /usr/local/bin/cogent

    cogent -v
    # For now, just put an empty folder where autocorres may go in the future
    mkdir autocorres
) || exit 1


# Get the linux kernel headers, to build filesystems with
as_root apt-get update -q
as_root apt-get install -y --no-install-recommends \
        linux-headers-amd64 \
        # end of list

# Get the dir of the kernel headers. Because we're in a container, we can't be sure
# that the kernel running is the same as the headers, and so can't use uname
kernel_headers_dir="$(find /usr/src -maxdepth 1 -name 'linux-headers-*amd64' -type d | head -n 1)"

echo "export KERNELDIR=\"$kernel_headers_dir\"" >> "$HOME/.bashrc"

