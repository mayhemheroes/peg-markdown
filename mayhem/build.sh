#!/usr/bin/env bash
#
# peg-markdown/mayhem/build.sh — build BOTH Mayhem targets with ASan+UBSan:
#   - markdown      (file-input CLI: full PEG parser + HTML/LaTeX/groff writers)
#   - fuzz_mk_str   (libFuzzer harness over mk_str/free_element)
# plus a NORMAL-flags oracle binary (/mayhem/markdown-oracle) that mayhem/test.sh
# runs against the shipped MarkdownTest_1.0.3 golden suite.
set -euo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# Build knobs come from the ENVIRONMENT (overridable), with sane defaults:
#   SANITIZER_FLAGS  base default = ASan+UBSan, halting
#   DEBUG_FLAGS      DWARF < 4 (Mayhem triage can't read DWARF >= 4; clang-19's -g is DWARF-5)
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -g}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS
cd "$SRC"

# Upstream's default CFLAGS are "-Wall -O3 -ansi -D_GNU_SOURCE". On glibc >= 2.34 that
# combination no longer compiles: _GNU_SOURCE pulls <unistd.h> (which declares link())
# into every TU via <signal.h>/bits/sigstksz.h, colliding with the project's
# `typedef struct Link link` in markdown_peg.h. -std=gnu89 keeps the C89 semantics the
# generated parser needs (and declares strdup) WITHOUT defining _GNU_SOURCE.
PM_CFLAGS="-Wall -O2 -std=gnu89"
GLIB_CFLAGS="$(pkg-config --cflags glib-2.0)"
GLIB_LIBS="$(pkg-config --libs glib-2.0)"

# 0) The vendored peg/leg parser generator is a BUILD TOOL: build it with its own normal
#    flags (never sanitized), then touch it so the top-level `$(LEG): $(PEGDIR)` rule
#    (dir mtime == leg mtime after a fresh build) doesn't re-enter the sub-make with our
#    overridden CFLAGS (-std=gnu89 would break tree.c's `inline` under -ansi-like modes).
make -C peg-0.1.9 CC=gcc leg
touch peg-0.1.9/leg

# 1) Oracle build FIRST, with NORMAL flags, stashed to /mayhem/markdown-oracle so
#    mayhem/test.sh only RUNS it. `make clean` on both sides so a re-run (PATCH tier)
#    never links normal-flags objects against leftover sanitized ones (idempotency).
make clean
make -j"$MAYHEM_JOBS" CC="$CC" CFLAGS="$PM_CFLAGS" markdown
cp markdown /mayhem/markdown-oracle
make clean

# 2) Sanitized library (all parser/writer objects).
make -j"$MAYHEM_JOBS" CC="$CC" CFLAGS="$PM_CFLAGS $SANITIZER_FLAGS $DEBUG_FLAGS" libpeg-markdown.a

# 3) File-input CLI target. Link mayhem/asan_options.c (STRONG __asan_default_options →
#    detect_leaks=0): the one-shot CLI never frees its parse tree before exit, and LSan's
#    ptrace-at-exit also collides with Mayhem's own tracing (SIGABRT → 0 edges).
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/asan_options.c -o /tmp/asan_options.o
$CC $GLIB_CFLAGS $PM_CFLAGS $SANITIZER_FLAGS $DEBUG_FLAGS \
    -o /mayhem/markdown markdown.c /tmp/asan_options.o libpeg-markdown.a $GLIB_LIBS

# 4) libFuzzer harness (in-process; leak detection stays ON — the harness frees what it
#    allocates, so any leak it reports is a real mk_str/free_element bug).
$CXX $GLIB_CFLAGS $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    mayhem/fuzz_mk_str.cpp -I. -Imayhem libpeg-markdown.a $GLIB_LIBS \
    -o /mayhem/fuzz_mk_str

# 5) Standalone (non-fuzzer) reproducer: same harness + LLVM's standalone main. Compile
#    the driver as C so its LLVMFuzzerTestOneInput reference keeps C linkage.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o
$CXX $GLIB_CFLAGS $SANITIZER_FLAGS $DEBUG_FLAGS /tmp/standalone_main.o \
    mayhem/fuzz_mk_str.cpp -I. -Imayhem libpeg-markdown.a $GLIB_LIBS \
    -o /mayhem/fuzz_mk_str-standalone
