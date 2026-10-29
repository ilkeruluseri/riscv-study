	.file	"exercise11.c"
	.option pic
	.attribute arch, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_v1p0_zicsr2p0_zifencei2p0_zve32f1p0_zve32x1p0_zve64d1p0_zve64f1p0_zve64x1p0_zvl128b1p0_zvl32b1p0_zvl64b1p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	1
	.type	dot_i8_scalar, @function
dot_i8_scalar:
.LFB16:
	.cfi_startproc
	beq	a2,zero,.L4
	mv	a5,a0
	add	a2,a0,a2
	li	a0,0
.L3:
	lb	a4,0(a5)
	lb	a3,0(a1)
	addi	a5,a5,1
	addi	a1,a1,1
	mulw	a4,a4,a3
	addw	a0,a4,a0
	bne	a2,a5,.L3
	ret
.L4:
	li	a0,0
	ret
	.cfi_endproc
.LFE16:
	.size	dot_i8_scalar, .-dot_i8_scalar
	.align	1
	.type	next_random, @function
next_random:
.LFB17:
	.cfi_startproc
	lw	a5,0(a0)
	mv	a4,a0
	slliw	a3,a5,13
	xor	a5,a5,a3
	srliw	a3,a5,17
	xor	a5,a5,a3
	slliw	a3,a5,5
	xor	a5,a5,a3
	sext.w	a0,a5
	sw	a0,0(a4)
	ret
	.cfi_endproc
.LFE17:
	.size	next_random, .-next_random
	.align	1
	.globl	dot_i8_rvv
	.type	dot_i8_rvv, @function
dot_i8_rvv:
.LFB15:
	.cfi_startproc
	addi	sp,sp,-32
	.cfi_def_cfa_offset 32
	la	t1,__stack_chk_guard
	sd	ra,24(sp)
	.cfi_offset 1, -8
	ld	a5, 0(t1)
	sd	a5, 8(sp)
	li	a5, 0
	vsetivli	zero,1,e32,m1,ta,ma
	beq	a2,zero,.L12
	mv	a7,a0
	li	a4,0
	li	a0,0
	vmv.v.i	v28,0
.L10:
	sub	a5,a2,a4
	vsetvli	a5,a5,e8,m1,ta,ma
	add	a6,a7,a4
	add	a3,a1,a4
	vle8.v	v24,0(a3)
	vle8.v	v25,0(a6)
	add	a4,a4,a5
	vwmul.vv	v26,v25,v24
	vsetvli	zero,zero,e16,m2,ta,ma
	vwredsum.vs	v24,v26,v28
	vsetivli	zero,0,e32,m1,ta,ma
	vmv.x.s	a5,v24
	addw	a0,a5,a0
	bgtu	a2,a4,.L10
.L9:
	ld	a4, 8(sp)
	ld	a5, 0(t1)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L15
	ld	ra,24(sp)
	.cfi_remember_state
	.cfi_restore 1
	addi	sp,sp,32
	.cfi_def_cfa_offset 0
	jr	ra
.L12:
	.cfi_restore_state
	li	a0,0
	j	.L9
.L15:
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE15:
	.size	dot_i8_rvv, .-dot_i8_rvv
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC0:
	.string	"random n=%zu: expected %d, got %d\n"
	.text
	.align	1
	.type	check_random_inputs, @function
check_random_inputs:
.LFB18:
	.cfi_startproc
	addi	sp,sp,-96
	.cfi_def_cfa_offset 96
	sd	s0,80(sp)
	li	a3,8192
	li	t0,-8192
	.cfi_offset 8, -16
	li	s0,-8192
	sd	s1,72(sp)
	sd	s2,64(sp)
	sd	s3,56(sp)
	sd	s4,48(sp)
	sd	ra,88(sp)
	sd	s5,40(sp)
	sd	s6,32(sp)
	addi	s0,s0,-24
	add	sp,sp,t0
	.cfi_def_cfa_offset 8288
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 1, -8
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	addi	a2,a3,32
	addi	a1,a3,24
	add	a2,a2,s0
	la	s4,__stack_chk_guard
	add	a1,a1,sp
	add	s0,a2,sp
	mv	a2,a3
	ld	a3, 0(s4)
	sd	a3, 0(a1)
	li	a3, 0
	mv	a3,a2
	li	a5,-8192
	addi	a2,a2,32
	li	a4,1958334464
	add	a2,a2,a5
	addi	a4,a4,543
	add	a5,a2,sp
	li	s1,-4096
	li	s2,-8192
	addi	s1,s1,-16
	addi	s2,s2,-28
	sw	a4,-28(a5)
	li	s3,4096
	addi	a4,a3,32
	addi	a5,a3,32
	addi	s3,s3,1
	add	a4,a4,s1
	add	a5,a5,s2
	add	s1,a4,sp
	add	s3,s0,s3
	add	s2,a5,sp
.L17:
	mv	a0,s2
	call	next_random
	mv	a5,a0
	sb	a5,0(s0)
	mv	a0,s2
	call	next_random
	sb	a0,0(s1)
	addi	s0,s0,1
	addi	s1,s1,1
	bne	s0,s3,.L17
	li	a4,8192
	li	s5,-4096
	addi	s5,s5,-16
	addi	a5,a4,32
	add	a5,a5,s5
	li	s3,-8192
	addi	s3,s3,-24
	add	s5,a5,sp
	addi	a5,a4,32
	add	a5,a5,s3
	lla	s1,.LANCHOR0+8
	lla	s6,.LANCHOR0+184
	li	s2,0
	add	s3,a5,sp
	j	.L20
.L18:
	beq	s1,s6,.L22
	ld	s2,0(s1)
	addi	s1,s1,8
.L20:
	mv	a2,s2
	mv	a1,s5
	mv	a0,s3
	call	dot_i8_scalar
	mv	s0,a0
	mv	a2,s2
	mv	a1,s5
	mv	a0,s3
	call	dot_i8_rvv
	mv	a5,a0
	beq	s0,a0,.L18
	la	a4,stderr
	ld	a0,0(a4)
	mv	a3,s2
	mv	a4,s0
	lla	a2,.LC0
	li	a1,2
	call	__fprintf_chk@plt
	li	a0,1
.L19:
	li	a5,8192
	addi	a5,a5,24
	add	a5,a5,sp
	ld	a4, 0(a5)
	ld	a5, 0(s4)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L25
	li	t0,8192
	add	sp,sp,t0
	.cfi_remember_state
	.cfi_def_cfa_offset 96
	ld	ra,88(sp)
	.cfi_restore 1
	ld	s0,80(sp)
	.cfi_restore 8
	ld	s1,72(sp)
	.cfi_restore 9
	ld	s2,64(sp)
	.cfi_restore 18
	ld	s3,56(sp)
	.cfi_restore 19
	ld	s4,48(sp)
	.cfi_restore 20
	ld	s5,40(sp)
	.cfi_restore 21
	ld	s6,32(sp)
	.cfi_restore 22
	addi	sp,sp,96
	.cfi_def_cfa_offset 0
	jr	ra
.L22:
	.cfi_restore_state
	li	a0,0
	j	.L19
.L25:
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE18:
	.size	check_random_inputs, .-check_random_inputs
	.section	.rodata.str1.8
	.align	3
.LC1:
	.string	"sign patterns: expected %d, got %d\n"
	.text
	.align	1
	.type	check_sign_patterns, @function
check_sign_patterns:
.LFB19:
	.cfi_startproc
	addi	sp,sp,-16
	.cfi_def_cfa_offset 16
	li	a2,10
	lla	a1,.LANCHOR0+184
	lla	a0,.LANCHOR0+200
	sd	ra,8(sp)
	sd	s0,0(sp)
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	call	dot_i8_scalar
	mv	s0,a0
	li	a2,10
	lla	a1,.LANCHOR0+184
	lla	a0,.LANCHOR0+200
	call	dot_i8_rvv
	mv	a4,a0
	li	a0,0
	bne	s0,a4,.L31
.L27:
	ld	ra,8(sp)
	.cfi_remember_state
	.cfi_restore 1
	ld	s0,0(sp)
	.cfi_restore 8
	addi	sp,sp,16
	.cfi_def_cfa_offset 0
	jr	ra
.L31:
	.cfi_restore_state
	la	a5,stderr
	ld	a0,0(a5)
	mv	a3,s0
	lla	a2,.LC1
	li	a1,2
	call	__fprintf_chk@plt
	li	a0,1
	j	.L27
	.cfi_endproc
.LFE19:
	.size	check_sign_patterns, .-check_sign_patterns
	.section	.rodata.str1.8
	.align	3
.LC2:
	.string	"wide accumulation: expected %ld, got %d\n"
	.text
	.align	1
	.type	check_wide_accumulation, @function
check_wide_accumulation:
.LFB20:
	.cfi_startproc
	li	a2,65536
	addi	sp,sp,-16
	.cfi_def_cfa_offset 16
	addi	a2,a2,1
	li	a1,128
	lla	a0,a.1
	sd	ra,8(sp)
	.cfi_offset 1, -8
	call	memset@plt
	li	a2,65536
	addi	a2,a2,1
	li	a1,128
	lla	a0,b.0
	call	memset@plt
	li	a2,65536
	addi	a2,a2,1
	lla	a1,b.0
	lla	a0,a.1
	call	dot_i8_rvv
	mv	a4,a0
	li	a5,1073758208
	li	a0,0
	bne	a4,a5,.L37
.L33:
	ld	ra,8(sp)
	.cfi_remember_state
	.cfi_restore 1
	addi	sp,sp,16
	.cfi_def_cfa_offset 0
	jr	ra
.L37:
	.cfi_restore_state
	la	a5,stderr
	ld	a0,0(a5)
	li	a3,1073758208
	lla	a2,.LC2
	li	a1,2
	call	__fprintf_chk@plt
	li	a0,1
	j	.L33
	.cfi_endproc
.LFE20:
	.size	check_wide_accumulation, .-check_wide_accumulation
	.section	.rodata.str1.8
	.align	3
.LC3:
	.string	"All RVV i8 dot-product checks passed"
	.section	.text.startup,"ax",@progbits
	.align	1
	.globl	main
	.type	main, @function
main:
.LFB21:
	.cfi_startproc
	addi	sp,sp,-16
	.cfi_def_cfa_offset 16
	sd	ra,8(sp)
	sd	s0,0(sp)
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	call	check_random_inputs
	beq	a0,zero,.L39
.L41:
	li	s0,1
.L40:
	ld	ra,8(sp)
	.cfi_remember_state
	.cfi_restore 1
	mv	a0,s0
	ld	s0,0(sp)
	.cfi_restore 8
	addi	sp,sp,16
	.cfi_def_cfa_offset 0
	jr	ra
.L39:
	.cfi_restore_state
	call	check_sign_patterns
	bne	a0,zero,.L41
	call	check_wide_accumulation
	mv	s0,a0
	bne	a0,zero,.L41
	lla	a0,.LC3
	call	puts@plt
	j	.L40
	.cfi_endproc
.LFE21:
	.size	main, .-main
	.section	.rodata
	.align	3
	.set	.LANCHOR0,. + 0
	.type	sizes.4, @object
	.size	sizes.4, 184
sizes.4:
	.dword	0
	.dword	1
	.dword	2
	.dword	3
	.dword	7
	.dword	15
	.dword	16
	.dword	17
	.dword	31
	.dword	32
	.dword	33
	.dword	37
	.dword	127
	.dword	128
	.dword	129
	.dword	255
	.dword	256
	.dword	257
	.dword	511
	.dword	512
	.dword	513
	.dword	1023
	.dword	4097
	.type	b.2, @object
	.size	b.2, 10
b.2:
	.ascii	"\007\007\371\371\177\200\234d\377\377"
	.zero	6
	.type	a.3, @object
	.size	a.3, 10
a.3:
	.ascii	"\005\373\005\373\177\200d\234\001\377"
	.bss
	.align	3
	.type	b.0, @object
	.size	b.0, 65537
b.0:
	.zero	65537
	.zero	7
	.type	a.1, @object
	.size	a.1, 65537
a.1:
	.zero	65537
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
