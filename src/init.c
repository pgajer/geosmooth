#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

extern SEXP S_geosmooth_native_stub(void);

static const R_CallMethodDef CallEntries[] = {
    {"S_geosmooth_native_stub", (DL_FUNC) &S_geosmooth_native_stub, 0},
    {NULL, NULL, 0}
};

void R_init_geosmooth(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
