/*
 * Disable LeakSanitizer for the file-input CLI target only.
 *
 * Two reasons:
 *  - `markdown` is a one-shot batch tool: it parses, prints, and exits without
 *    freeing its process-lifetime allocations, so LSan flags every run.
 *  - LSan ptrace-attaches at exit to walk the heap; Mayhem already traces the
 *    process for edge coverage, so LSan's ptrace fails → SIGABRT → 0 edges.
 *
 * A STRONG definition of __asan_default_options() overrides the WEAK copy in
 * the ASan runtime and injects detect_leaks=0 before any env processing.
 * The libFuzzer harness does NOT link this file — leak detection stays on there.
 */
const char *__asan_default_options(void) {
    return "detect_leaks=0";
}
