	.file	"exercise8.c"
	.option pic
	.attribute arch, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_v1p0_zicsr2p0_zifencei2p0_zve32f1p0_zve32x1p0_zve64d1p0_zve64f1p0_zve64x1p0_zvl128b1p0_zvl32b1p0_zvl64b1p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	1
	.globl	select_vl_e32m1
	.type	select_vl_e32m1, @function
select_vl_e32m1:
.LFB15:
	.cfi_startproc
	vsetvli	a0,a0,e32,m1,ta,mu
	ret
	.cfi_endproc
.LFE15:
	.size	select_vl_e32m1, .-select_vl_e32m1
	.align	1
	.globl	select_vl_e8m1
	.type	select_vl_e8m1, @function
select_vl_e8m1:
.LFB16:
	.cfi_startproc
	vsetvli	a0,a0,e8,m1,ta,mu
	ret
	.cfi_endproc
.LFE16:
	.size	select_vl_e8m1, .-select_vl_e8m1
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC0:
	.string	"%s (n=%zu, VLMAX=%zu):"
	.align	3
.LC1:
	.string	"%s: invalid vl=%zu with remaining=%zu and VLMAX=%zu\n"
	.align	3
.LC2:
	.string	" %zu"
	.align	3
.LC3:
	.string	"%s: trace did not make progress\n"
	.text
	.align	1
	.type	validate_trace, @function
validate_trace:
.LFB17:
	.cfi_startproc
	addi	sp,sp,-80
	.cfi_def_cfa_offset 80
	sd	s3,40(sp)
	sd	s4,32(sp)
	sd	s5,24(sp)
	sd	s6,16(sp)
	sd	s7,8(sp)
	sd	ra,72(sp)
	sd	s0,64(sp)
	sd	s1,56(sp)
	sd	s2,48(sp)
	sd	s8,0(sp)
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	.cfi_offset 23, -72
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 24, -80
	mv	s4,a4
	mv	s7,a0
	mv	s3,a1
	mv	s5,a2
	mv	s6,a3
	bne	a4,zero,.L26
.L5:
	mv	s1,s3
	li	s2,0
	lla	s8,.LC2
	j	.L10
.L9:
	addi	s2,s2,1
	sub	s1,s1,s0
	bltu	s3,s2,.L27
.L10:
	mv	a0,s1
	beq	s1,zero,.L28
	jalr	s6
	mv	s0,a0
	beq	a0,zero,.L6
	bltu	s1,a0,.L6
	bltu	s5,a0,.L6
	beq	s4,zero,.L9
	mv	a2,a0
	mv	a1,s8
	li	a0,2
	addi	s2,s2,1
	call	__printf_chk@plt
	sub	s1,s1,s0
	bgeu	s3,s2,.L10
.L27:
	la	a5,stderr
	ld	a0,0(a5)
	mv	a3,s7
	lla	a2,.LC3
	li	a1,2
	call	__fprintf_chk@plt
.L8:
	li	a0,1
.L13:
	ld	ra,72(sp)
	.cfi_remember_state
	.cfi_restore 1
	ld	s0,64(sp)
	.cfi_restore 8
	ld	s1,56(sp)
	.cfi_restore 9
	ld	s2,48(sp)
	.cfi_restore 18
	ld	s3,40(sp)
	.cfi_restore 19
	ld	s4,32(sp)
	.cfi_restore 20
	ld	s5,24(sp)
	.cfi_restore 21
	ld	s6,16(sp)
	.cfi_restore 22
	ld	s7,8(sp)
	.cfi_restore 23
	ld	s8,0(sp)
	.cfi_restore 24
	addi	sp,sp,80
	.cfi_def_cfa_offset 0
	jr	ra
.L6:
	.cfi_restore_state
	la	a5,stderr
	ld	a0,0(a5)
	mv	a6,s5
	mv	a5,s1
	mv	a4,s0
	mv	a3,s7
	lla	a2,.LC1
	li	a1,2
	call	__fprintf_chk@plt
	j	.L8
.L26:
	mv	a4,a2
	mv	a3,a1
	mv	a2,a0
	lla	a1,.LC0
	li	a0,2
	call	__printf_chk@plt
	j	.L5
.L28:
	bne	s4,zero,.L12
	li	a0,0
	j	.L13
.L12:
	li	a0,10
	call	putchar@plt
	li	a0,0
	j	.L13
	.cfi_endproc
.LFE17:
	.size	validate_trace, .-validate_trace
	.align	1
	.type	validate_awkward_sizes, @function
validate_awkward_sizes:
.LFB18:
	.cfi_startproc
	addi	sp,sp,-64
	.cfi_def_cfa_offset 64
	sd	s0,48(sp)
	sd	s1,40(sp)
	sd	s2,32(sp)
	sd	s3,24(sp)
	sd	s4,16(sp)
	sd	s5,8(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	mv	s3,a1
	sd	ra,56(sp)
	.cfi_offset 1, -8
	mv	s4,a0
	mv	s2,a2
	lla	s0,.LANCHOR0+8
	lla	s5,.LANCHOR0+96
	li	a1,0
	li	s1,0
	j	.L31
.L33:
	ld	a1,0(s0)
	addi	s0,s0,8
.L31:
	li	a4,0
	mv	a3,s2
	mv	a2,s3
	mv	a0,s4
	call	validate_trace
	addw	s1,a0,s1
	bne	a0,zero,.L30
	bne	s0,s5,.L33
.L30:
	ld	ra,56(sp)
	.cfi_restore 1
	ld	s0,48(sp)
	.cfi_restore 8
	ld	s2,32(sp)
	.cfi_restore 18
	ld	s3,24(sp)
	.cfi_restore 19
	ld	s4,16(sp)
	.cfi_restore 20
	ld	s5,8(sp)
	.cfi_restore 21
	mv	a0,s1
	ld	s1,40(sp)
	.cfi_restore 9
	addi	sp,sp,64
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE18:
	.size	validate_awkward_sizes, .-validate_awkward_sizes
	.section	.rodata.str1.8
	.align	3
.LC4:
	.string	"SEW=32, LMUL=1"
	.align	3
.LC5:
	.string	"SEW=8, LMUL=1"
	.align	3
.LC6:
	.string	"%d VL trace check(s) failed\n"
	.section	.text.startup,"ax",@progbits
	.align	1
	.globl	main
	.type	main, @function
main:
.LFB19:
	.cfi_startproc
	addi	sp,sp,-32
	.cfi_def_cfa_offset 32
	sd	s2,0(sp)
	.cfi_offset 18, -32
	vsetvli	s2,zero,e32,m1,ta,mu
	sd	s1,8(sp)
	lla	a2,select_vl_e32m1
	.cfi_offset 9, -24
	vsetvli	s1,zero,e8,m1,ta,mu
	mv	a1,s2
	lla	a0,.LC4
	sd	ra,24(sp)
	sd	s0,16(sp)
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	call	validate_awkward_sizes
	mv	s0,a0
	lla	a2,select_vl_e8m1
	mv	a1,s1
	lla	a0,.LC5
	call	validate_awkward_sizes
	addw	a3,s0,a0
	bne	a3,zero,.L42
	li	a4,1
	lla	a3,select_vl_e32m1
	mv	a2,s2
	li	a1,37
	lla	a0,.LC4
	call	validate_trace
	mv	s0,a0
	lla	a3,select_vl_e8m1
	li	a4,1
	mv	a2,s1
	li	a1,37
	lla	a0,.LC5
	call	validate_trace
	addw	a3,s0,a0
	bne	a3,zero,.L42
.L37:
	ld	ra,24(sp)
	.cfi_remember_state
	.cfi_restore 1
	ld	s0,16(sp)
	.cfi_restore 8
	ld	s1,8(sp)
	.cfi_restore 9
	ld	s2,0(sp)
	.cfi_restore 18
	mv	a0,a3
	addi	sp,sp,32
	.cfi_def_cfa_offset 0
	jr	ra
.L42:
	.cfi_restore_state
	la	a5,stderr
	ld	a0,0(a5)
	lla	a2,.LC6
	li	a1,2
	call	__fprintf_chk@plt
	li	a3,1
	j	.L37
	.cfi_endproc
.LFE19:
	.size	main, .-main
	.section	.rodata
	.align	3
	.set	.LANCHOR0,. + 0
	.type	sizes.0, @object
	.size	sizes.0, 96
sizes.0:
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
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
