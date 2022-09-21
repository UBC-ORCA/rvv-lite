#include "test_utils.h"
// COPIED FROM MXP REPO
void init_array_intrinsics( uint32_t *d, int size, int seed )
{
    int i;
    // printf("init size: %d\n", size);
    d[0]  = seed;
    for(i = 1; i < size; i++){
        d[i] = (((d[i-1]>>7)^(d[i-1]>>5)^(d[i-1]>>4)^(d[i-1]>>3))&0x1)|(((d[i-1])<<1)&0xFE);
    }
}

// COPIED FROM MXP REPO
void inc_array_intrinsics( uint32_t *d, int size, int seed, int increase )
{
    int i;
    for(i = 0; i < size; i++){
        d[i] = seed;
        seed += increase;
    }
}

void init_array_px_intrinsics(unsigned int *input, const int image_width, const int image_height)
{
    int aux = 1;
    for (int i = 0; i < image_width*image_height; ++i) {
        input[i] = aux;
        aux++;
        if(aux >= 0xFFFFFFFF ) aux = 1;
    }
}

void print_array_intrinsics( uint32_t *in, int rows, int cols, int rowlen, int max_print)
{
    for(int i = 0; i < rows && i < max_print; i++){
        for (int j = 0; j < cols && j < max_print; j++){
            printf("%08x ", in[i*rowlen + j]);
        }
        puts("");
    }
    puts("");
}

void print_array_intrinsics_half( uint16_t *in, int rows, int cols, int rowlen, int max_print)
{
    for(int i = 0; i < rows && i < max_print; i++){
        for (int j = 0; j < cols && j < max_print; j++){
            printf("%04x ", in[i*rowlen + j]);
        }
        puts("");
    }
    puts("");
}

int get_errors_intrinsics (uint32_t *out_sca, uint32_t *out, int num_elems)
{
    int errors = 0;
    // printf("N: %d\n", num_elems);
    for(int i = 0; i < num_elems; i++){
        if (out[i] != out_sca[i]){
            // printf("err @ %d: %d, expected %d\n", i, out[i], out_sca[i]);
            errors++;
        }
    }
    return errors;
}

int get_errors_mtx_intrinsics (uint32_t *out_sca, uint32_t *out, int rows, int cols, int rowlen)
{
    int errors = 0;
    for(int i = 0; i < rows; i++){
        for (int j = 0; j < cols; j++){
            int idx = i*rowlen + j;
            if (out[idx] != out_sca[idx]){
                printf("err @ %d: %d, expected %d\n", idx, out[idx], out_sca[idx]);
                errors++;
            }
        }
        // puts("");
    }
    return errors;
}

int get_errors_mtx_intrinsics_half (uint16_t *out_sca, uint16_t *out, int rows, int cols, int rowlen)
{
    int errors = 0;
    for(int i = 0; i < rows; i++){
        for (int j = 0; j < cols; j++){
            int idx = i*rowlen + j;
            if (out[idx] != out_sca[idx]){
                // printf("err @ %d: %d, expected %d\n", idx, out[idx], out_sca[idx]);
                errors++;
            } else {
                // printf(" %04x vs %04x |", out[idx], out_sca[idx]);
            }
        }
        // puts("");
    }
    return errors;
}
