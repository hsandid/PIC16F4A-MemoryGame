	title	"t1"
	list	p=16f84A
	radix	hex
	include	"p16f84A.inc"

;INITIALIZING THE GENERAL PURPOSE REGISTERS INSIDE OF THE PIC 
;HERE IS THE PURPOSE OF THESE REGISTERS
; C1-A1 .... A2-E2 : THESE ARE THE REGISTERS HOLDING INFO ABOUT THE CARDS => THE FIRST THREE BITS HOLD THE LETTER IDENTIFIER (000 IS A , 001 IS B , 010 IS C ... ) , THE 4TH BIT HOLDS THE 'OPENED/CLOSED' CONDITION , THE 5TH BIT HOLDS THE 'ALREADY OPENED / NEVER OPENED' CONDITION ( FOR MODE 3 ).
; COUNT 1 - 2- 3 -4 -5 : THESE ARE USED IN THE DELAY FUNCTIONS
; POS : THIS HAS TWO DIFFERENT PURPOSES DEPENDING ON WHETHER WE ARE IN A MODE OF MENU => IN MENU : THIS KEEPS TRACK OF WHETHER WE ARE IN POS1 , POS2 , OR POS3 ( '1' , '2' , '3' ). IN THE MODES IT KEEPS TRACK OF THE SECOND HEXADECIMAL NUMBER ASSOCIATED WITH THE DDRAM ADDRESS OF THE CURSOR
; PUD : THIS IS USED IN THE MODES TO KEEP TRACK OF THE FIRST HEXADECIMAL NUMBER FOR THE DDRAM ADDRESS OF THE CURSOR
; STATE : THIS REGISTER IS USED TO KEEP TRACK OF WHICH MENU / MODE WE ARE IN , THIS IS ESPECIALLY HELPFUL WHEN WORKING WITH INTERRUPTS . THE FIRST TWO BITS REPRENSENT THE ACTUAL MENU/MODE ( 00 IS MENU , 01 IS MODE-1 , 10 IS MODE-2 , 11 IS MODE-3 ) . THE FIFTH BIT IS USED IN MODE-3 TO SPECIFIY IF THE PLAYER HAS A NEGATIVE SCORE OF '13' , WHICH LEDS TO SPECIFIC ENDGAME CONDITIONS.
; STATE (cont'd) : THE SEVENTH BIT IS USED IN ALL MODES TO DETERMINE IF WE HAVE ALREADY OPENED ONE CARD AND ARE WAITING FOR THE SECOND CARD , OR IF WE HAVE NOT OPENED A CARD YET.
; TEMP : THIS IS A REGISTER USED TO HOLD TEMPORARY VALUES IN CASE WE WANT TO DO CALCULATIONS , OR WE NEED TO PASS A PARAMETER TO A CERTAIN FUNCTION ( example : Function 'prtScore' )
; TEid1-2: WE USE THIS REGISTER TO HOLD THE 'ADDRESS NUMBER' REPRESENTING A REGISTER HOLDING A CARD . ITS USED MAINLY IN INDIRECT ADDRESSING WHEN WE HAVE TWO CARDS . WE ALREADY HAVE 'PUD/POS' TO HOLD THE POSITION OF THE CURSOR , BUT WE NEED THIS REGISTER TO SOMEHOW IDENTIFY THE LAST CARD SELECTED.
; TEdat1-2: WE USE THIS REGISTER WITH THE PREVIOUS REGISTER 'TEidx' AND INDIRECT ADDRESSING TO OBTAIN THE DATA CONTAINED IN THE SELECTED CARDS AND CHECK FOR A FAIL/MATCH.
; TEMPX-TEMPY : THESE REGISTERS ARE USED TO STORE THE VALUES OF PUD/POS , WHEN WE NEED TO MOVE THE CURSOR TO CHECK OTHER REGISTERS FOR MATCH/FAIL CONDITION.
; PENAL : USED IN MODE-1 TO KEEP TRACK OF THE NUMBER OF MISTAKES THE PLAYER MAKES . THIS REGISTER IS INITIALIZED AT ZERO AND IS INCREMENTED EVERY TIME THE PLAYER MAKES A MISTAKE.
; MATCH : USED IN ALL MODES TO KEEP TRACK OF THE NUMBER OF MATCHES , IT IS INITIALIZED AT ZERO AND TRIGGERS AN ENDGAME CONDITION ONCE IT REACHES SIX.
; GUARD : USED IN ASSOCIATION WITH 'TEMP' IN CERTAIN LOOP CONDITIONS TO CHECK IF A NUMBER IS IN A CERTAIN RANGE.
; TMGUA : USED IN MODE-2 TO KEEP TRACK OF HOW MUCH TIME IS LEFT / HOW MUCH TIME BONUS SHOULD BE ADDED TO THE FINAL SCORE . IT IS INITIALIZED AT NINE AND TRIGGERS AN ENDGAME CONDITION WHEN IT REACHES ZERO.
; SCORE : USED TO KEEP TRACK OF THE FINAL SCORE IN MODE 3.
; NEGT : USED TO KEEP TRACK OF THE NEGATIVE SCORE IN MODE 3.



C1	   EQU	d'12'
A1	   EQU	d'13'	
E1	   EQU	d'14'
F1	   EQU	d'15'
B1	   EQU	d'16'
D1	   EQU	d'17'	
B2	   EQU	d'18'
D2	   EQU	d'19'	
F2	   EQU	d'20'
C2	   EQU	d'21'
A2	   EQU	d'22'
E2	   EQU	d'23'
COUNT1 EQU	d'24'
COUNT2 EQU	d'25'
COUNT3 EQU	d'26'
COUNT4 EQU	d'27'
COUNT5 EQU	d'28'
POS	   EQU	d'29'	 
STATE  EQU	d'30'
PUD	   EQU	d'31'
TEMP   EQU	d'32'		
TEid1  EQU	d'33'
TEid2  EQU	d'34'	
TEdat1 EQU	d'35'
TEdat2 EQU	d'36'
TEMPX  EQU	d'37'
TEMPY  EQU	d'38'
PENAL  EQU	d'39'
MATCH  EQU	d'40'
GUARD  EQU	d'41'
TIMER  EQU	d'42'
TMGUA  EQU	d'43'
SCORE  EQU	d'44'
NEGT   EQU	d'45'


;WE IDENTIFY THE ADDRESS FOR THE MAIN CODE ( 0X00 ) AND THE ADDRESS FOR THE INTERRUPT CODE (0X04)
;ADDRESS 0X00 : WE GO TO THE 'START' LABEL WHICH BEGINS OUR MAIN CODE WITH THE INITIALIZATION AND THE INFINITE LOOPS
;ADDRESS 0X04 : WE COME HERE AFTER AN INTERRUPT , WITH TWO POSSIBLE PATH DEPENDING ON THE ORIGIN OF THE INTERRUPT
;IF THE ORIGIN OF THE INTERRUPT IS RB0-RB4 ( MENU + ALL MODES ) , WE GO TO THE 'mainInt' FUNCTION .
;IF THE ORIGIN OF THE INTERRUPT IS TMR0 ( MODE 2 ONLY ) , WE GO TO THE 'TMR' FUNCTION .

	ORG	0x0
	GOTO START
	ORG 0x4
	BTFSC	INTCON,RBIF
	GOTO	mainInt
	BTFSC	INTCON,T0IF
	GOTO	TMR

; START [] INTERRUPT FUNCTIONS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

;['mainInt'] : In this function we check the state ( which menu/mode we are in )
;and we go to the appropriate function.
;The state is initialized in the 'MAIN' code before each function

mainInt:

		BTFSC	STATE,1
		GOTO	mdstate
		BTFSC	STATE,0
		GOTO	mdstate
		GOTO	mnState
		
; HERE ARE ALL THE FUNCTIONS RE-USED BY THE MENU AND MODES 
; START [] RE-USED CODE 

;['bckmenu'] : Used to go back to 'MENU' without enabling back interrupts.
bckmn:		

		BCF		INTCON,RBIF
		GOTO	menu

;['clRBF'] clears the rbf flag associated to rb0-rb4 interrupts + resets the GIE flag to 1 ( which says we are exiting the 
;interrupt function and can use other interrupts again ).

clRBF:
		BCF		INTCON,RBIF
		RETFIE
		
		
		
;['buz'] is the function associated with the buzzer. It's used in almost every mode

buz:

		BSF		PORTB,0
		call	delay5sec
		BCF		PORTB,0
		RETURN

;['buzc001'] is the function associated with the buzzer + return to the infinite loop. It's used in almost every mode when we have an error ( i.e. user presses right/left when on the edge of the cards table )

buzc001:
		CALL 	buz
		BCF		INTCON,RBIF
		RETFIE
		
;['redled'] is the function associated with the Red LED. It's used in almost every mode

redled:
		BSF		PORTB,2
		CALL	delay5sec	
		BCF		PORTB,2
		RETURN


;['greenled'] is the function associated with the Green LED. It's used in almost every mode

greenled:
		BSF		PORTB,3
		CALL	delay5sec	
		BCF		PORTB,3
		RETURN	
		
		
;['mdState'] : This function is associated to all modes . We check which button was pressed and go to the appropriate function.
		
mdstate: 
		BTFSS	PORTB,7
		GOTO	enMd
		
		BTFSS	PORTB,6
		GOTO	udMd

		BTFSS	PORTB,5
		GOTO	riMd

		BTFSS	PORTB,4
		GOTO	leMd
		
		CALL	addCur
		GOTO	clRBF
		
		
;['riMd'] : This function is entered if we press the right button in any mode. The PUD/POS counters are increment correctly , and we check if we are on the right edge while moving , if so we do not move and only
;activate the buzzer.
riMd:	
		MOVF	POS,0
		MOVWF	POS
		MOVWF	TEMP
		MOVLW	b'00101'
		SUBWF	TEMP
		BTFSC	STATUS,Z
		GOTO	buzc001
		MOVF	PUD,0
		CALL    simPorta
		
		
		INCF	POS
		MOVF	POS,0
		CALL    simPorta

		GOTO	clRBF

;['leMd'] : This function is entered if we press the left button in any mode. The PUD/POS counters are increment correctly , and we check if we are on the left edge while moving , if so we do not move and only
;activate the buzzer.
leMd:	
		MOVF	POS,0
		MOVWF	POS
		MOVWF	TEMP
		MOVLW	b'00000'
		SUBWF	TEMP
		BTFSC	STATUS,Z
		GOTO	buzc001
	

		MOVF	PUD,0
		CALL    simPorta
		
		
		DECF	POS
		MOVF	POS,0
		CALL    simPorta

		GOTO	clRBF	
		
;[udMd,ign ,ign2]: Functions associated to the up/down button in all modes
;POS and PUD are incremented properly to switch lines 


udMd:


		MOVLW	b'01100'
		SUBWF	PUD

		BTFSC	STATUS,Z
		GOTO	ign
		MOVWF	PUD
		GOTO	ign2
ign:	MOVLW	b'01000'
		MOVWF	PUD
		
ign2:	
		MOVF	PUD,0
		CALL    simPorta
		
		
	
		MOVF	POS,0
		CALL    simPorta

		GOTO	clRBF
		
;[enMd,ixa ,ixa2]: Functions associated to the confirm button in all modes
;We use it to display the letters selected , and then lead into function which will check whether or not the cards match	
enMd:
		MOVF	PUD,0
		SUBLW	b'01100'
		BTFSC	STATUS,Z
		GOTO ixa
		MOVLW	d'12'
		GOTO ixa1
ixa:	MOVLW	d'18'	
ixa1:	MOVWF	TEMP
		MOVF	POS,0	
		ADDWF	TEMP
		MOVF	TEMP,0
		MOVWF	FSR
		BTFSS	INDF,3
		GOTO	displ
		CALL	buz
		CALL	addCur
		GOTO	clRBF
		

		
;['notEmpty']	: If we have two cards selected , we checked if they match or not. If they match we enter the 'matcc' function , if they do not match we enter the 'arl' function.
notEmpty:

		MOVF	FSR,0
		MOVWF	TEid1
		MOVF	INDF,0
		MOVWF	TEdat1
		MOVF	TEid2,0
		MOVWF	FSR
		MOVF	INDF,0
		MOVWF	TEdat2
		MOVF	TEdat1,0
		XORWF	TEdat2,0
		MOVWF	TEMP
		BTFSC	TEMP,2
		GOTO	arl
		BTFSC	TEMP,1
		GOTO	arl
		BTFSC	TEMP,0
		GOTO	arl
		
		GOTO	matcc
		
;['displ','chkbit1','chkbit2','aDisp','bDisp','cDisp','dDisp','eDisp','fDisp'] : This function is used when we click on a card to display the letter associated with that card.
;We used indirect addressing to proceed.	

displ:
		BSF		INDF,3
		BTFSC	INDF,2
		GOTO	chkbit2
		BTFSC	INDF,1
		GOTO	chkbit1
		BTFSC	INDF,0
		GOTO	bDisp
		GOTO	aDisp

chkbit1:
		BTFSC	INDF,0
		GOTO	dDisp
		GOTO	cDisp
chkbit2:
		
		BTFSC	INDF,0
		GOTO	fDisp
		GOTO	eDisp
	
aDisp:	
		CALL A	
		GOTO chkMat

bDisp:	
		CALL Bl
		GOTO chkMat

cDisp:	
		CALL Cl
		GOTO chkMat

dDisp:	
		CALL D
		GOTO chkMat

eDisp:	
		CALL E
		GOTO chkMat

fDisp:	
		CALL Fl
		GOTO chkMat
		
		
		
;['prtScore' , 'chk0' till 'chk18'] : Used in Mode-2 and Mode-3 to print the updated scores

prtScore:

		MOVLW	d'0'
		SUBWF	TEMP,0
		BTFSS	STATUS,Z
		GOTO	chk0
		CALL	numInit
		CALL	ZERO	
		CALL	doSpace
		RETURN

chk0:	DECFSZ	TEMP,f
		GOTO	chk1
		CALL	numInit
		CALL	ONE	
		CALL	doSpace
		RETURN

chk1:	DECFSZ	TEMP,f
		GOTO	chk2
		CALL	numInit
		CALL	TWO	
		CALL	doSpace
		RETURN

chk2:	DECFSZ	TEMP,f
		GOTO	chk3
		CALL	numInit
		CALL	THREE	
		CALL	doSpace
		RETURN

chk3:	DECFSZ	TEMP,f
		GOTO	chk4
		CALL	numInit
		CALL	FOUR
		CALL	doSpace
		RETURN

chk4:	DECFSZ	TEMP,f
		GOTO	chk5
		CALL	numInit
		CALL	FIVE
		CALL	doSpace
		RETURN

chk5:	DECFSZ	TEMP,f
		GOTO	chk6
		CALL	numInit
		CALL	SIX
		CALL	doSpace
		RETURN

chk6:	DECFSZ	TEMP,f
		GOTO	chk7
		CALL	numInit
		CALL	SEVEN
		CALL	doSpace
		RETURN

chk7:	DECFSZ	TEMP,f
		GOTO	chk8
		CALL	numInit
		CALL	EIGHT
		CALL	doSpace	
		RETURN

chk8:	DECFSZ	TEMP,f
		GOTO	chk9
		CALL	numInit
		CALL	NINE
		CALL	doSpace
		RETURN

chk9:	DECFSZ	TEMP,f
		GOTO	chk10
		CALL	numInit
		CALL	ONE
		CALL	numInit
		CALL	ZERO
		RETURN

chk10:	DECFSZ	TEMP,f
		GOTO	chk11
		CALL	numInit
		CALL	ONE
		CALL	numInit
		CALL	ONE
		RETURN

chk11:	DECFSZ	TEMP,f
		GOTO	chk12
		CALL	numInit
		CALL	ONE
		CALL	numInit
		CALL	TWO
		RETURN

chk12:	DECFSZ	TEMP,f
		GOTO	chk13
		CALL	numInit
		CALL	ONE
		CALL	numInit
		CALL	THREE
		RETURN

chk13:	DECFSZ	TEMP,f
		GOTO	chk14
		CALL	numInit
		CALL	ONE
		CALL	numInit
		CALL	FOUR
		RETURN	

chk14:	DECFSZ	TEMP,f
		GOTO	chk15
		CALL	numInit
		CALL	ONE
		CALL	numInit
		CALL	FIVE
		RETURN

chk15:	DECFSZ	TEMP,f
		GOTO	chk16
		CALL	numInit
		CALL	ONE
		CALL	numInit
		CALL	SIX
		RETURN

chk16:	DECFSZ	TEMP,f
		GOTO	chk17
		CALL	numInit
		CALL	ONE
		CALL	numInit
		CALL	SEVEN
		RETURN

chk17:	DECFSZ	TEMP,f
		GOTO	chk18
		CALL	numInit
		CALL	ONE
		CALL	numInit
		CALL	EIGHT
		RETURN

chk18:	
		CALL	numInit
		CALL	ONE
		CALL	numInit
		CALL	NINE
		RETURN
		

;['failBack'] : ; Come back from fail condition on any mode


failBack: 
		CALL	redled
		CALL	addCur
		CALL	cle
		BCF		STATE,7
		GOTO	clRBF


; END [] RE-USED CODE 


; HERE ARE ALL THE FUNCTIONS USED EXCLUSIVELY BY THE MENU  
; START [] MENU CODE 


;['mnState'] : If the actual state is 'MENU' , we enter this function
;We check which interrupt is at the origin of the interrupt function call
;If it's the right button (rb5) we enter 'riMenu' , if it's the confirm button (rb7) we enter the 'enMenu'

mnState: 
		BTFSS	PORTB,5
		GOTO	riMenu
		BTFSS	PORTB,7
		GOTO	enMenu
		BCF		INTCON,RBIF
		RETFIE


;['enMenu'] : This function is entered if the confirm button was pressed in the 'MENU'
;Bit 7 of the State Register is set to '1' , this is going to trigger an entry into a mode ( depending on the value of the 'POS' register )
;Notice how we do not enable all interrupts ( No 'RETFIE' instructions ) , this is to avoid any interrupt call during the initialization of the selected mode
enMenu: 
		BSF		STATE,7
		BCF		INTCON,RBIF
		GOTO	movlop
	
	
;['riMenu'] : This function is used when the right button is pressed in the menu
;We check the current position and go to the appropriate function to move 
;from a pos to another 
;!!!!!!!!!!!Watch out ! Pos1 does not mean position next to number '1' , same goes for pos2 and pos3 .
;I named them depending on how easy it was to check the bits in the POS register which indicates the actual position
;POS is initialized at zero when we enter the MENU state.


riMenu: 

		BTFSC	POS,1
		GOTO	riPos3to1
		BTFSC	POS,0
		GOTO	riPos2to3
		GOTO	riPos1to2
		
		
		
;['riPos3to1'] : This function handles going from pos 1 to pos 2 in the MENU

riPos3to1:	 

		MOVLW	b'01000'
		CALL    simPorta

		MOVLW	b'01011'
		CALL    simPorta
	
		CALL	doSpace

		MOVLW	b'01000'
		CALL    simPorta

		MOVLW	b'00101'
		CALL    simPorta

		CALL	STAR
	
		MOVLW	b'00000000'
		MOVWF	POS
		GOTO	clRBF
		
;['riPos2to3'] :This function handles going from pos 2 to pos 3 in the MENU		

riPos2to3:	

		MOVLW	b'01000'
		CALL    simPorta

		MOVLW	b'01000'
		CALL    simPorta
	
		CALL	doSpace
		
		MOVLW	b'01000'
		CALL    simPorta

		MOVLW	b'01011'
		CALL    simPorta
		
		CALL	STAR
		
		MOVLW	b'00000011'
		MOVWF	POS
		GOTO	clRBF

;['riPos1to2'] :This function handles going from pos 3 to pos 1 in the MENU


riPos1to2:

		MOVLW	b'01000'
		CALL    simPorta

		MOVLW	b'00101'
		CALL    simPorta
		
		CALL	doSpace
		
		MOVLW	b'01000'
		CALL    simPorta

		MOVLW	b'01000'
		CALL    simPorta
		
		CALL	STAR
		
		MOVLW	b'00000001'
		MOVWF	POS
		GOTO	clRBF

; END [] MENU CODE 


; HERE ARE ALL THE FUNCTIONS USED EXCLUSIVELY BY MODE-1  
; START [] MODE-1   CODE 

;['md1fail'] : Increments the number of fail and displays a symbol for the error if a certain threshold has been reached
;[hnar,nms,endlh,pmos,xkcd] are random labels used for looping purposes
md1fail:
		CALL	remCur
		MOVF	PENAL,0	
		MOVWF	TEMP
		MOVLW	d'11'
		MOVWF	GUARD
		MOVLW	b'01000'
		MOVWF	PUD
		CALL    simPorta
		MOVLW	b'01001'
		MOVWF	POS
		CALL    simPorta
		CALL	blkbox	
hnar:	DECFSZ	GUARD,F
		GOTO	nmos
		GOTO	failBack
nmos:	DECFSZ	TEMP,F	
		GOTO	endlh
		GOTO	failBack
endlh:	DECFSZ	GUARD,F
		GOTO	pmos
		GOTO	failBack
pmos	DECFSZ	TEMP,F
		GOTO	xkcd
		GOTO	failBack
xkcd:	CALL	blkbox
		GOTO	hnar

;['SUPER','flash3'] :Write SUPER & light associated leds. Go back to endgame condition when done.
;We have the 'flash3' label here , which is used to light up the LEDS in case of a win in MODE-3.

		

SUPER:

		CALL	Sl

		CALL	U

		CALL	P

		CALL	E	

		CALL	Rl

flash3:
		CALL	delay5sec
		
		CALL	greenled
		CALL	redled
		CALL	greenled
		CALL	redled
		CALL	greenled

		GOTO	bckmn
;['AVG']:Write AVG & light associated leds. Go back to endgame condition when done.
AVG:

		CALL	A

		CALL	V

		CALL	G
		
		CALL	delay5sec
		CALL	greenled

		GOTO	bckmn
		
;['WEAK'] : Write WEAK & light associated leds. Go back to endgame condition when done.
WEAK:


		CALL	Wl

		CALL	E

		CALL	A

		CALL	K

		CALL	delay5sec

		CALL	redled

		GOTO	bckmn

; END [] MODE-1   CODE 


; HERE ARE ALL THE FUNCTIONS USED EXCLUSIVELY BY MODE-2 
; START [] MODE-2  CODE 


;['TMR','RETX','tmInc' ,'timEnd'] : Every time the TMR0  interrupt is activated we enter TMR , which will decrease the 'TIMER' register
;till it reaches zero ( this takes 10 seconds at clock frequency 4MHZ , with 'TIMER' initialized at a value of 76 and appropriate configuration of
; the 'OPTION' register ). When we reach a countdown of 10 seconds , we decrement the value
; of 'TMGUA' ( or timer guard ) , which starts at a value of 9 ( to represent the 90 seconds of the mode) .The displayed value on the pic 
;is modified according to 'TMGUA'. Once 'TMGUA' reaches zero , the time is over and move on to the endgame with a value of 'TMGUA' equal to zero.
;'RETX','tmInc' ,'timEnd' labels are used for looping conditions.

TMR:
		DECFSZ	TIMER,f
		GOTO	RETX

		MOVLW	d'76'
		MOVWF	TIMER
		GOTO	tmInc
		

RETX:	CALL	addCur
		BCF	INTCON,2
		RETFIE

tmInc:

		MOVLW	b'01000'
		CALL    simPorta

		MOVLW	b'01101'
		CALL    simPorta
	
		DECF	TMGUA	

		CALL	numInit

		MOVLW	d'8'
		SUBWF	TMGUA,0
		BTFSC	STATUS,Z
		CALL	EIGHT	
		
		
		MOVLW	d'7'
		SUBWF	TMGUA,0
		BTFSC	STATUS,Z
		CALL	SEVEN
		

		MOVLW	d'6'
		SUBWF	TMGUA,0
		BTFSC	STATUS,Z
		CALL	SIX
	

		MOVLW	d'5'
		SUBWF	TMGUA,0
		BTFSC	STATUS,Z
		CALL	FIVE
		
		
		MOVLW	d'4'
		SUBWF	TMGUA,0
		BTFSC	STATUS,Z
		CALL	FOUR
		

		MOVLW	d'3'
		SUBWF	TMGUA,0
		BTFSC	STATUS,Z
		CALL	THREE
		

		MOVLW	d'2'
		SUBWF	TMGUA,0
		BTFSC	STATUS,Z
		CALL	TWO
		

		MOVLW	d'1'
		SUBWF	TMGUA,0
		BTFSC	STATUS,Z
		CALL	ONE
		

		MOVLW	d'0'
		SUBWF	TMGUA,0
		BTFSC	STATUS,Z
		GOTO	timEnd

		MOVF	PUD,0
		CALL    simPorta

		MOVF	POS,0
		CALL    simPorta
		

		GOTO	RETX


timEnd:
		CALL	ZERO	
		GOTO	endgame
		
		
;['md2endgamechk']: Endgame check for 'MODE-2'
;It is triggered if TMGUA reaches zero , or the value of the 'MATCH' register is equal to six.
;The final score is displayed on the screen , and we return to the 'MENU' after a small delay.


md2endgamechk:

			MOVLW	b'01000'
			CALL    simPorta

			CALL	Sl	
			CALL	Cl	
			CALL	Ol
			CALL	Rl
			CALL	E	
			CALL	doSpace

			
			
			MOVF	TMGUA,0
			ADDWF	MATCH,0
			MOVWF	TEMP

			MOVF	TMGUA,0
			ADDWF	MATCH,F
			MOVF	MATCH,0
			MOVWF	TEMP

			CALL	prtScore
			CALL	delay5sec
			BCF		INTCON,RBIF
			BCF		INTCON,2
			BCF		INTCON,5
			GOTO	menu
	
;['md2fail']: Mode 2 has no fail condition related to errors by the players
;This function is just used to redirect the interrupt function to the main loop
md2fail:
		GOTO	failBack

; END [] MODE-2  CODE 


; HERE ARE ALL THE FUNCTIONS USED EXCLUSIVELY BY MODE-2 
; START [] MODE-3  CODE 

;['md3UpPos'] : We enter this function when we have a match in MODE-3 . We increment the MATCH register , update the positive score and the main score on the PIC LED , then go back to the common MATCH check to see if MATCH is equal to SIX ( or if we should proceed to endgame )
md3UpPos:
		
		MOVLW	b'01000'
		CALL    simPorta

		MOVLW	b'01101'
		CALL    simPorta

		MOVF	MATCH,0
		MOVWF	TEMP

		CALL	prtScore
		
		INCF	SCORE,F

		MOVLW	b'01100'
		CALL    simPorta

		MOVLW	b'01110'
		CALL    simPorta

		MOVF	SCORE,0
		MOVWF	TEMP

		CALL	prtScore

		GOTO	matccReg
		
;['md3endgamechk'] : Endgame function for mode-3 . Check if we the player has lost ( go to buzzer ) or won ( go to flash3 to light the leds up )


md3endgamechk: 

		MOVLW	b'01000'
		CALL    simPorta
		
		BTFSS	STATE,5
		GOTO	flash3
		CALL	delay5sec
		BCF		INTCON,RBIF
		GOTO	menu
		
;['md3fail','decScore','skipfz'] : Used to apply failure conditions in mode3	
;We check if the card has already been opened ( bit 4 of the card register , here taken as INDF ) to decide if we should remove a point or not for the card

md3fail:
		
		MOVF	TEid1,0
		MOVWF	FSR

		CALL	decScore

		MOVLW	d'13'
		SUBWF	NEGT,0
		BTFSC	STATUS,Z
		GOTO	firstCheck

		MOVF	TEid2,0
		MOVWF	FSR

		CALL	decScore	

		;['firstCheck'] : Print out the new Negative score and the new Total score

		
firstCheck: 

		MOVLW	b'01000'
		CALL    simPorta

		MOVLW	b'01001'
		CALL    simPorta

		MOVF	NEGT,0
		MOVWF	TEMP

		CALL	prtScore
	

		MOVLW	b'01100'
		CALL    simPorta

		MOVLW	b'01110'
		CALL    simPorta

		MOVF	SCORE,0
		MOVWF	TEMP

		CALL	prtScore

		MOVLW	d'13'
		SUBWF	NEGT,0
		BTFSS	STATUS,Z
		GOTO	failBack

		

		CALL	buz
		BSF		STATE,5
		GOTO	endgame	
	
decScore:
		BTFSS	INDF,4
		GOTO	skipfz
		DECF	SCORE,f
		INCF	NEGT,f

skipfz:
		BSF		INDF,4

		RETURN
		


; END [] MODE-3  CODE 



; THE FOLLWING CODE CAN NOT BE PUT IN A SPECIFIC CATEGORY , IT IS A MIX OF SPECIFIC AND RE-USED CODE
; START [] SPECIAL  CODE 

;['endgame']: Entered when an endgame condition is triggered in each respective mode
;[loz1,AZL,NOM1,NOM2,AZI] are random labels used for looping purposes
		

endgame: ;
	
		CALL	delay5sec
		CALL	cardinit
		CALL	remCur

		

	

		MOVLW	b'01100' ; SEPARATE INIT FOR THE CURSOR ON SECOND LINE !
		CALL    simPorta
	
		BTFSS	STATE,0
		GOTO	md2endgamechk ; No fail condition on mode2
		BTFSC	STATE,1
		GOTO	md3endgamechk
		
	
		;If passed condition , assume endgame for mode1 reached
		
		MOVLW	b'01001'
		CALL    simPorta

		MOVLW	d'5'
		MOVWF	TEMP

		MOVF	PENAL,0
		ADDWF	PENAL,0
		BTFSC	STATUS,Z
		GOTO	SUPER		
		
loz1:
		DECFSZ	TEMP,F
		GOTO	AZL
		GOTO	nom1
AZL:	DECFSZ	PENAL,F
		GOTO	loz1
		GOTO	SUPER			

nom1:
		MOVLW	d'5'
		MOVWF	TEMP
nom2:
		DECFSZ	TEMP,F
		GOTO	AZI	
		GOTO	WEAK
AZI:	DECFSZ	PENAL,F
		GOTO	nom2
		GOTO	AVG	
		
		
		


;['chkMat'] : check if we have already selected one card . If no card has been previously selected we save the address of the selected card for later access using indirect addressing.]
;Else , we go into function 'notEmpty'

chkMat:

		BTFSC	STATE,7
		GOTO	notEmpty
		BSF		STATE,7
		MOVF	FSR,0
		MOVWF	TEid2
		MOVF	PUD,0
		MOVWF	TEMPY
		MOVF	POS,0
		MOVWF	TEMPX
		CALL	cle
		CALL	addCur
		GOTO	clRBF
		
;['arl'] : ; cards selected do not match , close them and reset them as 'unopened' + add to the fail score

arl:
		

		MOVF	PUD,0
		CALL    simPorta
		MOVF	POS,0
		CALL    simPorta
		CALL	card
		MOVF	TEid1,0
		MOVWF	FSR
		BCF		INDF,3
		MOVF	TEid2,0
		MOVWF	FSR
		BCF		INDF,3
		MOVF	TEMPY,0
		MOVWF	PORTA
		CALL 	ET
		MOVF	TEMPX,0
		MOVWF	PORTA
		CALL 	ET
		CALL	card
		INCF	PENAL

		BTFSS	STATE,0
		GOTO	md2fail ; No fail condition on mode2
		BTFSS	STATE,1
		GOTO	md1fail
		GOTO	md3fail
		





;['matcc','matccReg','bckb']: This function is entered in case the player selects a matching pair , it increases the MATCH counter and redirects to other functions depending on the actual MODE

matcc:
		CALL	buz
		INCF	MATCH

		BTFSS	STATE,0
		GOTO	matccReg
		BTFSC	STATE,1
		GOTO	md3UpPos

matccReg:
		MOVLW	d'6'		
		SUBWF	MATCH,0

		BTFSS	STATUS,Z	
		GOTO	bckb
		GOTO	endgame

bckb:
		BCF		STATE,7
		CALL	cle
		CALL	addCur
		GOTO	clRBF

; END [] SPECIAL  CODE 












		







			



		





















;END OF CONFIRM BUTTON ACTIONS FOR MODE 1










; END [] INTERRUPT FUNCTIONS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

; START [] PROGRAM CODE

START:	
;SETTING INPUTS AND OUTPUTS
		BSF		STATUS,RP0
		MOVLW	b'10000111'
		MOVWF	OPTION_REG
		CLRF	TRISA
		CLRF	TRISB
		BSF		TRISB,4 
		BSF		TRISB,5 
		BSF		TRISB,6
		BSF		TRISB,7
		BCF		STATUS,RP0
		CLRF	INTCON
		BSF		INTCON,3
		CLRF	PORTB
		CLRF	PORTA

;INITIALIAZING CARD SET
		CALL	cardinit


init:
;INITIALIZING THE LED SCREEN 
		MOVLW	b'00010'
		CALL    simPorta

		MOVLW	b'00010'
		CALL    simPorta

		MOVLW	b'01000'
		CALL    simPorta

		CALL	remCur

		MOVLW	b'00000'
		CALL    simPorta

		MOVLW	b'00001'
		CALL    simPorta

		MOVLW	b'00000'
		CALL    simPorta

		MOVLW	b'00110'
		CALL    simPorta

		MOVLW	b'01000'
		CALL    simPorta

		MOVLW	b'00000'
		CALL    simPorta
;END OF LED SCREEN INIT
 
wlc:
;START 'WELCOME SCREEN'
		CALL	do2Space
		CALL	M
		CALL	E
		CALL	M
		CALL	Ol
		CALL	Rl
		CALL	Y
		CALL	do2Space
		CALL	G
		CALL	A
		CALL	M
		CALL	E
		CALL	delay5sec	
		
;END 'WELCOME SCREEN'

menu:
;START 'INITIALIZE MENU DISPLAY'
		CALL	clrsc
		MOVLW	b'00000000'
		MOVWF	STATE
		CALL	cle
		CALL	M
		CALL	Ol
		CALL	D
		CALL	E
		CALL	do2Space
		CALL	numInit
		CALL	ONE
		CALL	do2Space
		CALL	numInit
		CALL	TWO
		CALL	do2Space
		CALL	numInit
		CALL	THREE
		;GO TO INDEX NEXT TO '1'
		MOVLW	b'01000'
		CALL    simPorta
		MOVLW	b'00101'

		CALL    simPorta
		CALL	STAR
;END 'INITIALIZE MENU DISPLAY'

;INTERRUPT ARE MADE ACTIVE AGAIN
		BSF		INTCON,GIE

;INFINITE LOOP FOR MENU
movlop:	
		BTFSS	STATE,7
		GOTO	movlop
		BTFSC	POS,1
		GOTO	mode3
		BTFSC	POS,0
		GOTO	mode2
		GOTO	mode1
		GOTO 	movlop

		
;FOR PHASE 1 , WE ONLY COMPLETED THE CODE FOR MODE1
mode1:	
;START 'INITIALIZE MODE 1 DISPLAY AND REGISTERS'
		CALL	clrsc
		MOVLW	d'0'
		MOVWF	MATCH
		MOVWF	PENAL
		MOVLW	b'00000001'
		MOVWF	STATE
		CALL	cle
		CALL 	clrsc
		CALL	sixCard
		CALL	do2Space
		CALL	Sl
		CALL	symbol
		CALL	symbol
		CALL	symbol
		CALL	symbol
		CALL	symbol
		CALL	symbol
		CALL	Wl
		CALL	JUMPLINE
		CALL	sixCard
		CALL	cle
		CALL	addCur
;END 'INITIALIZE MODE 1 DISPLAY AND REGISTERS'

;INTERRUPT ARE MADE ACTIVE AGAIN
		BSF		INTCON,GIE

;INFINITE LOOP FOR MODE 1
		movlop1:	
		GOTO movlop1

;FOR PHASE 1 , WE DID NOT COMPLETE THE MODE2 CODE BELOW
mode2:	
;START 'INITIALIZE MODE 2 DISPLAY AND REGISTERS'
		CALL	clrsc
		MOVLW	b'00000010'
		MOVWF	STATE
		MOVLW	d'76'
		MOVWF	TIMER
		MOVLW	d'9' 
		MOVWF	TMGUA
		MOVLW	d'0'
		MOVWF	MATCH
		CALL	sixCard
		CALL	do2Space
		CALL	Rl
		CALL	E
		CALL	M
		CALL	doSpace
		CALL	T
		CALL	numInit
		CALL	NINE
		CALL	numInit
		CALL	ZERO
		CALL	JUMPLINE
		CALL	sixCard
		CALL	cle
		CALL	addCur
;END 'INITIALIZE MODE 2 DISPLAY AND REGISTERS'


;INTERRUPT ARE MADE ACTIVE AGAIN
		BSF		INTCON,GIE
		BSF		INTCON,T0IE

;INFINITE LOOP IN MODE 2 
		movlop2:	
		GOTO movlop2


		
;FOR PHASE 1 , WE DID NOT COMPLETE THE MODE3 CODE BELOW
mode3:
;START 'INITIALIZE MODE 3 DISPLAY AND REGISTERS'
		CALL	clrsc
		MOVLW	b'00000011'
		MOVWF	STATE
		MOVLW	d'13'
		MOVWF	SCORE
		MOVLW	d'0'
		MOVWF	NEGT
		MOVWF	MATCH
		CALL	clrsc
		CALL	sixCard
		CALL	do2Space
		CALL	MINUS
		CALL	numInit
		CALL	ZERO
		CALL	do2Space
		CALL 	PLUS	
		CALL	numInit
		CALL	ZERO
		CALL	JUMPLINE
		CALL	sixCard
		CALL	do2Space
		CALL	Sl
		CALL	Cl
		CALL	Ol
		CALL	Rl
		CALL	E
		CALL	doSpace
		CALL	numInit
		CALL	ONE
		CALL	numInit
		CALL	THREE
		CALL	cle
		CALL	addCur

;END 'INITIALIZE MODE 3 DISPLAY AND REGISTERS'

;INTERRUPT ARE MADE ACTIVE AGAIN
		BSF		INTCON,GIE

;INFINITE LOOP IN MODE 3 
		movlop3:	
		GOTO movlop3



card:	
;Display at cursor position the special card symbol used to represent a face-down card 
			MOVLW	b'11101'
			MOVWF	PORTA
			CALL	ET
		
			MOVLW	b'11011'
			MOVWF	PORTA
			CALL	ET
		 	RETURN

sixCard:
		CALL	card
		CALL	card
		CALL	card
		CALL	card
		CALL	card
		CALL	card
		RETURN

blkbox:
;Display at cursor position the special symbol used in Mode 1 : error 
			MOVLW	b'11111'
			MOVWF	PORTA
			CALL	ET
		
			MOVLW	b'11111'
			MOVWF	PORTA
			CALL	ET
		 	RETURN
		
symbol:		
;Display at cursor position a particular symbol present in each mode
			MOVLW	b'11010'
			MOVWF	PORTA
			CALL	ET
		
			MOVLW	b'10011'
			MOVWF	PORTA
			CALL	ET
		 	RETURN	


clrsc:
;clear display func
			MOVLW	b'00000'
			MOVWF	PORTA
			CALL	ET

			MOVLW	b'00001'
			MOVWF	PORTA
			CALL	ET
			RETURN



ET:
;ET function is used everytime we send data to the LCD
			BSF		PORTB,1
			NOP
			BCF		PORTB,1
			CALL	delay40ms
			RETURN	

doSpace:
;display a Space at cursor position
			MOVLW	b'10010'
			MOVWF	PORTA
			CALL	ET
			MOVLW	b'10000'
			MOVWF	PORTA
			CALL	ET
			RETURN

do2Space:
;display a Space at cursor position
			CALL	doSpace
			CALL	doSpace
			RETURN

JUMPLINE:
;Go to address 0x40 on the LCD display
		MOVLW	b'01100'
		CALL    simPorta
		MOVLW	b'00000'
		CALL    simPorta
		RETURN

A:
;display Letter A at cursor position
		MOVLW	b'10100'
		CALL    simPorta
		MOVLW	b'10001'
		CALL    simPorta
		RETURN
Bl:		
;display Letter B at cursor position
		MOVLW	b'10100'
		CALL    simPorta
		MOVLW	b'10010'
		CALL    simPorta
		RETURN
Cl:	
;display Letter C at cursor position
		MOVLW	b'10100'
		CALL    simPorta
		MOVLW	b'10011'
		CALL    simPorta
		RETURN
D:	
;display Letter D at cursor position
		MOVLW	b'10100'
		CALL    simPorta
		MOVLW	b'10100'
		CALL    simPorta
		RETURN


E:	
;display Letter E at cursor position
		MOVLW	b'10100'
		CALL    simPorta
		MOVLW	b'10101'
		CALL    simPorta
		RETURN

Fl:		
;display Letter F at cursor position
		MOVLW	b'10100'
		MOVWF	PORTA	
		CALL	ET
		MOVLW	b'10110'
		CALL    simPorta
		RETURN

G:
;display Letter G at cursor position
		MOVLW	b'10100'
		CALL    simPorta

		MOVLW	b'10111'
		CALL    simPorta
		RETURN
K:
;display Letter K at cursor position
		MOVLW	b'10100'
		CALL    simPorta

		MOVLW	b'11011'
		CALL    simPorta
		RETURN
M:
;display Letter m at cursor position
		MOVLW	b'10100' 
		CALL    simPorta
		MOVLW	b'11101'
		CALL    simPorta
		RETURN
Ol:
;display Letter O at cursor position		
		MOVLW	b'10100'
		CALL    simPorta
		MOVLW	b'11111'
		CALL    simPorta
		RETURN
P:
;display Letter P at cursor position
		MOVLW	b'10101'
		CALL    simPorta

		MOVLW	b'10000'
		CALL    simPorta
		RETURN
Rl:
;display Letter R at cursor position		
		MOVLW	b'10101'
		CALL    simPorta
		MOVLW	b'10010'
		CALL    simPorta
		RETURN
Sl:
;display Letter S at cursor position
		MOVLW	b'10101'
		CALL    simPorta
		MOVLW	b'10011'
		CALL    simPorta
		RETURN
T:
;display Letter T at cursor position
		MOVLW	b'10101' 
		CALL    simPorta
		MOVLW	b'10100'
		CALL    simPorta
		RETURN
U:
;display Letter U at cursor position
		MOVLW	b'10101'
		CALL    simPorta

		MOVLW	b'10101'
		CALL    simPorta
		RETURN

V:
;display Letter V at cursor position
		MOVLW	b'10101'
		CALL    simPorta

		MOVLW	b'10110'
		CALL    simPorta
		RETURN
Wl:
;display Letter W at cursor position
		MOVLW	b'10101'
		CALL    simPorta
		
		MOVLW	b'10111'
		CALL    simPorta
		RETURN
Y:
;display Letter Y at cursor position
		MOVLW	b'10101'
		CALL    simPorta

		MOVLW	b'11001'
		CALL    simPorta
		RETURN

numInit:

		MOVLW	b'10011'
		CALL    simPorta
		
		RETURN

ZERO:
;display Number 0 at cursor position
	
		MOVLW	b'10000'
		CALL    simPorta
		RETURN
ONE:
;display Number 1 at cursor position
		
		MOVLW	b'10001'
		CALL    simPorta
		RETURN

TWO:
;display Number 2 at cursor position
		
		MOVLW	b'10010'
		CALL    simPorta
		RETURN

THREE:
;display Number 3 at cursor position
	
		MOVLW	b'10011'
		CALL    simPorta
		RETURN
FOUR:
;display Number 4 at cursor position
		
		MOVLW	b'10100'
		CALL    simPorta
		RETURN

FIVE:
;display Number 5 at cursor position
		
		MOVLW	b'10101'
		CALL    simPorta
		RETURN
SIX:
;display Number 6 at cursor position
	
		MOVLW	b'10110'
		CALL    simPorta
		RETURN

SEVEN:
;display Number 7 at cursor position
		
		MOVLW	b'10111'
		CALL    simPorta
		RETURN

EIGHT:
;display Number 8 at cursor position
		
		MOVLW	b'11000'
		CALL    simPorta
		RETURN

NINE:
;display Number 9 at cursor position
		
		MOVLW	b'11001'
		CALL    simPorta
		RETURN
		
PLUS:
;display Symbol + at cursor position		
		MOVLW	b'10010'
		CALL    simPorta
		MOVLW	b'11011'
		CALL    simPorta
		RETURN
MINUS:
;display Symbol - at cursor position
		MOVLW	b'10010'
		CALL    simPorta
		MOVLW	b'11101'
		CALL    simPorta
		RETURN
STAR:
;display Symbol * at cursor position		
		MOVLW	b'10010'
		CALL    simPorta

		MOVLW	b'11010'
		CALL    simPorta
		RETURN
cle:	

; Here we reset the cursor position to home
; Also we reset the registers tracking the position of the cursor
; (POS and PUD) to the home address

		MOVLW	b'00000'
		CALL    simPorta

		MOVLW	b'00010'
		CALL    simPorta

		MOVLW	b'01000'
		MOVWF	PUD

		MOVLW	b'00000'
		MOVWF	POS
	
		RETURN
	
cardinit:

; Here we initialize the card values inside each register + init match register

;c1 & c2
		MOVLW	b'00010'
		MOVWF	d'12'
		MOVWF	d'21'
;a1 & a2
		MOVLW	b'00000'
		MOVWF	d'13'
		MOVWF	d'22'
;e1 & e2
		MOVLW	b'00100'
		MOVWF	d'14'
		MOVWF	d'23'
;f1& f2
		MOVLW	b'00101'
		MOVWF	d'15'
		MOVWF	d'20'
;b1& b2
		MOVLW	b'00001'
		MOVWF	d'16'
		MOVWF	d'18'
;d1 & d2
		MOVLW	b'00011'
		MOVWF	d'17'
		MOVWF	d'19'
			
		RETURN

remCur:

; Here we set the cursor display option to '0'
		MOVLW	b'00000'
		CALL    simPorta

		MOVLW	b'01100'
		CALL    simPorta

		RETURN

addCur:

; Here we set the cursor display option to '1'
		MOVLW	b'00000'
		CALL    simPorta

		MOVLW	b'01110'
		CALL    simPorta

		RETURN


;START "DELAY FUNC : 40MS"
delay40ms: MOVLW	H'00'
		MOVWF	COUNT2
		MOVLW	D'52'
		MOVWF	COUNT1
loop40:	INCFSZ	COUNT2,F
		GOTO	loop40
		DECFSZ	COUNT1,F
		GOTO	loop40
		RETURN
;END "DELAY FUNC : 40MS"

;START "DELAY FUNC : 5SEC"
delay5sec:

			MOVLW	d'0'
			MOVWF	COUNT3
			MOVWF	COUNT4
			MOVLW	d'4'
			MOVWF	COUNT5
loop5sec:	INCFSZ	COUNT3,F
			goto 	loop5sec
			INCFSZ	COUNT4,F
			goto 	loop5sec
			DECFSZ	COUNT5,F
			goto 	loop5sec
			RETURN 


simPorta:
		MOVWF	PORTA
		CALL    ET
		RETURN
		
;END "DELAY FUNC : 5SEC"
		
END	
