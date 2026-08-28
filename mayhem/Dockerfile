# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile for clib, built ON TOP of the org C/C++ base.
# The base provides clang/llvm + libFuzzer + the build-contract ENV
# (CC/CXX/SANITIZER_FLAGS/LIB_FUZZING_ENGINE/STANDALONE_FUZZ_MAIN/SRC).

FROM ghcr.io/savantenvs/base:20260621

ARG COMMIT
ARG REPO_URL
ARG SOURCE_DATE_EPOCH
ARG SANITIZER_FLAGS
ARG MAYHEM_JOBS=

# clib's manifest parser (fuzz_manifest target) links libcurl, mirroring
# upstream's Makefile. Bake the dev package as a root layer so the air-gapped
# build.sh re-run needs no network. (build.sh itself installs nothing.)
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends libcurl4-openssl-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh

RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
