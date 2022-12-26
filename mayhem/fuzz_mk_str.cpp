#include <stdint.h>
#include <stdio.h>
#include <climits>

#include <fuzzer/FuzzedDataProvider.h>

extern "C"
{
#include "utility_functions.h"
#include "markdown_peg.h"
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    FuzzedDataProvider provider(data, size);

    char *string = strdup(provider.ConsumeRandomLengthString(1000).c_str());

    element* e = mk_str(string);

    free_element(e);
    free(string);
    return 0;
}
