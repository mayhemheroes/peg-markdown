# syntax=docker/dockerfile:1.7
#
# peg-markdown commit-image: FROM the org base, a DEV image that retains full source
# + toolchain. Builds via mayhem/build.sh, then runs the functional suite (test.sh).
FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
# SOURCE_DATE_EPOCH stays an ARG (available to build.sh); do NOT bake it as an ENV — an
# empty value breaks clang both here and for any in-image rebuild.
ARG SOURCE_DATE_EPOCH
# Sanitizer override (default = base ASan+UBSan): --build-arg SANITIZER_FLAGS="-fsanitize=address ..."
ARG SANITIZER_FLAGS
# Build parallelism (optional; build.sh falls back to nproc): --build-arg MAYHEM_JOBS=8
ARG MAYHEM_JOBS=

# peg-markdown needs the GLib dev headers (GString throughout the parser/writers) and
# `tidy` (MarkdownTest.pl --tidy normalizes HTML before comparing); the base ships neither.
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends libglib2.0-dev tidy && \
    rm -rf /var/lib/apt/lists/*

USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

# Seed corpus: seeds are NOT baked into the image. Mayhem resolves the Mayhemfile
# `testsuite:` file:// entries against the checkout on the CI runner; the git-tracked
# seeds under mayhem/testsuite/ are all that's needed.
RUN bash mayhem/build.sh

# Run the shipped functional suite at build time — a failing suite fails the image
# build, so the commit image is guaranteed to build AND pass its own tests.
RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh — repo ships no functional tests"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
