/*
 * Disable LeakSanitizer for the `markdown` harness only.
 *
 * markdown_to_string() is the exact allocate-and-exit code path the upstream
 * `markdown` CLI drives, and the library intentionally does not free everything
 * it allocates: markdown_to_g_string() frees the parsed `result` and
 * `references` lists but never the `notes` list. Under the notes extension that
 * is a per-call leak by design, so LeakSanitizer would flag nearly every input
 * and drown out real defects. LSan also ptrace-attaches at exit, which collides
 * with Mayhem's own coverage tracing (SIGABRT).
 *
 * A STRONG definition of __asan_default_options() overrides the WEAK copy in
 * the ASan runtime and injects detect_leaks=0 before any env processing. ASan
 * (memory-safety errors) and UBSan stay fully ON and halting, so the
 * NULL-pointer-dereference / memory defects on this code path are still caught.
 * The fuzz_mk_str harness does NOT link this file — leak detection stays on
 * there (it frees what it allocates, so any leak it reports is a real bug).
 */
const char *__asan_default_options(void) {
    return "detect_leaks=0";
}
