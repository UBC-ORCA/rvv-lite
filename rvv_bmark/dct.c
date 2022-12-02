// #include <stdio.h>
// #include <stdlib.h>
// #include <math.h>
// #include <riscv_vector.h>

// #include "test_utils.h"

// // can only handle up to 4096 bits per line per single vector register(128*32-bit elements, 64*64-bit, etc)
// #define IMG_H 8
// #define IMG_W 8

// #define BLOCK_SIZE  4
// #define NUM_TILE_X  2
// #define NUM_TILE_Y  2

// #define SHIFT_AMOUNT    7
// #define SHIFT_DOUBLE    16.0
// #define DCT_SIZE        (BLOCK_SIZE*BLOCK_SIZE)

// #define MAX_RAND_NUMBER 5
// #define IMG_ACR         (IMG_W/(BLOCK_SIZE*NUM_TILE_X))
// #define IMG_DWN         (IMG_H/(BLOCK_SIZE*NUM_TILE_Y))

// #define MAX_PRINT_LEN 8

// void scalar_dct(short *block_s, short *coeff_s, short *image, int start_x, int start_y, int num_tile_x, int num_tile_y );
// void rvv_dct( short *output, const vint16m2_t *coeffs, const short *image, int start_x, int start_y, int num_tile_x, int num_tile_y);

// static void gen_rand_img( short *image, int width, int height, int seed );
// void gen_set_img( short *image, int width, int height );

// int test_rvv_dct (short *out, short *coeff_v, short *image, int num_tile_x, int num_tile_y);

// // Recreating math library since it doesn't work for these functions?
// double cosine(double x);
// double factorial(double x);
// double pwr(double x, int exp);

// double factorial(double x) {
//     double fact = 1;
//     for (int i=1; i<=x; i++)    fact *= i;
//     return fact;
// }

// double pwr(double x, int exp) {
//     double out = x;
//     for (int i=1; i < exp; i++) {
//         out *= x;
//     }  
//     return out;
// }

// double cosine(double x) {
//     double y = 1;
//     double s = -1;
//     for (int i=2; i<=100; i+=2) {
//         y+=s*(pwr(x,i)/factorial(i));
//         s *= -1;
//     }  
//     return y;
// }

// void gen_set_img( short *image, int width, int height )
// {
//     /*generate set input matrix   */
//     int i, j;
//     for (i = 0; i < height; i++) {
//         for (j = 0; j < width; j++) {
//             // image[ i*width + j] = (short) (i*width+j);
//             image[ i*width + j] = 1;
//         }
//     }
// }

// static void gen_rand_img( short *image, int width, int height, int seed )
// {
//     /*generate random input matrix   */
//     int i, j;
//     srand(seed);
//     for (i = 0; i < height; i++) {
//         short salt = (short) (rand() % MAX_RAND_NUMBER - rand() % MAX_RAND_NUMBER);
//         for (j = 0; j < width; j++) {
//             if( i==0 ) {
//                 // first row is entirely random. this is slow due to rand() and mmodulo.
//                 image[ i*width + j] = (short) (rand() % MAX_RAND_NUMBER - rand() % MAX_RAND_NUMBER);
//             } else {
//                 // to speed up image generation,
//                 // successive rows are xor of previous row with a new random value
//                 image[ i*width + j] = salt ^ image[ (i-1)*width + j ];
//             }

//         }
//     }
// }

// void get_coeffs(short* cs, short *image )
// {
//     const int num_bytes = NUM_TILE_X * NUM_TILE_Y * DCT_SIZE * sizeof(short);
//     const int co_bytes = NUM_TILE_X * DCT_SIZE * sizeof(short);

//     double c2 [BLOCK_SIZE][BLOCK_SIZE];

//     //compute coeffs matrix in double and truncated to dt
//     int i, j;
//     float s;
//     for (i = 0; i < BLOCK_SIZE; i++) {
//         s = (i == 0) ? sqrt(0.125) : 0.5;
//         for (j = 0; j < BLOCK_SIZE; j++) {
//             c2[i][j] = s * cosine((float) ((M_PI / 8.0) * i * j + 0.5));
//             cs[i*BLOCK_SIZE + j] = (short) (c2[i][j] * SHIFT_DOUBLE + 0.499999);
//         }
//     }
// }

// void scalar_dct( short *out, short *coeff_s, short *image, int start_x, 
//                   int start_y, int num_tile_x, int num_tile_y )
// {
//     int i, j, k;
//     int x, y;
//     short s;
//     short tmp[DCT_SIZE];

//     start_x *= NUM_TILE_X;
//     start_y *= NUM_TILE_Y;

//     for (y = 0; y < num_tile_y; y++) {
//         for (x = 0; x < num_tile_x; x++) {
//             int imgrow = (y+start_y)*BLOCK_SIZE;
//             for (i = 0; i < BLOCK_SIZE; i++) {
//                 // Multiplies each row of image input by the full coeff matrix
//                 for (j = 0; j < BLOCK_SIZE; j++) {
//                     int index_img   = imgrow * IMG_W + (x+start_x)*BLOCK_SIZE;
//                     int index_coeff = j*BLOCK_SIZE;
//                     s = 0;
//                     for (k = 0; k < BLOCK_SIZE; k++) {
//                         s += coeff_s[(index_coeff++)] * image[ (index_img++) ];
//                     }
//                     tmp[BLOCK_SIZE * i + j] = (s) >> SHIFT_AMOUNT;
//                 }
//                 imgrow++;
//             }

//             // Matrix Multiply
//             int blkrow = (y+start_y)*BLOCK_SIZE;
//             for (i = 0; i < BLOCK_SIZE; i++) {
//                 int blkcol = (x+start_x)*BLOCK_SIZE;
//                 for (j = 0; j < BLOCK_SIZE; j++) {
//                     int index_coeff = i*BLOCK_SIZE;
//                     s = 0;
//                     for (k = 0; k < BLOCK_SIZE; k++) {
//                         s += coeff_s[(index_coeff++)] * tmp[BLOCK_SIZE * k + j];
//                     }

//                     out[ blkrow * IMG_W + (blkcol++) ] = (s) >> SHIFT_AMOUNT;
//                 }
//                 blkrow++;
//             }
//         }
//     }
// }

// // Even with unroll it only uses a couple vec regs and stores in between ops
// void rvv_dct( short *output, const vint16m2_t *coeffs, const short *image, int start_x, int start_y, int num_tile_x, int num_tile_y)
// {
//     int i, j;
//     int x, y;
//     int imgcol,imgrow,index_coeff,index_img,blkcol,blkrow;

//     int index_res = 0;

//     size_t vl;

//     vint16m2_t* pass1, pass2;
//      // = (vint16m2_t*)malloc(sizeof(vint16m2_t) * BLOCK_SIZE);
//     // vint16m2_t* pass2 = (vint16m2_t*)malloc(sizeof(vint16m2_t) * BLOCK_SIZE);
//     vint16m2_t  img_in, tmp, zero;

//     vl      = vsetvl_e16m2 (BLOCK_SIZE);
//     zero    = vmv_vi_i16m2 (0);

//     for (y = 0; y < num_tile_y; y++) {
//         for (x = 0; x < num_tile_x; x++) {
//             imgcol = (x+start_x)*BLOCK_SIZE;
//             imgrow = (y+start_y)*BLOCK_SIZE;

//             index_img = imgrow * IMG_W + imgcol;

//             for (i = 0; i < BLOCK_SIZE; i++) {
//                 img_in  = vle16_v_i16m2(image + index_img, BLOCK_SIZE);

//                 //1
//                 for (j = 0; j < BLOCK_SIZE; j++){
//                     // tmp     = vzero_i16m2();
//                     tmp     = vmul_vv_i16m2(img_in, coeffs[j], BLOCK_SIZE);
//                     tmp     = vredsum_vx_i16m2_i16m1(tmp, tmp, zero, BLOCK_SIZE);

//                     pass1[j]= vslideup_vx_i16m2(pass1[j], tmp, i, BLOCK_SIZE);

//                     // vse16_v_i16m2(output + i*BLOCK_SIZE, pass1[i]);
//                 }

//                 // vse16_v_i16m2(output + i*BLOCK_SIZE, pass1[i]);
                
//                 imgrow ++;
//                 index_img += IMG_W;
//             }

//             //2
//             for (i = 0; i < BLOCK_SIZE; i++){
//                 pass1[i]    = vsra_vx_i16m2(pass1[i],SHIFT_AMOUNT, BLOCK_SIZE);

//                 vse16_v_i16m2(output + i*BLOCK_SIZE, pass1[i], BLOCK_SIZE);
//             }

//             for (i = 0; i < BLOCK_SIZE; i++){
//                 for (j = 0; j < BLOCK_SIZE; j++){
//                     // tmp     = vzero_i16m2();
//                     tmp     = vmul_vv_i16m2(pass1[j], coeffs[i], BLOCK_SIZE);
//                     tmp     = vredsum_vs_i16m2_i16m2(tmp, tmp, zero, BLOCK_SIZE);

//                     pass2[i]= vslideup_vx_i16m2(pass2[i], tmp, j, BLOCK_SIZE);
//                 }
//             }

//             //4
//             for (i = 0; i < BLOCK_SIZE; i++){
//                 pass2[i]    = vsra_vx_i16m2(pass2[i],SHIFT_AMOUNT, BLOCK_SIZE);
//             }

//             int offset = (x + start_x)*BLOCK_SIZE*IMG_W + (y + start_y)*BLOCK_SIZE;

//             //5
//             for (i = 0; i < BLOCK_SIZE; i++){
//                 // vse16_v_i16m2(output + offset, pass2[i]);
//                 offset  += IMG_W;
//             }
//         }
//     }
// }

// // void rvv_dct_unroll( short *output, const vint16m2_t *coeffs, const short *image, int start_x, int start_y, int num_tile_x, int num_tile_y)
// // {
// //     int i, j;
// //     int x, y;
// //     int imgcol,imgrow,index_coeff,index_img,blkcol,blkrow;

// //     int index_res = 0;

// //     size_t vl;

// //     vint16m2_t* pass1 = (vint16m2_t*)malloc(sizeof(vint16m2_t) * BLOCK_SIZE);
// //     vint16m2_t* pass2 = (vint16m2_t*)malloc(sizeof(vint16m2_t) * BLOCK_SIZE);
// //     vint16m2_t  img_in, tmp, zero;

// //     vl      = vsetvl_e16m2 (BLOCK_SIZE);
// //     zero    = vzero_i16m2();

// //     for (y = 0; y < num_tile_y; y++) {
// //         for (x = 0; x < num_tile_x; x++) {
// //             imgcol = (x+start_x)*BLOCK_SIZE;
// //             imgrow = (y+start_y)*BLOCK_SIZE;

// //             index_img = imgrow * IMG_W + imgcol;

// //             for (i = 0; i < BLOCK_SIZE; i++) {
// //                 vl      = vsetvl_e16m2 (BLOCK_SIZE);

// //                 img_in  = vle16_v_i16m2(image + index_img);

// //                 //1
// //                 for (j = 0; j < BLOCK_SIZE; j+=2){
// //                     tmp     = vmul_vv_i16m2(img_in, coeffs[j]);
// //                     tmp     = vredsum_vs_i16m2_i16m2(tmp, tmp, zero);

// //                     pass1[j]= vslideup_vx_i16m2(pass1[j], tmp, i);

// //                     tmp     = vmul_vv_i16m2(img_in, coeffs[j + 1]);
// //                     tmp     = vredsum_vs_i16m2_i16m2(tmp, tmp, zero);

// //                     pass1[j + 1]= vslideup_vx_i16m2(pass1[j + 1], tmp, i);
// //                 }
                
// //                 imgrow ++;
// //                 index_img += IMG_W;
// //             }

// //             //2
// //             for (i = 0; i < BLOCK_SIZE; i+=2){
// //                 pass1[i]    = vsra_vx_i16m2(pass1[i],SHIFT_AMOUNT);

// //                 pass1[i+1]    = vsra_vx_i16m2(pass1[i+1],SHIFT_AMOUNT);
// //             }

// //             for (i = 0; i < BLOCK_SIZE; i+=2){
// //                 for (j = 0; j < BLOCK_SIZE; j+=2){
// //                     tmp     = vmul_vv_i16m2(pass1[j], coeffs[i]);
// //                     tmp     = vredsum_vs_i16m2_i16m2(tmp, tmp, zero);

// //                     pass2[i]= vslideup_vx_i16m2(pass2[i], tmp, j);

// //                     tmp     = vmul_vv_i16m2(pass1[j + 1], coeffs[i]);
// //                     tmp     = vredsum_vs_i16m2_i16m2(tmp, tmp, zero);

// //                     pass2[i]= vslideup_vx_i16m2(pass2[i], tmp, j + 1);
// //                 }
// //             }

// //             //4
// //             for (i = 0; i < BLOCK_SIZE; i+=2){
// //                 pass2[i]    = vsra_vx_i16m2(pass2[i],SHIFT_AMOUNT);

// //                 pass2[i+1]    = vsra_vx_i16m2(pass2[i+1],SHIFT_AMOUNT);
// //             }

// //             vsetvl_e16m2(BLOCK_SIZE);

// //             int offset = (x + start_x)*BLOCK_SIZE*IMG_W + (y + start_y)*BLOCK_SIZE;

// //             //5
// //             for (i = 0; i < BLOCK_SIZE; i+=2){
// //                 vse16_v_i16m2(output + offset, pass2[i]);
// //                 offset  += IMG_W;

// //                 vse16_v_i16m2(output + offset, pass2[i+1]);
// //                 offset  += IMG_W;
// //             }
// //         }
// //     }
// //     free (pass1);
// //     free (pass2);
// // }

// int test_rvv_dct (short *out, short *cs, short *image, int num_tile_x, int num_tile_y) {
//     int x, y;
//     size_t vl;

//     vl      = vsetvl_e16m2 (BLOCK_SIZE);

//     vint16m2_t* coeff;

//     for (x = 0; x < BLOCK_SIZE; x++){
//         coeff[x]    = vle16_v_i16m2((cs+BLOCK_SIZE*x), BLOCK_SIZE);
//     }

//     printf("IMG_ACR: %d, IMG_DWN: %d\n", IMG_ACR, IMG_DWN);

//     for( y = 0; y < IMG_DWN; y++ ) {
//         for( x = 0; x < IMG_ACR; x++ ) {
//             rvv_dct( out, coeff, image, x*NUM_TILE_X, y*NUM_TILE_Y, NUM_TILE_X, NUM_TILE_Y);
//         }
//     }
//     return 0;
// }

// int rvv_dct_test()
// {
//     short in [IMG_H*IMG_W];
//     short coeffs [DCT_SIZE];
//     short out [IMG_H*IMG_W] = {0};
//     short out_sca [IMG_H*IMG_W] = {0};

//     int x, y, i, j;

//     gen_rand_img(in, IMG_W, IMG_H, 100);
//     get_coeffs(coeffs, in);

//     puts("in:");
//     print_array_intrinsics_half(in, IMG_H, IMG_W, IMG_W, MAX_PRINT_LEN );

//     puts("coeffs:");
//     print_array_intrinsics_half(coeffs, BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE, MAX_PRINT_LEN);

//     for( y = 0; y < IMG_DWN; y++ ) {
//         for( x = 0; x < IMG_ACR; x++ ) {
//             scalar_dct( out_sca, coeffs, in, x, y, NUM_TILE_X, NUM_TILE_Y );
//         }
//     }

//     puts("\nscalar out:");
//     print_array_intrinsics_half(out_sca, IMG_H, IMG_W, IMG_W, MAX_PRINT_LEN );

//     test_rvv_dct(out, coeffs, in, NUM_TILE_X, NUM_TILE_Y );
//     puts("\nrvv out:");
//     print_array_intrinsics_half(out, IMG_H, IMG_W, IMG_W, MAX_PRINT_LEN );

//     int errors = 0;
//     printf("%d x %d input\n", IMG_H, IMG_W);
//     for (y = 0; y < IMG_H; y+=BLOCK_SIZE) {
//         for (x = 0; x < IMG_W; x+= BLOCK_SIZE) {
//             errors += get_errors_mtx_intrinsics_half(out_sca + y*IMG_W + x, out + y*IMG_W + x, BLOCK_SIZE, BLOCK_SIZE, IMG_W);
//         }
//     }

//     printf("\nTest %s with %d errors\n", (errors ? "failed" : "passed"), errors);

//     return 0;
// }
