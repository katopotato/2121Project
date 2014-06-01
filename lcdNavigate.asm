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
//.def decoder_count = r25 // wont need later on
.def distToO = r25 ; dist between car and obstacle, int is 6
.def flags = r24
.def xPos = r26 // x coordinate of car
.def actual_speed = r27
.def desired_speed = r28 // wont need later on
.def yPos = r29

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


;############################# Default interrupt #####################################
default:
reti


;############################# Reset #####################################
RESET:
; car starts at position 8, starts in center
ldi xPos, 8
ldi yPos, 0 ; car starts at first column
ldi distToO, 6 ; init dist to O
;stack pointer (initialises the stack?)
ldi temp, low(RAMEND)
out SPL, temp
ldi temp, high(RAMEND)
out SPH, temp


;set up starting values for registers
//ldi decoder_count, 0x00
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
ldi data, 0x08 // 00001000 display off
rcall lcd_write_com

rcall lcd_wait_busy
ldi data, 0x01 // 00000001 clear
rcall lcd_write_com

rcall lcd_wait_busy
ldi data, 0x06 // 00000110 entry mode set
rcall lcd_write_com
rcall lcd_wait_busy
ldi data, 0b00001100 // 15: 00001111, originally 0E
rcall lcd_write_com

ret




;############################# Main #####################################

main:
	rcall lcd_update
	rcall keyboard_read
	
	CPI digit, 0x02 // up
	BREQ up
	CPI digit, 0x04 // left
	BREQ left
	CPI digit, 0x06 // right
	BREQ right
	CPI digit, 0x08 // down
	BREQ down
	cpi digit, 0x00
	breq stop	

rjmp main

stop:
	ldi desired_speed, 0x00
	ldi temp, 0x00
	mov temp, desired_speed
	sub temp, actual_speed
	in temp2, OCR0
	add temp2, temp
	out OCR0, temp2
	rjmp main
; shift position up
up:
dec yPos
rjmp main
down:
inc yPos
jmp main

left:
	dec xPos // can't go less than 9
	rjmp main

right: ; move across, so add a space
	; have a counter for x and y co ordinate
	ldi desired_speed, 0x00
	inc xPos ; increase current xPos by 1, have a loop to loop over this and right sufficient spaces
	; can't go bigger than 16
	dec distToO // dist to obstacle decreases
	rjmp main

start:
	ldi desired_speed, 0x14 // 20
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
clr temp
; don't let it go too high or too low
; write data first, ie lives and car remaining
ldi temp, 0
cpi temp, 0
breq write_game_data

write_game_data: ; should always write to first line
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

ldi temp, 48
add temp, distToO

mov data, temp
//ldi data, temp // arbitary number, need to change this
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, '|' // divider
rcall lcd_wait_busy
rcall lcd_write_data

cpi yPos, 0 ; if 0 then car goes on this line
breq write_car_top
cpi yPos, 0
brlt topLimit
; write obstacle here, go here car will be in bottom row
mov temp, distToO
jmp write_space_obstacle
jmp write_game_data_bot_row

// writing to the second line
write_game_data_bot_row:
rcall lcd_wait_busy
ldi data, 0xC0
rcall lcd_write_com

ldi data, 'S' // current score
rcall lcd_wait_busy
rcall lcd_write_data

ldi data, ':'
rcall lcd_wait_busy
rcall lcd_write_data

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

ldi temp, 8
cpi yPos, 1

breq write_car_bot
cpi yPos, 2
brge bottomLimit
ret

topLimit: ; hit top limit (ie. car is already on highest pos.)
ldi yPos, 0
jmp main

write_car_bot:
rcall spaceLoop
ret

write_car_top:
ldi temp, 8
rcall spaceLoop
// write obstacle to end 
// write 6 spaces, then obstacle
mov temp, distToO // copy dist into temp, so we can keep original val.
cpi distToO, -1
brge write_space_obstacle ; space routine for obstacle
	ldi data, 'A'
	rcall lcd_wait_busy
	rcall lcd_write_data

//rcall write_obstacle
jmp write_game_data_bot_row

write_A:
	ldi data, 'A'
	rcall lcd_wait_busy
	rcall lcd_write_data
	jmp write_game_data_bot_row
write_space_obstacle:
//cpi temp, 1 // Co, no need to write A
//breq car_crash
cpi temp, 0
brlt write_obstacle
ldi data, ' ' 
rcall lcd_wait_busy
rcall lcd_write_data
dec temp
//cpi temp, 0 // on the car
//breq write_obstacle
cpi temp, 1
brge write_space_obstacle
rcall write_obstacle
// falls through here, can write obstacle
//ret
jmp write_game_data_bot_row

; if dist = 1 we crash TESTCASE: turn the light on
car_crash:
;clr temp

ret 

secondLine: ; start writing to second line
rcall lcd_wait_busy
ldi data, 0xC0
rcall lcd_write_com
jmp spaceLoop

firstLine: ; start writing to first line
rcall lcd_wait_busy
ldi data, 0x01
rcall lcd_write_com
jmp spaceLoop

bottomLimit: ; hit right limit (ie. car is already on lowest pos.)
ldi yPos, 1
jmp main

spaceLoop: ; wont it let go off the screen
; check that xPos >= 8 and xPos <= 16
cpi xPos, 8
brlt leftLimit ; write to pos 8
cpi xPos, 16
brge rightLimit ; write to pos 15
cp temp, xPos
brne write_space
cp temp, xPos
breq write_Car
ret

write_Car:
ldi data, 'C' ; the current car
rcall lcd_wait_busy
rcall lcd_write_data
ret

write_space:
ldi data, ' ' 
rcall lcd_wait_busy
rcall lcd_write_data
inc temp
jmp spaceLoop

leftLimit: ; hit left limit (ie. car is too far left)
ldi xPos, 8
rjmp spaceLoop

rightLimit: ; hit right limit (ie. car is too far right)
ldi xPos, 15
rjmp spaceLoop

write_obstacle:
ldi data, 'o'
rcall lcd_wait_busy
rcall lcd_write_data
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
