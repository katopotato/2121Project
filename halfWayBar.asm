; PIN CONFIG:
; LCD		D0-D7 -> PD0-PD7
;			BE-RS -> PA0-PA3


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


;set up output LCD
ser temp
out DDRD, temp
out DDRA, temp


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
ldi data, 0x08 // 0001000 turn the display ON
rcall lcd_write_com

rcall lcd_wait_busy
ldi data, 0x01 // 00000001 clear the display
rcall lcd_write_com

rcall lcd_wait_busy
ldi data, 0x06 // 0000110 entry mode set? 
rcall lcd_write_com
rcall lcd_wait_busy
ldi data, 0x0E // 15 - 00001110 function set, display on off? 
rcall lcd_write_com

ret

;############################# Main #####################################

main:
	rcall lcd_update

loop:
rjmp loop

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

ldi data, 'L' // lives remaining
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, ':'
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, '7' // arbitary number, need to change this
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, ' ' // space
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, 'C' // cars remaining
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, ':'
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, '9' // arbitary number, need to change this
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, '|' // divider
rcall lcd_wait_busy
rcall lcd_write_data

// writing to the second line
rcall lcd_wait_busy
ldi data, 0xC0
rcall lcd_write_com

ldi data, 'S' // current score
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, ':'
rcall lcd_wait_busy
rcall lcd_write_data
/*
ldi data, 0x73
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, 0x3A
rcall lcd_wait_busy
rcall lcd_write_data
*/
ldi data, ' '
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, ' '
rcall lcd_wait_busy
rcall lcd_write_data

ldi desired_speed, 99
mov data, desired_speed
rcall write_number

ldi data, '|'
rcall lcd_wait_busy
rcall lcd_write_data

ret

;############################# writes data to LCD as number #####################################
// max dgits is 5 digits
write_number:
mov temp, data // temp contains 99, 63 in hex
clr temp2 // contains 0
clr temp3 // contains 0

checkhundred:
cpi temp, 0x64 // d, number less than 100
BRLO checkten
subi temp, 0x64
inc temp3
rjmp checkhundred


checkten:
cpi temp, 0x0A // temp = 99, 10
BRLO underten
subi temp, 0x0A
inc temp2
rjmp checkten


underten:
mov data, temp3 // data = 0
rcall write_digit
mov data, temp2
rcall write_digit
mov data, temp
rcall write_digit
ret

;############################# writes digit to LCD as asci #####################################
write_digit:
push temp

ldi temp, 0x30 // 0
add data, temp // 0 + 0 = 0
rcall lcd_wait_busy
rcall lcd_write_data

pop temp
ret
