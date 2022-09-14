#include <riscv_vector.h>
#include <stdio.h>

void vec_add_rvv(int *a, int *b, int *c, size_t n) {
	size_t vl;
	vint32m4_t va, vb, vc;
	for (;vl = vsetvl_e32m4 (n);n -= vl) {
		vb = vle32_v_i32m4 (b, n);
		vc = vle32_v_i32m4 (c, n);
		va = vadd_vv_i32m4 (vb, vc, n);
		vse32_v_i32m4 (a, va, n);
		a += vl;
		b += vl;
		c += vl;
	}
}

int x[10] = {1,2,3,4,5,6,7,8,9,0};
int y[10] = {0,9,8,7,6,5,4,3,2,1};
int z[10];

int rvv_add_ex_test() {
	int i;
	vec_add_rvv(z, x, y, 10);
	for (i=0; i<10; i++)
		printf ("%d ", z[i]);
	printf("\n");
	return 0;
}