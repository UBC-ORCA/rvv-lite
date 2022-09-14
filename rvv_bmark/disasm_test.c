// #include <stdio.h>
// #include <riscv_vector.h>
// #include <stdlib.h>


// #define TEST_SIZE   10
// #define ARR_LEN     3
// // can only handle up to 4096 bits per line per single vector register(128*32-bit elements, 64*64-bit, etc)

// // Uses 1 vector reg -> 23 lines total
// int test_malloc_param(int* out, vint32m4_t *test_malloc_arr) {
//     size_t vl;
//     vl = vsetvl_e32m4(TEST_SIZE);
    
//     for (int i = 0; i < ARR_LEN; i++){
//         test_malloc_arr[i] = vmv_v_x_i32m4(i, TEST_SIZE);
//     }
//     for (int i = 0; i < ARR_LEN; i++){
//         vse32_v_i32m4(out + i*ARR_LEN, test_malloc_arr[i], TEST_SIZE);
//     }
// }

// int test_malloc_param_main(int* out) {
//     vint32m4_t *test_malloc_arr = (vint32m4_t *)malloc(sizeof(vint32m4_t) * ARR_LEN);

//     test_malloc_param(out, test_malloc_arr);
// }

// // Uses 3 vector regs -> 12 lines total
// int test_malloc_arr(int* out) {
//     vint32m4_t *test_malloc_arr = (vint32m4_t *)malloc(sizeof(vint32m4_t) * ARR_LEN);

//     size_t vl;
//     vl = vsetvl_e32m4(TEST_SIZE);
    
//     for (int i = 0; i < ARR_LEN; i++){
//         test_malloc_arr[i] = vmv_v_x_i32m4(i, TEST_SIZE);
//     }
//     for (int i = 0; i < ARR_LEN; i++){
//         vse32_v_i32m4(out + i*ARR_LEN, test_malloc_arr[i], TEST_SIZE);
//     }
// }

// // Uses 1 vector reg -> 12 lines total
// int test_malloc_arr_strb4(int* out) {
//     vint32m4_t *test_malloc_arr = (vint32m4_t *)malloc(sizeof(vint32m4_t) * ARR_LEN);

//     size_t vl;
//     vl = vsetvl_e32m4(TEST_SIZE);
    
//     for (int i = 0; i < ARR_LEN; i++){
//         test_malloc_arr[i] = vmv_v_x_i32m4(i, TEST_SIZE);
//         vse32_v_i32m4(out + i*ARR_LEN, test_malloc_arr[i], TEST_SIZE);
//     }
// }

// // Uses 1 vector reg -> 40 lines (very inefficient)
// int test_setlen_arr(int* out) {
//     vint32m4_t test_arr[ARR_LEN];

//     size_t vl;
//     vl = vsetvl_e32m4(TEST_SIZE);

//     for (int i = 0; i < ARR_LEN; i++){
//         test_arr[i] = vmv_v_x_i32m4(i, vl);
//     }

//     for (int i = 0; i < ARR_LEN; i++){
//         vse32_v_i32m4(out + i*ARR_LEN, test_arr[i], vl);
//     }
// }

// // Uses 1 vector reg -> 12 lines of code total
// int test_setlen_arr_strb4(int* out) {
//     vint32m4_t test_arr[ARR_LEN];

//     size_t vl;
//     vl = vsetvl_e32m4(TEST_SIZE);

//     for (int i = 0; i < ARR_LEN; i++){
//         test_arr[i] = vmv_v_x_i32m4(i, vl);
//         vse32_v_i32m4(out + i*ARR_LEN, test_arr[i], vl);
//     }
// }

// // Uses 3 vector registers -> 12 lines
// int test_sep_vec(int* out) {
//     vint32m4_t test_sep_1;
//     vint32m4_t test_sep_2;
//     vint32m4_t test_sep_3;

//     size_t vl;
//     vl = vsetvl_e32m4(TEST_SIZE);

//     test_sep_1 = vmv_v_x_i32m4(0, vl);
//     test_sep_2 = vmv_v_x_i32m4(1, vl);
//     test_sep_3 = vmv_v_x_i32m4(2, vl);

//     vse32_v_i32m4(out, test_sep_1, vl);
//     vse32_v_i32m4(out + ARR_LEN, test_sep_2, vl);
//     vse32_v_i32m4(out + 2*ARR_LEN, test_sep_3, vl);
// }

// // Uses 1 vector register -> 12 lines
// int test_sep_vec_strb4(int* out) {
//     vint32m4_t test_sep_1;
//     vint32m4_t test_sep_2;
//     vint32m4_t test_sep_3;

//     size_t vl;
//     vl = vsetvl_e32m4(TEST_SIZE);

//     test_sep_1 = vmv_v_x_i32m4(0, vl);
//     vse32_v_i32m4(out, test_sep_1, vl);

//     test_sep_2 = vmv_v_x_i32m4(1, vl);
//     vse32_v_i32m4(out + ARR_LEN, test_sep_2, vl);

//     test_sep_3 = vmv_v_x_i32m4(2, vl);
//     vse32_v_i32m4(out + 2*ARR_LEN, test_sep_3, vl);
// }

// int rvv_disasm_test()
// {
//     int out [ARR_LEN*TEST_SIZE];

//     test_malloc_arr(out);
//     test_malloc_arr_strb4(out);

//     test_setlen_arr(out);
//     test_setlen_arr_strb4(out);

//     test_sep_vec(out);
//     test_sep_vec_strb4(out);

//     return 0;
// }
