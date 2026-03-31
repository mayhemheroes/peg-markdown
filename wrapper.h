// https://stackoverflow.com/questions/72177535/how-can-i-include-a-c-header-that-uses-a-c-keyword-as-an-identifier-in-c
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wkeyword-macro"
#endif
#define new new_
#ifdef __clang__
#pragma clang diagnostic pop
#endif

#include "utility_functions.h"

#undef new
