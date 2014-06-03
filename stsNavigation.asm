/** connections:
 * PB0-PB3     -> LED0 - LED3
 * PB4         -> Mot    
 * Ain(Audio)  -> OpD
 * ASD         -> Speaker (PIN 1)
 * PB0(Switch) -> OpE   
 */
.include "m64def.inc"

.def temp=r16
.def counter=r17
.def temp3=r18
.def counter3=r19
.def xPos = r20
.def yPos = r21
.def data = r22
.def row =r23
.def col =r24
.def mask =r25
.def currentLocation = r28

.equ PORTDDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F

.equ keyboard = 0

.equ RAND_A = 214013
.equ RAND_C = 2531011

.dseg
.org 0x100
RAND: .byte 4
top_row: .byte 8 ; top row data
.cseg
;setting up the interrupt vector
jmp RESET
jmp Default ; IRQ0 Handler
jmp Default ; IRQ1 Handler
jmp Default ; IRQ2 Handler
jmp Default ; IRQ3 Handler
jmp Default ; IRQ4 Handler
jmp Default ; IRQ5 Handler
jmp Default ; IRQ6 Handler
jmp Default ; IRQ7 Handler
jmp Default ; Timer2 Compare Handler
jmp Default ; Timer2 Overflow Handler
jmp Default ; Timer1 Capture Handler
jmp Default ; Timer1 CompareA Handler
jmp Default ; Timer1 CompareB Handler
jmp Default ; Timer1 Overflow Handler
jmp Default ; Timer0 Compare Handler
jmp Timer0  ; Timer0 Overflow Handler

Default: reti

RESET:
; write game data 
ldi r31, high(RAMEND) ; Initialize stack pointer
out SPH, r31 ; z stack pointer
ldi r30, low(RAMEND)
out SPL, r30

; top row data
ldi YL, low(0x000100)
ldi YH, high(0x000100)

ldi counter,0            
;ldi temp3,0
ldi counter3,0
ldi temp,255
out DDRB,temp

; set up keyboard
;Outputs for keyboard
ldi temp, PORTDDIR ; columns are outputs, rows are inputs
out DDRC, temp


ldi xPos, 0 ; begins far right
ldi yPos, 0	; begins top
;ldi currentLocation, 0x000116 ; currentLocation of x
;set up output LCD
ser temp
out DDRD, temp
out DDRA, temp
; initialise the LCD
rcall init_lcd

; initialise values to store
ldi temp, 'L'; represents nothing
sts 0x000132,temp

ldi temp, ':' 
sts 0x000133,r16

ldi temp, '2' 
sts 0x000134,r16

ldi temp, ' ' 
sts 0x000135,r16

ldi temp, 'C' 
sts 0x000104,r16

ldi temp, ':' 
sts 0x000105,r16

ldi temp, '3' 
sts 0x000106,r16

ldi temp, '|' 
sts 0x000107,r16

;game play area of level 1 (this is what should be shifted across)
ldi temp, 'C'; represents nothing, initial position of car
sts 0x000116,temp

ldi temp, ' ' 
sts 0x000117,r16

ldi temp, ' ' 
sts 0x000118,r16

ldi temp, ' ' 
sts 0x000119,r16

ldi temp, ' ' 
sts 0x000120,r16

ldi temp, ' ' 
sts 0x000121,r16

ldi temp, ' ' 
sts 0x000122,r16

ldi temp, ' ' ; FAR RIGHT 
sts 0x000123,r16

; #################### SECOND ROW GAME DATA  ###################
ldi temp, ' '; represents nothing
sts 0x000124,temp

ldi temp, ' ' 
sts 0x000125,r16

ldi temp, ' ' 
sts 0x000126,r16

ldi temp, ' ' 
sts 0x000127,r16

ldi temp, ' ' 
sts 0x000128,r16

ldi temp, ' ' 
sts 0x000129,r16

ldi temp, ' ' 
sts 0x000130,r16

ldi temp, ' ' ; FAR RIGHT 
sts 0x000131,r16

; #################### SECOND ROW SCORE DATA ###################
ldi temp, 'S'; represents nothing
sts 0x000108,temp

ldi temp, ':' 
sts 0x000109,r16

ldi temp, ' ' 
sts 0x000110,r16

ldi temp, ' ' 
sts 0x000111,r16

ldi temp, '1' 
sts 0x000112,r16

ldi temp, '3' 
sts 0x000113,r16

ldi temp, '7' 
sts 0x000114,r16

ldi temp, '|' 
sts 0x000115,r16

rjmp main

;############################# Macros #####################################
.macro micro_delay
	loop1:
		subi temp, 1
		sbci temp3, 0
		nop
		nop
		nop
		nop
		brne loop1

.endmacro

/* Shifts cell across, @0 - left address, @1 - right address
	move @1 into @0
*/
.macro shift
; check that contents of @0 is not C
		lds r24, @0
		cpi r24, 'C'
		brne shift_position

shift_position:
		lds r24, @1
		sts @0, r24
		ret	
.endmacro
;############################## initialize the LCD #######################################
init_lcd:

ldi data, 0x38
rcall lcd_write_com

;4.1 ms delay
ldi temp, low(4100)
ldi temp3, high (4100)
micro_delay

rcall lcd_write_com

;100us delay
ldi temp, low(100)
ldi temp3, high (100)
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


Timer0:                  ; Prologue starts.
in r24, SREG ; any overflow/ flags that are already on
push r24                 ; Prologue ends.

/**** a counter for 3597 is needed to get one second-- Three counters are used in this example **************/                                          
                         ; 3597  (1 interrupt 278microseconds therefore 3597 interrupts needed for 1 sec)
cpi counter, 97          ; counting for 97
brne notsecond
 
cpi temp3, 35         ; counting for 35
brne secondloop          ; jumping into count 100 

rjmp outmot              ; jump to out put value

notsecond:
inc counter   ; if it is not a second, increment the counter

rjmp exit

secondloop: 
	inc counter3 ; counting 100 for every 35 times := 35*100 := 3500
    cpi counter3,100 
    brne exit
	inc temp3
	ldi counter3,0  
; does this every second
; change this every second
; shift everything down by one position

exit: 
	pop r24                  ; Epilogue starts;
	out SREG, r24            ; Restore all conflict registers from the stack.
	reti  

outmot: 
		; write to first line
		rcall lcd_wait_busy
		ldi data, 0x01
		rcall lcd_write_com

		ldi counter,0    ; clearing the counter values after counting 3597 interrupts which gives us one second
        ldi temp3,0
        ldi counter3,0
		;dec xPos
		rcall keyboard_read ; number will be stored in temp
		rcall lcd_update
;RCALL WRITE SCORE TOP
;WRITE GAME TOP

;RCALL WRITE SCORE BOT
; WRITE GAME BOT

;SHIFT EVERYTHING BY ONE
; ### shift top row ### there always has to be a c appearing
; check for car, before moving data across
; check that current square does not contain car
lds r24, 0x000116 ; ######## check that it isn't car
cpi r24, 'C' ; only move across if not equal
brne move_across1
;shift 0x000116, 0x000117  /** shift macro takes in address to shift*/
;		lds r24, 0x000117
;		sts 0x000116, r24 ; move the data across one

		lds r24, 0x000118
		sts 0x000117, r24
		
		lds r24, 0x000119
		sts 0x000118, r24

		lds r24, 0x000120 ; check if power up was read here
		cpi r24, 'S'
		breq remove_power_up_top
		jmp second_half_top

move_across1:
		lds r24, 0x000117
		sts 0x000116, r24 ; move the data across one
		ret
second_half_top:
		sts 0x000119, r24
		lds r24, 0x000121
		sts 0x000120, r24

		lds r24, 0x000122
		sts 0x000121, r24

		lds r27, 0x000123
		sts 0x000122, r27
		; change the last one, by 1 every time

		; if at this stage r24(which is the previous column), there were no obsatacles == " "
		; then, 5% power up in top
		;       5% power up in bot
		;       25% obstacle in top
		;       25% obstacle in bot
		;       40% nothing
		
		
; ## shift second row##
		lds r24, 0x000125
		sts 0x000124, r24 ; move the data across one

		lds r24, 0x000126
		sts 0x000125, r24
		
		lds r24, 0x000127
		sts 0x000126, r24

		lds r24, 0x000128
		cpi r24, 'S'	; remove power up
		breq remove_power_up_bot
		jmp second_half_bot

second_half_bot:	
		sts 0x000127, r24
		lds r24, 0x000129
		sts 0x000128, r24

		lds r24, 0x000130
		sts 0x000129, r24

		lds r26, 0x000131
		sts 0x000130, r26
		; find the data and see what it should be

		cpi r27, ' ' ; if there was nothing in the previous column
		breq check_bottom
		cpi r27, ' ' ; else there was something, so have to load space
		brne no_obstacle ; ##NO OBJECT
		
		; have to check the values of both temp, and temp 3?
		rjmp exit        ; go to exit
remove_power_up_bot:
	ldi r24, ' '
	rjmp second_half_bot
remove_power_up_top: ;#### removes the power up
	ldi r24, ' '
	rjmp second_half_top                
                   ; Return from the interrupt.
check_bottom: ; check that the bottom row has no obstacle
	cpi r26, ' '
	breq place_object
	cpi r26, ' '
	brne no_obstacle
place_object: ; use random number generator to generate an object
	rcall getRandom ; result is in data
	cpi data, 14
	brlo powerup_top
	cpi data, 28
	brlo powerup_bottom  ; ######################################CHANGE TO BOTTOM, FOR DEBUG
	cpi data, 93
	brlo obstacle_bottom ; ######################################CHANGE TO BOTTOM, FOR DEBUG
	cpi data, 158
	brlo obstacle_top 
	jmp	 no_obstacle

powerup_top:
	ldi data, 'S'
	sts 0x000123, data
	ldi data, ' '
	sts 0x000131, data
	rjmp exit

powerup_bottom:
	ldi data, 'S'
	sts 0x000131, data
	ldi data, ' '
	sts 0x000123, data
	rjmp exit

obstacle_top:
	ldi data, 'O'
	sts 0x000123, data
	ldi data, ' '
	sts 0x000131, data
	rjmp exit

obstacle_bottom:
	ldi data, 'O'
	sts 0x000131, data
	ldi data, ' '
	sts 0x000123, data
	rjmp exit

no_obstacle: ; write a space
	ldi data, ' '
	sts 0x000123, data
	sts 0x000131, data
	rjmp exit
main:
ldi temp, 0b00000010     ; 
out TCCR0, temp          ; Prescaling value=8  ;256*8/7.3728( Frequency of the clock 7.3728MHz, for the overflow it should go for 256 times)
ldi temp, 1<<TOIE0       ; =278 microseconds
out TIMSK, temp          ; T/C0 interrupt enable
sei                      ; Enable global interrupt
;### Read the keyboard ###
;rcall keyboard_read ; number will be stored in temp
;cpi r27, 0
;breq clear_display ;#### clear the display as a test
;initially obstacle is on the far right

; press the number zero
;cpi r27, 0
;breq clear_display
; storing the data
ldi temp, 49
; check what y pointer is being used for

rjmp main


;### Read keyboard

keyboard_read:
CLT
BLD temp, 0

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
mov r27, temp
and r27, mask ; check masked bit
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
BST temp, 0
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
;clr r27
; write the value to lives:

mov r27, temp
sts 0x000134, r27
cpi r27, 6 ; move right
breq right
/* #############################################  TO DO , IMPLEMENT THIS

cpi r27, 4 ; move left
breq left
cpi r27, 2 ; move up
breq up
cpi r27, 4 ; move down
breq down
cpi r27, star
breq skip_level
cpi r27, hash
breq restart_game
else do not move c, car only moves with key press
*/
SET
BLD temp, 0

ret ; return to caller
;ret

; shifts across to the right
right: 
	; find c
	ldi temp, 'P'
	sts 0x000127, temp
	ldi temp, 'X'
	sts 0x000128, temp
	;lds r24, 0x000126
	;cpi r24, 'C'
	;breq shift_1
	ret

	; Xpos 
shift_1:
	ldi temp, 'C'
	sts 0x000127, temp
	ret
clear_display: ; ################################################## this should only occur when button has been pressed?
	; display something random
;rcall lcd_wait_busy
;ldi data, 0x01
;rcall lcd_write_com
ldi temp, 'h'; represents nothing
sts 0x000132,temp

ldi temp, 'e' 
sts 0x000133,r16

ldi temp, 'l' 
sts 0x000134,r16

ldi temp, 'l' 
sts 0x000135,r16

ldi temp, 'o' 
sts 0x000104,r16

ldi temp, 't' 
sts 0x000105,r16

ldi temp, 'a' 
sts 0x000106,r16

ldi temp, 'b' 
sts 0x000107,r16
	cli ; disbale global interrupt
	;rcall lcd_wait_busy
	;ldi data, 0x01 // 00000001 clear
	;rcall lcd_write_com
	ret

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

; ### make this read
write_game_data: ; should always write to first line
rcall lcd_wait_busy
ldi data, 0x01
rcall lcd_write_com

lds data, 0x000132 ; the contents of this is changing every second
;ldi data, 'M'
;ldi data, 'L' // lives remaining
rcall lcd_wait_busy
rcall lcd_write_data

lds data, 0x000133
;ldi data, ':'
rcall lcd_wait_busy
rcall lcd_write_data

lds data, 0x000134
;ldi data, '1' // arbitary number, need to change this
rcall lcd_wait_busy
rcall lcd_write_data

lds data, 0x000135
;ldi data, ' ' // space
rcall lcd_wait_busy
rcall lcd_write_data

lds data, 0x000104
;ldi data, 'C' // cars remaining
rcall lcd_wait_busy
rcall lcd_write_data

lds data, 0x000105
;ldi data, ':'
rcall lcd_wait_busy
rcall lcd_write_data

lds data, 0x000106
;ldi data, ':'
rcall lcd_wait_busy
rcall lcd_write_data
lds data, 0x000107
;ldi data, ':'
rcall lcd_wait_busy
rcall lcd_write_data
;ldi temp, '3'
;mov data, temp
//ldi data, temp // arbitary number, need to change this
;rcall lcd_wait_busy
;rcall lcd_write_data

;ldi data, '|' // divider
;rcall lcd_wait_busy
;rcall lcd_write_data
rcall write_gameplay_top
jmp write_game_data_bot_row

;####### write top line of game play (right corner) ##############
write_gameplay_top:
	; retrieve each of the values
	; move from left to right in top row
	; retreive the value
	lds data,0x000116 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000117 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000118 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000119 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000120 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000121 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000122 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000123 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data
	ret
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

ldi temp, 99
mov data, temp
rcall write_number

ldi data, '|'
rcall lcd_wait_busy
rcall lcd_write_data
rcall write_gameplay_bot
ret


write_gameplay_bot:
	; retrieve each of the values
	; move from left to right in top row
	; retreive the value
	lds data,0x000124 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000125 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000126 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000127 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000128 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000129 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000130 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data

	lds data,0x000131 ; load value at 105 into r16
	rcall lcd_wait_busy
	rcall lcd_write_data
	ret
topLimit: ; hit top limit (ie. car is already on highest pos.)
ldi yPos, 0
jmp main

write_obstacle_bot:
rcall spaceLoop
ret

write_obstacle_top:
ldi temp, 8
rcall spaceLoop
// write obstacle to end 
// write 6 spaces, then obstacle
jmp write_game_data_bot_row


write_space_obstacle:
ldi data, ' ' 
rcall lcd_wait_busy
rcall lcd_write_data
dec temp
cpi temp, 1
brge write_space_obstacle
// falls through here, can write obstacle
jmp write_game_data_bot_row

; if dist = 1 we crash TESTCASE: turn the light on
car_crash:

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
breq write_obstacle
ret

write_obstacle:
ldi data, 'O'
rcall lcd_wait_busy
rcall lcd_write_data
ret

write_powerup:
ldi data, 'S'
rcall lcd_wait_busy
rcall lcd_write_data
ret

write_space:
ldi data, ' ' 
rcall lcd_wait_busy
rcall lcd_write_data
inc temp
jmp spaceLoop

leftLimit: ; hit left limit (ie. obstacle is too far left)
; write nothing, makes whole top row disappear
; print bottom row
jmp write_game_data_bot_row

rightLimit: ; hit right limit (ie. car is too far right)
ldi xPos, 15
rjmp spaceLoop

;############################# writes data to LCD as number #####################################
write_number:
mov temp, data
;clr temp3
clr temp3

; number is stored in temp
checkhundred: ; subtract 100
cpi temp, 0x64 ; 100
BRLO checkten
subi temp, 0x64 ; 100
inc temp3
rjmp checkhundred
; at the end, temp3 will contain value of 100's digit


checkten:
; write value from check 100
rcall write_hundred
; subtracting 10 will be done maximum 100 times

clr temp3
;can now use temp3 as a counter, because we do not need its value anymore, as it has already been written to the lcd
cpi temp, 0x0A ; subtract 10
BRLO underten
subi temp, 0x0A
inc temp3
 
cpi temp, 0x0A ; subtract 10
BRLO underten
subi temp, 0x0A
inc temp3 

cpi temp, 0x0A ; subtract 10
BRLO underten
subi temp, 0x0A
inc temp3 

cpi temp, 0x0A ; subtract 10
BRLO underten
subi temp, 0x0A
inc temp3 

cpi temp, 0x0A ; subtract 10
BRLO underten
subi temp, 0x0A
inc temp3 

cpi temp, 0x0A ; subtract 10
BRLO underten
subi temp, 0x0A
inc temp3 

cpi temp, 0x0A ; subtract 10
BRLO underten
subi temp, 0x0A
inc temp3 

cpi temp, 0x0A ; subtract 10
BRLO underten
subi temp, 0x0A
inc temp3 

cpi temp, 0x0A ; subtract 10
BRLO underten
subi temp, 0x0A
inc temp3 


;rjmp checkten


underten:
mov data, temp3 ; tens col
rcall write_digit
mov data, temp
rcall write_digit
ret

;############################# writes digit to LCD as asci #####################################
write_hundred: ; writes digit for hundreds column
	push temp
	mov data, temp3
	ldi temp, 48
	add data, temp
	rcall lcd_wait_busy
	rcall lcd_write_data
	pop temp
	ret

write_digit:
push temp

ldi temp, 0x30 ; ascii for 0
add data, temp
rcall lcd_wait_busy
rcall lcd_write_data

pop temp
ret


;### END, infinite loop
loop: rjmp loop          ; loop forever

GetRandom:
push r0 ; save conflict registers
push r1
push r17
push r18
push r19
push r20
push r21
;push r22

clr r22 ; remains zero throughout

ldi r16, low(RAND_C) ; set original value to be equal to C
ldi r17, BYTE2(RAND_C)
ldi r18, BYTE3(RAND_C)
ldi r19, BYTE4(RAND_C)

; calculate A*X + C where X is previous random number.  A is 3 bytes.
lds r20, RAND
ldi r21, low(RAND_A)
mul r20, r21 ; low byte of X * low byte of A
add r16, r0
adc r17, r1
adc r18, r22

ldi r21, byte2(RAND_A)
mul r20, r21  ; low byte of X * middle byte of A
add r17, r0
adc r18, r1
adc r19, r22

ldi r21, byte3(RAND_A)
mul r20, r21  ; low byte of X * high byte of A
add r18, r0
adc r19, r1

lds r20, RAND+1
ldi r21, low(RAND_A)
mul r20, r21  ; byte 2 of X * low byte of A
add r17, r0
adc r18, r1
adc r19, r22

ldi r21, byte2(RAND_A)
mul r20, r21  ; byte 2 of X * middle byte of A
add r18, r0
adc r19, r1

ldi r21, byte3(RAND_A)
mul r20, r21  ; byte 2 of X * high byte of A
add r19, r0

lds r20, RAND+2
ldi r21, low(RAND_A)
mul r20, r21  ; byte 3 of X * low byte of A
add r18, r0
adc r19, r1

ldi r21, byte2(RAND_A)
mul r20, r21  ; byte 2 of X * middle byte of A
add r19, r0

lds r20, RAND+3
ldi r21, low(RAND_A)	
mul r20, r21  ; byte 3 of X * low byte of A
add r19, r0

; have already generated the random number
mov data, r16
sts RAND, r16 ; store random number
sts RAND+1, r17
sts RAND+2, r18
sts RAND+3, r19

mov r16, r19  ; prepare result (bits 30-23 of random number X)
lsl r18
rol r16
;mov data, r16
;pop r22 ; restore conflict registers
pop r21 
pop r20
pop r19
pop r18
pop r17
pop r1
pop r0
ret
