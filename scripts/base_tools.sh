#!/bin/bash

set -exuo pipefail

# Source common functions with funky bash, as per: https://stackoverflow.com/a/12694189
DIR="${BASH_SOURCE%/*}"
test -d "$DIR" || DIR=$PWD
# shellcheck source=utils/common.sh
. "$DIR/utils/common.sh"

# General usage scripts location
: "${SCRIPTS_DIR:=$HOME/bin}"

# Are we building inside Trustworthy Systems?
: "${INTERNAL:=no}"

# Repo location
: "${REPO_DIR:=$HOME/bin}"

# By default, assume we are on a desktop (usually less destructive)
: "${DESKTOP_MACHINE:=yes}"

# Docker may set this variable - fill if not set
: "${SCM:=https://github.com}"


if [ "$DESKTOP_MACHINE" = "no" ] ; then
    # Add additional mirrors for different Debian releases
    as_root tee -a /etc/apt/sources.list.d/alternate_mirror.list > /dev/null << EOF
    deb http://httpredir.debian.org/debian/ buster main
    deb http://httpredir.debian.org/debian/ buster-updates main
    deb http://httpredir.debian.org/debian/ stretch main
    deb http://httpredir.debian.org/debian/ bullseye main
EOF

    # Tell apt that we should prefer packages from Buster
    as_root tee -a /etc/apt/apt.conf.d/70debconf << EOF
APT::Default-Release "buster";
EOF

    # These commands supposedly speed-up and better dockerize apt.
    echo "force-unsafe-io" | as_root tee /etc/dpkg/dpkg.cfg.d/02apt-speedup > /dev/null
    echo "Acquire::http {No-Cache=True;};" | as_root tee /etc/apt/apt.conf.d/no-cache > /dev/null

fi

as_root apt-get update -q
as_root apt-get install -y --no-install-recommends \
        bc \
        ca-certificates \
        devscripts \
        expect \
        git \
        jq \
        make \
        mercurial \
        python-dev \
        python-pip \
        python3-dev \
        python3-pip \
        wget \
        # end of list

# Install python dependencies for both python 2 & 3
# Upgrade pip first, then install setuptools (required for other pip packages)
# Install some basic python tools
for pip in "pip2" "pip3"; do
    as_root ${pip} install --no-cache-dir --upgrade pip==18.1
    as_root ${pip} install --no-cache-dir \
        setuptools
    as_root ${pip} install --no-cache-dir \
        aenum \
        gitlint \
        nose \
        pexpect \
        plyplus \
        sh \
        # end of list
done

# 'reuse' tool only available for python3:
as_root pip3 install --no-cache-dir \
    reuse \
    # end of list

# Add some symlinks so some programs can find things
if [ "$DESKTOP_MACHINE" = "no" ] ; then
    as_root ln -s /usr/bin/hg /usr/local/bin/hg
    as_root ln -s /usr/bin/make /usr/bin/gmake
fi

try_nonroot_first mkdir -p "$SCRIPTS_DIR" || chown_dir_to_user "$SCRIPTS_DIR"

# Install Google's repo
try_nonroot_first mkdir -p "$REPO_DIR" || chown_dir_to_user "$REPO_DIR"
wget -O - https://storage.googleapis.com/git-repo-downloads/repo > "$REPO_DIR/repo"
chmod a+x "$REPO_DIR/repo"
echo "export PATH=\$PATH:$REPO_DIR" >> "$HOME/.bashrc"
export PATH=$PATH:$REPO_DIR  # make repo available ASAP

# If this is being built inside Trustworthy Systems, get some scripts used to control simulations
if [ "$INTERNAL" = "yes" ]; then
    (
        cd "$SCRIPTS_DIR"
        if [ "$INTERNAL" = "yes" ]; then
            # This repo is not released externally
            git clone --depth=1 http://bitbucket.ts.data61.csiro.au/scm/sel4proj/console_reboot.git
            chmod +x console_reboot/simulate/*
        fi
        # Get some useful SEL4 tools
        git clone --depth=1 "${SCM}/sel4/sel4_libs.git"
    ) || exit 1
fi
