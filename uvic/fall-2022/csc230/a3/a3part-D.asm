;
; a3part-D.asm
;
; Part D of assignment #3
;
;
; Student name: Michael Jin
; Student ID: V00952626
; Date of completed work: 2022-Nov-22
;
; **********************************
; Code provided for Assignment #3
;
; Author: Mike Zastre (2022-Nov-05)
;
; This skeleton of an assembly-language program is provided to help you 
; begin with the programming tasks for A#3. As with A#2 and A#1, there are
; "DO NOT TOUCH" sections. You are *not* to modify the lines within these
; sections. The only exceptions are for specific changes announced on
; Brightspace or in written permission from the course instruction.
; *** Unapproved changes could result in incorrect code execution
; during assignment evaluation, along with an assignment grade of zero. ***
;


; =============================================
; ==== BEGINNING OF "DO NOT TOUCH" SECTION ====
; =============================================
;
; In this "DO NOT TOUCH" section are:
; 
; (1) assembler direction setting up the interrupt-vector table
;
; (2) "includes" for the LCD display
;
; (3) some definitions of constants that may be used later in
;     the program
;
; (4) code for initial setup of the Analog-to-Digital Converter
;     (in the same manner in which it was set up for Lab #4)
;
; (5) Code for setting up three timers (timers 1, 3, and 4).
;
; After all this initial code, your own solutions's code may start
;

.cseg
.org 0
	jmp reset

; Actual .org details for this an other interrupt vectors can be
; obtained from main ATmega2560 data sheet
;
.org 0x22
	jmp timer1

; This included for completeness. Because timer3 is used to
; drive updates of the LCD display, and because LCD routines
; *cannot* be called from within an interrupt handler, we
; will need to use a polling loop for timer3.
;
; .org 0x40
;	jmp timer3

.org 0x54
	jmp timer4

.include "m2560def.inc"
.include "lcd.asm"

.cseg
#define CLOCK 16.0e6
#define DELAY1 0.01
#define DELAY3 0.1
#define DELAY4 0.5

#define BUTTON_RIGHT_MASK 0b00000001	
#define BUTTON_UP_MASK    0b00000010
#define BUTTON_DOWN_MASK  0b00000100
#define BUTTON_LEFT_MASK  0b00001000

#define BUTTON_RIGHT_ADC  0x032
#define BUTTON_UP_ADC     0x0b0   ; was 0x0c3
#define BUTTON_DOWN_ADC   0x160   ; was 0x17c
#define BUTTON_LEFT_ADC   0x22b
#define BUTTON_SELECT_ADC 0x316

.equ PRESCALE_DIV=1024   ; w.r.t. clock, CS[2:0] = 0b101

; TIMER1 is a 16-bit timer. If the Output Compare value is
; larger than what can be stored in 16 bits, then either
; the PRESCALE needs to be larger, or the DELAY has to be
; shorter, or both.
.equ TOP1=int(0.5+(CLOCK/PRESCALE_DIV*DELAY1))
.if TOP1>65535
.error "TOP1 is out of range"
.endif

; TIMER3 is a 16-bit timer. If the Output Compare value is
; larger than what can be stored in 16 bits, then either
; the PRESCALE needs to be larger, or the DELAY has to be
; shorter, or both.
.equ TOP3=int(0.5+(CLOCK/PRESCALE_DIV*DELAY3))
.if TOP3>65535
.error "TOP3 is out of range"
.endif

; TIMER4 is a 16-bit timer. If the Output Compare value is
; larger than what can be stored in 16 bits, then either
; the PRESCALE needs to be larger, or the DELAY has to be
; shorter, or both.
.equ TOP4=int(0.5+(CLOCK/PRESCALE_DIV*DELAY4))
.if TOP4>65535
.error "TOP4 is out of range"
.endif

reset:
; ***************************************************
; **** BEGINNING OF FIRST "STUDENT CODE" SECTION ****
; ***************************************************

; Anything that needs initialization before interrupts
; start must be placed here.

; Initialize the LCD display.
	rcall lcd_init

; Since TEMP is already defined in LCDdefs.inc as R16, I define my own temporary register as R20 here.
.def my_temp = r20
; The second temp below is used solely for pushing arguments onto the stack.
.def s_temp = r22
; This is the counter intended for initialiation loops.
.def counter = r23

; Set up a stack for parameter passing and temporary storage.
	ldi my_temp, low(RAMEND)
	out SPL, my_temp
	ldi my_temp, high(RAMEND)
	out SPH, my_temp

; Note: ADCH:L is already mapped to 0x79:78 in m2560def.inc

; Reserve some registers for ADC data and boundary values.
.def DATAH = r1 ; Use R0-R16 to save upper register space since CP/CPC support all 32 registers.
.def DATAL = r0
.def BOUNDARY_H = r25
.def BOUNDARY_L = r24

; Initialize LAST_BUTTON_PRESSED with an impossible value.
	ldi my_temp, 0xff
	sts LAST_BUTTON_PRESSED, my_temp

; Initialize every byte of TOP_LINE_CONTENT with a space character.
	ldi my_temp, 0x20 ; Space character to be loaded into each offset location of TOP_LINE_CONTENT.
	clr counter ; Counter & offset.
TOP_LINE_CONTENT_init_loop:
	cpi counter, 16
	brsh TOP_LINE_CONTENT_init_done
	ldi YL, LOW(TOP_LINE_CONTENT)
	ldi YH, HIGH(TOP_LINE_CONTENT)
	add YL, counter
	push counter ; Push counter's value onto the stack.
	clr counter ; This line and the previous don't affect the Carry Flag.
	adc YH, counter ; Effectively add offset's value to the address of TOP_LINE_CONTENT and store the result in Y.
	pop counter ; Restore counter's value.
	st Y, my_temp ; Use ST to store a space character to the offset location indirectly using the Y pointer.
	inc counter
	rjmp TOP_LINE_CONTENT_init_loop
TOP_LINE_CONTENT_init_done:

; Initialize every byte of CURRENT_CHARSET_INDEX with 0.
	clr my_temp
	clr counter
CURRENT_CHARSET_INDEX_init_loop:
	cpi counter, 16
	brsh CURRENT_CHARSET_INDEX_init_done
	ldi YL, LOW(CURRENT_CHARSET_INDEX)
	ldi YH, HIGH(CURRENT_CHARSET_INDEX)
	add YL, counter
	push counter ; Ditto.
	clr counter ; Ditto.
	adc YH, counter ; Effectively add offset's value to the address of CURRENT_CHARSET_INDEX and store the result in Y.
	pop counter ; Ditto.
	st Y, my_temp ; Use ST to store a zero to the offset location indirectly using the Y pointer.
	inc counter
	rjmp CURRENT_CHARSET_INDEX_init_loop
CURRENT_CHARSET_INDEX_init_done:

; Initialize CURRENT_CHAR_INDEX with 0.
	clr my_temp
	sts CURRENT_CHAR_INDEX, my_temp

; ***************************************************
; ******* END OF FIRST "STUDENT CODE" SECTION *******
; ***************************************************

; =============================================
; ====  START OF "DO NOT TOUCH" SECTION    ====
; =============================================

	; initialize the ADC converter (which is needed
	; to read buttons on shield). Note that we'll
	; use the interrupt handler for timer 1 to
	; read the buttons (i.e., every 10 ms)
	;
	ldi temp, (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0)
	sts ADCSRA, temp
	ldi temp, (1 << REFS0)
	sts ADMUX, r16

	; Timer 1 is for sampling the buttons at 10 ms intervals.
	; We will use an interrupt handler for this timer.
	ldi r17, high(TOP1)
	ldi r16, low(TOP1)
	sts OCR1AH, r17
	sts OCR1AL, r16
	clr r16
	sts TCCR1A, r16
	ldi r16, (1 << WGM12) | (1 << CS12) | (1 << CS10)
	sts TCCR1B, r16
	ldi r16, (1 << OCIE1A)
	sts TIMSK1, r16

	; Timer 3 is for updating the LCD display. We are
	; *not* able to call LCD routines from within an 
	; interrupt handler, so this timer must be used
	; in a polling loop.
	ldi r17, high(TOP3)
	ldi r16, low(TOP3)
	sts OCR3AH, r17
	sts OCR3AL, r16
	clr r16
	sts TCCR3A, r16
	ldi r16, (1 << WGM32) | (1 << CS32) | (1 << CS30)
	sts TCCR3B, r16
	; Notice that the code for enabling the Timer 3
	; interrupt is missing at this point.

	; Timer 4 is for updating the contents to be displayed
	; on the top line of the LCD.
	ldi r17, high(TOP4)
	ldi r16, low(TOP4)
	sts OCR4AH, r17
	sts OCR4AL, r16
	clr r16
	sts TCCR4A, r16
	ldi r16, (1 << WGM42) | (1 << CS42) | (1 << CS40)
	sts TCCR4B, r16
	ldi r16, (1 << OCIE4A)
	sts TIMSK4, r16

	sei

; =============================================
; ====    END OF "DO NOT TOUCH" SECTION    ====
; =============================================

; ****************************************************
; **** BEGINNING OF SECOND "STUDENT CODE" SECTION ****
; ****************************************************

start:

; This is the LCD update (polling) loop.
polling_loop:
	in my_temp, TIFR3
	sbrs my_temp, OCF3A ; If Interrupt Flag is set, then
	rjmp TOP3_not_yet_reached ; skip this line.

	; If execution arrives here, TOP3 is reached, and 
	; we reset the Interrupt Flag.
	ldi my_temp, 1<<OCF3A ; Clear bit 1 in TIFR3 by writing logical one to its bit position.
	out TIFR3, my_temp

	; Go to the specified location (Row 1 Col 15).
	ldi my_temp, 1
	push my_temp
	ldi my_temp, 15
	push my_temp
	rcall lcd_gotoxy
	pop my_temp
	pop my_temp

	; Put the correct character based on whether BUTTON_IS_PRESSED is set.
	lds my_temp, BUTTON_IS_PRESSED ; Load 0 or 1 to my_temp directly from SRAM address BUTTON_IS_PRESSED.
	cpi my_temp, 0 ; If button is not NOT pressed (is indeed pressed), then
	brne skip_hyphen ; skip the next 4 lines.
		ldi s_temp, '-'
		push s_temp
		rcall lcd_putchar
		pop s_temp
	skip_hyphen:
	cpi my_temp, 1 ; If button is not pressed, then
	brne skip_asterisk ; skip the next 4 lines.
	; The code section from the next instruction to "; Now continue normally." repeats lcd_gotoxy(1, 15) and could *perhaps* be avoided by changing the control flow.
	; However the program runs as required and I'm lazy so I'll leave my shoddy work as it is.
		; Whenever a button is pressed, clear the area for L/D/U/R before we continue on to put a new one.
		clr counter
		clear_LDUR_loop:
		cpi counter, 4
		brsh clear_LDUR_loop_done
			ldi my_temp, 1
			push my_temp
			mov my_temp, counter
			push my_temp
			rcall lcd_gotoxy
			pop my_temp
			pop my_temp
			
			ldi my_temp, 0x20
			push my_temp
			rcall lcd_putchar
			pop my_temp

			inc counter
			rjmp clear_LDUR_loop
		clear_LDUR_loop_done:
		; Then return cursor to Row 1 Col 15 so I can continue to put the "button is pressed" indicator (*).
		ldi my_temp, 1
		push my_temp
		ldi my_temp, 15
		push my_temp
		rcall lcd_gotoxy
		pop my_temp
		pop my_temp
		; Now continue normally.
		ldi s_temp, '*'
		push s_temp
		rcall lcd_putchar
		pop s_temp
	skip_asterisk:

	; Decide where to put the character stored in LAST_BUTTON_PRESSED.
	ldi my_temp, 1 ; Row 1.
	push my_temp
	lds my_temp, LAST_BUTTON_PRESSED ; The following section decides which column.
	cpi my_temp, 'L'
	brne try_D
		ldi s_temp, 0
		push s_temp
		rjmp ready_for_gotoxy ; Break out from switch comparison.
	try_D:
	cpi my_temp, 'D'
	brne try_U
		ldi s_temp, 1
		push s_temp
		rjmp ready_for_gotoxy ; Break out from switch comparison.
	try_U:
	cpi my_temp, 'U'
	brne try_R
		ldi s_temp, 2
		push s_temp
		rjmp ready_for_gotoxy
	try_R:
	cpi my_temp, 'R'
	brne jump_point_polling_loop ; If all comparisons failed, then no button has been pressed yet.
		ldi s_temp, 3
		push s_temp

	; Go to the correct location (Row 1, Col y).
	ready_for_gotoxy:
		rcall lcd_gotoxy
		pop s_temp
		pop my_temp

	; Put the character stored in LAST_BUTTON_PRESSED at the correct location.
	lds my_temp, LAST_BUTTON_PRESSED
	push my_temp
	rcall lcd_putchar
	pop my_temp

	; The code section below is added in Part-C and D.
	; The current byte of TOP_LINE_CONTENT is put at Row 0 Col CURRENT_CHAR_INDEX.
	; PATCH SECTION 2022-11-22. 
	; This section checks whether the last button pressed was DOWN or UP. If it wasn't, leave the top row in its initialized state with space characters.
	lds my_temp, LAST_BUTTON_PRESSED
	cpi my_temp, 'D' ; Only when the last button pressed was D or U does the top row get updated.
	breq ready_for_top_row_update
	cpi my_temp, 'U'
	breq ready_for_top_row_update
	rjmp jump_point_polling_loop ; If execution reaches here, then the last button pressed was not D or U (it was R or L), and the top row does NOT update.
	ready_for_top_row_update:
	; END OF PATCH SECTION 2022-11-22.
	ldi my_temp, 0 ; Go to the correct location (0, CURRENT_CHAR_INDEX).
	push my_temp
	lds my_temp, CURRENT_CHAR_INDEX
	push my_temp
	rcall lcd_gotoxy
	pop my_temp
	pop my_temp

	ld my_temp, X ; Put the corresponding character. Note that X is the already offset position of TOP_LINE_CONTENT
	push my_temp
	rcall lcd_putchar
	pop my_temp
	; End of code section added in Part-C and D.

	jump_point_polling_loop:
	TOP3_not_yet_reached:
	rjmp polling_loop

stop: ; Execution should never reach here.
	rjmp stop


timer1:
	; Start Analog to Digital Conversion by setting the Start Conversion (SC) bit to 1
	lds my_temp, ADCSRA
	ori my_temp, 0b01000000 ; Toggle bit 6 (the SC bit) on and preserve all other bits.
	sts ADCSRA, my_temp
	; Converting ...

	; Wait for the conversion to be done.
	wait_conversion:
	lds my_temp, ADCSRA
	andi my_temp, 0b01000000 ; Retrieve bit 6 (the SC bit). When the conversion is done, the SC bit will be 0 -> the masking result will be 0 -> the zero flag will be set.
	brne wait_conversion ; While the zero flag is not yet set, continue waiting.

	; When execution reaches here, conversion is done.
	; Read the ADC 10-bit value and store it in DATAH:L.
	lds DATAL, ADCL
	lds DATAH, ADCH

	; Store the correct value (0/1) and character (L/D/U/R) to BUTTON_IS_PRESSED and LAST_BUTTON_PRESSED, respectively. 
	not_pressed:
	ldi BOUNDARY_H, 0x03 ; 0x384 = 900. Anything above 900 means button is NOT pressed.
	ldi BOUNDARY_L, 0x84
	cp DATAL, BOUNDARY_L
	cpc DATAH, BOUNDARY_H ; Sanity check passed for three special cases (Check GoodNotes Program Design.)
	brlo is_pressed ; If DATA is less than our threshold, then skip the next 3 lines.
		clr my_temp ; This is where DATA >= 900, i.e. NO button is pressed.
		sts BUTTON_IS_PRESSED, my_temp
		rjmp done_timer1
	is_pressed:
		ldi my_temp, 1 ; This is where DATA < 900, i.e. some button is pressed.
		sts BUTTON_IS_PRESSED, my_temp
		; Store the correct character to LAST_BUTTON_PRESSED according to the corresponding ADC interval.
		select:
		ldi BOUNDARY_H, 0x02 ; 0x22b = 555.
		ldi BOUNDARY_L, 0x2b
		cp DATAL, BOUNDARY_L
		cpc DATAH, BOUNDARY_H
		brlo left ; If DATA is lower than the lower bound of "select", then jump to "left".
			nop ; Values between 555 and 900 are ignored.
			rjmp done_timer1
		left:
		ldi BOUNDARY_H, 0x01 ; 0x160 = 352.
		ldi BOUNDARY_L, 0x60
		cp DATAL, BOUNDARY_L
		cpc DATAH, BOUNDARY_H
		brlo down ; If DATA is lower than the lower bound of "left", then jump to "down".
			ldi my_temp, 'L'
			sts LAST_BUTTON_PRESSED, my_temp
			rjmp done_timer1
		down:
		ldi BOUNDARY_H, 0 ; 0xb0 = 176
		ldi BOUNDARY_L, 0xb0
		cp DATAL, BOUNDARY_L
		cpc DATAH, BOUNDARY_H
		brlo up ; If DATA is lower than the lower bound of "down", then jump to "up".
			ldi my_temp, 'D'
			sts LAST_BUTTON_PRESSED, my_temp
			rjmp done_timer1
		up:
		ldi BOUNDARY_H, 0 ; 0x32 = 50
		ldi BOUNDARY_L, 0x32
		cp DATAL, BOUNDARY_L
		cpc DATAH, BOUNDARY_H
		brlo right ; If DATA is lower than the lower bound of "up", then jump to "right".
			ldi my_temp, 'U'
			sts LAST_BUTTON_PRESSED, my_temp
			rjmp done_timer1
		right:
			ldi my_temp, 'R'
			sts LAST_BUTTON_PRESSED, my_temp

	done_timer1:

	reti

; timer3:
;
; Note: There is no "timer3" interrupt handler as you must use
; timer3 in a polling style (i.e. it is used to drive the refreshing
; of the LCD display, but LCD functions cannot be called/used from
; within an interrupt handler).


timer4:
	lds my_temp, BUTTON_IS_PRESSED
	cpi my_temp, 1 ; If button is not pressed at all,
	brne jump_point_timer4 ; then skip everything below.
	; Note that I had to branch to an intermediate "jump point" because label done_timer4 is out of reach for brne.

		lds my_temp, LAST_BUTTON_PRESSED
		cpi my_temp, 'U'
		breq is_U
		cpi my_temp, 'D'
		breq is_D
		cpi my_temp, 'R'
		breq is_R
		cpi my_temp, 'L'
		breq is_L
		jump_point_timer4:
		rjmp done_timer4 ; If execution reaches here, the button pressed is none of UP, DOWN, RIGHT, or LEFT.
		is_U: ; If character is U, then increment the correct byte of Character Set Index.
			ldi YL, LOW(CURRENT_CHARSET_INDEX)
			ldi YH, HIGH(CURRENT_CHARSET_INDEX)
			lds my_temp, CURRENT_CHAR_INDEX
			add YL, my_temp
			clr my_temp
			adc YH, my_temp ; Now the offset location of CURRENT_CHARSET_INDEX is stored in Y.
			ld my_temp, Y ; Load the value at the offset location into my_temp.
			inc my_temp
			st Y, my_temp ; Increase the value at the offset location by 1.
			rjmp load_TOP_LINE_CONTENT ; This is equivalent to a break statement.
		is_D: ; If character is D, then decrement the correct byte of Character Set Index.
			ldi YL, LOW(CURRENT_CHARSET_INDEX)
			ldi YH, HIGH(CURRENT_CHARSET_INDEX)
			lds my_temp, CURRENT_CHAR_INDEX
			add YL, my_temp
			clr my_temp
			adc YH, my_temp ; Now the offset location of CURRENT_CHARSET_INDEX is stored in Y.
			ld my_temp, Y ; Load the value at the offset location into my_temp.
			dec my_temp
			; Negative index (out of string's lower bound) check.
			cpi my_temp, 0
			brge neg_index_check_passed ; If index is negative, then 
				clr my_temp ; reassign 0 to index (so that the first character continues to be displayed.)
			neg_index_check_passed:
			; End of negative index check. Resume normal control flow.
			st Y, my_temp ; Decrease the value at the offset location by 1.
			rjmp load_TOP_LINE_CONTENT
		is_R:
			lds my_temp, CURRENT_CHAR_INDEX
			inc my_temp
			sts CURRENT_CHAR_INDEX, my_temp
			rjmp load_TOP_LINE_CONTENT
		is_L:
			lds my_temp, CURRENT_CHAR_INDEX
			dec my_temp
			sts CURRENT_CHAR_INDEX, my_temp
			rjmp load_TOP_LINE_CONTENT

		load_TOP_LINE_CONTENT: ; Load the character indicated by the Character Set Index into TOP_LINE_CONTENT.
		; Load the location of AVAILABLE_CHARSET into Z.
		ldi ZL, LOW(AVAILABLE_CHARSET << 1) ; Convert Character Set's word address to byte address, and 
		ldi ZH, HIGH(AVAILABLE_CHARSET << 1) ; load the 16-bit byte address to the Z pointer.
		; Load the offset location of CURRENT_CHARSET_INDEX into Y.
		ldi YL, LOW(CURRENT_CHARSET_INDEX)
		ldi YH, HIGH(CURRENT_CHARSET_INDEX) ; Now the location of CURRENT_CHARSET_INDEX is stored in Y.
		lds my_temp, CURRENT_CHAR_INDEX ; Load the value of offset into my_temp.
		add YL, my_temp
		clr my_temp
		adc YH, my_temp ; Now the offset location of CURRENT_CHARSET_INDEX is stored in Y.

		ld my_temp, Y ; Load the charset index value at the offset location into my_temp.

		add ZL, my_temp
		clr my_temp
		adc ZH, my_temp ; Now the offset location of AVAILABLE_CHARSET is stored in Z.

		lpm my_temp, Z ; Extract the character at said location.
		; Null (out of string's higher bound) check:
		cpi my_temp, 0 ; Check if the extracted character is null (end of string).
		brne null_check_passed ; If the end of the character string is reached, then 
			clr my_temp ; reassign 0 to index (so instead of an invalid character, the first character will be displayed.)
			st Y, my_temp ; Zero is stored at the offset location of CURRENT_CHARSET_INDEX.
			rjmp load_TOP_LINE_CONTENT
		null_check_passed:
		; End of null check. Resume normal control flow.
		; Store the extracted character to the offset location of TOP_LINE_CONTENT.
		lds s_temp, CURRENT_CHAR_INDEX ; Load the value of offset into s_temp (necessary abuse of s_temp since my_temp contains our extracted character.)
		ldi XL, LOW(TOP_LINE_CONTENT)
		ldi XH, HIGH(TOP_LINE_CONTENT)
		add XL, s_temp
		clr s_temp
		adc XH, s_temp ; Now the offset location of TOP_LINE_CONTENT is stored in X.
		st X, my_temp ; Finally, the extracted character is stored at the offset location of TOP_LINE_CONTENT.

	done_timer4:
	reti


; ****************************************************
; ******* END OF SECOND "STUDENT CODE" SECTION *******
; ****************************************************


; =============================================
; ==== BEGINNING OF "DO NOT TOUCH" SECTION ====
; =============================================

; r17:r16 -- word 1
; r19:r18 -- word 2
; word 1 < word 2? return -1 in r25
; word 1 > word 2? return 1 in r25
; word 1 == word 2? return 0 in r25
;
compare_words:
	; if high bytes are different, look at lower bytes
	cp r17, r19
	breq compare_words_lower_byte

	; since high bytes are different, use these to
	; determine result
	;
	; if C is set from previous cp, it means r17 < r19
	; 
	; preload r25 with 1 with the assume r17 > r19
	ldi r25, 1
	brcs compare_words_is_less_than
	rjmp compare_words_exit

compare_words_is_less_than:
	ldi r25, -1
	rjmp compare_words_exit

compare_words_lower_byte:
	clr r25
	cp r16, r18
	breq compare_words_exit

	ldi r25, 1
	brcs compare_words_is_less_than  ; re-use what we already wrote...

compare_words_exit:
	ret

.cseg
AVAILABLE_CHARSET: .db "0123456789abcdef_", 0


.dseg

BUTTON_IS_PRESSED: .byte 1			; updated by timer1 interrupt, used by LCD update loop
LAST_BUTTON_PRESSED: .byte 1        ; updated by timer1 interrupt, used by LCD update loop

TOP_LINE_CONTENT: .byte 16			; updated by timer4 interrupt, used by LCD update loop
CURRENT_CHARSET_INDEX: .byte 16		; updated by timer4 interrupt, used by LCD update loop
CURRENT_CHAR_INDEX: .byte 1			; ; updated by timer4 interrupt, used by LCD update loop


; =============================================
; ======= END OF "DO NOT TOUCH" SECTION =======
; =============================================


; ***************************************************
; **** BEGINNING OF THIRD "STUDENT CODE" SECTION ****
; ***************************************************

.dseg

; If you should need additional memory for storage of state,
; then place it within the section. However, the items here
; must not be simply a way to replace or ignore the memory
; locations provided up above.


; ***************************************************
; ******* END OF THIRD "STUDENT CODE" SECTION *******
; ***************************************************
