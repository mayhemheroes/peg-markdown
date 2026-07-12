// https://stackoverflow.com/questions/72177535/how-can-i-include-a-c-header-that-uses-a-c-keyword-as-an-identifier-in-c
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wkeyword-macro"
#endif
#define new new_
// <unistd.h> declares link(), which collides with the project's
// `typedef struct Link link`. Include it FIRST (its guard then keeps later
// includes from re-declaring link under the macro), and rename the typedef
// (nothing in the harness uses it by name).
#include <unistd.h>
#define link md_link_t
#ifdef __clang__
#pragma clang diagnostic pop
#endif

#include "utility_functions.h"

#undef new
#undef link
