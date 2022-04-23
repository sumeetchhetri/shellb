#include <assert.h>

#ifdef __cplusplus
extern "C"
#endif
char FUNC_NAME();

#if _MSC_VER && !__INTEL_COMPILER
    #pragma function(accept4)
#endif

int main(void) {
#if defined (__stub_accept4) || defined (__stub___accept4)
  fail fail fail
#else
  FUNC_NAME();
#endif

  return 0;
}

