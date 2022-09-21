#include <stdio.h>
#include <stdlib.h>
#include <riscv_vector.h>

#include "test_utils.h"

// can only handle up to 16
#define MAX_ELEMS   16
#define LMUL        4   // if this changes, the function calls in rvv_2d_fir must also change

#define NTAP_ROWS 4
#define NTAP_COLS 4

#define MAX_ELEMS_PER_VEC (MAX_ELEMS*LMUL)/NTAP_ROWS

#define TEST_ROWS 8
#define TEST_COLS 16

#define OUT_COLS (TEST_COLS - NTAP_COLS + 1)
#define OUT_ROWS (TEST_ROWS - NTAP_ROWS + 1)

#define IN_SIZE TEST_ROWS*TEST_COLS

#define MAX_PRINT_LEN 8

#define MIN(a,b) ((a>b) ? b : a)

void scalar_2d_fir( uint32_t *output, uint32_t *input, const uint32_t *coeffs,
        const int num_row, const int num_column, const int ntaps_row, const int ntaps_column );

void rvv_2d_fir(uint32_t *output, uint32_t *input, uint32_t *coeffs, const int stride,
        const int num_row, const int num_column, const int ntaps_row, const int ntaps_column );

void rvv_2d_fir(uint32_t *output, uint32_t *input, uint32_t *coeffs, const int stride,
        const int num_row, const int num_column, const int ntaps_row, const int ntaps_column )
{
    int l,j,i;

    size_t vl;

    vint32m4_t mul_int, accum, curr_row, acc_int;
    //          v1      v2      v3      v4

    int modj = 0;

    vl = vsetvl_e32m4 (stride);

    int32_t sample_row[ntaps_row * num_column];
    // get first batch of inputs
    
    for (i = 0; i < ntaps_row; i++){
        vint32m4_t tmp = vle32_v_i32m4 (reinterpret_cast<int32_t*>(&input[i * num_column]), vl);
        vse32_v_i32m4(&sample_row[i * num_column], tmp, vl);
    }

    for( l = 0; l <= num_row - ntaps_row; l++ ) {
        vint32m4_t tmp = vle32_v_i32m4 (&sample_row[modj * num_column], vl);
        acc_int     = vmul_vx_i32m4 (tmp, coeffs[0], vl);

        for( i = 1; i < ntaps_column; i++ ) {
            curr_row    = vslidedown_vx_i32m4 (tmp, tmp, i, vl);
            mul_int     = vmul_vx_i32m4 (curr_row, coeffs[i], vl);
            acc_int     = vadd_vv_i32m4 (acc_int, mul_int, vl);
        }

        int idx = (modj + 1) % ntaps_row;

        for( j = 1; j < ntaps_row; j++ ) {
            for( i = 0; i < ntaps_column; i++ ) {
                tmp = vle32_v_i32m4 (&sample_row[idx * num_column], vl);
                curr_row    = vslidedown_vx_i32m4 (tmp, tmp, i, vl);
                mul_int     = vmul_vx_i32m4 (curr_row, coeffs[j*ntaps_column+i], vl);
                acc_int     = vadd_vv_i32m4 (acc_int, mul_int, vl);
            }            
            idx = (idx + 1) % ntaps_row;
        }

        accum   = vsra_vx_i32m4 (acc_int, 8, vl);
        vl      = vsetvl_e32m4 (stride - ntaps_column + 1);

        vse32_v_i32m4 (reinterpret_cast<int32_t*>(&output[l*num_column]), accum, vl);

        if (l < (num_row - ntaps_row)){
            vl      = vsetvl_e32m4 (stride);
            vint32m4_t tmp = vle32_v_i32m4 (reinterpret_cast<int32_t*>(&input[(l + ntaps_row)*num_column]), vl);
            vse32_v_i32m4(&sample_row[modj * num_column], tmp, vl);
        }

        modj = (modj + 1) % ntaps_row;
    }
}

// COPIED FROM MXP REPO
void scalar_2d_fir( uint32_t *output, uint32_t *input, const uint32_t *coeffs,
        const int num_row, const int num_column, const int ntaps_row, const int ntaps_column )
{
    int l,k,j,i;
    uint32_t temp1, temp2;
    for( l = 0 ; l <= num_row-ntaps_row; l++) {
        for( k = 0; k <= num_column-ntaps_column; k++) {
            temp1 = 0;
            for( j = 0; j < ntaps_row; j++) {
                for( i = 0; i < ntaps_column; i++) {
                    temp1 += input[(l+j)*num_column+(k+i)] * coeffs[j*ntaps_column+i];
                }
            }
            output[l*num_column+k] = temp1 >> 8;
        }
    }
}

void rvv_2d_fir_test()
{
    // Compiler occasionally gives wrong result when these are on the same line
    int dim = TEST_COLS;
    dim *= TEST_ROWS;

    int coeff_dim = NTAP_ROWS;
    coeff_dim *= NTAP_COLS;

    unsigned int in         [dim];
    unsigned int coeffs     [coeff_dim];
    unsigned int out        [dim];
    unsigned int out_sca    [dim];

    // Initialize inputs with pseudo-random numbers

    init_array_intrinsics(  in,     dim,        1);
    init_array_intrinsics(  coeffs, coeff_dim,  1);

    puts("input:");
    print_array_intrinsics(in, TEST_ROWS, TEST_COLS, TEST_COLS, MAX_PRINT_LEN );

    puts("coeffs:");
    print_array_intrinsics(coeffs, NTAP_ROWS, NTAP_COLS, NTAP_COLS, MAX_PRINT_LEN);
    scalar_2d_fir(out_sca, in, coeffs, TEST_ROWS, TEST_COLS, NTAP_ROWS, NTAP_COLS );

    puts("scalar out:");
    print_array_intrinsics(out_sca, OUT_ROWS, OUT_COLS, TEST_COLS, MAX_PRINT_LEN );


    if (TEST_COLS <= MAX_ELEMS_PER_VEC) {
        rvv_2d_fir(out, in, coeffs, TEST_COLS, TEST_ROWS, TEST_COLS, NTAP_ROWS, NTAP_COLS );
    } else {
        // Compiler occasionally gives wrong result when these are on the same line
        int iters = TEST_COLS;
        iters /= MAX_ELEMS_PER_VEC;
        iters ++;

        int cols_left = TEST_COLS;

        for (int i = 0; i < iters; i++) {
            int stride = (i < (iters - 1)) ? MAX_ELEMS_PER_VEC : cols_left;
            int out_offset = MAX_ELEMS_PER_VEC - NTAP_COLS + 1;

            rvv_2d_fir(out + i*out_offset, in + i*out_offset, coeffs, stride, TEST_ROWS, TEST_COLS, NTAP_ROWS, NTAP_COLS );
            cols_left -= out_offset;
        }
    }


    puts("rvv out:");
    print_array_intrinsics(out, OUT_ROWS, OUT_COLS, TEST_COLS, MAX_PRINT_LEN );

    int errors = 0;
    printf("%d rows, %d cols\n", TEST_ROWS, TEST_COLS);
    errors += get_errors_mtx_intrinsics(out_sca, out, OUT_ROWS, OUT_COLS, TEST_COLS);

    printf("Test %s with %d errors\n", (errors ? "failed" : "passed"), errors);
}
