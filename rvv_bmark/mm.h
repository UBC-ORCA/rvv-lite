#ifndef MM_TEST_H
#define MM_TEST_H

#ifdef __cplusplus
extern "C" {
#endif

int32_t* matrix_multiply_riscv_int(int32_t* A, int32_t* B, int N);

void print_matrix_int(int32_t* A, int N);

int32_t* random_matrix_int(int N);

int32_t* mm_scalar_int(int32_t* A, int32_t* B, int N);

void check_mm_equal_int(int32_t* rvv_mm, int32_t* scalar_mm, int N);

int rvv_mm_test();

#ifdef __cplusplus
}
#endif

#endif 