	.file	"exercise7.c"
	.option pic
	.attribute arch, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_v1p0_zicsr2p0_zifencei2p0_zve32f1p0_zve32x1p0_zve64d1p0_zve64f1p0_zve64x1p0_zvl128b1p0_zvl32b1p0_zvl64b1p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	1
	.type	add_i32_scalar, @function
add_i32_scalar:
.LFB16:
	.cfi_startproc
	beq	a3,zero,.L1
	slli	a3,a3,2
	add	a3,a0,a3
.L3:
	lw	a4,0(a0)
	lw	a5,0(a1)
	addi	a0,a0,4
	addi	a1,a1,4
	addw	a5,a5,a4
	sw	a5,0(a2)
	addi	a2,a2,4
	bne	a0,a3,.L3
.L1:
	ret
	.cfi_endproc
.LFE16:
	.size	add_i32_scalar, .-add_i32_scalar
	.align	1
	.globl	add_i32_rvv
	.type	add_i32_rvv, @function
add_i32_rvv:
.LFB15:
	.cfi_startproc
	addi	sp,sp,-32
	.cfi_def_cfa_offset 32
	la	t3,__stack_chk_guard
	sd	ra,24(sp)
	.cfi_offset 1, -8
	ld	a5, 0(t3)
	sd	a5, 8(sp)
	li	a5, 0
	beq	a3,zero,.L9
	li	a6,0
.L11:
	slli	a4,a6,2
	sub	a5,a3,a6
	add	t1,a0,a4
	add	a7,a1,a4
	add	a4,a2,a4
	vsetvli	a5,a5,e32,m1,ta,ma
	vle32.v	v24,0(t1)
	vle32.v	v25,0(a7)
	add	a6,a6,a5
	vadd.vv	v24,v24,v25
	vse32.v	v24,0(a4)
	bgtu	a3,a6,.L11
.L9:
	ld	a4, 8(sp)
	ld	a5, 0(t3)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L18
	ld	ra,24(sp)
	.cfi_remember_state
	.cfi_restore 1
	addi	sp,sp,32
	.cfi_def_cfa_offset 0
	jr	ra
.L18:
	.cfi_restore_state
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE15:
	.size	add_i32_rvv, .-add_i32_rvv
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC0:
	.string	"n=%zu, index=%zu: expected %d, got %d\n"
	.align	3
.LC1:
	.string	"n=%zu: result[%zu] was modified past the requested length\n"
	.align	3
.LC2:
	.string	"n=%zu: result was modified outside its allocation\n"
	.text
	.align	1
	.type	check_size, @function
check_size:
.LFB17:
	.cfi_startproc
	addi	sp,sp,-144
	.cfi_def_cfa_offset 144
	sd	s3,104(sp)
	li	t0,-4096
	.cfi_offset 19, -40
	mv	s3,a0
	li	a0,4096
	sd	s0,128(sp)
	sd	s1,120(sp)
	sd	ra,136(sp)
	sd	s2,112(sp)
	sd	s4,96(sp)
	sd	s5,88(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 1, -8
	.cfi_offset 18, -32
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	addi	s0,a0,72
	add	sp,sp,t0
	.cfi_def_cfa_offset 4240
	la	s1,__stack_chk_guard
	add	s0,s0,sp
	ld	a3, 0(s1)
	sd	a3, 0(s0)
	li	a3, 0
	mv	a3,a0
	li	a2,-4096
	li	a4,-4096
	addi	a2,a2,-80
	addi	a4,a4,960
	addi	a0,a0,80
	addi	a3,a3,80
	li	a1,-81920
	li	a5,-98304
	li	a6,-73728
	add	a0,a0,a2
	add	a3,a3,a4
	add	a2,a0,sp
	add	a4,a3,sp
	addi	a1,a1,1927
	addi	a5,a5,-1665
	addi	a6,a6,-1118
.L20:
	sw	a5,0(a2)
	sw	a1,0(a4)
	addiw	a5,a5,97
	addi	a2,a2,4
	addiw	a1,a1,53
	addi	a4,a4,4
	bne	a5,a6,.L20
	li	s4,4096
	addi	a5,s4,-972
	add	s2,sp,a5
	li	a2,1036
	li	a1,85
	mv	a0,s2
	call	memset@plt
	li	a5,-4096
	addi	a5,a5,2000
	addi	a4,s4,80
	add	a4,a4,a5
	add	s0,a4,sp
	li	a2,1036
	li	a1,85
	mv	a0,s0
	call	memset@plt
	li	a4,-4096
	li	a5,-4096
	addi	a4,a4,960
	addi	a5,a5,-80
	addi	a2,s4,80
	addi	a3,s4,80
	add	a2,a2,a4
	add	a3,a3,a5
	mv	a4,s4
	add	s5,a2,sp
	add	s4,a3,sp
	addi	a6,a4,-976
	li	a5,1431654400
	addi	a4,a4,64
	addi	a5,a5,1365
	mv	a3,s3
	mv	a2,s0
	mv	a1,s5
	mv	a0,s4
	add	a6,a6,sp
	add	a4,a4,sp
	sw	a5,0(a6)
	sw	a5,0(a4)
	call	add_i32_scalar
	mv	a3,s3
	mv	a2,s2
	mv	a1,s5
	mv	a0,s4
	call	add_i32_rvv
	beq	s3,zero,.L31
	mv	a1,s2
	mv	a2,s0
	li	a4,0
	j	.L24
.L22:
	addi	a4,a4,1
	addi	a1,a1,4
	addi	a2,a2,4
	beq	s3,a4,.L36
.L24:
	lw	a6,0(a1)
	lw	a5,0(a2)
	beq	a6,a5,.L22
	la	a3,stderr
	ld	a0,0(a3)
	lla	a2,.LC0
	mv	a3,s3
	li	a1,2
	call	__fprintf_chk@plt
	li	s0,1
.L23:
	li	a5,258
	bgtu	s3,a5,.L25
.L21:
	li	a5,4096
	addi	a4,s3,1
	addi	a5,a5,-976
	slli	a4,a4,2
	li	a2,1431654400
	add	a5,sp,a5
	add	a5,a5,a4
	addi	a2,a2,1365
	mv	a4,s3
	li	a1,259
	j	.L27
.L26:
	addi	a4,a4,1
	addi	a5,a5,4
	beq	a4,a1,.L25
.L27:
	lw	a3,0(a5)
	beq	a3,a2,.L26
	la	a5,stderr
	ld	a0,0(a5)
	mv	a3,s3
	lla	a2,.LC1
	li	a1,2
	call	__fprintf_chk@plt
	addiw	s0,s0,1
.L25:
	li	a3,4096
	addi	a5,a3,-976
	add	a5,a5,sp
	lw	a4,0(a5)
	li	a5,1431654400
	addi	a5,a5,1365
	bne	a4,a5,.L28
	addi	a5,a3,64
	add	a5,a5,sp
	lw	a5,0(a5)
	beq	a5,a4,.L29
.L28:
	la	a5,stderr
	ld	a0,0(a5)
	mv	a3,s3
	lla	a2,.LC2
	li	a1,2
	call	__fprintf_chk@plt
	addiw	s0,s0,1
.L29:
	li	a5,4096
	addi	a5,a5,72
	add	a5,a5,sp
	ld	a4, 0(a5)
	ld	a5, 0(s1)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L37
	li	t0,4096
	add	sp,sp,t0
	.cfi_remember_state
	.cfi_def_cfa_offset 144
	ld	ra,136(sp)
	.cfi_restore 1
	mv	a0,s0
	ld	s1,120(sp)
	.cfi_restore 9
	ld	s0,128(sp)
	.cfi_restore 8
	ld	s2,112(sp)
	.cfi_restore 18
	ld	s3,104(sp)
	.cfi_restore 19
	ld	s4,96(sp)
	.cfi_restore 20
	ld	s5,88(sp)
	.cfi_restore 21
	addi	sp,sp,144
	.cfi_def_cfa_offset 0
	jr	ra
.L36:
	.cfi_restore_state
	li	s0,0
	j	.L23
.L31:
	li	s0,0
	j	.L21
.L37:
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE17:
	.size	check_size, .-check_size
	.section	.rodata.str1.8
	.align	3
.LC3:
	.string	"boundary index=%zu: expected %d, got %d\n"
	.text
	.align	1
	.type	check_boundary_values, @function
check_boundary_values:
.LFB18:
	.cfi_startproc
	addi	sp,sp,-112
	.cfi_def_cfa_offset 112
	sd	s0,96(sp)
	sd	s5,56(sp)
	.cfi_offset 8, -16
	.cfi_offset 21, -56
	addi	s0,sp,8
	la	s5,__stack_chk_guard
	ld	a5, 0(s5)
	sd	a5, 24(sp)
	li	a5, 0
	li	a3,4
	mv	a2,s0
	lla	a1,.LANCHOR0
	lla	a0,.LANCHOR0+16
	sd	s1,88(sp)
	sd	s2,80(sp)
	sd	s3,72(sp)
	sd	s4,64(sp)
	sd	s6,48(sp)
	sd	s7,40(sp)
	sd	ra,104(sp)
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 22, -64
	.cfi_offset 23, -72
	.cfi_offset 1, -8
	sd	zero,8(sp)
	sd	zero,16(sp)
	call	add_i32_rvv
	lw	a5,0(s0)
	li	a4,-2147483648
	xori	a4,a4,-1
	lla	s2,.LANCHOR0+32
	li	s1,0
	li	s3,0
	la	s7,stderr
	lla	s6,.LC3
	li	s4,4
	beq	a5,a4,.L39
.L45:
	ld	a0,0(s7)
	mv	a3,s1
	mv	a2,s6
	li	a1,2
	call	__fprintf_chk@plt
	addiw	s3,s3,1
.L39:
	addi	s1,s1,1
	addi	s0,s0,4
	addi	s2,s2,4
	beq	s1,s4,.L40
.L46:
	lw	a4,0(s2)
	lw	a5,0(s0)
	bne	a5,a4,.L45
	addi	s1,s1,1
	addi	s0,s0,4
	addi	s2,s2,4
	bne	s1,s4,.L46
.L40:
	ld	a4, 24(sp)
	ld	a5, 0(s5)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L47
	ld	ra,104(sp)
	.cfi_remember_state
	.cfi_restore 1
	ld	s0,96(sp)
	.cfi_restore 8
	ld	s1,88(sp)
	.cfi_restore 9
	ld	s2,80(sp)
	.cfi_restore 18
	ld	s4,64(sp)
	.cfi_restore 20
	ld	s5,56(sp)
	.cfi_restore 21
	ld	s6,48(sp)
	.cfi_restore 22
	ld	s7,40(sp)
	.cfi_restore 23
	mv	a0,s3
	ld	s3,72(sp)
	.cfi_restore 19
	addi	sp,sp,112
	.cfi_def_cfa_offset 0
	jr	ra
.L47:
	.cfi_restore_state
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE18:
	.size	check_boundary_values, .-check_boundary_values
	.section	.rodata.str1.8
	.align	3
.LC4:
	.string	"%d check(s) failed\n"
	.align	3
.LC5:
	.string	"All RVV array-addition checks passed"
	.section	.text.startup,"ax",@progbits
	.align	1
	.globl	main
	.type	main, @function
main:
.LFB19:
	.cfi_startproc
	addi	sp,sp,-48
	.cfi_def_cfa_offset 48
	sd	s1,24(sp)
	sd	s2,16(sp)
	sd	s3,8(sp)
	sd	ra,40(sp)
	sd	s0,32(sp)
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	lla	s1,.LANCHOR0+56
	lla	s3,.LANCHOR0+176
	li	a0,0
	li	s2,0
	j	.L50
.L54:
	ld	a0,0(s1)
	addi	s1,s1,8
.L50:
	call	check_size
	addw	s2,a0,s2
	bne	s1,s3,.L54
	call	check_boundary_values
	addw	s0,s2,a0
	bne	s0,zero,.L55
	lla	a0,.LC5
	call	puts@plt
.L52:
	ld	ra,40(sp)
	.cfi_remember_state
	.cfi_restore 1
	mv	a0,s0
	ld	s0,32(sp)
	.cfi_restore 8
	ld	s1,24(sp)
	.cfi_restore 9
	ld	s2,16(sp)
	.cfi_restore 18
	ld	s3,8(sp)
	.cfi_restore 19
	addi	sp,sp,48
	.cfi_def_cfa_offset 0
	jr	ra
.L55:
	.cfi_restore_state
	la	a5,stderr
	ld	a0,0(a5)
	mv	a3,s0
	lla	a2,.LC4
	li	a1,2
	call	__fprintf_chk@plt
	li	s0,1
	j	.L52
	.cfi_endproc
.LFE19:
	.size	main, .-main
	.section	.rodata
	.align	3
	.set	.LANCHOR0,. + 0
	.type	b.1, @object
	.size	b.1, 16
b.1:
	.word	0
	.word	0
	.word	-10
	.word	10
	.type	a.2, @object
	.size	a.2, 16
a.2:
	.word	2147483647
	.word	-2147483648
	.word	2147483637
	.word	-2147483638
	.type	expected.0, @object
	.size	expected.0, 16
expected.0:
	.word	2147483647
	.word	-2147483648
	.word	2147483627
	.word	-2147483628
	.type	sizes.3, @object
	.size	sizes.3, 128
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
	.dword	257
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
