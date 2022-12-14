********************************
*     EOR-FILLER-SIMULATION    *
*                              *
*      BY MARC GOLOMBECK       *
*                              *
*   VERSION 1.00 / 04.04.2018  *
********************************
*
 			DSK EOR-filler
 			MX 	%11
          	ORG $6000
*
Temp		EQU $FD
even		EQU	$FE
ADRHIR		EQU	$FE					; + $FF
XKO			EQU	$06					; pseudo random number generator EOR-val
MATOR		EQU	$07
ANDMSK		EQU	$08
PSLO      	EQU $D8      			; USING FAC-ADRESS RANGE
PSHI      	EQU $DA        			; FOR POINTER IN MULT-TAB
PDLO      	EQU $DC        			; USING ARG-ADRESS RANGE
PDHI      	EQU $DE        			; FOR POINTER IN MULT-TAB
RCOUNT		EQU	$FC					; roundhouse counter
RCOUNT2		EQU	$FB
;SINZ      	EQU $7F					; $7F @s8
;COSZ      	EQU $80					; $80 @s8
;P1       	EQU $85					; $85
;P2       	EQU $87					; $87
;P3       	EQU $89					; $89
;P4       	EQU $8B					; $8B
;ROW			EQU	$8B
ASCR		EQU	$30B				; champ trigger
colPTR		EQU	$89
pLDEF		EQU	$85					; pointer to LINE defintion buffer
pCDEF		EQU	$87					; pointer to COLOR definition buffer
pLDEF2		EQU	$8D					; pointer to 2nd LINE definition buffer
YFROM		EQU	$FE					; from-to-coord for the Y-value
YTO			EQU	$FF
WAITVAL		EQU	$300				; wait value
*
HCLR      	EQU $F3F2     			; CLEAR HIRES SCREEN TO BLACK1
WAIT		EQU	$FCA8				; monitor ROM delay routine
KYBD      	EQU $C000     			; READ KEYBOARD
STROBE    	EQU $C010     			; CLEAR KEYBOARD
HOME      	EQU	$FC58     			; CLEAR SCREEN
COUT1		EQU	$FDF0				; character output routine
VERTBLANK	EQU	$C019				; vertical blanking -> available only IIe and above
*
LBUFFER		EQU	$0C00				; start of line buffer
LBUFP		EQU	$8B					; pointer into line buffer
LDEF		EQU	$0B00				; definition buffer of a single line or curve (points X,Y) which is translated into the general line buffer 
CDEF		EQU	$0B80				; definiton buffer of pixel colors
*
*	algorithm start
*
INIT		JSR	SETUP				; init algorithm

			LDA	#<LBUF1				; set buffer pointer
			STA	pLDEF
			LDA	#>LBUF1
			STA	pLDEF+1
			
			LDA	#<CBUF1
			STA	pCDEF
			LDA	#>CBUF1
			STA	pCDEF+1
			
			LDA	#1
			STA	WAITVAL
			
			;JSR	SETBUFFER
			;JSR	CALLFILLER

*		
READKBD   	LDA KYBD
          	BMI KEYQ   				; CHECK KEYS
          	JMP	NOKEY      			; NO KEYPRESS
*				
KEYQ      	CMP	#$D1       			; KEY 'Q' IS PRESSED
          	BNE	KEYW
          	LDA	STROBE
			STZ $C051      			; SWITCH TO TEXT -> end of program
          	STZ $C052
          	STZ $C054
          	JSR HOME      			; CLEAR SCREEN
          	JMP $03D0      			; DOS WARM START NO RTS HERE!
KEYW		CMP	#$D7       			; KEY 'W' IS PRESSED
          	BNE	ENDKEY2
          	LDA	WAITVAL
          	EOR	#$FF				; Toggle 0 - 255
			STA	WAITVAL
*
ENDKEY2		LDA	STROBE         	
*
NOKEY		;STZ	ROW
			
			LDA	#<LBUF1				; set 1st buffer pointer
			STA	pLDEF
			LDA	#>LBUF1
			STA	pLDEF+1
			
			LDA	#<CBUF1
			STA	pCDEF
			LDA	#>CBUF1
			STA	pCDEF+1

			LDA	#<LBUF2				; set 2nd buffer pointer
			STA	pLDEF2
			LDA	#>LBUF2
			STA	pLDEF2+1

			JSR	SETBUFFER

			JSR	CALLFILLER

			JSR	CLEARBUF

			LDA	WAITVAL
			JSR	WAIT

			LDA	WAITVAL
			JSR	WAIT

			;LDA	ASCR
			;EOR	#1
			;STA	ASCR				; increment screen counter
				
								
			JMP	READKBD
*
* set up line buffer
*
SETBUFFER	
			LDX	#0					; 63 pixel wide = *2! = 126 pixels since a color pixel is always 2 pixels wide!
			LDA	#$0C
			STZ	LBUFP				; init line buffer pointer
			STA	LBUFP+1
	
; outer loop				
LOOP1		TXA						; transfer X -> Y-reg for indexed access
			TAY
			STY	XKO
			LDA	(pLDEF),Y			; get new Y-coord from definition buffer
			;BEQ	noact1				; if value = 0 do not write to LINE buffer
			STA	YFROM				; set Y-FROM value
			LDA	(pLDEF2),Y
			INC						; increase +1 for later comparison
			STA	YTO					; set Y-TO value for inner loop

; inner loop			
LOOP1b				
			LDY	XKO
			LDA	(pCDEF),Y			; get new color information
			;BEQ	nocol1				; if zero color needs not ot be changed
			JSR SETCOLPOINTER		; set new color pointer
				
nocol1		LDA	MOD7LO,X			; retrieve bit pattern at pixel number X
			TAY
			LDA	(colPTR),Y
			STA	Temp				; save value
				
			CPY	#3					; do LBUFP-offset calculation -> pixel in HI-byte or LO-byte or both?
			BCC	onlyLO
			BEQ	specialC
			BCS	onlyHI

onlyLO		LDA	#$00
			STA	LBUFP				; write only to LO-Byte of line buffer
			LDY	YFROM				; retrieve current Y-value 
			BRA	sc2
onlyHI		LDA	#$80	
			STA	LBUFP				; write only to HI-byte of line buffer
			LDY	YFROM
			
			BRA	sc2				
specialC	LDY	#7					; change to LDY YFROM???
			LDA	#$80
			STA	LBUFP
			LDA	(colPTR),Y			; special case to fix carry bit in HI-byte
			LDY	YFROM
			ORA	(LBUFP),Y			; ORA or EOR???
				
			STA	(LBUFP),Y
			LDA	#$00				; fix line buffer pointer for LO-byte storage
			STA	LBUFP
				
sc2			LDA	Temp
			ORA	(LBUFP),Y			; set pixel, ORA or EOR???
			STA	(LBUFP),Y

			INC	YFROM				;Inner loop
			LDA	YFROM
			CMP	YTO
			BCC	LOOP1b	
			
			
			;LDY	MOD7LO,X			; try to cancel out the current bit
			;LDA	bBIT,Y
			;LDY	YTO
			;;DEY
			;;DEY
			
			;AND	(LBUFP),Y			; check if pixel bit was really set before 
			;BEQ	noact1				; no pixel set -> do not set kill pixel
			;INY
			;ORA	(LBUFP),Y
			;STA	(LBUFP),Y
			
			
noact1		LDX	XKO
			LDA	MOD7LO,X
			CMP	#6
			BLT	noLBUF1
			
					
doLBUF1		INC	LBUFP+1
			;BRA	nochg
	
nochg		
noLBUF1
		
			INX						; do this for 9 pages line buffer
			CPX	#63
			BEQ	setRTS	
			JMP	LOOP1				; outer loop
setRTS		RTS

;
; old routines
;
			LDA	#$00
			STA	LBUFP
			LDY	#$7F
lp2a		LDA	(LBUFP),Y			; blank out from last drawn pixel downwards
			BNE	chg2
			DEY
			BRA lp2a	
chg2		INY
			STA	(LBUFP),Y			; duplicate last pixel
			LDA	#$80
			STA	LBUFP
			LDY	#$7F
lp3a		LDA	(LBUFP),Y			; blank out from last drawn pixel downwards
			BNE	chg3
			DEY
			BRA lp3a	
chg3		INY
			STA	(LBUFP),Y			; duplicate last pixel
;
; old routines end
;

*
* sets the new color pointer, accu holds color value
* 
SETCOLPOINTER
			CMP	#1
			BNE	notgreen
			LDA	YFROM			; get current Y-coord into Accu
			AND	#%00000001		; check for uneven coord
			BEQ	green2			; if even do pattern green 2
			LDA	#<bGREEN1
			STA	colPTR
			LDA	#>bGREEN1
			STA	colPTR+1
			RTS
green2		LDA	#<bGREEN1
			STA	colPTR
			LDA	#>bGREEN1
			STA	colPTR+1
			RTS
notgreen	CMP #2
			BNE	notviolet
			LDA	#<bLILAC
			STA	colPTR
			LDA	#>bLILAC
			STA	colPTR+1
			RTS
notviolet	CMP #3
			BNE	notwhite1
			LDA	#<bWHITE1
			STA	colPTR
			LDA	#>bWHITE1
			STA	colPTR+1
			RTS
notwhite1	CMP #5
			BNE	notorange
			LDA	#<bORANGE
			STA	colPTR
			LDA	#>bORANGE
			STA	colPTR+1
			RTS
notorange	CMP #6
			BNE	notblue
			LDA	#<bBLUE
			STA	colPTR
			LDA	#>bBLUE
			STA	colPTR+1
			RTS
notblue		CMP #7
			BNE	notwhite2
			LDA	#<bWHITE2
			STA	colPTR
			LDA	#>bWHITE2
			STA	colPTR+1
notwhite2	RTS


*
* clear line buffer
*
CLEARBUF	
				LDX #10				; delete SLED data area & HIRES 1
				LDA #00				; if sled area is not cleared explicitly we get 
				TAY					; weird results on some machines!
				LDA	#$00
HCLRlp			STA $0C00,Y	
				INY
				BNE HCLRlp
				INC HCLRlp+02
				DEX
				BNE HCLRlp	
				LDA	#$0C			; enables algo restartability from monitor
				STA	HCLRlp+02		
			
			RTS

				
*
* setup algorithm
*
SETUP		STA STROBE   			; delete keystrobe
			LDA $C050				; text
			LDA $C054				; page 1
			LDA $C052 				; mixed off
			LDA $C057				; hires
        	LDA #32
         	STA $E6       			; DRAW ON 1
			JSR	HCLR				; clear screen
			;STZ	PRNG
			LDA #SSQLO/256 			; SETUP MULT-TAB
          	STA PSLO+1
          	LDA #SSQHI/256
          	STA PSHI+1
          	LDA #DSQLO/256
          	STA PDLO+1
          	LDA #DSQHI/256
          	STA PDHI+1
          	LDA	#$1D
          	STA	Temp
          	;STZ	ASCR				; init screen counter
          	;STZ	RCOUNT
          	JSR	CLRLBUF
          	;STZ	P1
          	STZ	even
          	RTS
*
* clear line buffer
*
CLRLBUF
			LDY	#0
			LDX	#10
			LDA	#$0C
			STZ	LBUFP				; init line buffer pointer
			STA	LBUFP+1
			LDA	#$00
LOOP3		STA	(LBUFP),Y	
			INY
			BNE	LOOP3
			;LDA #$80				; activate HI-bit on first entry
			;STA (LBUFP),Y
			;LDA #$00
			INC	LBUFP+1
			DEX						; do this for 9 pages line buffer
			BNE	LOOP3
]count		= 0
			;LDA	#$80
			LUP	18
]adr		= {$c00 + ]count * $80 + $40}
			STA	]adr
]count 		= ]count + 1			
			--^
          	RTS
          	
*
* wait for vertical blanking
*
WAITVBL
        	LDA #$7F                                                                   
_L1     	CMP VERTBLANK         
        	BPL _L1         		; wait fin VBL courant

        	;LDA bMachine      
_L2     	CMP VERTBLANK         
        	BMI _L2         		; wait fin display courant      

;			LDA	#10
;			JSR	WAIT
        	RTS
				
*
* EOR-filler loops
*
CALLFILLER
]count 		= 0	
			LUP	18
			LDA	#<{LBUFFER + ]count * 128}
     		STA	LBUFP
    		LDA #>{LBUFFER + ]count * 128}
     		STA LBUFP+1
       		;LDA #0
      		LDX #{]count + 11}
      		JSR FILLCOLUMN
]count 		= ]count + 1      	
      		--^
      		RTS
*
FILLCOLUMN							; X-reg holds column number
			LDA #0
			LDY	#0
]count 		= 0
			LUP	128
]ypos 		= 40 + ]count
]hbasl		= $2000 + {{]ypos @ 3} & 7 * $80} + {]ypos & 7 * $400} + {]ypos @ 6 * $28}
			;;LDY	#]count
			PHA
			LDA	(LBUFP),Y
			BNE :drw
			PLA
			BRA :nodrw
:drw		PLA			
			EOR	(LBUFP),Y
			STA	]hbasl,X
:nodrw		INY
]count 		= ]count + 1			
			--^
			RTS

*
* hints
*
;to convert from a standard signed full amplitude sine to an unsigned with halv amplitude just do

;lda sine,x
;clc
;adc #$80
;lsr
			
				
*
* data tables
*
bGREEN1			DFB	%00000001,%00000100,%00010000,%01000000,%00000010,%00001000,%00100000,%00000000
bGREEN2			DFB	%00000100,%01000000,%00010000,%00000100,%00000000,%00100000,%00000000,%00000000
;bGREEN2			DFB	%00000000,%00000100,%00000000,%01000000,%00000000,%00001000,%00000000,%00000000
;bGREEN2			DFB	%00000001,%00000100,%00010000,%01000000,%00000010,%00001000,%00100000,%00000000


bWHITE1			DFB	%00000011,%00001100,%00110000,%01000000,%00000110,%00011000,%01100000,%00000001
bGREEN			DFB	%00000001,%00000100,%00010000,%01000000,%00000010,%00001000,%00100000,%00000000
bLILAC			DFB	%00000010,%00001000,%00100000,%00000000,%00000100,%00010000,%01000000,%00000001
bWHITE2			DFB	%10000011,%10001100,%10110000,%11000000,%10000110,%10011000,%11100000,%10000001
bORANGE			DFB	%10000001,%10000100,%10010000,%11000000,%10000010,%10001000,%10100000,%10000000
bBLUE			DFB	%10000010,%10001000,%10100000,%10000000,%10000100,%10010000,%11000000,%10000001
;bWHITE2		DFB	%00000011,%00000110,%00001100,%00011000,%00110000,%01100000,%11000000
;bWHITEe		DFB	%11000000,%01100000,%00110000,%00011000,%00001100,%00000110,%00000011
;bWHITE			DFB	%01100000,%00110000,%00011000,%00001100,%00000110,%00000011,%00000001
;bWHITE			DFB	%01100000,%00011000,%00000110,%11000000,%00110000,%00001100,%00000011,%00000001
bBIT			DFB %00000001,%00000010,%00000100,%00001000,%00010000,%00100000,%01000000,%10000000

LBUF1		DFB	1,2,3,4,5,6,7,8,9
			DFB	10,11,12,13,14,15,16,17,18,19
			DFB	20,21,22,23,24,25,26,27,28,29
			DFB	30,31,32,33,34,35,36,37,38,39
			DFB	40,41,42,43,44,45,46,47,48,49
			DFB	50,51,52,53,54,55,56,57,58,59
			DFB	60,61,62,63,64
			
CBUF1		
			DFB 1,2,1,2,1,2,1,2
			DFB 1,2,1,2,1,2,1,2
			DFB 1,2,1,2,1,2,1,2
			DFB 1,2,1,2,1,2,1,2
			DFB 1,2,1,2,1,2,1,2
			DFB 1,2,1,2,1,2,1,2
			DFB 1,2,1,2,1,2,1,2
			DFB 1,2,1,2,1,2,1,2
;			DFB 1,1,1,1,1,1,1
;			DFB 1,1,1,1,1,1,1
;			DFB 1,1,1,1,1,1,1
;			DFB 1,1,1,1,1,1,1
;			DFB 1,1,1,1,1,1,1
;			DFB 1,1,1,1,1,1,1
;			DFB 1,1,1,1,1,1,1
;			DFB 1,1,1,1,1,1,1
;			DFB 1,1,1,1,1,1,1
;			DFB 1,1,1,1,1,1,1
			
LBUF2		DFB	126,125,124,123,122,121,120
			DFB	119,118,117,116,115,114,113,112,111,110
			DFB	109,108,107,106,105,104,103,102,101,100
			DFB	99,98,97,96,95,94,93,92,91,90
			DFB	89,88,87,86,85,84,83,82,81,80
			DFB	79,78,77,76,75,74,73,72,71,70
			DFB	69,68,67,66,65,64,63,62,61,60
			DFB	59,58,57,56,55,54,53,52,51,50
			
CBUF2		
			DFB 1,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0

LBUF3a		DFB	64,64,64,64,64,64,64,64,64,64
			DFB	64,64,64,64,64,64,64,64,64,64
			DFB	64,64,64,64,64,64,64,64,64,64
			DFB	64,64,64,64,64,64,64,64,64,64
			DFB	64,64,64,64,64,64,64,64,64,64
			DFB	64,64,64,64,64,64,64,64,64,64
			DFB	64,64,64,64,64,64,64,64,64,64

LBUF3b		DFB	1,1,1,1,1,1,1,1,1,1
			DFB	1,1,1,1,1,1,1,1,1,1
			DFB	1,1,1,1,1,1,1,1,1,1
			DFB	1,1,1,1,1,1,1,1,1,1
			DFB	1,1,1,1,1,1,1,1,1,1
			DFB	1,1,1,1,1,1,1,1,1,1
			DFB	1,1,1,1,1,1,1,1,1,1
			
			

CBUF3		
			DFB 2,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			DFB 0,0,0,0,0,0,0
			

			
LBUF1a		DFB	1,2,3,4,5,6,7,8,9
			DFB	10,11,12,13,14,15,16,17,18,19
			DFB	20,21,22,23,24,25,26,27,28,29
			DFB	30,31,32,33,34,35,36,37,38,39
			DFB	40,41,42,43,44,45,46,47,48,49
			DFB	50,51,52,53,54,55,56,57,58,59
			DFB	60,61,62,63,64
			
CBUF1a		
			DFB 1,1,1,1,1,1,1
			DFB 2,2,2,2,2,2,2
			DFB 3,3,3,3,3,3,3
			DFB 1,1,1,1,1,1,1
			DFB 2,2,2,2,2,2,2
			DFB 3,3,3,3,3,3,3
			DFB 1,1,1,1,1,1,1
			DFB 2,2,2,2,2,2,2
			DFB 3,3,3,3,3,3,3
			
			
LBUF2a		DFB	64,63,62,61,60
			DFB	59,58,57,56,55,54,53,52,51,50
			DFB	49,48,47,46,45,44,43,42,41,40
			DFB	39,38,37,36,35,34,33,32,31,30
			DFB	29,28,27,26,25,24,23,22,21,20
			DFB	19,18,17,16,15,14,13,12,11,10
			DFB	9,8,7,6,5,4,3,2,1
			
CBUF2a		
			DFB 3,3,3,3,3,3,3
			DFB 2,2,2,2,2,2,2
			DFB 1,1,1,1,1,1,1
			DFB 3,3,3,3,3,3,3
			DFB 2,2,2,2,2,2,2
			DFB 1,1,1,1,1,1,1
			DFB 3,3,3,3,3,3,3
			DFB 2,2,2,2,2,2,2
			DFB 1,1,1,1,1,1,1

			

ANDMASK   		DFB $81,$82,$84,$88,$90,$a0,$c0
CLRMASK			DFB	$7E,$7D,$7B,$77,$6F,$5F,$3F
*
          		DS \
YLOOKLO   		HEX 0000000000000000
          		HEX 8080808080808080
                HEX 0000000000000000
                HEX 8080808080808080
                HEX 0000000000000000
                HEX 8080808080808080
                HEX 0000000000000000
                HEX 8080808080808080
                HEX 2828282828282828
                  HEX   a8a8a8a8a8a8a8a8
                  HEX   2828282828282828
                  HEX   a8a8a8a8a8a8a8a8
                  HEX   2828282828282828
                  HEX   a8a8a8a8a8a8a8a8
                  HEX   2828282828282828
                  HEX   a8a8a8a8a8a8a8a8
                  HEX   5050505050505050
                  HEX   d0d0d0d0d0d0d0d0
                  HEX   5050505050505050
                  HEX   d0d0d0d0d0d0d0d0
                  HEX   5050505050505050
                  HEX   d0d0d0d0d0d0d0d0
                  HEX   5050505050505050
                  HEX   d0d0d0d0d0d0d0d0
          		DS \
                  
YLOOKHI   		HEX 	0004080c1014181c
                  HEX   0004080c1014181c
                  HEX   0105090d1115191d
                  HEX   0105090d1115191d
                  HEX   02060a0e12161a1e
                  HEX   02060a0e12161a1e
                  HEX   03070b0f13171b1f
                  HEX   03070b0f13171b1f
                  HEX   0004080c1014181c
                  HEX   0004080c1014181c
                  HEX   0105090d1115191d
                  HEX   0105090d1115191d
                  HEX   02060a0e12161a1e
                  HEX   02060a0e12161a1e
                  HEX   03070b0f13171b1f
                  HEX   03070b0f13171b1f
                  HEX   0004080c1014181c
                  HEX   0004080c1014181c
                  HEX   0105090d1115191d
                  HEX   0105090d1115191d
                  HEX   02060a0e12161a1e
                  HEX   02060a0e12161a1e
                  HEX   03070b0f13171b1f
                  HEX   03070b0f13171b1f

			DS \

DIV7HI		HEX   2424242525252525
            HEX   2525262626262626
            HEX   2627272727272727

MOD7HI    	HEX   0405060001020304
            HEX   0506000102030405
            HEX   0600010203040506
	
	        DS \

DIV7LO    HEX 0000000000000001
                  HEX   0101010101010202
                  HEX   0202020202030303
                  HEX   0303030304040404
                  HEX   0404040505050505
                  HEX   0505060606060606
                  HEX   0607070707070707
                  HEX   0808080808080809
                  HEX   0909090909090a0a
                  HEX   0a0a0a0a0a0b0b0b
                  HEX   0b0b0b0b0c0c0c0c
                  HEX   0c0c0c0d0d0d0d0d
                  HEX   0d0d0e0e0e0e0e0e
                  HEX   0e0f0f0f0f0f0f0f
                  HEX   1010101010101011
                  HEX   1111111111111212
                  HEX   1212121212131313
                  HEX   1313131314141414
                  HEX   1414141515151515
                  HEX   1515161616161616
                  HEX   1617171717171717
                  HEX   1818181818181819
                  HEX   1919191919191a1a
                  HEX   1a1a1a1a1a1b1b1b
                  HEX   1b1b1b1b1c1c1c1c
                  HEX   1c1c1c1d1d1d1d1d
                  HEX   1d1d1e1e1e1e1e1e
                  HEX   1e1f1f1f1f1f1f1f
                  HEX   2020202020202021
                  HEX   2121212121212222
                  HEX   2222222222232323
                  HEX   2323232324242424
          
MOD7LO    HEX 0001020304050600
                  HEX   0102030405060001
                  HEX   0203040506000102
                  HEX   0304050600010203
                  HEX   0405060001020304
                  HEX   0506000102030405
                  HEX   0600010203040506
                  HEX   0001020304050600
                  HEX   0102030405060001
                  HEX   0203040506000102
                  HEX   0304050600010203
                  HEX   0405060001020304
                  HEX   0506000102030405
                  HEX   0600010203040506
                  HEX   0001020304050600
                  HEX   0102030405060001
                  HEX   0203040506000102
                  HEX   0304050600010203
                  HEX   0405060001020304
                  HEX   0506000102030405
                  HEX   0600010203040506
                  HEX   0001020304050600
                  HEX   0102030405060001
                  HEX   0203040506000102
                  HEX   0304050600010203
                  HEX   0405060001020304
                  HEX   0506000102030405
                  HEX   0600010203040506
                  HEX   0001020304050600
                  HEX   0102030405060001
                  HEX   0203040506000102
                  HEX   0304050600010203
*
SSQLO       DFB $00,$00,$01,$02,$04,$06,$09,$0C
                 DFB $10,$14,$19,$1E,$24,$2A,$31,$38
                 DFB $40,$48,$51,$5A,$64,$6E,$79,$84
                 DFB $90,$9C,$A9,$B6,$C4,$D2,$E1,$F0
                 DFB $00,$10,$21,$32,$44,$56,$69,$7C
                 DFB $90,$A4,$B9,$CE,$E4,$FA,$11,$28
                 DFB $40,$58,$71,$8A,$A4,$BE,$D9,$F4
                 DFB $10,$2C,$49,$66,$84,$A2,$C1,$E0
                 DFB $00,$20,$41,$62,$84,$A6,$C9,$EC
                 DFB $10,$34,$59,$7E,$A4,$CA,$F1,$18
                 DFB $40,$68,$91,$BA,$E4,$0E,$39,$64
                 DFB $90,$BC,$E9,$16,$44,$72,$A1,$D0
                 DFB $00,$30,$61,$92,$C4,$F6,$29,$5C
                 DFB $90,$C4,$F9,$2E,$64,$9A,$D1,$08
                 DFB $40,$78,$B1,$EA,$24,$5E,$99,$D4
                 DFB $10,$4C,$89,$C6,$04,$42,$81,$C0
                 DFB $00,$40,$81,$C2,$04,$46,$89,$CC
                 DFB $10,$54,$99,$DE,$24,$6A,$B1,$F8
                 DFB $40,$88,$D1,$1A,$64,$AE,$F9,$44
                 DFB $90,$DC,$29,$76,$C4,$12,$61,$B0
                 DFB $00,$50,$A1,$F2,$44,$96,$E9,$3C
                 DFB $90,$E4,$39,$8E,$E4,$3A,$91,$E8
                 DFB $40,$98,$F1,$4A,$A4,$FE,$59,$B4
                 DFB $10,$6C,$C9,$26,$84,$E2,$41,$A0
                 DFB $00,$60,$C1,$22,$84,$E6,$49,$AC
                 DFB $10,$74,$D9,$3E,$A4,$0A,$71,$D8
                 DFB $40,$A8,$11,$7A,$E4,$4E,$B9,$24
                 DFB $90,$FC,$69,$D6,$44,$B2,$21,$90
                 DFB $00,$70,$E1,$52,$C4,$36,$A9,$1C
                 DFB $90,$04,$79,$EE,$64,$DA,$51,$C8
                 DFB $40,$B8,$31,$AA,$24,$9E,$19,$94
                 DFB $10,$8C,$09,$86,$04,$82,$01,$80
                 DFB $00,$80,$01,$82,$04,$86,$09,$8C
                 DFB $10,$94,$19,$9E,$24,$AA,$31,$B8
                 DFB $40,$C8,$51,$DA,$64,$EE,$79,$04
                 DFB $90,$1C,$A9,$36,$C4,$52,$E1,$70
                 DFB $00,$90,$21,$B2,$44,$D6,$69,$FC
                 DFB $90,$24,$B9,$4E,$E4,$7A,$11,$A8
                 DFB $40,$D8,$71,$0A,$A4,$3E,$D9,$74
                 DFB $10,$AC,$49,$E6,$84,$22,$C1,$60
                 DFB $00,$A0,$41,$E2,$84,$26,$C9,$6C
                 DFB $10,$B4,$59,$FE,$A4,$4A,$F1,$98
                 DFB $40,$E8,$91,$3A,$E4,$8E,$39,$E4
                 DFB $90,$3C,$E9,$96,$44,$F2,$A1,$50
                 DFB $00,$B0,$61,$12,$C4,$76,$29,$DC
                 DFB $90,$44,$F9,$AE,$64,$1A,$D1,$88
                 DFB $40,$F8,$B1,$6A,$24,$DE,$99,$54
                 DFB $10,$CC,$89,$46,$04,$C2,$81,$40
                 DFB $00,$C0,$81,$42,$04,$C6,$89,$4C
                 DFB $10,$D4,$99,$5E,$24,$EA,$B1,$78
                 DFB $40,$08,$D1,$9A,$64,$2E,$F9,$C4
                 DFB $90,$5C,$29,$F6,$C4,$92,$61,$30
                 DFB $00,$D0,$A1,$72,$44,$16,$E9,$BC
                 DFB $90,$64,$39,$0E,$E4,$BA,$91,$68
                 DFB $40,$18,$F1,$CA,$A4,$7E,$59,$34
                 DFB $10,$EC,$C9,$A6,$84,$62,$41,$20
                 DFB $00,$E0,$C1,$A2,$84,$66,$49,$2C
                 DFB $10,$F4,$D9,$BE,$A4,$8A,$71,$58
                 DFB $40,$28,$11,$FA,$E4,$CE,$B9,$A4
                 DFB $90,$7C,$69,$56,$44,$32,$21,$10
                 DFB $00,$F0,$E1,$D2,$C4,$B6,$A9,$9C
                 DFB $90,$84,$79,$6E,$64,$5A,$51,$48
                 DFB $40,$38,$31,$2A,$24,$1E,$19,$14
                 DFB $10,$0C,$09,$06,$04,$02,$01,$00
*
SSQHI       DFB $00,$00,$00,$00,$00,$00,$00,$00
                 DFB $00,$00,$00,$00,$00,$00,$00,$00
                 DFB $00,$00,$00,$00,$00,$00,$00,$00
                 DFB $00,$00,$00,$00,$00,$00,$00,$00
                 DFB $01,$01,$01,$01,$01,$01,$01,$01
                 DFB $01,$01,$01,$01,$01,$01,$02,$02
                 DFB $02,$02,$02,$02,$02,$02,$02,$02
                 DFB $03,$03,$03,$03,$03,$03,$03,$03
                 DFB $04,$04,$04,$04,$04,$04,$04,$04
                 DFB $05,$05,$05,$05,$05,$05,$05,$06
                 DFB $06,$06,$06,$06,$06,$07,$07,$07
                 DFB $07,$07,$07,$08,$08,$08,$08,$08
                 DFB $09,$09,$09,$09,$09,$09,$0A,$0A
                 DFB $0A,$0A,$0A,$0B,$0B,$0B,$0B,$0C
                 DFB $0C,$0C,$0C,$0C,$0D,$0D,$0D,$0D
                 DFB $0E,$0E,$0E,$0E,$0F,$0F,$0F,$0F
                 DFB $10,$10,$10,$10,$11,$11,$11,$11
                 DFB $12,$12,$12,$12,$13,$13,$13,$13
                 DFB $14,$14,$14,$15,$15,$15,$15,$16
                 DFB $16,$16,$17,$17,$17,$18,$18,$18
                 DFB $19,$19,$19,$19,$1A,$1A,$1A,$1B
                 DFB $1B,$1B,$1C,$1C,$1C,$1D,$1D,$1D
                 DFB $1E,$1E,$1E,$1F,$1F,$1F,$20,$20
                 DFB $21,$21,$21,$22,$22,$22,$23,$23
                 DFB $24,$24,$24,$25,$25,$25,$26,$26
                 DFB $27,$27,$27,$28,$28,$29,$29,$29
                 DFB $2A,$2A,$2B,$2B,$2B,$2C,$2C,$2D
                 DFB $2D,$2D,$2E,$2E,$2F,$2F,$30,$30
                 DFB $31,$31,$31,$32,$32,$33,$33,$34
                 DFB $34,$35,$35,$35,$36,$36,$37,$37
                 DFB $38,$38,$39,$39,$3A,$3A,$3B,$3B
                 DFB $3C,$3C,$3D,$3D,$3E,$3E,$3F,$3F
                 DFB $40,$40,$41,$41,$42,$42,$43,$43
                 DFB $44,$44,$45,$45,$46,$46,$47,$47
                 DFB $48,$48,$49,$49,$4A,$4A,$4B,$4C
                 DFB $4C,$4D,$4D,$4E,$4E,$4F,$4F,$50
                 DFB $51,$51,$52,$52,$53,$53,$54,$54
                 DFB $55,$56,$56,$57,$57,$58,$59,$59
                 DFB $5A,$5A,$5B,$5C,$5C,$5D,$5D,$5E
                 DFB $5F,$5F,$60,$60,$61,$62,$62,$63
                 DFB $64,$64,$65,$65,$66,$67,$67,$68
                 DFB $69,$69,$6A,$6A,$6B,$6C,$6C,$6D
                 DFB $6E,$6E,$6F,$70,$70,$71,$72,$72
                 DFB $73,$74,$74,$75,$76,$76,$77,$78
                 DFB $79,$79,$7A,$7B,$7B,$7C,$7D,$7D
                 DFB $7E,$7F,$7F,$80,$81,$82,$82,$83
                 DFB $84,$84,$85,$86,$87,$87,$88,$89
                 DFB $8A,$8A,$8B,$8C,$8D,$8D,$8E,$8F
                 DFB $90,$90,$91,$92,$93,$93,$94,$95
                 DFB $96,$96,$97,$98,$99,$99,$9A,$9B
                 DFB $9C,$9D,$9D,$9E,$9F,$A0,$A0,$A1
                 DFB $A2,$A3,$A4,$A4,$A5,$A6,$A7,$A8
                 DFB $A9,$A9,$AA,$AB,$AC,$AD,$AD,$AE
                 DFB $AF,$B0,$B1,$B2,$B2,$B3,$B4,$B5
                 DFB $B6,$B7,$B7,$B8,$B9,$BA,$BB,$BC
                 DFB $BD,$BD,$BE,$BF,$C0,$C1,$C2,$C3
                 DFB $C4,$C4,$C5,$C6,$C7,$C8,$C9,$CA
                 DFB $CB,$CB,$CC,$CD,$CE,$CF,$D0,$D1
                 DFB $D2,$D3,$D4,$D4,$D5,$D6,$D7,$D8
                 DFB $D9,$DA,$DB,$DC,$DD,$DE,$DF,$E0
                 DFB $E1,$E1,$E2,$E3,$E4,$E5,$E6,$E7
                 DFB $E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF
                 DFB $F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7
                 DFB $F8,$F9,$FA,$FB,$FC,$FD,$FE,$00
*
DSQLO       DFB $80,$01,$82,$04,$86,$09,$8C,$10
                 DFB $94,$19,$9E,$24,$AA,$31,$B8,$40
                 DFB $C8,$51,$DA,$64,$EE,$79,$04,$90
                 DFB $1C,$A9,$36,$C4,$52,$E1,$70,$00
                 DFB $90,$21,$B2,$44,$D6,$69,$FC,$90
                 DFB $24,$B9,$4E,$E4,$7A,$11,$A8,$40
                 DFB $D8,$71,$0A,$A4,$3E,$D9,$74,$10
                 DFB $AC,$49,$E6,$84,$22,$C1,$60,$00
                 DFB $A0,$41,$E2,$84,$26,$C9,$6C,$10
                 DFB $B4,$59,$FE,$A4,$4A,$F1,$98,$40
                 DFB $E8,$91,$3A,$E4,$8E,$39,$E4,$90
                 DFB $3C,$E9,$96,$44,$F2,$A1,$50,$00
                 DFB $B0,$61,$12,$C4,$76,$29,$DC,$90
                 DFB $44,$F9,$AE,$64,$1A,$D1,$88,$40
                 DFB $F8,$B1,$6A,$24,$DE,$99,$54,$10
                 DFB $CC,$89,$46,$04,$C2,$81,$40,$00
                 DFB $C0,$81,$42,$04,$C6,$89,$4C,$10
                 DFB $D4,$99,$5E,$24,$EA,$B1,$78,$40
                 DFB $08,$D1,$9A,$64,$2E,$F9,$C4,$90
                 DFB $5C,$29,$F6,$C4,$92,$61,$30,$00
                 DFB $D0,$A1,$72,$44,$16,$E9,$BC,$90
                 DFB $64,$39,$0E,$E4,$BA,$91,$68,$40
                 DFB $18,$F1,$CA,$A4,$7E,$59,$34,$10
                 DFB $EC,$C9,$A6,$84,$62,$41,$20,$00
                 DFB $E0,$C1,$A2,$84,$66,$49,$2C,$10
                 DFB $F4,$D9,$BE,$A4,$8A,$71,$58,$40
                 DFB $28,$11,$FA,$E4,$CE,$B9,$A4,$90
                 DFB $7C,$69,$56,$44,$32,$21,$10,$00
                 DFB $F0,$E1,$D2,$C4,$B6,$A9,$9C,$90
                 DFB $84,$79,$6E,$64,$5A,$51,$48,$40
                 DFB $38,$31,$2A,$24,$1E,$19,$14,$10
                 DFB $0C,$09,$06,$04,$02,$01,$00,$00
                 DFB $00,$01,$02,$04,$06,$09,$0C,$10
                 DFB $14,$19,$1E,$24,$2A,$31,$38,$40
                 DFB $48,$51,$5A,$64,$6E,$79,$84,$90
                 DFB $9C,$A9,$B6,$C4,$D2,$E1,$F0,$00
                 DFB $10,$21,$32,$44,$56,$69,$7C,$90
                 DFB $A4,$B9,$CE,$E4,$FA,$11,$28,$40
                 DFB $58,$71,$8A,$A4,$BE,$D9,$F4,$10
                 DFB $2C,$49,$66,$84,$A2,$C1,$E0,$00
                 DFB $20,$41,$62,$84,$A6,$C9,$EC,$10
                 DFB $34,$59,$7E,$A4,$CA,$F1,$18,$40
                 DFB $68,$91,$BA,$E4,$0E,$39,$64,$90
                 DFB $BC,$E9,$16,$44,$72,$A1,$D0,$00
                 DFB $30,$61,$92,$C4,$F6,$29,$5C,$90
                 DFB $C4,$F9,$2E,$64,$9A,$D1,$08,$40
                 DFB $78,$B1,$EA,$24,$5E,$99,$D4,$10
                 DFB $4C,$89,$C6,$04,$42,$81,$C0,$00
                 DFB $40,$81,$C2,$04,$46,$89,$CC,$10
                 DFB $54,$99,$DE,$24,$6A,$B1,$F8,$40
                 DFB $88,$D1,$1A,$64,$AE,$F9,$44,$90
                 DFB $DC,$29,$76,$C4,$12,$61,$B0,$00
                 DFB $50,$A1,$F2,$44,$96,$E9,$3C,$90
                 DFB $E4,$39,$8E,$E4,$3A,$91,$E8,$40
                 DFB $98,$F1,$4A,$A4,$FE,$59,$B4,$10
                 DFB $6C,$C9,$26,$84,$E2,$41,$A0,$00
                 DFB $60,$C1,$22,$84,$E6,$49,$AC,$10
                 DFB $74,$D9,$3E,$A4,$0A,$71,$D8,$40
                 DFB $A8,$11,$7A,$E4,$4E,$B9,$24,$90
                 DFB $FC,$69,$D6,$44,$B2,$21,$90,$00
                 DFB $70,$E1,$52,$C4,$36,$A9,$1C,$90
                 DFB $04,$79,$EE,$64,$DA,$51,$C8,$40
                 DFB $B8,$31,$AA,$24,$9E,$19,$94,$10
                 DFB $8C,$09,$86,$04,$82,$01,$80,$00
*
DSQHI       DFB $3F,$3F,$3E,$3E,$3D,$3D,$3C,$3C
                 DFB $3B,$3B,$3A,$3A,$39,$39,$38,$38
                 DFB $37,$37,$36,$36,$35,$35,$35,$34
                 DFB $34,$33,$33,$32,$32,$31,$31,$31
                 DFB $30,$30,$2F,$2F,$2E,$2E,$2D,$2D
                 DFB $2D,$2C,$2C,$2B,$2B,$2B,$2A,$2A
                 DFB $29,$29,$29,$28,$28,$27,$27,$27
                 DFB $26,$26,$25,$25,$25,$24,$24,$24
                 DFB $23,$23,$22,$22,$22,$21,$21,$21
                 DFB $20,$20,$1F,$1F,$1F,$1E,$1E,$1E
                 DFB $1D,$1D,$1D,$1C,$1C,$1C,$1B,$1B
                 DFB $1B,$1A,$1A,$1A,$19,$19,$19,$19
                 DFB $18,$18,$18,$17,$17,$17,$16,$16
                 DFB $16,$15,$15,$15,$15,$14,$14,$14
                 DFB $13,$13,$13,$13,$12,$12,$12,$12
                 DFB $11,$11,$11,$11,$10,$10,$10,$10
                 DFB $0F,$0F,$0F,$0F,$0E,$0E,$0E,$0E
                 DFB $0D,$0D,$0D,$0D,$0C,$0C,$0C,$0C
                 DFB $0C,$0B,$0B,$0B,$0B,$0A,$0A,$0A
                 DFB $0A,$0A,$09,$09,$09,$09,$09,$09
                 DFB $08,$08,$08,$08,$08,$07,$07,$07
                 DFB $07,$07,$07,$06,$06,$06,$06,$06
                 DFB $06,$05,$05,$05,$05,$05,$05,$05
                 DFB $04,$04,$04,$04,$04,$04,$04,$04
                 DFB $03,$03,$03,$03,$03,$03,$03,$03
                 DFB $02,$02,$02,$02,$02,$02,$02,$02
                 DFB $02,$02,$01,$01,$01,$01,$01,$01
                 DFB $01,$01,$01,$01,$01,$01,$01,$01
                 DFB $00,$00,$00,$00,$00,$00,$00,$00
                 DFB $00,$00,$00,$00,$00,$00,$00,$00
                 DFB $00,$00,$00,$00,$00,$00,$00,$00
                 DFB $00,$00,$00,$00,$00,$00,$00,$00
                 DFB $00,$00,$00,$00,$00,$00,$00,$00
                 DFB $00,$00,$00,$00,$00,$00,$00,$00
                 DFB $00,$00,$00,$00,$00,$00,$00,$00
                 DFB $00,$00,$00,$00,$00,$00,$00,$01
                 DFB $01,$01,$01,$01,$01,$01,$01,$01
                 DFB $01,$01,$01,$01,$01,$02,$02,$02
                 DFB $02,$02,$02,$02,$02,$02,$02,$03
                 DFB $03,$03,$03,$03,$03,$03,$03,$04
                 DFB $04,$04,$04,$04,$04,$04,$04,$05
                 DFB $05,$05,$05,$05,$05,$05,$06,$06
                 DFB $06,$06,$06,$06,$07,$07,$07,$07
                 DFB $07,$07,$08,$08,$08,$08,$08,$09
                 DFB $09,$09,$09,$09,$09,$0A,$0A,$0A
                 DFB $0A,$0A,$0B,$0B,$0B,$0B,$0C,$0C
                 DFB $0C,$0C,$0C,$0D,$0D,$0D,$0D,$0E
                 DFB $0E,$0E,$0E,$0F,$0F,$0F,$0F,$10
                 DFB $10,$10,$10,$11,$11,$11,$11,$12
                 DFB $12,$12,$12,$13,$13,$13,$13,$14
                 DFB $14,$14,$15,$15,$15,$15,$16,$16
                 DFB $16,$17,$17,$17,$18,$18,$18,$19
                 DFB $19,$19,$19,$1A,$1A,$1A,$1B,$1B
                 DFB $1B,$1C,$1C,$1C,$1D,$1D,$1D,$1E
                 DFB $1E,$1E,$1F,$1F,$1F,$20,$20,$21
                 DFB $21,$21,$22,$22,$22,$23,$23,$24
                 DFB $24,$24,$25,$25,$25,$26,$26,$27
                 DFB $27,$27,$28,$28,$29,$29,$29,$2A
                 DFB $2A,$2B,$2B,$2B,$2C,$2C,$2D,$2D
                 DFB $2D,$2E,$2E,$2F,$2F,$30,$30,$31
                 DFB $31,$31,$32,$32,$33,$33,$34,$34
                 DFB $35,$35,$35,$36,$36,$37,$37,$38
                 DFB $38,$39,$39,$3A,$3A,$3B,$3B,$3C
                 DFB $3C,$3D,$3D,$3E,$3E,$3F,$3F,$00

*
* SINETABLE
*
SINTAB	HEX FF0306090C0F1215
			HEX 181B1E2124272A2D
			HEX 303336393B3E4143
			HEX 46494B4E50525557
			HEX 595B5E6062646667
			HEX 696B6C6E70717274
			HEX 75767778797A7B7B
			HEX 7C7D7D7E7E7E7E7E
COSTAB	HEX 7E7E7E7E7E7E7D7D
			HEX 7C7B7B7A79787776
			HEX 75747271706E6C6B
			HEX 6967666462605E5B
			HEX 59575552504E4B49
			HEX 4643413E3B393633
			HEX 302D2A2724211E1B
			HEX 1815120F0C090603
			HEX FFFCF9F6F3F0EDEA
			HEX E7E4E1DEDBD8D5D2
			HEX CFCCC9C6C4C1BEBC
			HEX B9B6B4B1AFADAAA8
			HEX A6A4A19F9D9B9998
			HEX 969493918F8E8D8B
			HEX 8A89888786858484
			HEX 8382828181818181
			HEX 8181818181818282
			HEX 8384848586878889
			HEX 8A8B8D8E8F919394
			HEX 9698999B9D9FA1A4
			HEX A6A8AAADAFB1B4B6
			HEX B9BCBEC1C4C6C9CC
			HEX CFD2D5D8DBDEE1E4
			HEX E7EAEDF0F3F6F9FC
			HEX 000306090C0F1215
			HEX 181B1E2124272A2D
			HEX 303336393B3E4143
			HEX 46494B4E50525557
			HEX 595B5E6062646667
			HEX 696B6C6E70717274
			HEX 75767778797A7B7B
			HEX 7C7D7D7E7E7E7E7E
			HEX 7E7E7E7E7E7E7D7D
			HEX 7C7B7B7A79787776
			HEX 75747271706E6C6B
			HEX 6967666462605E5B
			HEX 59575552504E4B49
			HEX 4643413E3B393633
			HEX 302D2A2724211E1B
			HEX 1815120F0C090603
			HEX FFFCF9F6F3F0EDEA
			HEX E7E4E1DEDBD8D5D2
			HEX CFCCC9C6C4C1BEBC
			HEX B9B6B4B1AFADAAA8
			HEX A6A4A19F9D9B9998
			HEX 969493918F8E8D8B
			HEX 8A89888786858484
			HEX 8382828181818181
			HEX 8181818181818282
			HEX 8384848586878889
			HEX 8A8B8D8E8F919394
			HEX 9698999B9D9FA1A4
			HEX A6A8AAADAFB1B4B6
			HEX B9BCBEC1C4C6C9CC
			HEX CFD2D5D8DBDEE1E4
			HEX E7EAEDF0F3F6F9FC
			HEX 000306090C0F1215
			HEX 181B1E2124272A2D
			HEX 303336393B3E4143
			HEX 46494B4E50525557
			HEX 595B5E6062646667
			HEX 696B6C6E70717274
			HEX 75767778797A7B7B
			HEX 7C7D7D7E7E7E7E7E
			HEX 7E7E7E7E7E7E7D7D
			HEX 7C7B7B7A79787776
			HEX 75747271706E6C6B
			HEX 6967666462605E5B
			HEX 59575552504E4B49
			HEX 4643413E3B393633
			HEX 302D2A2724211E1B
			HEX 1815120F0C090603
			HEX FFFCF9F6F3F0EDEA
			HEX E7E4E1DEDBD8D5D2
			HEX CFCCC9C6C4C1BEBC
			HEX B9B6B4B1AFADAAA8
			HEX A6A4A19F9D9B9998
			HEX 969493918F8E8D8B
			HEX 8A89888786858484
			HEX 8382828181818181
			HEX 8181818181818282
			HEX 8384848586878889
			HEX 8A8B8D8E8F919394
			HEX 9698999B9D9FA1A4
			HEX A6A8AAADAFB1B4B6
			HEX B9BCBEC1C4C6C9CC
			HEX CFD2D5D8DBDEE1E4
			HEX E7EAEDF0F3F6F9FC
			HEX 000306090C0F1215
			HEX 181B1E2124272A2D
			HEX 303336393B3E4143
			HEX 46494B4E50525557
			HEX 595B5E6062646667
			HEX 696B6C6E70717274
			HEX 75767778797A7B7B
			HEX 7C7D7D7E7E7E7E7E
			HEX 7E7E7E7E7E7E7D7D
			HEX 7C7B7B7A79787776
			HEX 75747271706E6C6B
			HEX 6967666462605E5B
			HEX 59575552504E4B49
			HEX 4643413E3B393633
			HEX 302D2A2724211E1B
			HEX 1815120F0C090603
CODEEND                  
*
                
          	