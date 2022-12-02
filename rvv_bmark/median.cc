
#include <stdio.h>
#include <riscv_vector.h>
#include <stdlib.h>

#include "test_utils.h"

#define IMG_H 908
#define IMG_W 128
#define IMG_PITCH_MAX 16

#define FILTER_WIDTH 3
#define FILTER_HEIGHT 3

#define MAX_PRINT_LEN 8

void rvv_vminmaxup (vint32m4_t v1, vint32m4_t v2, vint32m4_t vtmp);
void rvv_vminmaxdn (vint32m4_t v1, vint32m4_t v2, vint32m4_t vtmp);
void rvv_median(unsigned int* output, unsigned int* input, 
        const int image_width, const int image_height, const int32_t image_pitch);

uint32_t scalar_bubble_uword(uint32_t *array, const int32_t filter_size);
void scalar_median_uword(uint32_t *output, uint32_t *input, const int32_t filter_height,
        const int32_t filter_width, const int32_t image_height, const int32_t image_width,
        const int32_t image_pitch);

uint32_t scalar_bubble_uword(uint32_t *array, const int32_t filter_size)
{
    uint32_t min, temp;
    int32_t j, i;
    for(j = 0; j < filter_size/2; j++){
        min = array[j];
        for(i = j+1; i < filter_size; i++){
            if(array[i] < min){
                temp = min;
                min = array[i];
                array[i] = temp;
            }
        }
        array[j] = min;
    }
    min = array[filter_size/2];
    for (i = (filter_size/2)+1; i < filter_size; i++){
        if (array[i] < min){
            min = array[i];
        }
    }
    return min;
}

void scalar_median_uword(uint32_t *output, uint32_t *input, const int32_t filter_height,
        const int32_t filter_width, const int32_t image_height, const int32_t image_width,
        const int32_t image_pitch)
{
    int32_t y,x,j,i;
    uint32_t array[filter_height*filter_width];

    for(y=0; y<image_height-2; y++){
        for(x=0; x<image_width-2; x++){
            for(j=0; j<filter_height; j++){
                for(i=0; i<filter_width; i++){
                    array[j*filter_width+i] = input[(y+j)*image_pitch+(x+i)];
                }
            }
            output[y*image_pitch+x] = scalar_bubble_uword(array, filter_height*filter_width);
        }
    }
}

void rvv_vminmaxdn (vint32m4_t v1, vint32m4_t v2, vint32m4_t vtmp, size_t vl) {
    vtmp    = vmv_v_v_i32m4 (v1, vl);
    v1      = vmin_vv_i32m4 (vtmp, v2, vl);
    v2      = vmax_vv_i32m4 (vtmp, v2, vl);
}

void rvv_vminmaxup (vint32m4_t v1, vint32m4_t v2, vint32m4_t vtmp, size_t vl) {
    vtmp    = vmv_v_v_i32m4 (v2, vl);
    v2      = vmin_vv_i32m4 (vtmp, v1, vl);
    v1      = vmax_vv_i32m4 (vtmp, v1, vl);
}

void rvv_median(unsigned int* output, unsigned int* input, 
        const int image_width, const int image_height, const int32_t image_pitch)
{

    size_t vl = vsetvl_e32m4 (image_pitch - 2);

    int32_t in_row[9 * vl];
    int32_t tmp[6 * vl];

    vint32m4_t vtmp;

    for (int i = 0; i < 2; i++)
    {
        for (int j = 0; j < 3; j++)
        {
            vtmp = vle32_v_i32m4(reinterpret_cast<int*>(input + image_width*i + j), vl);
            vse32_v_i32m4(&in_row[(j + 3*i) * vl], vtmp, vl);
        }
    }

    for (int i = 0; i < image_height - 2; i++) {
        for (int j = 0; j < 3; j++)
        {
            vtmp = vle32_v_i32m4(reinterpret_cast<int*>(input + 2*image_width + j), vl);
            vse32_v_i32m4(&in_row[(j + 6) * vl], vtmp, vl);
        }

        for (int j = 0; j < 6; j++){
            vtmp = vle32_v_i32m4(&in_row[(j+3)*vl], vl);
            vse32_v_i32m4(&tmp[j* vl], vmv_v_v_i32m4(vtmp, vl), vl);
        }

        //Stage 1
        rvv_vminmaxdn (vle32_v_i32m4(&in_row[0*vl],vl), vle32_v_i32m4(&in_row[1*vl],vl), vtmp, vl);
        rvv_vminmaxup (vle32_v_i32m4(&in_row[2*vl],vl), vle32_v_i32m4(&tmp[0*vl],vl), vtmp, vl);
        rvv_vminmaxup (vle32_v_i32m4(&tmp[1*vl],vl), vle32_v_i32m4(&tmp[2*vl],vl), vtmp, vl);
        rvv_vminmaxdn (vle32_v_i32m4(&tmp[4*vl],vl), vle32_v_i32m4(&tmp[5*vl],vl), vtmp, vl);

        //Stage 2
        rvv_vminmaxup (vle32_v_i32m4(&in_row[0*vl],vl), vle32_v_i32m4(&in_row[2*vl],vl), vtmp, vl);
        rvv_vminmaxdn (vle32_v_i32m4(&tmp[3*vl],vl), vle32_v_i32m4(&tmp[5*vl],vl), vtmp, vl);

        rvv_vminmaxup (vle32_v_i32m4(&in_row[1*vl],vl), vle32_v_i32m4(&tmp[0*vl],vl), vtmp, vl);

        //Stage 3
        rvv_vminmaxup (vle32_v_i32m4(&in_row[0*vl],vl), vle32_v_i32m4(&in_row[1*vl],vl), vtmp, vl);
        rvv_vminmaxup (vle32_v_i32m4(&in_row[2*vl],vl), vle32_v_i32m4(&tmp[0*vl],vl), vtmp, vl);
        rvv_vminmaxdn (vle32_v_i32m4(&tmp[1*vl],vl), vle32_v_i32m4(&tmp[5*vl],vl), vtmp, vl);

        rvv_vminmaxdn(vle32_v_i32m4(&tmp[3*vl],vl), vle32_v_i32m4(&tmp[4*vl],vl), vtmp, vl);

        //Stage 4
        rvv_vminmaxdn(vle32_v_i32m4(&in_row[0*vl],vl), vle32_v_i32m4(&tmp[5*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&tmp[1*vl],vl), vle32_v_i32m4(&tmp[3*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&tmp[2*vl],vl), vle32_v_i32m4(&tmp[4*vl],vl), vtmp, vl);

        //Stage 5
        rvv_vminmaxdn(vle32_v_i32m4(&tmp[1*vl],vl), vle32_v_i32m4(&tmp[2*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&tmp[3*vl],vl), vle32_v_i32m4(&tmp[4*vl],vl), vtmp, vl);

        //Stage 6
        rvv_vminmaxdn(vle32_v_i32m4(&in_row[0*vl],vl), vle32_v_i32m4(&tmp[1*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&in_row[1*vl],vl), vle32_v_i32m4(&tmp[2*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&in_row[2*vl],vl), vle32_v_i32m4(&tmp[3*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&tmp[0*vl],vl), vle32_v_i32m4(&tmp[4*vl],vl), vtmp, vl);

        //Stage 7
        rvv_vminmaxdn(vle32_v_i32m4(&in_row[0*vl],vl), vle32_v_i32m4(&in_row[2*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&in_row[1*vl],vl), vle32_v_i32m4(&tmp[0*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&tmp[1*vl],vl), vle32_v_i32m4(&tmp[3*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&tmp[2*vl],vl), vle32_v_i32m4(&tmp[4*vl],vl), vtmp, vl);

        //Stage 8
        rvv_vminmaxdn(vle32_v_i32m4(&in_row[0*vl],vl), vle32_v_i32m4(&in_row[1*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&in_row[2*vl],vl), vle32_v_i32m4(&tmp[0*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&tmp[1*vl],vl), vle32_v_i32m4(&tmp[2*vl],vl), vtmp, vl);
        rvv_vminmaxdn(vle32_v_i32m4(&tmp[3*vl],vl), vle32_v_i32m4(&tmp[4*vl],vl), vtmp, vl);

        vse32_v_i32m4(reinterpret_cast<int*>(output), vle32_v_i32m4(&tmp[1*vl],vl), vl);

        // Move to next set of rows
        for (int j = 0; j < 6; j++){
            vtmp = vle32_v_i32m4(&in_row[(j+3)*vl], vl);
            vse32_v_i32m4(&in_row[j* vl], vmv_v_v_i32m4(vtmp, vl), vl);
        }

        output += image_width;
        input += image_width;
    }
}

void rvv_median_test()
{
    unsigned int in [IMG_H*IMG_W];
    unsigned int out [IMG_H*IMG_W] = {0};
    unsigned int out_sca [IMG_H*IMG_W] = {0};

    init_array_px_intrinsics(in, IMG_W, IMG_H);
    puts("input:");
    print_array_intrinsics(in, IMG_H, IMG_W, IMG_W, MAX_PRINT_LEN );

    scalar_median_uword(out_sca, in, FILTER_HEIGHT, FILTER_WIDTH, IMG_H, IMG_W, IMG_W);
    puts("scalar out:");
    print_array_intrinsics(out_sca, IMG_H, IMG_W, IMG_W, MAX_PRINT_LEN );


    if (IMG_W <= IMG_PITCH_MAX) {
        rvv_median(out, in, IMG_W, IMG_H, IMG_W);
    } else {
        int iters = IMG_W/IMG_PITCH_MAX;
        for (int i = 0; i <= iters; i++){
            int img_pitch = (i < iters) ? IMG_PITCH_MAX : (IMG_W - i*(IMG_PITCH_MAX - 2));
            rvv_median(out + i*(IMG_PITCH_MAX - 2), in + i*(IMG_PITCH_MAX - 2), IMG_W, IMG_H, img_pitch);
        }
    }

    puts("rvv out:");
    print_array_intrinsics(out, IMG_H, IMG_W, IMG_W, MAX_PRINT_LEN );

    int errors = 0;

    errors += get_errors_intrinsics(out_sca, out, IMG_W*IMG_H);

    printf("Test %s with %d errors\n", (errors ? "failed" : "passed"), errors);
}
