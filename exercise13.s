	.file	"exercise13.c"
	.option pic
	.attribute arch, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_v1p0_zicsr2p0_zifencei2p0_zve32f1p0_zve32x1p0_zve64d1p0_zve64f1p0_zve64x1p0_zvl128b1p0_zvl32b1p0_zvl64b1p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	1
	.globl	decode_table_scalar
	.type	decode_table_scalar, @function
decode_table_scalar:
.LFB15:
	.cfi_startproc
	beq	a3,zero,.L1
	add	a3,a1,a3
.L3:
	lbu	a5,0(a1)
	addi	a2,a2,1
	addi	a1,a1,1
	add	a5,a0,a5
	lb	a5,0(a5)
	sb	a5,-1(a2)
	bne	a1,a3,.L3
.L1:
	ret
	.cfi_endproc
.LFE15:
	.size	decode_table_scalar, .-decode_table_scalar
	.align	1
	.type	next_random, @function
next_random:
.LFB18:
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
.LFE18:
	.size	next_random, .-next_random
	.align	1
	.globl	decode_table_rvv
	.type	decode_table_rvv, @function
decode_table_rvv:
.LFB16:
	.cfi_startproc
	addi	sp,sp,-32
	.cfi_def_cfa_offset 32
	la	a7,__stack_chk_guard
	ld	a5, 0(a7)
	sd	a5, 8(sp)
	li	a5, 0
	sd	ra,24(sp)
	.cfi_offset 1, -8
	vsetivli	a5,16,e8,m1,ta,ma
	vle8.v	v26,0(a0)
	beq	a3,zero,.L10
	li	a4,0
.L12:
	sub	a5,a3,a4
	add	a6,a1,a4
	add	a0,a2,a4
	vsetvli	a5,a5,e8,m1,ta,ma
	vle8.v	v25,0(a6)
	add	a4,a4,a5
	vrgather.vv	v24,v26,v25
	vse8.v	v24,0(a0)
	bgtu	a3,a4,.L12
.L10:
	ld	a4, 8(sp)
	ld	a5, 0(a7)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L19
	ld	ra,24(sp)
	.cfi_remember_state
	.cfi_restore 1
	addi	sp,sp,32
	.cfi_def_cfa_offset 0
	jr	ra
.L19:
	.cfi_restore_state
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE16:
	.size	decode_table_rvv, .-decode_table_rvv
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC0:
	.string	"%s, pattern=%s, n=%zu, index=%zu, table index=%u: expected %d, got %d\n"
	.align	3
.LC1:
	.string	"%s, pattern=%s, n=%zu: decoded[%zu] was modified past the requested length\n"
	.text
	.align	1
	.type	check_case.constprop.0, @function
check_case.constprop.0:
.LFB20:
	.cfi_startproc
	addi	sp,sp,-352
	.cfi_def_cfa_offset 352
	sd	s0,336(sp)
	sd	s3,312(sp)
	.cfi_offset 8, -16
	.cfi_offset 19, -40
	addi	s0,sp,16
	la	s3,__stack_chk_guard
	sd	s1,328(sp)
	sd	s2,320(sp)
	sd	s5,296(sp)
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 21, -56
	mv	s1,a0
	mv	s5,a2
	ld	a5, 0(s3)
	sd	a5, 280(sp)
	li	a5, 0
	li	a2,259
	mv	s2,a1
	mv	a0,s0
	li	a1,85
	sd	s4,304(sp)
	sd	ra,344(sp)
	.cfi_offset 20, -48
	.cfi_offset 1, -8
	mv	s4,a3
	call	memset@plt
	ld	a5,8(s1)
	mv	a3,s4
	mv	a2,s0
	mv	a1,s5
	lla	a0,.LANCHOR0
	jalr	a5
	beq	s4,zero,.L21
	mv	a4,s0
	li	a6,0
	lla	a5,.LANCHOR0
	j	.L24
.L22:
	addi	a6,a6,1
	addi	a4,a4,1
	beq	s4,a6,.L36
.L24:
	add	a7,s5,a6
	lbu	a7,0(a7)
	lb	t3,0(a4)
	add	t1,a5,a7
	lb	t1,0(t1)
	beq	t1,t3,.L22
	la	a5,stderr
	ld	a0,0(a5)
	ld	a3,0(s1)
	mv	a5,s4
	sd	t3,8(sp)
	sd	t1,0(sp)
	mv	a4,s2
	lla	a2,.LC0
	li	a1,2
	call	__fprintf_chk@plt
.L23:
	li	a0,1
.L25:
	ld	a4, 280(sp)
	ld	a5, 0(s3)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L37
	ld	ra,344(sp)
	.cfi_remember_state
	.cfi_restore 1
	ld	s0,336(sp)
	.cfi_restore 8
	ld	s1,328(sp)
	.cfi_restore 9
	ld	s2,320(sp)
	.cfi_restore 18
	ld	s3,312(sp)
	.cfi_restore 19
	ld	s4,304(sp)
	.cfi_restore 20
	ld	s5,296(sp)
	.cfi_restore 21
	addi	sp,sp,352
	.cfi_def_cfa_offset 0
	jr	ra
.L36:
	.cfi_restore_state
	li	a5,259
	beq	s4,a5,.L29
.L21:
	add	a4,s0,s4
	mv	a6,s4
	li	a3,85
	li	a2,259
	j	.L27
.L26:
	addi	a6,a6,1
	addi	a4,a4,1
	beq	a6,a2,.L29
.L27:
	lbu	a5,0(a4)
	beq	a5,a3,.L26
	la	a5,stderr
	ld	a3,0(s1)
	ld	a0,0(a5)
	mv	a4,s2
	mv	a5,s4
	lla	a2,.LC1
	li	a1,2
	call	__fprintf_chk@plt
	j	.L23
.L29:
	li	a0,0
	j	.L25
.L37:
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE20:
	.size	check_case.constprop.0, .-check_case.constprop.0
	.section	.rodata.str1.8
	.align	3
.LC2:
	.string	"ascending"
	.align	3
.LC3:
	.string	"reversed"
	.align	3
.LC4:
	.string	"repeated"
	.align	3
.LC5:
	.string	"randomized"
	.align	3
.LC6:
	.string	"All scalar and RVV table-decoding checks passed"
	.section	.text.startup,"ax",@progbits
	.align	1
	.globl	main
	.type	main, @function
main:
.LFB19:
	.cfi_startproc
	addi	sp,sp,-1184
	.cfi_def_cfa_offset 1184
	li	a5,-935686144
	sd	s3,1144(sp)
	sd	s4,1136(sp)
	sd	s5,1128(sp)
	sd	s6,1120(sp)
	addi	a5,a5,485
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	addi	s3,sp,8
	addi	s4,sp,272
	addi	s5,sp,536
	addi	s6,sp,800
	la	a3,__stack_chk_guard
	sd	s0,1168(sp)
	sd	s1,1160(sp)
	sd	s2,1152(sp)
	sd	s7,1112(sp)
	sd	s8,1104(sp)
	sd	s9,1096(sp)
	sd	s10,1088(sp)
	sd	s11,1080(sp)
	sd	ra,1176(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 23, -72
	.cfi_offset 24, -80
	.cfi_offset 25, -88
	.cfi_offset 26, -96
	.cfi_offset 27, -104
	.cfi_offset 1, -8
	ld	a4, 0(a3)
	sd	a4, 1064(sp)
	li	a4, 0
	sw	a5,4(sp)
	mv	s11,s3
	mv	s10,s4
	mv	s9,s5
	mv	s8,s6
	li	s0,0
	addi	s7,sp,4
	li	s2,7
	li	s1,259
.L39:
	divu	a5,s0,s2
	not	a4,s0
	andi	a3,s0,15
	andi	a4,a4,15
	sb	a3,0(s11)
	sb	a4,0(s10)
	mv	a0,s7
	addi	s0,s0,1
	addi	s11,s11,1
	addi	s10,s10,1
	addi	s9,s9,1
	addi	s8,s8,1
	andi	a5,a5,15
	sb	a5,-1(s9)
	call	next_random
	andi	a0,a0,15
	sb	a0,-1(s8)
	bne	s0,s1,.L39
	lla	s1,.LANCHOR1
	lla	s11,.LANCHOR0+168
	lla	s7,.LC2
	lla	s8,.LC3
	lla	s9,.LC4
	lla	s10,.LC5
.L40:
	lla	s2,.LANCHOR0+24
	li	s0,0
	j	.L46
.L44:
	ld	s0,0(s2)
	addi	s2,s2,8
.L46:
	mv	a3,s0
	mv	a2,s3
	mv	a1,s7
	mv	a0,s1
	call	check_case.constprop.0
	bne	a0,zero,.L43
	mv	a3,s0
	mv	a2,s4
	mv	a1,s8
	mv	a0,s1
	call	check_case.constprop.0
	bne	a0,zero,.L43
	mv	a3,s0
	mv	a2,s5
	mv	a1,s9
	mv	a0,s1
	call	check_case.constprop.0
	bne	a0,zero,.L43
	mv	a3,s0
	mv	a2,s6
	mv	a1,s10
	mv	a0,s1
	call	check_case.constprop.0
	mv	s0,a0
	bne	a0,zero,.L43
	bne	s11,s2,.L44
	addi	s1,s1,16
	lla	a5,.LANCHOR1+32
	bne	s1,a5,.L40
	lla	a0,.LC6
	call	puts@plt
	j	.L42
.L43:
	li	s0,1
.L42:
	la	a5,__stack_chk_guard
	ld	a4, 1064(sp)
	ld	a5, 0(a5)
	xor	a5, a4, a5
	li	a4, 0
	bne	a5,zero,.L50
	ld	ra,1176(sp)
	.cfi_remember_state
	.cfi_restore 1
	mv	a0,s0
	ld	s0,1168(sp)
	.cfi_restore 8
	ld	s1,1160(sp)
	.cfi_restore 9
	ld	s2,1152(sp)
	.cfi_restore 18
	ld	s3,1144(sp)
	.cfi_restore 19
	ld	s4,1136(sp)
	.cfi_restore 20
	ld	s5,1128(sp)
	.cfi_restore 21
	ld	s6,1120(sp)
	.cfi_restore 22
	ld	s7,1112(sp)
	.cfi_restore 23
	ld	s8,1104(sp)
	.cfi_restore 24
	ld	s9,1096(sp)
	.cfi_restore 25
	ld	s10,1088(sp)
	.cfi_restore 26
	ld	s11,1080(sp)
	.cfi_restore 27
	addi	sp,sp,1184
	.cfi_def_cfa_offset 0
	jr	ra
.L50:
	.cfi_restore_state
	call	__stack_chk_fail@plt
	.cfi_endproc
.LFE19:
	.size	main, .-main
	.section	.rodata.str1.8
	.align	3
.LC7:
	.string	"scalar"
	.align	3
.LC8:
	.string	"RVV"
	.section	.rodata
	.align	3
	.set	.LANCHOR0,. + 0
	.type	values.0, @object
	.size	values.0, 16
values.0:
	.string	"\007\375\f\370"
	.ascii	"\005\377\017\360\004\371\t\364\002\373\013"
	.type	sizes.2, @object
	.size	sizes.2, 152
sizes.2:
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
	.dword	.LC7
	.dword	decode_table_scalar
	.dword	.LC8
	.dword	decode_table_rvv
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
