#include <stdio.h>
#include <math.h>

void init_array_intrinsics( uint32_t *d, int size, int seed );
void inc_array_intrinsics( uint32_t *d, int size, int seed, int increase );
void init_array_px_intrinsics(unsigned int *input, const int image_width, const int image_height)
void print_array_intrinsics( uint32_t *in, int rows, int cols, int rowlen, int max_print);
void print_array_intrinsics_half( uint16_t *in, int rows, int cols, int rowlen, int max_print);

int get_errors_intrinsics (uint32_t *in, uint32_t *out, int num_elems);
int get_errors_mtx_intrinsics (uint32_t *out_sca, uint32_t *out, int rows, int cols, int rowlen);
int get_errors_mtx_intrinsics_half (uint16_t *out_sca, uint16_t *out, int rows, int cols, int rowlen);