ARG BASE_IMG=trustworthysystems/sel4
FROM $BASE_IMG
LABEL ORGANISATION="Trustworthy Systems"
LABEL MAINTAINER="Luke Mondy (luke.mondy@data61.csiro.au)"

# ARGS are env vars that are *only available* during the docker build
# They can be modified at docker build time via '--build-arg VAR="something"'
ARG SCM=https://bitbucket.ts.data61.csiro.au/scm
ARG INTERNAL=yes
ARG DESKTOP_MACHINE=no
ARG MAKE_CACHES=yes

ARG SCRIPT=camkes.sh

COPY scripts /tmp/

RUN /bin/bash /tmp/${SCRIPT} \
    && apt-get clean autoclean \
    && apt-get autoremove --purge --yes \
    && rm -rf /var/lib/apt/lists/*
