	.file	"exercise10.c"
	.option pic
	.attribute arch, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_v1p0_zicsr2p0_zifencei2p0_zve32f1p0_zve32x1p0_zve64d1p0_zve64f1p0_zve64x1p0_zvl128b1p0_zvl32b1p0_zvl64b1p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	1
	.type	sum_i32_scalar, @function
sum_i32_scalar:
.LFB16:
	.cfi_startproc
	beq	a1,zero,.L4
	slli	a1,a1,2
	mv	a5,a0
	add	a3,a0,a1
	li	a0,0
.L3:
	lw	a4,0(a5)
	addi	a5,a5,4
	addw	a0,a4,a0
	bne	a5,a3,.L3
	ret
.L4:
	li	a0,0
	ret
	.cfi_endproc
.LFE16:
	.size	sum_i32_scalar, .-sum_i32_scalar
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
	.globl	sum_i32_rvv
	.type	sum_i32_rvv, @function
sum_i32_rvv:
.LFB15:
	.cfi_startproc
	addi	sp,sp,-32
	.cfi_def_cfa_offset 32
	la	a6,__stack_chk_guard
	sd	ra,24(sp)
	.cfi_offset 1, -8
	ld	a5, 0(a6)
	sd	a5, 8(sp)
	li	a5, 0
	beq	a1,zero,.L12
	mv	a2,a0
	li	a4,0
	li	a0,0
.L10:
	sub	a5,a1,a4
	slli	a3,a4,2
	vsetvli	a5,a5,e32,m1,ta,ma
	add	a3,a2,a3
	add	a4,a4,a5
	vle32.v	v24,0(a3)
	vmv.v.i	v25,0
	vredsum.vs	v24,v24,v25
	vmv.x.s	a5,v24
	addw	a0,a5,a0
	bgtu	a1,a4,.L10
.L9:
	ld	a4, 8(sp)
	ld	a5, 0(a6)
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
	.size	sum_i32_rvv, .-sum_i32_rvv
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC0:
	.string	"n=%zu: expected %d, got %d\n"
	.text
	.align	1
	.type	check_random_inputs, @function
check_random_inputs:
.LFB18:
	.cfi_startproc
	addi	sp,sp,-96
	.cfi_def_cfa_offset 96
	li	a2,16384
	li	t0,-16384
	sd	s0,80(sp)
	sd	s1,72(sp)
	sd	s2,64(sp)
	sd	s3,56(sp)
	sd	s4,48(sp)
	sd	ra,88(sp)
	sd	s5,40(sp)
	addi	a1,a2,24
	add	sp,sp,t0
	.cfi_def_cfa_offset 16480
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 1, -8
	.cfi_offset 21, -56
	la	s4,__stack_chk_guard
	add	a1,a1,sp
	ld	a3, 0(s4)
	sd	a3, 0(a1)
	li	a3, 0
	mv	a3,a2
	li	a5,-16384
	addi	a2,a2,32
	li	a4,-1907245056
	add	a2,a2,a5
	addi	a4,a4,679
	add	a5,a2,sp
	li	s0,-16384
	addi	s0,s0,-16
	sw	a4,-20(a5)
	li	s1,-16384
	addi	a4,a3,32
	addi	s1,s1,-20
	add	a4,a4,s0
	addi	a5,a3,32
	add	s0,a4,sp
	add	a5,a5,s1
	addi	a4,a3,20
	add	s3,sp,a4
	add	s1,a5,sp
	li	s2,2001
.L17:
	mv	a0,s1
	call	next_random
	remuw	a0,a0,s2
	addi	s0,s0,4
	addiw	a0,a0,-1000
	sw	a0,-4(s0)
	bne	s0,s3,.L17
	li	s3,-16384
	li	a5,16384
	addi	s3,s3,-16
	addi	a5,a5,32
	add	a5,a5,s3
	lla	s1,.LANCHOR0+8
	lla	s5,.LANCHOR0+184
	li	s2,0
	add	s3,a5,sp
	j	.L20
.L18:
	beq	s1,s5,.L22
	ld	s2,0(s1)
	addi	s1,s1,8
.L20:
	mv	a1,s2
	mv	a0,s3
	call	sum_i32_scalar
	mv	s0,a0
	mv	a1,s2
	mv	a0,s3
	call	sum_i32_rvv
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
	li	a5,16384
	addi	a5,a5,24
	add	a5,a5,sp
	ld	a4, 0(a5)
	ld	a5, 0(s4)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L25
	li	t0,16384
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
	.string	"boundary test %zu: expected %d, got %d\n"
	.text
	.align	1
	.type	check_boundary_values, @function
check_boundary_values:
.LFB19:
	.cfi_startproc
	addi	sp,sp,-48
	.cfi_def_cfa_offset 48
	sd	s2,16(sp)
	.cfi_offset 18, -32
	lla	s2,.LANCHOR0+184
	li	a1,1
	mv	a0,s2
	sd	s0,32(sp)
	sd	s1,24(sp)
	sd	s3,8(sp)
	sd	s4,0(sp)
	sd	ra,40(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 1, -8
	lla	s1,.LANCHOR0+232
	call	sum_i32_rvv
	lw	a4,0(s1)
	lla	s3,.LANCHOR0+248
	li	s0,0
	li	s4,4
	mv	a5,a0
	addi	s3,s3,8
	bne	a4,a0,.L32
.L27:
	addi	s0,s0,1
	addi	s2,s2,12
	addi	s1,s1,4
	beq	s0,s4,.L30
	ld	a1,0(s3)
	mv	a0,s2
	addi	s3,s3,8
	call	sum_i32_rvv
	lw	a4,0(s1)
	mv	a5,a0
	beq	a4,a0,.L27
.L32:
	la	a3,stderr
	ld	a0,0(a3)
	lla	a2,.LC1
	mv	a3,s0
	li	a1,2
	call	__fprintf_chk@plt
	li	a0,1
	j	.L28
.L30:
	li	a0,0
.L28:
	ld	ra,40(sp)
	.cfi_restore 1
	ld	s0,32(sp)
	.cfi_restore 8
	ld	s1,24(sp)
	.cfi_restore 9
	ld	s2,16(sp)
	.cfi_restore 18
	ld	s3,8(sp)
	.cfi_restore 19
	ld	s4,0(sp)
	.cfi_restore 20
	addi	sp,sp,48
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE19:
	.size	check_boundary_values, .-check_boundary_values
	.section	.rodata.str1.8
	.align	3
.LC2:
	.string	"All RVV reduction checks passed"
	.section	.text.startup,"ax",@progbits
	.align	1
	.globl	main
	.type	main, @function
main:
.LFB20:
	.cfi_startproc
	addi	sp,sp,-16
	.cfi_def_cfa_offset 16
	sd	ra,8(sp)
	sd	s0,0(sp)
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	call	check_random_inputs
	beq	a0,zero,.L34
.L36:
	li	s0,1
.L35:
	ld	ra,8(sp)
	.cfi_remember_state
	.cfi_restore 1
	mv	a0,s0
	ld	s0,0(sp)
	.cfi_restore 8
	addi	sp,sp,16
	.cfi_def_cfa_offset 0
	jr	ra
.L34:
	.cfi_restore_state
	call	check_boundary_values
	mv	s0,a0
	bne	a0,zero,.L36
	lla	a0,.LC2
	call	puts@plt
	j	.L35
	.cfi_endproc
.LFE20:
	.size	main, .-main
	.section	.rodata
	.align	3
	.set	.LANCHOR0,. + 0
	.type	sizes.3, @object
	.size	sizes.3, 184
sizes.3:
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
	.type	inputs.2, @object
	.size	inputs.2, 48
inputs.2:
	.word	2147483647
	.word	0
	.word	0
	.word	-2147483648
	.word	0
	.word	0
	.word	2147483647
	.word	-1
	.word	-2147483647
	.word	-2147483648
	.word	1
	.word	2147483647
	.type	expected.0, @object
	.size	expected.0, 16
expected.0:
	.word	2147483647
	.word	-2147483648
	.word	-1
	.word	0
	.type	sizes.1, @object
	.size	sizes.1, 32
sizes.1:
	.dword	1
	.dword	1
	.dword	3
	.dword	3
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
