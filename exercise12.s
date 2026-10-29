	.file	"exercise12.c"
	.option pic
	.attribute arch, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_v1p0_zicsr2p0_zifencei2p0_zve32f1p0_zve32x1p0_zve64d1p0_zve64f1p0_zve64x1p0_zvl128b1p0_zvl32b1p0_zvl64b1p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	1
	.globl	unpack_nibbles_scalar
	.type	unpack_nibbles_scalar, @function
unpack_nibbles_scalar:
.LFB15:
	.cfi_startproc
	beq	a3,zero,.L1
	add	a3,a0,a3
.L3:
	lbu	a5,0(a0)
	addi	a1,a1,1
	addi	a0,a0,1
	andi	a5,a5,15
	sb	a5,-1(a1)
	lbu	a5,-1(a0)
	addi	a2,a2,1
	srliw	a5,a5,4
	sb	a5,-1(a2)
	bne	a0,a3,.L3
.L1:
	ret
	.cfi_endproc
.LFE15:
	.size	unpack_nibbles_scalar, .-unpack_nibbles_scalar
	.align	1
	.globl	unpack_nibbles_rvv
	.type	unpack_nibbles_rvv, @function
unpack_nibbles_rvv:
.LFB16:
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
	li	a4,0
.L11:
	sub	a5,a3,a4
	add	t1,a0,a4
	add	a7,a1,a4
	add	a6,a2,a4
	vsetvli	a5,a5,e8,m1,ta,ma
	vle8.v	v24,0(t1)
	add	a4,a4,a5
	vand.vi	v25,v24,15
	vsrl.vi	v24,v24,4
	vse8.v	v25,0(a7)
	vse8.v	v24,0(a6)
	bgtu	a3,a4,.L11
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
.LFE16:
	.size	unpack_nibbles_rvv, .-unpack_nibbles_rvv
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC0:
	.string	"%s, n=%zu, index=%zu, packed=0x%02x: expected low=%u high=%u, got low=%u high=%u\n"
	.align	3
.LC1:
	.string	"%s, n=%zu: output index %zu was modified past the requested length\n"
	.text
	.align	1
	.type	check_case, @function
check_case:
.LFB17:
	.cfi_startproc
	addi	sp,sp,-896
	.cfi_def_cfa_offset 896
	sd	s2,864(sp)
	sd	s6,832(sp)
	.cfi_offset 18, -32
	.cfi_offset 22, -64
	la	s2,__stack_chk_guard
	addi	s6,sp,32
	sd	s0,880(sp)
	sd	s1,872(sp)
	sd	s5,840(sp)
	sd	ra,888(sp)
	sd	s3,856(sp)
	sd	s4,848(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 21, -56
	.cfi_offset 1, -8
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	mv	s1,a0
	mv	s5,a1
	ld	a5, 0(s2)
	sd	a5, 824(sp)
	li	a5, 0
	mv	s0,s6
	mv	a3,s6
	li	a2,259
.L20:
	sb	a5,0(a3)
	addi	a5,a5,1
	addi	a3,a3,1
	bne	a5,a2,.L20
	addi	s3,sp,296
	li	a2,259
	li	a1,165
	mv	a0,s3
	call	memset@plt
	addi	s4,sp,560
	li	a2,259
	li	a1,165
	mv	a0,s4
	call	memset@plt
	ld	a5,8(s1)
	mv	a3,s5
	mv	a2,s4
	mv	a1,s3
	mv	a0,s6
	jalr	a5
	beq	s5,zero,.L21
	mv	a2,s3
	mv	a3,s4
	li	a5,0
	j	.L25
.L40:
	bne	t4,t3,.L22
	addi	a5,a5,1
	addi	s0,s0,1
	addi	a2,a2,1
	addi	a3,a3,1
	beq	s5,a5,.L39
.L25:
	lbu	a6,0(s0)
	lbu	t1,0(a2)
	lbu	t4,0(a3)
	andi	a7,a6,15
	srli	t3,a6,4
	beq	t1,a7,.L40
.L22:
	la	a4,stderr
	ld	a0,0(a4)
	ld	a3,0(s1)
	mv	a4,s5
	sd	t4,16(sp)
	sd	t1,8(sp)
	sd	t3,0(sp)
	lla	a2,.LC0
	li	a1,2
	call	__fprintf_chk@plt
.L24:
	li	a0,1
.L26:
	ld	a4, 824(sp)
	ld	a5, 0(s2)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L41
	ld	ra,888(sp)
	.cfi_remember_state
	.cfi_restore 1
	ld	s0,880(sp)
	.cfi_restore 8
	ld	s1,872(sp)
	.cfi_restore 9
	ld	s2,864(sp)
	.cfi_restore 18
	ld	s3,856(sp)
	.cfi_restore 19
	ld	s4,848(sp)
	.cfi_restore 20
	ld	s5,840(sp)
	.cfi_restore 21
	ld	s6,832(sp)
	.cfi_restore 22
	addi	sp,sp,896
	.cfi_def_cfa_offset 0
	jr	ra
.L39:
	.cfi_restore_state
	li	a5,259
	beq	s5,a5,.L31
.L21:
	add	s3,s3,s5
	add	s4,s4,s5
	mv	a5,s5
	li	a4,165
	li	a2,259
	j	.L29
.L42:
	lbu	a3,0(s4)
	bne	a3,a4,.L27
	addi	a5,a5,1
	addi	s3,s3,1
	addi	s4,s4,1
	beq	a5,a2,.L31
.L29:
	lbu	a3,0(s3)
	beq	a3,a4,.L42
.L27:
	la	a4,stderr
	ld	a3,0(s1)
	ld	a0,0(a4)
	lla	a2,.LC1
	mv	a4,s5
	li	a1,2
	call	__fprintf_chk@plt
	j	.L24
.L31:
	li	a0,0
	j	.L26
.L41:
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE17:
	.size	check_case, .-check_case
	.section	.rodata.str1.8
	.align	3
.LC2:
	.string	"All scalar and RVV nibble-extraction checks passed"
	.section	.text.startup,"ax",@progbits
	.align	1
	.globl	main
	.type	main, @function
main:
.LFB18:
	.cfi_startproc
	addi	sp,sp,-48
	.cfi_def_cfa_offset 48
	sd	s0,32(sp)
	sd	s1,24(sp)
	sd	s2,16(sp)
	sd	s3,8(sp)
	sd	ra,40(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 1, -8
	lla	s0,.LANCHOR0+8
	lla	s1,.LANCHOR0
	lla	s2,.LANCHOR0+152
	li	a1,0
	lla	s3,.LANCHOR1
	j	.L47
.L44:
	beq	s0,s2,.L53
	ld	a1,0(s0)
	addi	s0,s0,8
.L47:
	mv	a0,s3
	call	check_case
	beq	a0,zero,.L44
.L48:
	li	s0,1
.L45:
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
.L53:
	.cfi_restore_state
	lla	s3,.LANCHOR1+16
	j	.L46
.L55:
	beq	s1,s2,.L54
.L46:
	ld	a1,0(s1)
	mv	a0,s3
	addi	s1,s1,8
	call	check_case
	mv	s0,a0
	beq	a0,zero,.L55
	j	.L48
.L54:
	lla	a0,.LC2
	call	puts@plt
	j	.L45
	.cfi_endproc
.LFE18:
	.size	main, .-main
	.section	.rodata.str1.8
	.align	3
.LC3:
	.string	"scalar"
	.align	3
.LC4:
	.string	"RVV"
	.section	.rodata
	.align	3
	.set	.LANCHOR0,. + 0
	.type	sizes.0, @object
	.size	sizes.0, 152
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
	.dword	127
	.dword	128
	.dword	129
	.dword	255
	.dword	256
	.dword	257
	.dword	259
	.section	.data.rel.ro.local,"aw"
	.align	3
	.set	.LANCHOR1,. + 0
	.type	implementations.1, @object
	.size	implementations.1, 32
implementations.1:
	.dword	.LC3
	.dword	unpack_nibbles_scalar
	.dword	.LC4
	.dword	unpack_nibbles_rvv
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
