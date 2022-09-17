#include <stdio.h>
#include <riscv_vector.h>
#include <cstdlib>
#include <assert.h>

#include "base.h"
#include "menu.h"
#include "riscv.h"

#include "perf.h"

#include "mm.h"

void print_matrix_int(int32_t* A, int N) {
	for (int i = 0; i < N; i++) {
		for (int j = 0; j < N; j++) {
			printf("%d ", A[i * N + j]);	
		}
		printf("\n");
	}
}

int32_t* random_matrix_int(int N) {
	int32_t*  A = new int32_t[N * N];
	for (int i = 0; i < N; i++) {
		for (int j = 0; j < N; j++) {
			A[i * N + j] = rand() % 5;	
		}
	}
	return A;
}

void check_mm_equal_int(int32_t* rvv_mm, int32_t* scalar_mm, int N) {
	int err = 0;
	for (int i = 0; i < N; i++) {
		for (int j = 0; j < N; j++) {
			if (rvv_mm[i * N + j] - scalar_mm[i * N + j] != 0) err++;

			if (rvv_mm[i*N+j] != scalar_mm[i*N+j] & err < 15) printf("Got %x, expected %x\n", rvv_mm[i*N+j], scalar_mm[i*N+j]);
		}
	}
	if (err > 0)	printf("Failed with %d errors\n.", err);
	else	printf("Correct values from the matrix multiplication.\n");
}

void rvv_mm_test() {
	int N = 64;
	printf("performing integer matrix mulitplication... \n");
    int32_t* A = random_matrix_int(N);
	int32_t* B = random_matrix_int(N);

	int start = perf_get_mcycle();
 	// so gcc stops reordering it
	int32_t D [N * N] = {0};
	int32_t value;
	for (int i = 0; i < N; i++) {
		for (int k = 0; k < N; k++) {
			value = A[i * N + k]; 
			for (int j = 0; j < N; j++) {
				D[i * N + j] += value * B[k * N + j];
			}
		}
	}

	int end = perf_get_mcycle();

	vint32m4_t vA, vB, vC, vTmp;
	
	int32_t C [N * N] = {0};
	
	int stride = N;

	int start_v = perf_get_mcycle();

	vsetvl_e32m4(stride);

	// vC = vmv_v_x_i32m4(0,stride);

	for (int i = 0; i < N; i++) {
		for (int k = 0; k < N; k++) {
			value = A[i * N + k];
			for (int j = 0; j < N; j+=stride) {
				// C[i * N + j] += A[i * N + k] * B[k * N + j];	

				vB = vle32_v_i32m4(&B[k * N + j], stride);
				vC = vle32_v_i32m4(&C[i * N + j], stride);

				// accumulator, constant, vector, number of elements
				vTmp = vmul_vx_i32m4(vB, value, stride);
				vC = vadd_vv_i32m4(vC, vTmp, stride);

				vse32_v_i32m4(&C[i * N + j], vC, stride);
			}
		}
	}
	int end_v = perf_get_mcycle();

	check_mm_equal_int(C, D, N);
	
	delete A;
	delete B;

	printf("Timestamps: %d, %d, %d, %d\n", start, end, start_v, end_v);
	printf("Cycle count: %d\n", (end_v - start_v));
	print_float("Speedup", (float)(end-start)/(float)(end_v-start_v)); // SCALAR OVER VECTOR DUMMY
}