;---------------------------------------------------------------------------
;
; PS/2 repeater
;
; Firmware for ATMega8-16PI microcontroller
; Copyright by Maksym Veremeyenko, 2005
;
; Changelog:
;	2005-12-17:
;		*Optimization of code
;		*Additional 'nop' between OUT IN operations
;		*Crystal is 16MHz now
;	2005-12-14:
;		*Comment out monitoring LED control
;		*Additional 'nop' command for I/O LATCH sync
;	2005-12-11:
;		*New IO scheme PUD, HiZ<->OutputLow(Sink)
;		*STATE_LED delay.
;		*Loop occuring fixed?
;	2005-12-10:
;		*Monitoring of RS_OUT added
;		*Minor fixes
;	2005-12-07:
;		*Draft version.
;
;
; Notes:
;
;	Fuse bits values (See page 220)
;		CKSEL0	=	1	(See page 26)
;		SUT0	=	1
;		SUT1	=	1
;
;		CKOPT	=	0	(See page 25)
;		CKSEL1	=	1
;		CKSEL2	=	1
;		CKSEL3	=	1
;
;		BOOTRST	=	1	(See page 45)
;		IVSEL	=	0
;
;
;	Port direction
;		0 - in
;		1 - out
;		00001111 - |in|in|in|in|out|out|out|out|
;
;	Port B:						XXXX1111
;		PB0	OUT	RS_OUT[0]
;		PB1	OUT	RS_OUT[1]
;		PB2	OUT	RS_OUT[2]
;		PB3	OUT	RS_OUT[3]
;
;	Port C:						XX111111
;		PC0	OUT	PS2_OUT[0]
;		PC1	OUT	PS2_OUT[1]
;		PC2	OUT	PS2_OUT[2]
;		PC3	OUT	PS2_OUT[3]
;		PC4	OUT	DIAG[0]
;		PC5	OUT	DIAG[1]
;
;	Port D:						11110000
;		PD0	IN	RS_IN[0]
;		PD1	IN	RS_IN[1]
;		PD2	IN	RS_IN[2]
;		PD3	IN	RS_IN[3]
;		PD4	OUT	STATE[0]
;		PD5	OUT	STATE[1]
;		PD6	OUT	STATE[2]
;		PD7	OUT	STATE[3]
;
;

.nolist
.include "m8def.inc"		;chip definition
.list
.listmac


; inputs/outputs
.equ	PORT_B_DIRECTION	= 0x0F		; 00001111
.equ	PORT_C_DIRECTION	= 0xFF		; 11111111
.equ	PORT_D_DIRECTION	= 0xF0		; 11110000

; ticks counters
.equ	TICK_STOP_VALUE		= 0x02
.equ	TICK_COMP_VALUE		= 0xFF

; reg used
.def	temp				= R16		; temporarity register
.def	PS2_IN				= R17
.def	PS2_OUT				= R18
.def	RS_IN				= R19
.def	RS_OUT				= R20
.def	PS2_OUT_CURR		= R21
.def	RS_OUT_CURR			= R22
.def	CONST_0xFF			= R1
.def	CONST_0xF0			= R2
.def	CONST_0x0F			= R3
.def	STATE_LED			= R23
.def	TICK_COMP			= R4
.def	TICK_STOP			= R5
.def	TICK_0				= R6
.def	TICK_1				= R7
.def	TICK_2				= R8

;---------------------------------------------------------------------------
;
; INTERRUPT VECTORS TABLE
;
;---------------------------------------------------------------------------
.cseg
.org	0
	rjmp	main			; RESET - main proc
	rjmp	int_ignore		; IRQ0 - ignore
	rjmp	int_ignore		; TIMER - state machine proc handler
	rjmp	int_ignore		; ignore

;---------------------------------------------------------------------------
;
; ignore interrupts
;
;---------------------------------------------------------------------------

.org	1024

int_ignore:
	reti


;---------------------------------------------------------------------------
;
; main proc
;
;---------------------------------------------------------------------------
main:
	; init stack poiner
	ldi	r16,high(RAMEND) ;High byte only required if 
	out	SPH,r16	         ;RAM is bigger than 256 Bytes
	ldi	r16,low(RAMEND)	 
	out	SPL,r16

	; prepare for tick counters
	clr	TICK_1
	clr	TICK_2
	clr	TICK_0
	ldi	temp,	TICK_STOP_VALUE
	mov	TICK_STOP, temp	
	ldi	temp,	TICK_COMP_VALUE
	mov	TICK_COMP, temp

	; init B,C,D ports direction
	ldi	temp, PORT_B_DIRECTION
	out	DDRB, temp
	ldi	temp, PORT_C_DIRECTION
	out	DDRC, temp
	ldi	temp, PORT_D_DIRECTION
	out	DDRD, temp

	; turn off pull-up resistors
;	in	temp,	SFIOR
;	sbr	temp,	1<<PUD
;	out	SFIOR,	temp

	; setup default port values
	ldi	temp, 0xFF
	out	PORTD, temp

	; setup initials values of registers
	ldi	temp,	0xFF
	mov	CONST_0xFF,	temp

	ldi	temp,	0x0F
	mov	CONST_0x0F,	temp

	ldi	temp,	0xF0
	mov	CONST_0xF0,	temp

	mov	PS2_OUT, CONST_0xFF
	mov	RS_OUT, CONST_0xFF


;mov	temp, CONST_0xFF
;out	PORTC, temp
;out	DDRC, temp
;_deb:
;in	temp, PINC
;eor	temp, CONST_0xFF
;swap temp
;out	PORTD, temp
;rjmp	_deb

	clr temp
	out	DDRC, temp
	out	PORTC, temp

_l1:
	; output data
	mov	temp, PS2_OUT
	eor temp, CONST_0xFF
	out	PORTB, RS_OUT
;#	out	PORTC, PS2_OUT
	out	DDRC, temp

	; save prev state
;	mov RS_OUT_CURR, RS_OUT
;	mov PS2_OUT_CURR, PS2_OUT

	; read data from port
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	in	RS_IN, PIND
	in	PS2_IN, PINC

	; calc data
;	RS_OUT = !(RS_IN*PS2_OUT) | PS2_IN
	mov	RS_OUT, RS_IN
	and	RS_OUT,	PS2_OUT
	eor	RS_OUT, CONST_0xFF
	or	RS_OUT, PS2_IN
	or	RS_OUT, CONST_0xF0			; mask upper bits

;	PS2_OUT = RS_IN
	mov	PS2_OUT, RS_IN
	or	PS2_OUT, CONST_0xF0			; mask upper bits

	; setup signalization
;	and	STATE_LED, RS_OUT	; signalization is the same RS_OUT bits
;	and	STATE_LED, PS2_OUT	; signalization is the same PS2_OUT bits
;	and	STATE_LED, PS2_IN	; signalization is the same PS2_IN bits
;	rcall _leds

	; setup diag leds
;	sbr PS2_OUT, (1<<4)
	cbr PS2_OUT, (1<<5)

	; continue loop
	rjmp _l1

_leds:
	inc	TICK_0
	breq __inc_tick_1
	ret
__inc_tick_1:
	inc	TICK_1
	breq __inc_tick_2
	ret
__inc_tick_2:
	inc	TICK_2
	cp	TICK_2,	TICK_STOP
	breq __leds
	ret
__leds:
	clr	TICK_2

	swap STATE_LED
	or	STATE_LED, CONST_0x0F			; mask upper bits
	out	PORTD, STATE_LED
	mov	STATE_LED, CONST_0xFF
	ret

