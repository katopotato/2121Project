; PIN CONFIG:
; Keypad	R0-C3 -> PC1-PC7
; LCD		D0-D7 -> PD0-PD7
;			BE-RS -> PA0-PA3
; Motor		Mot   -> PB4
; Detector  OpD   -> PE5
; Emitter	OpE   -> PB2

;############################# includes #####################################
.include "m64def.inc"

;############################# definitions #####################################
.def temp =r16
.def row =r17
.def col =r18
.def mask =r19
.def temp2 =r20
.def digit = r21
.def data = r22
.def temp3 = r23
;================================
.def decoder_count = r25
.def flags = r24
.def timer1_counter = r26
.def actual_speed = r27
.def desired_speed = r28

.equ PORTDDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F

.equ keyboard = 0


;############################# Macros #####################################
.macro micro_delay
	loop1:
		subi temp, 1
		sbci temp2, 0
		nop
		nop
		nop
		nop
		brne loop1

.endmacro


;############################# Interrupt table #####################################
.cseg
jmp RESET
jmp default
jmp default
jmp default
jmp default
jmp speed_count
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp Timer1_ISR
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default
jmp default

;############################# Timer1 interrupt #####################################
Timer1_ISR:
	inc timer1_counter
	cpi timer1_counter, 0x38
	BRGE half_second
	reti

half_second:
	clr timer1_counter
	mov actual_speed, decoder_count
	lsr actual_speed
	clr decoder_count
	rcall lcd_update
	rcall adjust_speed
	reti

adjust_speed:
	ldi temp, 0x00
	mov temp, desired_speed
	sub temp, actual_speed
	in temp2, OCR0
	add temp2, temp
	out OCR0, temp2

ret
;############################# Default interrupt #####################################
default:
reti


speed_count:
inc decoder_count
reti

;############################# Reset #####################################
RESET:
;stack pointer
ldi temp, low(RAMEND)
out SPL, temp
ldi temp, high(RAMEND)
out SPH, temp


;set up starting values for registers
ldi decoder_count, 0x00
ldi desired_speed, 0x14

;Outputs for keyboard
ldi temp, PORTDDIR ; columns are outputs, rows are inputs
out DDRC, temp

; set outputs for Motor and speed measurment
ldi temp, 0x14
out DDRB, temp

ldi temp, 0x04 ; turns Emittor on
out PORTB, temp

ldi temp, 0x00
out DDRE, temp

ldi temp, 0x10
out PORTE, temp


;set up output LCD
ser temp
out DDRD, temp
out DDRA, temp


;Set motor PWM up

ldi temp, 0x50
out OCR0, temp

ldi temp, 0x6b
out TCCR0, temp



; set up speed control Interrupts
ldi temp, 0x10
out EIMSK, temp


ldi temp, 0x02
out EICRB, temp

; set up timer1 to count 1s
ldi temp, 0x04
out TIMSK, temp

ldi temp, 0x00
out TCCR1A, temp

ldi temp, 0x01
out TCCR1B, temp

SEI



ldi temp, low(15000)
ldi temp2, high (15000)
micro_delay

rcall init_lcd

rjmp main

;############################## initialize the LCD #######################################
init_lcd:

ldi data, 0x38
rcall lcd_write_com

;4.1 ms delay
ldi temp, low(4100)
ldi temp2, high (4100)
micro_delay

rcall lcd_write_com

;100us delay
ldi temp, low(100)
ldi temp2, high (100)
micro_delay

rcall lcd_write_com
rcall lcd_write_com

rcall lcd_wait_busy
ldi data, 0x08
rcall lcd_write_com

rcall lcd_wait_busy
ldi data, 0x01
rcall lcd_write_com

rcall lcd_wait_busy
ldi data, 0x06
rcall lcd_write_com
rcall lcd_wait_busy
ldi data, 0x0E
rcall lcd_write_com

ret




;############################# Main #####################################

main:
	rcall lcd_update
	rcall keyboard_read
	
	
	CPI digit, 0x01
	BREQ faster
	CPI digit, 0x02
	BREQ slower
	CPI digit, 0x03
	BREQ stop
	CPI digit, 0x04
	BREQ start
	

rjmp main


faster:
	CPI desired_speed, 0x00
	BREQ stop
	ldi temp, 0x05
	add desired_speed, temp
	CPI desired_speed, 0x50
	BRGE too_fast
	rjmp main

too_fast:
	ldi desired_speed, 0x50
	rjmp main

slower:
	CPI desired_speed, 0x00
	BREQ stop
	subi desired_speed, 0x05
	CPI desired_speed, 0x14
	BRLO too_slow
	rjmp main

too_slow:
	ldi desired_speed, 0x14
	rjmp main

stop:
	ldi desired_speed, 0x00
	rjmp main

start:
	ldi desired_speed, 0x14
	rjmp main


;############################# reads Keyboard #####################################
keyboard_read:
CLT
BLD flags, 0

keyboard_read_internal:

ldi mask, INITCOLMASK
clr col ; initial column

colloop:
out PORTC, mask ; set column to mask value
; (sets column 0 off)
ldi temp, 0xFF ; implement a delay so the
; hardware can stabilize
delay:
dec temp
brne delay

in temp, PINC ; read PORTD
andi temp, ROWMASK ; read only the row bits
cpi temp, 0xF ; check if any rows are grounded
breq nextcol ; if not go to the next column

ldi mask, INITROWMASK ; initialise row check
clr row ; initial row

rowloop:
mov temp2, temp
and temp2, mask ; check masked bit
brne skipconv ; if the result is non-zero,
; we need to look again
rcall convert ; if bit is clear, convert the bitcode
rjmp keyboard_read_internal ; and be done

skipconv:
inc row ; else move to the next row
lsl mask ; shift the mask to the next bit
jmp rowloop

nextcol:
cpi col, 3 ; check if we?re on the last column
breq none ; if so, no buttons were pushed,
; so start again.

sec ; else shift the column mask:
; We must set the carry bit
rol mask ; and then rotate left by a bit,
; shifting the carry into
; bit zero. We need this to make
; sure all the rows have
; pull-up resistors
inc col ; increment column value
jmp colloop ; and check the next column
; convert function converts the row and column given to a
; binary number and also outputs the value to PORTC.
; Inputs come from registers row and col and output is in
; temp.

end_keyboard:

ret

none:
BST flags, 0
BRTS end_keyboard
rjmp keyboard_read

;################################# Converts keyboard to digit #######################
convert:
cpi col, 3 ; if column is 3 we have a letter
breq letters
cpi row, 3 ; if row is 3 we have a symbol or 0
breq symbols

mov temp, row ; otherwise we have a number (1-9)
lsl temp ; temp = row * 2
add temp, row ; temp = row * 3
add temp, col ; add the column address
; to get the offset from 1
inc temp ; add 1. Value of switch is
; row*3 + col + 1.
jmp convert_end

letters:
ldi temp, 0xA
add temp, row ; increment from 0xA by the row value
jmp convert_end

symbols:
cpi col, 0 ; check if we have a star
breq star
cpi col, 1 ; or if we have zero
breq zero
ldi temp, 0xFF ; we'll output 0xF for hash
jmp convert_end

star:
ldi temp, 0xE ; we'll output 0xE for star
jmp convert_end
zero:
clr temp ; set to zero

convert_end:
mov digit, temp ; write value to digit

SET
BLD flags, 0

ret ; return to caller

;############################# sends data to LCD #####################################

lcd_write_com:
	push temp
	out PORTD, data ; set the data port's value up 
 	clr temp 
 	out PORTA, temp ; RS = 0, RW = 0 for a command write 
 	nop ; delay to meet timing (Set up time) 
 	sbi PORTA, 2 ; turn on the enable pin 
 	nop ; delay to meet timing (Enable pulse width) 
 	nop 
	nop 
 	cbi PORTA, 2 ; turn off the enable pin 
 	nop ; delay to meet timing (Enable cycle time) 
 	nop 
 	nop
	pop temp
	ret

lcd_write_data:
	push temp
	out PORTD, data ; set the data port's value up 
 	ldi temp, 1 << 3
 	out PORTA, temp ; RS = 0, RW = 0 for a command write 
 	nop ; delay to meet timing (Set up time) 
 	sbi PORTA, 2 ; turn on the enable pin 
 	nop ; delay to meet timing (Enable pulse width) 
 	nop 
	nop 
 	cbi PORTA, 2 ; turn off the enable pin 
 	nop ; delay to meet timing (Enable cycle time) 
 	nop 
 	nop
	pop temp
	ret

;############################# waits to send data to LCD #####################################
lcd_wait_busy:
push temp
 clr temp 
 out DDRD, temp ; Make PORTD be an input port for now 
 out PORTD, temp 
 ldi temp, 1 << 1
 out PORTA, temp ; RS = 0, RW = 1 for a command port read 
busy_loop: 
 nop ; delay to meet set-up time) 
 sbi PORTA, 2 ; turn on the enable pin 
 nop ; delay to meet timing (Data delay time) 
 nop 
 nop 
 in temp, PIND ; read value from LCD 
 cbi PORTA, 2 ; turn off the enable pin 
 sbrc temp, 7 ; if the busy flag is set 
 rjmp busy_loop ; repeat command read 
 clr temp ; else 
 out PORTA, temp ; turn off read mode, 
 ser temp ; 
 out DDRD, temp ; make PORTD an output port again
 pop temp
ret

;############################# updates LCD display #####################################
lcd_update:

rcall lcd_wait_busy
ldi data, 0x01
rcall lcd_write_com

ldi data, 0x41
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, 0x63
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, 0x74
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, 0x3A
rcall lcd_wait_busy
rcall lcd_write_data

mov data, actual_speed
rcall write_number

rcall lcd_wait_busy
ldi data, 0xC0
rcall lcd_write_com

ldi data, 0x44
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, 0x65
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, 0x73
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, 0x3A
rcall lcd_wait_busy
rcall lcd_write_data

mov data, desired_speed
rcall write_number
ret

;############################# writes data to LCD as number #####################################
write_number:
mov temp, data
clr temp2
clr temp3

checkhundred:
cpi temp, 0x64
BRLO checkten
subi temp, 0x64
inc temp3
rjmp checkhundred


checkten:
cpi temp, 0x0A
BRLO underten
subi temp, 0x0A
inc temp2
rjmp checkten


underten:
mov data, temp3
rcall write_digit
mov data, temp2
rcall write_digit
mov data, temp
rcall write_digit
ret

;############################# writes digit to LCD as asci #####################################
write_digit:
push temp

ldi temp, 0x30
add data, temp
rcall lcd_wait_busy
rcall lcd_write_data

pop temp
ret
