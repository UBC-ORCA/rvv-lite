#include <stdio.h>
#include <riscv_vector.h>
#include <cstdlib>
#include <assert.h>

#include "mm.h"

int32_t* matrix_multiply_riscv_int(int32_t* A, int32_t* B, int N) {
	vint32m8_t vA, vB, vC;
	
	int32_t* C = (int32_t*) calloc(N * N, sizeof(int32_t));
	int value;
	
	int stride;

	if (N >= 8) {
		stride = 8;
	} else {
		stride = N;
	}

	for (int i = 0; i < N; i++) {
		for (int k = 0; k < N; k++) {
			value = A[i * N + k];
			for (int j = 0; j < N; j+=stride) {
				// C[i * N + j] += A[i * N + k] * B[k * N + j];	

				vB = vle32_v_i32m8(&B[k * N + j], stride);
				vC = vle32_v_i32m8(&C[i * N + j], stride);

				// accumulator, constant, vector, number of elements
				vC = vmacc_vx_i32m8(vC, value, vB, stride);
				vse32_v_i32m8(&C[i * N + j], vC, stride);
			}
		}
	}
	return C;
}

void print_matrix_int(int32_t* A, int N) {
	for (int i = 0; i < N; i++) {
		for (int j = 0; j < N; j++) {
			printf("%d ", A[i * N + j]);	
		}
		printf("\n");
	}
}

int32_t* random_matrix_int(int N) {
	int32_t* A = (int32_t*)calloc(N * N, sizeof(int));
	for (int i = 0; i < N; i++) {
		for (int j = 0; j < N; j++) {
			A[i * N + j] = rand() % 5;	
		}
	}
	return A;
}

int32_t* mm_scalar_int(int32_t* A, int32_t* B, int N) {
	int32_t* C = (int32_t*)calloc(N * N, sizeof(int));
	int value;
	for (int i = 0; i < N; i++) {
		for (int k = 0; k < N; k++) {
			value = A[i * N + k]; 
			for (int j = 0; j < N; j++) {
				C[i * N + j] += value * B[k * N + j];
			}
		}
	}
	return C;
}

void check_mm_equal_int(int32_t* rvv_mm, int32_t* scalar_mm, int N) {
	for (int i = 0; i < N; i++) {
		for (int j = 0; j < N; j++) {
			assert(rvv_mm[i * N + j] - scalar_mm[i * N + j] == 0);		
		}
	}
	printf("Correct values from the matrix multiplication.\n");
}

int rvv_mm_test() {
	int N = 16;
	printf("performing integer matrix mulitplication... \n");
    int32_t* A = random_matrix_int(N);
	int32_t* B = random_matrix_int(N);
	int32_t* C = matrix_multiply_riscv_int(A, B, N);

	printf("Matrix A: \n");
	print_matrix_int(A, N);
	printf("Matrix B: \n");
	print_matrix_int(B, N);
	printf("Matrix C: \n");
	print_matrix_int(C, N);

	int32_t* D = mm_scalar_int(A, B, N);
	printf("Matrix D: \n");
	print_matrix_int(D, N);

	check_mm_equal_int(C, D, N);
	
	free(A);
	free(B);
	free(C);
	free(D);
	return 0;
}