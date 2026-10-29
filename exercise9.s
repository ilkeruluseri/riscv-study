	.file	"exercise9.c"
	.option pic
	.attribute arch, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_v1p0_zicsr2p0_zifencei2p0_zve32f1p0_zve32x1p0_zve64d1p0_zve64f1p0_zve64x1p0_zvl128b1p0_zvl32b1p0_zvl64b1p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	1
	.type	multiply_scalar_i32_reference, @function
multiply_scalar_i32_reference:
.LFB16:
	.cfi_startproc
	beq	a3,zero,.L1
	slli	a3,a3,2
	add	a4,a0,a3
.L3:
	lw	a5,0(a0)
	addi	a2,a2,4
	addi	a0,a0,4
	mulw	a5,a5,a1
	sw	a5,-4(a2)
	bne	a0,a4,.L3
.L1:
	ret
	.cfi_endproc
.LFE16:
	.size	multiply_scalar_i32_reference, .-multiply_scalar_i32_reference
	.align	1
	.globl	multiply_scalar_i32
	.type	multiply_scalar_i32, @function
multiply_scalar_i32:
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
	beq	a3,zero,.L9
	li	a6,0
.L11:
	slli	a4,a6,2
	sub	a5,a3,a6
	add	a7,a0,a4
	add	a4,a2,a4
	vsetvli	a5,a5,e32,m1,ta,ma
	vle32.v	v24,0(a7)
	add	a6,a6,a5
	vmul.vx	v24,v24,a1
	vse32.v	v24,0(a4)
	bgtu	a3,a6,.L11
.L9:
	ld	a4, 8(sp)
	ld	a5, 0(t1)
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
	.size	multiply_scalar_i32, .-multiply_scalar_i32
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC0:
	.string	"n=%zu, scalar=%d, index=%zu: expected %d, got %d\n"
	.align	3
.LC1:
	.string	"n=%zu, scalar=%d: output[%zu] was modified past the requested length\n"
	.align	3
.LC2:
	.string	"n=%zu, scalar=%d: output was modified outside its allocation\n"
	.text
	.align	1
	.type	check_case, @function
check_case:
.LFB17:
	.cfi_startproc
	addi	sp,sp,-2032
	.cfi_def_cfa_offset 2032
	sd	s4,1984(sp)
	.cfi_offset 20, -48
	mv	s4,a0
	li	a0,4096
	sd	s2,2000(sp)
	sd	s3,1992(sp)
	sd	ra,2024(sp)
	sd	s0,2016(sp)
	sd	s1,2008(sp)
	sd	s5,1976(sp)
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 21, -56
	mv	s2,a1
	addi	sp,sp,-1168
	.cfi_def_cfa_offset 3200
	addi	a1,a0,-968
	la	s3,__stack_chk_guard
	add	a1,a1,sp
	li	a4,-4096
	ld	a3, 0(s3)
	sd	a3, 0(a1)
	li	a3, 0
	addi	a4,a4,960
	addi	a3,a0,-960
	li	a5,-49152
	li	a2,-24576
	add	a3,a3,a4
	add	a4,a3,sp
	addi	a5,a5,-817
	addi	a2,a2,-270
.L20:
	sw	a5,0(a4)
	addiw	a5,a5,97
	addi	a4,a4,4
	bne	a5,a2,.L20
	li	s5,4096
	li	a5,-4096
	addi	a5,a5,2000
	addi	a4,s5,-960
	add	a4,a4,a5
	add	s0,a4,sp
	li	a2,1036
	li	a1,85
	mv	a0,s0
	call	memset@plt
	addi	a5,s5,-2012
	add	s1,sp,a5
	li	a2,1036
	li	a1,85
	mv	a0,s1
	call	memset@plt
	li	a5,-4096
	addi	a5,a5,960
	addi	a3,s5,-960
	mv	a4,s5
	add	a3,a3,a5
	add	s5,a3,sp
	addi	a6,a4,-2016
	li	a5,1431654400
	addi	a4,a4,-976
	addi	a5,a5,1365
	mv	a3,s4
	mv	a2,s0
	mv	a1,s2
	mv	a0,s5
	add	a6,a6,sp
	add	a4,a4,sp
	sw	a5,0(a6)
	sw	a5,0(a4)
	call	multiply_scalar_i32_reference
	mv	a3,s4
	mv	a2,s1
	mv	a1,s2
	mv	a0,s5
	call	multiply_scalar_i32
	beq	s4,zero,.L21
	mv	a2,s1
	mv	a4,s0
	li	a5,0
	j	.L24
.L22:
	addi	a5,a5,1
	addi	a2,a2,4
	addi	a4,a4,4
	beq	s4,a5,.L39
.L24:
	lw	a7,0(a2)
	lw	a6,0(a4)
	beq	a7,a6,.L22
	la	a4,stderr
	ld	a0,0(a4)
	mv	a3,s4
	mv	a4,s2
	lla	a2,.LC0
	li	a1,2
	call	__fprintf_chk@plt
.L23:
	li	a0,1
.L27:
	li	a5,4096
	addi	a5,a5,-968
	add	a5,a5,sp
	ld	a4, 0(a5)
	ld	a5, 0(s3)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L40
	addi	sp,sp,1168
	.cfi_remember_state
	.cfi_def_cfa_offset 2032
	ld	ra,2024(sp)
	.cfi_restore 1
	ld	s0,2016(sp)
	.cfi_restore 8
	ld	s1,2008(sp)
	.cfi_restore 9
	ld	s2,2000(sp)
	.cfi_restore 18
	ld	s3,1992(sp)
	.cfi_restore 19
	ld	s4,1984(sp)
	.cfi_restore 20
	ld	s5,1976(sp)
	.cfi_restore 21
	addi	sp,sp,2032
	.cfi_def_cfa_offset 0
	jr	ra
.L39:
	.cfi_restore_state
	li	a5,259
	beq	s4,a5,.L25
.L21:
	li	a4,4096
	addi	a5,s4,1
	addi	a4,a4,-2016
	slli	a5,a5,2
	li	a2,1431654400
	add	a4,sp,a4
	add	a4,a4,a5
	addi	a2,a2,1365
	mv	a5,s4
	li	a1,259
	j	.L28
.L26:
	addi	a5,a5,1
	addi	a4,a4,4
	beq	a5,a1,.L25
.L28:
	lw	a3,0(a4)
	beq	a3,a2,.L26
	la	a4,stderr
	ld	a0,0(a4)
	mv	a3,s4
	mv	a4,s2
	lla	a2,.LC1
	li	a1,2
	call	__fprintf_chk@plt
	j	.L23
.L25:
	li	a3,4096
	addi	a5,a3,-2016
	add	a5,a5,sp
	lw	a4,0(a5)
	li	a5,1431654400
	addi	a5,a5,1365
	bne	a4,a5,.L29
	addi	a5,a3,-976
	add	a5,a5,sp
	lw	a5,0(a5)
	li	a0,0
	beq	a5,a4,.L27
.L29:
	la	a5,stderr
	ld	a0,0(a5)
	mv	a4,s2
	mv	a3,s4
	lla	a2,.LC2
	li	a1,2
	call	__fprintf_chk@plt
	j	.L23
.L40:
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE17:
	.size	check_case, .-check_case
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
	addi	sp,sp,-48
	.cfi_def_cfa_offset 48
	sd	s0,32(sp)
	.cfi_offset 8, -16
	la	s0,__stack_chk_guard
	ld	a5, 0(s0)
	sd	a5, 24(sp)
	li	a5, 0
	li	a3,4
	addi	a2,sp,8
	li	a1,-1
	lla	a0,.LANCHOR0
	sd	ra,40(sp)
	.cfi_offset 1, -8
	sd	zero,8(sp)
	sd	zero,16(sp)
	call	multiply_scalar_i32
	lw	a5,8(sp)
	li	a4,-2147483648
	addi	a4,a4,1
	bne	a5,a4,.L45
	lw	a5,12(sp)
	li	a4,-2147483648
	not	a4,a4
	bne	a5,a4,.L46
	lw	a5,16(sp)
	li	a4,-2147483648
	addi	a4,a4,11
	bne	a5,a4,.L47
	lw	a5,20(sp)
	li	a4,-2147483648
	xori	a4,a4,-10
	li	a0,0
	li	a3,3
	bne	a5,a4,.L42
.L43:
	ld	a4, 24(sp)
	ld	a5, 0(s0)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L50
	ld	ra,40(sp)
	.cfi_remember_state
	.cfi_restore 1
	ld	s0,32(sp)
	.cfi_restore 8
	addi	sp,sp,48
	.cfi_def_cfa_offset 0
	jr	ra
.L45:
	.cfi_restore_state
	li	a3,0
.L42:
	la	a2,stderr
	ld	a0,0(a2)
	li	a1,2
	lla	a2,.LC3
	call	__fprintf_chk@plt
	li	a0,1
	j	.L43
.L46:
	li	a3,1
	j	.L42
.L47:
	li	a3,2
	j	.L42
.L50:
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE18:
	.size	check_boundary_values, .-check_boundary_values
	.section	.rodata.str1.8
	.align	3
.LC4:
	.string	"All RVV scalar-multiplication checks passed"
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
	sd	s4,0(sp)
	sd	ra,40(sp)
	sd	s0,32(sp)
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	lla	s3,.LANCHOR0+20
	lla	s4,.LANCHOR0+36
	li	s1,0
	lla	s2,.LANCHOR0+168
.L52:
	lla	s0,.LANCHOR0+48
	li	a0,0
	j	.L57
.L55:
	ld	a0,0(s0)
	addi	s0,s0,8
.L57:
	mv	a1,s1
	call	check_case
	bne	a0,zero,.L58
	bne	s2,s0,.L55
	beq	s3,s4,.L56
	lw	s1,0(s3)
	addi	s3,s3,4
	j	.L52
.L56:
	call	check_boundary_values
	mv	s0,a0
	beq	a0,zero,.L60
.L58:
	li	s0,1
.L54:
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
	ld	s4,0(sp)
	.cfi_restore 20
	addi	sp,sp,48
	.cfi_def_cfa_offset 0
	jr	ra
.L60:
	.cfi_restore_state
	lla	a0,.LC4
	call	puts@plt
	j	.L54
	.cfi_endproc
.LFE19:
	.size	main, .-main
	.section	.rodata
	.align	3
	.set	.LANCHOR0,. + 0
	.type	input.1, @object
	.size	input.1, 16
input.1:
	.word	2147483647
	.word	-2147483647
	.word	2147483637
	.word	-2147483638
	.type	scalars.2, @object
	.size	scalars.2, 20
scalars.2:
	.word	0
	.word	1
	.word	-1
	.word	7
	.word	-11
	.zero	4
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
