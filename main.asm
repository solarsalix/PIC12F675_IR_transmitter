; Simple IR transmitter program on ASM

	LIST		P=PIC12F675
	#include	P12F675.INC
	;__CONFIG	0x3FB1
	__CONFIG	_XT_OSC & _WDT_OFF & _MCLRE_ON & _PWRTE_OFF & _BODEN_OFF & _CP_OFF & _CPD_OFF

				org		0x0000			; program start
				goto	F_MAIN			; go to main function

				org		0x0004			; interrupts vector
F_INT_START:
				; saving context
				movwf	var_tmp_w
				swapf	STATUS,w
				movwf	var_tmp_st
F_INT_GPINT:	
				; some interrupt actions
				comf	var_int,1		; reverse INT flag:
				bsf		GPIO,0x00		; write to GP0 for reset GPIF
				bsf		STATUS,0x05		; go to Bank1
				bcf		INTCON,GPIF 	; reset GPIF flag
				bcf		STATUS,0x05		; go to Bank0
				
F_INT_EXIT:
				swapf	var_tmp_st,w
				movwf	STATUS
				swapf	var_tmp_w,f
				swapf	var_tmp_w,w
				retfie					; back to main program
				

F_MAIN:			; FUNC_MAIN
; Declaring variables
var_tmp_w		equ		0x0020
var_tmp_st		equ		0x0021
var_delay		equ		0x0022
var_pwm			equ		0x0023
var_pause		equ		0x0024
var_ir_len		equ		0x0025
var_ir_bit		equ		0x0026
var_ir_cmd		equ		0x0027
var_ir_cnt		equ		0x0028
var_btn_pause	equ		0x0029
var_int			equ		0x002A
var_dbnc_cnt	equ		0x002B


				bsf		STATUS,0x05	; go to Bank1
				bsf		INTCON,GPIE	; enable internal interrupt
				bsf		INTCON,GIE	; enable global interrupts
				movlw	0x06		;
				movwf	TRISIO		; TRISIO = 0b00000110
				movwf	IOCB		; allow GP1, GP2 interrupts
				clrf	ANSEL		; disable analog outputs
				bcf		STATUS,0x05	; go to bank0
				movlw	0x07		;
				movwf	CMCON		; disable comparator
				clrf	var_int		; clear interrupt flag

;****************************************************************
F_CYCLE:								; main cycle start
;***************						;
				bcf		GPIO,GP0		;
				btfss	var_int,0		; check INT flag for 1
				sleep					; if 0 - go to sleep
				call	F_CHECK_BTNS	; if 1 - call function
;***************						;
				goto	F_CYCLE			; return to main cycle start
;****************************************************************

; Buttons functions
F_CHECK_BTNS:
				btfss	GPIO,GP1		; if GP1 is 0 - next line
				call	F_BTN_01		; else jump over
				btfss	GPIO,GP2		; if GP2 is 0 - next line
				call	F_BTN_02		; else jump over
				movlw	.85				;
				movwf	var_dbnc_cnt	; reset debounce counter
				bcf		GPIO,GP0		; disable LED
				call	DELAY_100ms		; 
				return;

; Button 1 pressed
F_BTN_01:
				clrf	var_dbnc_cnt
				movlw	.85				; debounce counter start value
				movwf	var_dbnc_cnt	;
debounce01		decfsz	var_dbnc_cnt,1	; counter--, if != 0
				goto 	debounce01		; repeat
				call	F_IR_01		    ; else - send IR pack
				call	DELAY_100ms		;
				return

; Button 2 pressed
F_BTN_02:
				movlw	.85				; debounce counter start value
				movwf	var_dbnc_cnt	;
debounce02		decfsz	var_dbnc_cnt,1	; counter--, if != 0
				goto 	debounce02		; repeat
				call	F_IR_02		    ; else - send IR pack
				call	DELAY_100ms		;
				return

; IR functions
; F_IR_01 - send "070701FE" (addr01 > addr02 > ~data > data)
F_IR_01:
				call	F_IR_start	; send IR start signal
				movlw	0x07		; put value to W
				call	F_IR_BYTE
				movlw	0x07		; put value to W
				call	F_IR_BYTE
				movlw	0x01		; put value to W
				call	F_IR_BYTE
				movlw	0xFE		; put value to W
				call	F_IR_BYTE
				call	PWM_560us
				return

; F_IR_02 - send "070702FD"
F_IR_02:
				call	F_IR_start	; send IR start signal
				movlw	0x07		; put value to W
				call	F_IR_BYTE
				movlw	0x07		; put value to W
				call	F_IR_BYTE
				movlw	0x02		; put value to W
				call	F_IR_BYTE
				movlw	0xFD		; put value to W
				call	F_IR_BYTE
				call	PWM_560us
				return

; F_IR_start - send start signal (~4500us PWM and ~4500us pause).
F_IR_start:
				movlw	.8          ; set to .15 for ~9000us PWM (classic NEC)
				movwf	var_ir_len
ir_strt_imp	    call	PWM_560us
				decfsz	var_ir_len,1
				goto 	ir_strt_imp
				movlw	.8          ; ~4500us pause
				movwf	var_ir_len
ir_strt_pau	    call	DELAY_560us
				call	F_DELAY_15us
				call	F_DELAY_15us
				nop
				decfsz	var_ir_len,1
				goto 	ir_strt_pau
				return

; F_IR_byte - send one byte from current W register
F_IR_BYTE:
				clrf	var_ir_cnt		; set bit counter to 0
				movwf	var_ir_cmd		; send current W value to var_ir_cmd				
ir_send		    call	PWM_560us		;
				btfsc	var_ir_cmd,0	; if var_ir_cmd<0>==1 - go to the next line
				call	DELAY_1690us	; else - jump over
				btfss	var_ir_cmd,0	; if var_ir_cmd<0>==0 - go to the next line
				call	DELAY_560us		; else - jump over
				incf	var_ir_cnt,1	; counter++
				rrf		var_ir_cmd,1	; shift var_ir_cmd to the right, get next bit
				btfss	var_ir_cnt,3	; if counter still less than 7 (0b00001000),
				goto	ir_send		    ; repeat function, else - jump over this line
				return                  ; and exit

; PWM and delay functions
; "short" short delay (first in PWM (peak) or delay)
F_DELAY_7us:
				nop
				nop
				nop
				return

; "long" short delay (second in PWM (pause) or delay)
F_DELAY_15us:
				movlw	.3
				movwf	var_delay
delay_count		decfsz	var_delay,1
				goto	delay_count
				return

F_DELAY_13us:
				movlw	.1
				movwf	var_delay
delay13_count	decfsz	var_delay,1
				goto	delay13_count
				nop
				return

; PWM ~560us
; in IR pack it means "0"
PWM_560us:
				movlw	.22
				movwf	var_pwm
pwm_count		bsf		GPIO,GP0
				call	F_DELAY_13us
				nop
				nop
				nop
				bcf		GPIO,GP0
				call	F_DELAY_13us
				decfsz	var_pwm,1
				goto	pwm_count
				return

; delay length a bit lesser than PWM lenght,
; because delay using for calculation next PWM bit
; and this calculation get some CPU time
DELAY_560us:
				movlw	.21
				movwf	var_pause
pause_count		bcf		GPIO,GP0
				call	F_DELAY_7us
				call	F_DELAY_15us
				decfsz	var_pause,1
				goto	pause_count
				nop
				nop
				nop
				return

DELAY_1690us:
				movlw	.61
				movwf	var_pause
pause_count2	bcf		GPIO,GP0
				call	F_DELAY_7us
				call	F_DELAY_15us
				decfsz	var_pause,1
				goto	pause_count2
				return

; delay 100ms after sending IR pack
DELAY_100ms:
				movlw	.200		; wait ~100ms after pack
				movwf	var_ir_len
pack_pause		call	DELAY_560us
				decfsz	var_ir_len,1
				goto 	pack_pause
				return

DELAY_10ms:
				movlw	.20			; wait ~10ms after pack
				movwf	var_ir_len
debounce10		call	DELAY_560us
				decfsz	var_ir_len,1
				goto 	debounce10
				return

				end					; program end