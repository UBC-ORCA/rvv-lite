/*
 * Copyright 2021 The rvv-Playground Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "functional_rvv_tests.h"

#include <stdio.h>
#include <riscv_vector.h>
#include <cstdlib>

#include "base.h"
// #include "rvvLite.h"
#include "menu.h"
#include "riscv.h"

namespace {

void do_basic_ld_st_test(void) {
  int num_elems = 64;

  vsetvl_e32m4(num_elems);

  int32_t v0[num_elems];
  int32_t v1[num_elems], v1_ex[num_elems];

  vint32m4_t vA;

  for (int i = 0; i < num_elems; i++){
    v0[i] = (int32_t)i;
    v1_ex[i] = v0[i];
    v1[i] = 1;
  }

  vA = vle32_v_i32m4(v0, num_elems);
  vse32_v_i32m4(v1, vA, num_elems);

  // the only way to get gcc to not suck apparently
  vA = vle32_v_i32m4(v1, num_elems);
  vse32_v_i32m4(v1, vA, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v1[i] != v1_ex[i]){
      err_count++;
      printf("v1: %0x. Got %d, expected %d\n", &(v1[i]), v1[i], v1_ex[i]);
    }
  }

  printf("Done basic ld/st test with %d errors\n", err_count);
}


void do_vmv_xs_test(void) {
  int num_elems = 64;

  vsetvl_e8m1(num_elems);

  int8_t v0[num_elems];
  int8_t v1[num_elems], v1_ex[num_elems];

  vint8m1_t vA, vB;

  for (int i = 0; i < num_elems; i++){
    v0[i] = num_elems - i;
    v1_ex[i] = 0;
    v1[i] = 1;
  }
  v1_ex[0] = 12;

  vA = vmv_s_x_i8m1(vA, 12, num_elems);
  vse8_v_i8m1(v1, vA, num_elems);

  vB = vle8_v_i8m1(v0, num_elems);
  int8_t a = vmv_x_s_i8m1_i8(vB);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v1[i] != v1_ex[i]){
      err_count++;
      printf("v1: %0x. Got %d, expected %d\n", &(v1[i]), v1[i], v1_ex[i]);
    }
  }

  if (a != num_elems){
    err_count ++;
    printf("a: Got %d, expected %d\n", a, (num_elems));
  }
  
  printf("Done vmv_xs test with %d errors\n", err_count);
}

void do_srl64_test(void) {
  int num_elems = 128;

  uint64_t v2[num_elems];
  vuint64m8_t vA, vC;

  vsetvl_e64m8(num_elems);

  vA = vid_v_u64m8(num_elems);

  vC = vsrl_vx_u64m8(vA, 3, num_elems);

  vse64_v_u64m8(v2, vC, num_elems);
}

void do_add_test(void) {
  int num_elems = 128;

  vsetvl_e16m2(num_elems);
  vuint16m2_t vA, vB, vC;

  uint16_t v0[num_elems];
  uint16_t v1[num_elems];
  uint16_t v2[num_elems];
  uint16_t v2_ex[num_elems];

  for (int i = 0; i < num_elems; i++) {
    v0[i] = (int32_t)i;
    v1[i] = (int32_t)(i + 1);
    v2[i] = 1;

    v2_ex[i] = v0[i] + v1[i];
  }

  vA = vle16_v_u16m2(v0, num_elems);
  vB = vle16_v_u16m2(v1, num_elems);

  vC = vadd_vv_u16m2(vA, vB, num_elems);

  vse16_v_u16m2(v2, vC, num_elems);

  vC = vle16_v_u16m2(v2, num_elems);
  vse16_v_u16m2(v2, vC, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v2[i] != v2_ex[i]){
      err_count++;
      printf("v2: %0x. Got %d, expected %d\n", &(v2[i]), v2[i], v2_ex[i]);
    }
    // if (v2[i] != v2_ex[i]) err_count++;
  }

  printf("Finished ADD test with %d errors.\n", err_count);
}

void do_avg_add_test(void) {
  int num_elems = 128;

  vsetvl_e16m2(num_elems);
  vuint16m2_t vA, vB, vC;

  uint16_t v0[num_elems];
  uint16_t v1[num_elems];
  uint16_t v2[num_elems];
  uint16_t v2_ex[num_elems];

  for (int i = 0; i < num_elems; i++) {
    v0[i] = (uint16_t)(2*i);
    v1[i] = (uint16_t)(2*i + 4);
    v2[i] = 1;

    v2_ex[i] = (v0[i] + v1[i])/2;
  }

  vA = vle16_v_u16m2(v0, num_elems);
  vB = vle16_v_u16m2(v1, num_elems);

  vC = vaaddu_vv_u16m2(vA, vB, num_elems);

  vse16_v_u16m2(v2, vC, num_elems);

  vC = vle16_v_u16m2(v2, num_elems);
  vse16_v_u16m2(v2, vC, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v2[i] != v2_ex[i]){
      err_count++;
      printf("v2: %0x. Got %d, expected %d\n", &(v2[i]), v2[i], v2_ex[i]);
    }
    // if (v2[i] != v2_ex[i]) err_count++;
  }

  printf("Finished FXP ADD test with %d errors.\n", err_count);
}

void do_sra8_test(void) {
  int num_elems = 64;

  vsetvl_e8m1(num_elems);
  vint8m1_t vA, vB, vC;

  int8_t v0[num_elems];
  // int8_t v1[num_elems];
  int8_t v2[num_elems];
  int8_t v2_ex[num_elems];

  for (int i = 0; i < num_elems; i++) {
    v0[i] = (int8_t)i;
    // v1[i] = (int8_t)i;
    v2[i] = 1;

    printf("%d,",v0[i]);

    v2_ex[i] = v0[i]/8;//*v1[i];
  }
  printf("\n");

  vA = vle8_v_i8m1(v0, num_elems);
  // vB = vle8_v_i8m1(v1, num_elems);

  vC = vsra_vx_i8m1(vA, 3, num_elems);

  vse8_v_i8m1(v2, vC, num_elems);

  vC = vle8_v_i8m1(v2, num_elems);
  vse8_v_i8m1(v2, vC, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v2[i] != v2_ex[i]){
      err_count++;
      printf("v2: %0x. Got %d, expected %d\n", &(v2[i]), v2[i], v2_ex[i]);
    }
  }
  printf("Finished SRA8 test with %d errors.\n", err_count);
}

void do_srl16_test(void) {
  int num_elems = 64;

  vsetvl_e16m1(num_elems);
  vuint16m1_t vA, vB, vC;

  uint16_t v0[num_elems];
  // int8_t v1[num_elems];
  uint16_t v2[num_elems];
  uint16_t v2_ex[num_elems];

  for (int i = 0; i < num_elems; i++) {
    v0[i] = (uint16_t)i;
    // v1[i] = (int8_t)i;
    v2[i] = 1;

    printf("%d,",v0[i]);

    v2_ex[i] = v0[i]>>3;//*v1[i];
  }
  printf("\n");

  vA = vle16_v_u16m1(v0, num_elems);
  // vB = vle8_v_i8m1(v1, num_elems);

  vC = vsrl_vx_u16m1(vA, 3, num_elems);

  vse16_v_u16m1(v2, vC, num_elems);

  vC = vle16_v_u16m1(v2, num_elems);
  vse16_v_u16m1(v2, vC, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v2[i] != v2_ex[i]){
      err_count++;
      printf("v2[%d]: %0x. Got %d, expected %d\n", i, &(v2[i]), v2[i], v2_ex[i]);
    }
  }
  printf("Finished SRL16 test with %d errors.\n", err_count);
}

void do_ssrl16_test(void) {
  int num_elems = 64;

  vsetvl_e16m1(num_elems);
  vuint16m1_t vA, vB, vC;

  uint16_t v0[num_elems];
  // int8_t v1[num_elems];
  uint16_t v2[num_elems];
  uint16_t v2_ex[num_elems];

  for (int i = 0; i < num_elems; i++) {
    v0[i] = (uint16_t)i;
    // v1[i] = (int8_t)i;
    v2[i] = 1;

    printf("%d,",v0[i]);

    v2_ex[i] = v0[i]>>3;//*v1[i];
  }
  printf("\n");

  vA = vle16_v_u16m1(v0, num_elems);
  // vB = vle8_v_i8m1(v1, num_elems);

  vC = vssrl_vx_u16m1(vA, 3, num_elems);

  vse16_v_u16m1(v2, vC, num_elems);

  vC = vle16_v_u16m1(v2, num_elems);
  vse16_v_u16m1(v2, vC, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v2[i] != v2_ex[i]){
      err_count++;
      printf("v2[%d]: %0x. Got %d, expected %d\n", i, &(v2[i]), v2[i], v2_ex[i]);
    }
  }
  printf("Finished SSRL16 test with %d errors.\n", err_count);
}

void do_srl32_test(void) {
  int num_elems = 64;

  vsetvl_e32m1(num_elems);
  vuint32m1_t vA, vB, vC;

  uint32_t v0[num_elems];
  // int8_t v1[num_elems];
  uint32_t v2[num_elems];
  uint32_t v2_ex[num_elems];

  for (int i = 0; i < num_elems; i++) {
    v0[i] = (uint32_t)i;
    // v1[i] = (int8_t)i;
    v2[i] = 1;

    printf("%d,",v0[i]);

    v2_ex[i] = v0[i]/64;//*v1[i];
  }
  printf("\n");

  vA = vle32_v_u32m1(v0, num_elems);
  // vB = vle8_v_i8m1(v1, num_elems);

  vC = vsrl_vx_u32m1(vA, 8, num_elems);

  vse32_v_u32m1(v2, vC, num_elems);

  vC = vle32_v_u32m1(v2, num_elems);
  vse32_v_u32m1(v2, vC, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v2[i] != v2_ex[i]){
      err_count++;
      printf("v2: %0x. Got %d, expected %d\n", &(v2[i]), v2[i], v2_ex[i]);
    }
  }
  printf("Finished SRL32 test with %d errors.\n", err_count);
}

void do_mul8_test(void) {
  int num_elems = 16;

  vsetvl_e8m1(num_elems);
  vuint8m1_t vA, vB, vC;

  uint8_t v0[num_elems];
  uint8_t v1[num_elems];
  uint8_t v2[num_elems];
  uint8_t v2_ex[num_elems];

  for (int i = 0; i < num_elems; i++) {
    v0[i] = (uint8_t)i;
    v1[i] = (uint8_t)i;
    v2[i] = 1;

    v2_ex[i] = v0[i]*v1[i];
  }

  vA = vle8_v_u8m1(v0, num_elems);
  vB = vle8_v_u8m1(v1, num_elems);

  vC = vmul_vv_u8m1(vA, vB, num_elems);

  vse8_v_u8m1(v2, vC, num_elems);

  vC = vle8_v_u8m1(v2, num_elems);
  vse8_v_u8m1(v2, vC, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v2[i] != v2_ex[i]){
      err_count++;
      printf("v2: %0x. Got %d, expected %d\n", &(v2[i]), v2[i], v2_ex[i]);
    }
  }
  printf("Finished MUL8 test with %d errors.\n", err_count);
}

void do_mul16_test(void) {
  int num_elems = 32;
  vsetvl_e16m2(num_elems);
  vint16m2_t vD, vE, vF;

  int16_t v3[num_elems];
  int16_t v4[num_elems];
  int16_t v5[num_elems];
  int16_t v5_ex[num_elems];

  for (int i = 0; i < num_elems; i++) {
    v3[i] = (int16_t)i;
    v4[i] = (int16_t)i;
    v5[i] = 1;

    v5_ex[i] = v3[i]*v4[i];
  }

  vD = vle16_v_i16m2(v3, num_elems);
  vE = vle16_v_i16m2(v4, num_elems);

  vF = vmul_vv_i16m2(vD, vE, num_elems);

  vse16_v_i16m2(v5, vF, num_elems);

  vF = vle16_v_i16m2(v5, num_elems);
  vse16_v_i16m2(v5, vF, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v5[i] != v5_ex[i]){
      err_count++;
      printf("v5: %0x. Got %d, expected %d\n", &(v5[i]), v5[i], v5_ex[i]);
    }
  }

  printf("Finished MUL16 test with %d errors.\n", err_count);
}

void do_mul32_test(void) {
  int num_elems = 16;

  vsetvl_e32m4(num_elems);
  vint32m4_t vA, vB, vC;

  int32_t v0[num_elems];
  int32_t v1[num_elems];
  int32_t v2[num_elems];
  int32_t v2_ex[num_elems];

  for (int i = 0; i < num_elems; i++) {
    v0[i] = (int32_t)i;
    v1[i] = (int32_t)i;
    v2[i] = 1;

    v2_ex[i] = v0[i]*v1[i];
  }

  vA = vle32_v_i32m4(v0, num_elems);
  vB = vle32_v_i32m4(v1, num_elems);

  vC = vmul_vv_i32m4(vA, vB, num_elems);

  vse32_v_i32m4(v2, vC, num_elems);

  asm("fence iorw,rw");

  vC = vle32_v_i32m4(v2, num_elems);
  vse32_v_i32m4(v2, vC, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v2[i] != v2_ex[i]){
      err_count++;
      printf("v2: %0x. Got %d, expected %d\n", &(v2[i]), v2[i], v2_ex[i]);
    }
  }
  printf("Finished MUL32 test with %d errors.\n", err_count);
}

void do_smul32_test(void) {
  int num_elems = 64;

  vsetvl_e32m4(num_elems);
  vint32m4_t vA, vB, vC;

  int32_t v0[num_elems];
  int32_t v1[num_elems];
  int32_t v2[num_elems];
  int32_t v2_ex[num_elems];

  for (int i = 0; i < num_elems; i++) {
    v0[i] = (int32_t)(i << 16);
    v1[i] = (int32_t)((i % 5) << 16);
    v2[i] = 1;

    v2_ex[i] = ((v0[i]>>16)*(v1[i]>>16))<<16;
  }

  vA = vle32_v_i32m4(v0, num_elems);
  vB = vle32_v_i32m4(v1, num_elems);

  vC = vsmul_vv_i32m4(vA, vB, num_elems);

  vse32_v_i32m4(v2, vC, num_elems);

  asm("fence iorw,rw");

  vC = vle32_v_i32m4(v2, num_elems);
  vse32_v_i32m4(v2, vC, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v2[i] != v2_ex[i]){
      err_count++;
      printf("v2: %0x. Got %x, expected %x\n", &(v2[i]), v2[i], v2_ex[i]);
    }
  }
  printf("Finished SMUL32 test with %d errors.\n", err_count);
}

void do_mul_test(void) {
  do_mul8_test();
  do_mul16_test();
  do_mul32_test();
}

void do_slide_test(void) {
  int num_elems = 128;
  int slide = 4;

  vsetvl_e16m2(num_elems);
  vuint16m2_t vA, vB, vC;

  uint16_t v0[num_elems];
  uint16_t v1[num_elems];
  uint16_t v2[num_elems];
  uint16_t v2_ex[num_elems];

  for (int i = 0; i < num_elems; i++) {
    v0[i] = (int16_t)i;
    v1[i] = (int16_t)(i + 1);
    v2[i] = 1;

    v2_ex[i] = 0;
  }

  for (int i = 0; i < num_elems - slide; i++) {
    v2_ex[i+slide] = v0[i] + v1[i];
  }

  vA = vle16_v_u16m2(v0, num_elems);
  vB = vle16_v_u16m2(v1, num_elems);

  vC = vadd_vv_u16m2(vA, vB, num_elems);
  vC = vslideup_vx_u16m2(vC, vC, slide, num_elems);

  vse16_v_u16m2(v2, vC, num_elems);

  vC = vle16_v_u16m2(v2, num_elems);
  vse16_v_u16m2(v2, vC, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;
  for (int i = 0; i < num_elems; i++) {
    if (v2[i] != v2_ex[i]){
      err_count++;
      printf("v2: %0x. Got %d, expected %d\n", &(v2[i]), v2[i], v2_ex[i]);
    }
    // if (v2[i] != v2_ex[i]) err_count++;
  }

  printf("Finished SLIDE test with %d errors.\n", err_count);
}

// 106542340
// 106542230

void do_mask_logic_test(void) {
  int num_elems = 2047;


  
  vsetvl_e32m4(num_elems);

  vint32m4_t vA, vB, vC;
  vbool8_t vm0, vm1, vm2;

  int32_t v0[num_elems];
  int32_t v1[num_elems];
  int32_t v2[num_elems];
  int32_t v3[num_elems];
  int32_t v2_ex[num_elems];
  int32_t v3_ex[num_elems];

  // printf("v2 addr: %0x\n", v2);

  for (int i = 0; i < num_elems; i++) {
    v0[i] = 2;
    v1[i] = (int32_t)i;
    v2[i] = 1;
    v3[i] = 1;
  }

  long start = csr_read(cycle);
  for (int i = 0; i < num_elems; i++) {
    if (v1[i] <= v0[i])
      v2_ex[i] = v0[i] + v1[i];
    else
      v2_ex[i] = 0;

    v3_ex[i] = v1[i] + v2_ex[i];
  }
  long end = csr_read(cycle);

  long start_v = csr_read(cycle);
  vA = vle32_v_i32m4(v0, num_elems);
  // vB = vle16_v_u16m2(v1, num_elems);
  // vA = vmv_v_x_i32m4(2, num_elems);
  vB = vid_v_i32m4(num_elems);

  vm0 = vmsgt_vv_i32m4_b8(vB, vA, num_elems);
  vm1 = vmseq_vv_i32m4_b8(vA, vB, num_elems);
  vm2 = vmxor_mm_b8(vm0, vm1, num_elems);

  vC = vadd_vv_i32m4_m(vm2, vC, vA, vB, num_elems);

  vse32_v_i32m4(v2, vC, num_elems);

  vC = vle32_v_i32m4(v2, num_elems);
  vA = vadd_vv_i32m4(vC, vB, num_elems);

  vse32_v_i32m4(v3, vA, num_elems);

  long end_v = csr_read(cycle);

  int a = vcpop_m_b8(vm2, num_elems);

  asm("fence iorw,rw");

  int err_count = 0;

  for (int i = 0; i < num_elems; i++) {
    if (v2[i] != v2_ex[i]){
      err_count++;
      printf("v2: %0x. Got %d, expected %d\n", &(v2[i]), v2[i], v2_ex[i]);
    }
  }

  asm("fence iorw,rw");

  for (int i = 0; i < num_elems; i++) {
    if (v3[i] != v3_ex[i]){
      err_count++;
      printf("v3: %0x. Got %d, expected %d\n", &(v3[i]), v3[i], v3_ex[i]);
    }
  }

  printf("pop: %d\n",a);

  printf("time: %ld, %ld\n", start, end);
  printf("time_v: %ld, %ld\n", start_v, end_v);
  // printf("speedup: %f\n", ((float)(end-start)/(float)(end_v-start_v)));

  printf("Finished MASK test with %d errors\n", err_count);
}

struct Menu MENU = {
    "Tests for Functional rvvs",
    "functional",
    {
        MENU_ITEM('a', "Run ADD test", do_add_test),
        MENU_ITEM('v', "Run FXP AVG ADD test", do_avg_add_test),
        MENU_ITEM('m', "Run MASK test", do_mask_logic_test),
        MENU_ITEM('l', "Run LOAD/STORE test", do_basic_ld_st_test),
        MENU_ITEM('s', "Run vmv_xs test", do_vmv_xs_test),
        MENU_ITEM('u', "Run slideup test", do_slide_test),
        MENU_ITEM('*', "Run MUL test", do_mul_test),
        MENU_ITEM('>', "Run shift right test", do_srl16_test),
        MENU_ITEM('f', "Run scaling shift right test", do_ssrl16_test),
        MENU_ITEM('.', "Run SMUL32 test", do_smul32_test),
        MENU_END,
    },
};

};  // anonymous namespace

extern "C" void do_functional_rvv_tests() { menu_run(&MENU); }
