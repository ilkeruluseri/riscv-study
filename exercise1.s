	.file	"exercise1.c"
	.option pic
	.attribute arch, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_v1p0_zicsr2p0_zifencei2p0_zve32f1p0_zve32x1p0_zve64d1p0_zve64f1p0_zve64x1p0_zvl128b1p0_zvl32b1p0_zvl64b1p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	1
	.globl	add_i32
	.type	add_i32, @function
add_i32:
.LFB23:
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
.LFE23:
	.size	add_i32, .-add_i32
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC3:
	.string	"n=%zu, index=%zu: expected %d, got %d\n"
	.align	3
.LC4:
	.string	"n=%zu: result[%zu] was modified past the requested length\n"
	.align	3
.LC8:
	.string	"boundary index=%zu: expected %d, got %d\n"
	.align	3
.LC9:
	.string	"%d check(s) failed\n"
	.align	3
.LC10:
	.string	"All add_i32 checks passed"
	.section	.text.startup,"ax",@progbits
	.align	1
	.globl	main
	.type	main, @function
main:
.LFB24:
	.cfi_startproc
	addi	sp,sp,-368
	.cfi_def_cfa_offset 368
	la	a4,__stack_chk_guard
	ld	a5, 0(a4)
	sd	a5, 248(sp)
	li	a5, 0
	sd	s3,328(sp)
	addi	a5,sp,104
	.cfi_offset 19, -40
	li	s3,1431654400
	sd	s1,344(sp)
	sd	s2,336(sp)
	sd	s4,320(sp)
	sd	s5,312(sp)
	sd	s6,304(sp)
	sd	s8,288(sp)
	sd	ra,360(sp)
	sd	s0,352(sp)
	sd	s7,296(sp)
	sd	s9,280(sp)
	sd	s10,272(sp)
	sd	s11,264(sp)
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	.cfi_offset 24, -80
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	.cfi_offset 23, -72
	.cfi_offset 25, -88
	.cfi_offset 26, -96
	.cfi_offset 27, -104
	lla	s8,.LANCHOR0
	li	s2,0
	addi	s6,sp,32
	sd	a5,0(sp)
	addi	s5,sp,176
	li	s1,31
	addi	s3,s3,1365
	la	s4,stderr
.L18:
	ld	a1,0(sp)
	ld	s9,0(s8)
	mv	s11,s6
	mv	s10,a1
	mv	a2,s6
	li	a4,12
	li	a5,-20
.L10:
	sw	a5,0(a2)
	sw	a4,0(a1)
	addiw	a5,a5,3
	addi	a2,a2,4
	addiw	a4,a4,-2
	addi	a1,a1,4
	bne	a5,s1,.L10
	li	a2,68
	li	a1,85
	mv	a0,s5
	call	memset@plt
	beq	s9,zero,.L36
	ld	a2,0(sp)
	slli	a5,s9,2
	sd	a5,8(sp)
	add	a6,a5,s6
	mv	s7,s5
	mv	a1,s5
	mv	a5,s6
.L12:
	lw	a0,0(a5)
	lw	a4,0(a2)
	addi	a5,a5,4
	addi	a2,a2,4
	addw	a4,a4,a0
	sw	a4,0(a1)
	addi	a1,a1,4
	bne	a5,a6,.L12
	li	s0,0
.L14:
	lw	a2,0(s11)
	lw	a5,0(s10)
	lw	a6,0(s7)
	addw	a5,a5,a2
	beq	a6,a5,.L13
	ld	a0,0(s4)
	mv	a4,s0
	mv	a3,s9
	lla	a2,.LC3
	li	a1,2
	call	__fprintf_chk@plt
	addiw	s2,s2,1
.L13:
	addi	s0,s0,1
	addi	s11,s11,4
	addi	s10,s10,4
	addi	s7,s7,4
	bne	s9,s0,.L14
	li	a5,17
	beq	s9,a5,.L15
.L11:
	ld	a5,8(sp)
	mv	s0,s9
	li	s11,17
	add	s10,s5,a5
.L17:
	lw	a4,0(s10)
	beq	a4,s3,.L16
	ld	a0,0(s4)
	mv	a4,s0
	mv	a3,s9
	lla	a2,.LC4
	li	a1,2
	call	__fprintf_chk@plt
	addiw	s2,s2,1
.L16:
	addi	s0,s0,1
	addi	s10,s10,4
	bne	s0,s11,.L17
.L15:
	addi	s8,s8,8
	lla	a5,.LANCHOR0+56
	bne	s8,a5,.L18
	li	a5,11
	slli	a5,a5,32
	addi	a5,a5,-10
	ld	a4,.LC5
	ld	a3,.LC6
	sd	a5,40(sp)
	ld	a5,.LC7
	sd	a3,24(sp)
	sd	a5,112(sp)
	sd	a4,16(sp)
	sd	zero,32(sp)
	sd	a4,104(sp)
	sd	zero,176(sp)
	sd	zero,184(sp)
	addi	a5,sp,16
	mv	a2,s6
	mv	a3,s5
.L19:
	lw	a1,0(a5)
	lw	a4,0(a2)
	addi	a5,a5,4
	addi	a2,a2,4
	addw	a4,a4,a1
	sw	a4,0(a3)
	addi	a3,a3,4
	bne	s6,a5,.L19
	ld	s7,0(sp)
	li	s0,0
	la	s4,stderr
	lla	s3,.LC8
	li	s1,4
.L21:
	lw	a5,0(s5)
	lw	a4,0(s7)
	beq	a5,a4,.L20
	ld	a0,0(s4)
	mv	a3,s0
	mv	a2,s3
	li	a1,2
	call	__fprintf_chk@plt
	addiw	s2,s2,1
.L20:
	addi	s0,s0,1
	addi	s5,s5,4
	addi	s7,s7,4
	bne	s0,s1,.L21
	bne	s2,zero,.L37
	lla	a0,.LC10
	call	puts@plt
.L23:
	la	a5,__stack_chk_guard
	ld	a4, 248(sp)
	ld	a5, 0(a5)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L38
	ld	ra,360(sp)
	.cfi_remember_state
	.cfi_restore 1
	ld	s0,352(sp)
	.cfi_restore 8
	ld	s1,344(sp)
	.cfi_restore 9
	ld	s3,328(sp)
	.cfi_restore 19
	ld	s4,320(sp)
	.cfi_restore 20
	ld	s5,312(sp)
	.cfi_restore 21
	ld	s6,304(sp)
	.cfi_restore 22
	ld	s7,296(sp)
	.cfi_restore 23
	ld	s8,288(sp)
	.cfi_restore 24
	ld	s9,280(sp)
	.cfi_restore 25
	ld	s10,272(sp)
	.cfi_restore 26
	ld	s11,264(sp)
	.cfi_restore 27
	mv	a0,s2
	ld	s2,336(sp)
	.cfi_restore 18
	addi	sp,sp,368
	.cfi_def_cfa_offset 0
	jr	ra
.L36:
	.cfi_restore_state
	sd	zero,8(sp)
	j	.L11
.L37:
	la	a5,stderr
	ld	a0,0(a5)
	mv	a3,s2
	lla	a2,.LC9
	li	a1,2
	call	__fprintf_chk@plt
	li	s2,1
	j	.L23
.L38:
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE24:
	.size	main, .-main
	.section	.rodata.cst8,"aM",@progbits,8
	.align	3
.LC5:
	.dword	-9223372034707292161
	.align	3
.LC6:
	.dword	-9223371991757619211
	.align	3
.LC7:
	.dword	-9223371948807946261
	.section	.rodata
	.align	3
	.set	.LANCHOR0,. + 0
	.type	sizes.0, @object
	.size	sizes.0, 56
sizes.0:
	.dword	0
	.dword	1
	.dword	3
	.dword	4
	.dword	7
	.dword	16
	.dword	17
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
