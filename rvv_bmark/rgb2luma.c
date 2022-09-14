#include <stdio.h>
// #include <math.h>
#include <riscv_vector.h>

// can only handle up to 4096 bits per line (64*64-bit elements)
#define IMG_H 8
#define IMG_W 8

void rgb2luma(unsigned int *luma, unsigned int *rgb, const int32_t image_width, const int32_t image_height);
void scalar_rgb2luma(unsigned int *luma, unsigned int *rgb, const int32_t image_width, const int32_t image_height);
void rv_init_matrix_word_pixel(unsigned int *input, const int image_width, const int image_height);

void scalar_rgb2luma(unsigned int *luma, unsigned int *rgb, const int32_t image_width, const int32_t image_height)
{
    for (int i = 0; i < image_width*image_height; i++) {
        unsigned int red = (rgb[i]&0xFF0000) >> 16;
        unsigned int green = (rgb[i]&0xFF00) >> 8;
        unsigned int blue = (rgb[i]&0xFF);
        luma[i] = (25*blue + 129*green + 66*red + 128) >> 8U;
    }
}

void rvv_rgb2luma(unsigned int *luma, unsigned int *rgb, const int32_t image_width, const int32_t image_height)
{
    size_t vl;
    vuint32m4_t mask, red, green, blue, offset, r_coeff, g_coeff, b_coeff, out, tmp;

    vl = vsetvl_e32m4 (image_width);

    mask = vmv_v_x_u32m4(255, image_width);
    offset = vmv_v_x_u32m4(128, image_width);
    b_coeff = vmv_v_x_u32m4(25, image_width);
    r_coeff = vmv_v_x_u32m4(66, image_width);
    g_coeff = vmv_v_x_u32m4(129, image_width);

    for (int i = 0; i < image_height; i++){
        blue    = vle32_v_u32m4(rgb, image_width);

        red     = vsrl_vx_u32m4(blue, 16, image_width);
        green   = vsrl_vx_u32m4(blue, 8, image_width);

        red     = vand_vv_u32m4(red, mask, image_width);
        out     = vmul_vv_u32m4(red, r_coeff, image_width);

        green   = vand_vv_u32m4(green, mask, image_width);
        tmp     = vmul_vv_u32m4(green, g_coeff, image_width);
        out     = vadd_vv_u32m4(out, tmp, image_width);

        blue    = vand_vv_u32m4(blue, mask, image_width);
        tmp     = vmul_vv_u32m4(blue, b_coeff, image_width);
        out     = vadd_vv_u32m4(out, tmp, image_width);

        out     = vadd_vv_u32m4(out, offset, image_width);
        out     = vsrl_vx_u32m4(out, 8, image_width);

        vse32_v_u32m4 (luma, out, image_width);

        luma += image_width;
        rgb += image_width;
    }
}

void rv_init_matrix_word_pixel(unsigned int *input, const int image_width, const int image_height)
{
    unsigned int rgba = 0xFFFFFFFF;

    // Load data for each frame...
    puts("in:");
    for (int i = 0; i < image_height*image_width; i++) {
        if (i && !(i%image_width)) printf("\n");
        input[i] = rgba;
        printf("%08x\t", input[i]);
        rgba -= 263;
    }
    puts("");
}

int rvv_rgb2luma_test()
{
    unsigned int in [IMG_H*IMG_W];
    unsigned int out [IMG_H*IMG_W] = {0};

    unsigned int out_sca [IMG_H*IMG_W] = {0};

    rv_init_matrix_word_pixel(in, IMG_W, IMG_H);

    scalar_rgb2luma(out_sca, in, IMG_W, IMG_H);

    puts("\nscalar:");
    for (size_t i = 0; i < IMG_H; ++i){
        for (size_t j = 0; j < IMG_W; ++j){
             printf("%04x\t", out_sca[i*IMG_W + j]);
        }
        puts("");
    }

    rvv_rgb2luma(out, in, IMG_W, IMG_H);

    puts("\nout:");
    int errors = 0;
    for (size_t i = 0; i < IMG_H; i++){
        for (size_t j = 0; j < IMG_W; j++){
            if (out[i*IMG_W + j] != out_sca[i*IMG_W + j])   errors++;

            printf("%04x ", out[i*IMG_W + j]);
        }
        puts("");
    }

    printf("\nTest %s with %d errors\n", (errors ? "failed" : "passed"), errors);

    return 0;
}
