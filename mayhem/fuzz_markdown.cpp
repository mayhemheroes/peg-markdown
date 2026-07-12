// In-process libFuzzer harness for the FULL peg-markdown pipeline:
// PEG parser (references + notes + document passes) -> every output writer
// (HTML / LaTeX / groff-mm / ODF) via the public markdown_to_string() API —
// the exact code path the `markdown` CLI drives.
//
// Why a libFuzzer harness and not the raw `markdown @@` CLI: the file-input CLI
// produced 0 edges in Mayhem (an uninstrumented one-shot batch binary Mayhem
// could not trace for coverage). Converting to an in-process harness over the
// same library entry point (markdown_to_string) makes the fuzzed code
// SanitizerCoverage-instrumented, so it actually accrues edges, while covering
// the identical parser + writer code. Target name `markdown` is preserved.
//
// Each iteration also exercises the extension flags and all four output
// formats so the smart-typography / notes / HTML-filter / strike passes and
// every writer are reachable.
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <string>

#include <fuzzer/FuzzedDataProvider.h>

extern "C" {
#include "markdown_lib.h"
}

static const int kFormats[] = {
    HTML_FORMAT, LATEX_FORMAT, GROFF_MM_FORMAT, ODF_FORMAT
};

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    FuzzedDataProvider provider(data, size);

    int format = kFormats[provider.ConsumeIntegralInRange<size_t>(0, 3)];
    // Low 5 bits map onto the five defined markdown_extensions flags.
    int extensions = provider.ConsumeIntegral<uint8_t>() & 0x1F;

    // markdown_to_string() takes a mutable, NUL-terminated C string.
    std::string text = provider.ConsumeRemainingBytesAsString();
    char *input = strdup(text.c_str());
    if (input == NULL)
        return 0;

    char *out = markdown_to_string(input, extensions, format);
    free(out);
    free(input);
    return 0;
}
