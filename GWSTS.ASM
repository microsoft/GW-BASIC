; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   GWSTS - GW-BASIC Common Statement Support

COMMENT	*

--------- --- ---- -- ---------
COPYRIGHT (C) 1982 BY MICROSOFT
--------- --- ---- -- ---------

        *

;General Feature Switches (Not OEM Switches)
;
KANADT=0			;Japanese date format("[yy]yy/mm/dd")
STKEYF=1D			;Start number of string function keys
IBMCSR=IBMLIK			;IBM comp. cursor interface
FKEYCR=74O			;CR character for F-KEY display line
GWLEV2=0			;Version 2.0 of GW BASIC-86

;OEM Switches (ONLY INCLUDE IF ABSOLUTELY NECESSARY)
;
MCI=0
TETRA=0
MELCO=0
ZENITH=0

;Definition of scroll types
; Choice of scroll type is by switch SCROLT.
; Switches defined here are used to implement a specific SCROLT type.
; If other scroll types are needed then additional SCROLT types should be
;   defined here.
	INVLIN=SCROLT		;Invisible (function key) Line
	FKFSRL=(SCROLT-1) AND 1	;Clear fkeys/full scroll/rewrite fkeys

;Local Switches
;
	KEYFSW=0		;No KEY Function
	INTHND=SCP		;MSDOS Ctl-C interrupt handler
	CLRFMT=(MELCO-1) AND (ZENITH-1)	;New COLOR parameter format
	FKEYCR=27D		;IBM CR FKey display line graphic
	.SALL
	.RADIX	10

	EXTRN	CHRGTR:NEAR,SYNCHR:NEAR,SNERR:NEAR,FCERR:NEAR,GETBYT:NEAR
	EXTRN	USERR:NEAR


IF	CPM86  
CPMXIO	MACRO	DFUN
	MOV	CL,LOW OFFSET DFUN
	INT	340O		;CPM86 system call
ENDM 
ENDIF 

DOSIO	MACRO	DFUN
	MOV	AH,LOW OFFSET DFUN
	INT	33		;MS-DOS system call
ENDM 
	GDAT=42D		;MS-DOS Get Date Function
	SDAT=43D		;MS-DOS Set Date Function
	GTIM=44D		;MS-DOS Get Time Function
	STIM=45D		;MS-DOS Set Time Function
	PUBLIC	PATCHG
PATCHG:	DB	500D DUP(?)	;GW patch space
	PAGE	
	SUBTTL CLS,LOCATE,WIDTH (of screen),LCOPY

	PUBLIC	CLS,LOCATE,GWWID,LCOPYS,COLOR,GETLIN,SCRENF,SCREEN

DSEG	SEGMENT PUBLIC 'DATASG'		
	ASSUME DS:DSEG
	EXTRN	LINCNT:WORD,LINLEN:WORD,CSRY:WORD,CSRX:WORD,BUF:WORD
DSEG	ENDS

	EXTRN	GETFBC:NEAR
	EXTRN	SCRSTT:NEAR,SCRATR:NEAR
	EXTRN	SETCLR:NEAR,SWIDTH:NEAR
	EXTRN	LCPY:NEAR

	COMMA=","
	OPAREN="("
	CPAREN=")"
	QUOTE=34D
	BKSPC=8D
	CR=13D
	LF=10D
	PAGE	
;CLS: CLear Screen issues an escape sequence to clear
;     the CRT.  Sequences are ANSII standard whereas the machine
;     default is not.  CLS resets the graphics cursor position.
;ENTRY - none
;EXIT  - none
;USES  - none
;
	EXTRN	CLRSCN:NEAR
CLS:	CALL	SCNINT		;Test for optional parameter
	CMC	
	PUSHF	
	PUSH	AX
	CALL	EOSCHK		;Test for end of statement
	POP	AX
	POPF	
	PUSH	BX
	CALL	CLRSCN
	POP	BX
	RET	
	PAGE	
;LOCATE: Parse the following syntax:
;       LOCATE [Y] [, [X] [, [CURSOR] [, [START] [, [STOP] ]]]
;
	EXTRN	SCNPOS:NEAR
LOCATE:	CALL	SCNINT		;Get optional Y parameter
	JNB	YLCPRM		;Parameter present
	CALL	GTLINE		;Get the current screen position
YLCPRM:	MOV	DL,AL
	OR	AL,AL		;Test for LOCATE 0
	JZ	GOFCER
	SUB	DL,BYTE PTR KEYSW	;Increment if PF-keys are displayed
	CMP	DL,BYTE PTR LINCNT	;Check for parameter range
	JA	GOFCER
	PUSH	AX		;Save new Y location
	CALL	SCNINT		;Get optional X parameter
	JNB	XLCPRM		;Parameter present
	CALL	SCNPOS		;Get the current screen position
	MOV	AL,DH		;Default to current cursor position
XLCPRM:	MOV	DL,AL
	DEC	DL		;Dissallow LOCATE ,0
	CMP	DL,BYTE PTR LINLEN	;Check for parameter range
	JAE	GOFCER
	PUSH	AX		;Save new X
	CALL	SCNINT		;Cursor on/off - 0=off else on
	EXTRN	CSRATR:NEAR
	MOV	AH,LOW 377O	;Ensure non-zero
	JNB	LOCPR1		;Parameter 1 found
	XOR	AH,AH		;Flag as a default
LOCPR1:	PUSH	AX		;Push first parameter and flag
	CALL	SCNINT		;Get next parameter
	MOV	AH,LOW 377O	;Ensure non-zero flag
	JNB	LOCPR2		;Parameter 2 found
	XOR	AH,AH		;Flag as a default
LOCPR2:	PUSH	AX		;Push second parameter and flag
	CALL	SCNINT		;Get next parameter
	MOV	AH,LOW 377O	;Ensure non-zero flag
	JNB	LOCPR3		;Parameter 3 found
	XOR	AH,AH		;Flag as a default
LOCPR3:	PUSH	AX		;Push third parameter
	CALL	EOSCHK		;Check for end of statement
	MOV	DX,BX		;Save text pointer
	POP	CX
	POP	BX
	POP	AX		;Recover three parameters
	PUSH	DX		;Save text pointer
	CALL	CSRATR		;Set Cursor Attribute (OEM routine)
	JB	GFCERR		;Declare error from CSRATR
	POP	BX		;Text pointer
SETLOC:	MOV	AX,BX
	POP	CX
	POP	BX
	PUSH	AX
	MOV	BH,CL
	EXTRN	SCNLOC:NEAR
	MOV	AX,BX
	CALL	SCNLOC		;position cursor at line [AL], col [AH]
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CSRTYP:WORD
DSEG	ENDS
	EXTRN	CSRDSP:NEAR
	MOV	DX,AX		;Load cursor position
	MOV	AL,LOW 3D	;Signal for user cursor
	CALL	CSRDSP		;Set cursor
	POP	BX		;Restore text pointer
	RET	


GOFCER:	JMP	FCERR
	PAGE	
;GWWID: Parsing for WIDTH [X] [, [Y]]
;ENTRY - WIDTH LPRINT is not a possibility at this point.
;EXIT  - AL = X param
;        BX = text pointer
;
GWWID:	CALL	SCNINT		;Get X dimension
	JNB	XPRAM		;X param found
	MOV	AL,BYTE PTR LINLEN	;Use current as default
XPRAM:	PUSH	AX		;Save for RET to WIDTH
	PUSH	AX		;Save for GWWID use
	CALL	SCNINT		;Get Y dimension
	JNB	YPRAM		;Y param found
	MOV	AL,BYTE PTR LINCNT	;Use current as default
YPRAM:	PUSH	AX
	CALL	EOSCHK		;Must be at end of statement
	POP	AX
	CMP	AL,BYTE PTR LINCNT	;Set CC's for Y dimension change
	LAHF	
	MOV	CX,AX
	POP	AX
	CMP	AL,BYTE PTR LINLEN	;Set CC's for X dimension change
	LAHF	
	AND	AH,CH		;Set CC's for X OR Y change
	SAHF	
	JZ	GWWIDX		;No change - done
	PUSH	BX		;Save text pointer
	PUSH	AX		;save Width
	PUSH	CX		;save Height
	CALL	SWIDTH		;Machine dependent set logic
	POP	CX
	POP	AX
	JB	GFCERR		;Error detected within SWIDTH
	POP	BX		;Restore text pointer
GWWIDX:	POP	AX		;Return X dimension for WIDTH
	RET	

GFCERR:	JMP	FCERR

	PAGE	
;LCOPY: Copy the screen to the line printer.
;ENTRY - BX = text pointer
;EXIT  - BX = text pointer
LCOPYS:	MOV	DL,LOW 0	;default parm is 0
	JZ	NOPARM		;branch if end-of-statement
	CALL	GETBYT		;[DL]=parm
NOPARM:	CALL	EOSCHK		;Check for unwanted parameters
	PUSH	BX		;Save text pointer
	CALL	LCPY
	JB	GFCERR		;Error detected in low level routine
	POP	BX
	RET	
	PAGE	
	SUBTTL  COLOR,GETLIN,SCREEN (function and statement)
;COLOR: Set the foreground, background, and boarder attributes.
;       SYNTAX - COLOR [FOR] [,BACK [,BOARD]]
;       Where - FOR   = Foreground attribute
;               BACK  = Background attribute
;               BOARD = Boarder attribute
;
COLOR:	CALL	GTPRMS		;Get arbitrary number of int. parms.
COLOR1:	PUSH	BX		;Save text pointer
	MOV	BX,DI		;Get parameter buffer pointer
	CALL	SETCLR		;Check colors for validity
	JB	GFCERR		;Error detected by low level routine
	POP	BX
	RET	
	PAGE	
;GETLIN: Obtain the current cursor line number.
;EXIT - FAC = cursor line number
;       BX preserved
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	LINLEN:WORD,LINCNT:WORD,KEYSW:WORD
DSEG	ENDS
GETLIN:	CALL	GTLINE
	PUSH	BX
	XOR	BX,BX
	MOV	BL,AL
	CALL	MAKINT
	POP	BX
	CALL	CHRGTR
	RET	

;GTLINE: Get the line number of the character position to which the next
;character would be written.
;Entry - none
;Exit  - [AL] = line number
;Uses  - AH
;
GTLINE:	MOV	AL,BYTE PTR CSRY	;BX = cursor line number
	MOV	AH,BYTE PTR CSRX
	CMP	AH,BYTE PTR LINLEN
	JBE	GETLN0		;BRIF will not wrap before next char is output
	MOV	AH,BYTE PTR LINCNT	;AL=last valid line number
	DEC	AH		;Scroll always occurs on line [LINCNT]-1
	CMP	AL,AH
	JAE	GETLN0		;BRIF wrap will cause scroll
	INC	AL		;Else wrap will cause line number increment
GETLN0:	RET	
	PAGE	
;SCRENF: Obtain character from screen.
SCRENF:
	CALL	CHRGTR		;Eat the SCREEN token since SCREEN is
				;defined as a statement and the function
				;is dispatched to by EVAL.
	CALL	SYNCHR
	DB	OFFSET OPAREN	;Check for "("
	CALL	SCNINT		;Get Y parameter
	JB	FCERGO		;Parameter not present
	DEC	AL
	CMP	AL,BYTE PTR LINCNT	;Check range [1,LINCNT]
	JAE	FCERGO		;Out of range
	INC	AL
	PUSH	AX		;Y param.
	CALL	SCNINT		;Check for X param
	JB	FCERGO		;Error - no X param
	DEC	AL
	CMP	AL,BYTE PTR LINLEN	;Check range [1,LINLEN]
	JAE	FCERGO		;Out of range
	INC	AL
	PUSH	AX		;X param.
	CMP	AH,LOW OFFSET CPAREN	;Check terminator
	JE	SCRCHR		;End of params - go get char.
	CALL	SCNINT
	JB	FCERGO		;Error - no CPAREN and no Z param.
	CMP	AH,LOW OFFSET CPAREN	;Must now have CPAREN
	JNE	FCERGO
	CMP	AL,LOW 00O	;Is Z zero?
	JE	SCRCHR		;Yes - go get screen character
	POP	AX		;Retrieve X param
	POP	CX		;Retrieve Y param
	PUSH	BX		;Save text pointer
	MOV	BX,CX		;Call SCRATR with AX=X,BX=Y
	CALL	SCRATR		;Get screen attributes
	JMP	SHORT SCRENX

FCERGO:	JMP	FCERR

SCRCHR:	POP	AX		;Retrieve col number
	POP	CX		;Retrieve row number
	PUSH	BX		;Save the text pointer
	EXTRN	SCRINP:NEAR
	PUSH	DX
	MOV	DL,CL
	MOV	DH,AL
	STC			;Indicate call is from SCREEN function
	CALL	SCRINP		;[AX]=Read char at (DH,DL)
	MOV	BX,AX		;return result in BX
	POP	DX
SCRENX:	CALL	MAKINT		;Set FAC
	POP	BX		;Retrieve text pointer
	DEC	BX
	CALL	CHRGTR
	RET	
	PAGE	
;SCREEN: This statement has no standard syntax.  It is handled
;        by parsing single byte integers until end of statement.
;        Parameters may be null (appearance of a comma before an
;        expression is encountered).
;       SCRSTT (machine dependent) is called to process parameters
;       which are in a list which is headed by a one word parameter
;        count.  The remaining list entries are two bytes long.
;        The first byte is 0 if the SCREEN parameter was null.
;        The second byte is the parameter value if it is nonnull
;        or meaningless (if the parameter was null).

SCREEN:	CALL	GTPRMS		;Get single byte integer parms
	PUSH	BX
	MOV	BX,DI
	CALL	SCRSTT		;Process params
	JB	FCERGO		;Error detected in low level routine
	POP	BX		;Restore text pointer
	RET	


GTPRMS:	MOV	DI,OFFSET BUF	;Parameters stored in BUF
	XOR	CX,CX		;Initialize parameter count
	INC	DI		;Reserve parameter count location
SCRLOP:	INC	CX		;Count the param
	PUSH	CX
	PUSH	DI
	CALL	SCNINT		;Look for a parameter
	POP	DI
	POP	CX
	JZ	STTEND		;End of statement encountered
	JNB	PRMFND		;Parameter found (AH = separator)
	XOR	AX,AX		;Indicate a null parameter
PRMFND:	XCHG	AH,AL
	MOV	WORD PTR 0[DI],AX	;Load parameter to list
	INC	DI		;Next list entry
	INC	DI
	JMP	SHORT SCRLOP	;Go get next param


STTEND:	JB	NOPRM
	MOV	BYTE PTR 0[DI],LOW 255D	;Set param. exists flag
	MOV	BYTE PTR 1[DI],AL
	INC	CX
NOPRM:	DEC	CX
	MOV	DI,OFFSET BUF	;Reset list index
	MOV	BYTE PTR 0[DI],CL	;Head list with param count
	RET	
	PAGE	
	SUBTTL  PUT & GET (Distinguish Disk from Graphics)

	PUBLIC	PUT,GET

	EXTRN	DPUTG:NEAR,GPUTG:NEAR

;PUT: This code parses enough of the PUT/GET statement to
;GET: distinguish between the graphics and disk versions of
;     these commands.
;       The accepted technique is to search for a "(".  This
;       does not always allow for file number expressions which begin
;       with  "(".
;ENTRY: [BX] points to the character following the token.
;EXIT  - Exit is made by jumping to the appropriate PUT/GET
;        code.
;        [BX] - restored to entry value before call of PUT/GET code.

PUT:	MOV	CX,1		;Set PUT flag
	JMP	PARSE
GET:	XOR	CX,CX		;Set GET flag
PARSE:	PUSH	CX		;Save indication of PUT or GET
	PUSH	BX		;Save text pointer
	CMP	AL,LOW "("	;Test for "("
	JE	GRPVER		;branch if graphics version
	CMP	AL,LOW "@"	;test for relative GET/PUT
	JNE	DSKVER		;Disk code may have no "(" or "@"
GRPVER:	POP	BX		;Restore text pointer
	POP	AX
	JMP	GPUTG		;Go to graphics PUT/GET

DSKVER:	POP	BX		;Restore text pointer
	POP	AX		;Get PUT/GET flag
	JMP	DPUTG

	PAGE	
	SUBTTL  Parsing Routines for GWSTS
	PUBLIC	SCNINT,EOSCHK

;SCNINT: Test for an optional integer parameter.
;       If a comma or EOL is discovered assume parameter is missing.
;       Otherwise evaluate the parameter.
;EXIT - [AL] = parameter value
;       C set - no parameter found
;       C reset - parameter found
;USES - ALL
SCNINT:	DEC	BX
	CALL	CHRGTR
	JZ	NOMORE		;EOL - Param null
	CMP	AL,LOW OFFSET COMMA
	JZ	OMITD		;Comma found. Param null.
	CALL	GETBYT		;Evaluate parameter
	PUSH	AX		;Save parameter
	DEC	BX		;Prepare to test expression terminator
	CALL	CHRGTR
	JZ	TRMOK		;EOL caused termination - OK
	CMP	AL,LOW OFFSET COMMA
	JZ	TRMCOM		;Comma caused termination - OK
	CMP	AL,LOW OFFSET CPAREN	;CPAREN caused termination - OK
	JZ	TRMCOM
	POP	AX		;Retrieve param.
	JMP	FCERR		;All other terminators not OK

TRMCOM:	INC	BX		;Move over comma
TRMOK:	MOV	CL,AL		;Save terminator
	POP	AX		;Retrieve parameter value
	MOV	AH,CL		;Return with AH = terminator
	CLC			;Flag param. found
	RET	

OMITD:	INC	BX
NOMORE:	MOV	AH,AL		;Save terminator
	MOV	AL,LOW 0D	;Set param value to 0, save flags
	STC			;Flag param. not found
	RET	
	PAGE	
;EOSCHK: Detect garbage beyond end of statement
;ENTRY - BX = text pointer
;EXIT  - AL = 0 & all other registers preserved or
;      - Exit on error through FCERR
;
EOSCHK:
	DEC	BX		;Back up text pointer
EOSCH1:
	CALL	CHRGTR		;Get next character (skipping blanks)
	JZ	EOSCKX		;End of statement
	JMP	SNERR		;Not EOS - error
EOSCKX:	RET	

	PAGE	
	SUBTTL  Graphics Support Specific to the 8086

	PUBLIC	LINLP3
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	MINDEL:WORD,MAXDEL:WORD,MINUPD:WORD,MAXUPD:WORD
DSEG	ENDS
	EXTRN	SETC:NEAR

;LINLP3: Inner loop of line code.

LINLP3:	CALL	SETC		;SET CURRENT POINT
	ADD	DX,WORD PTR MINDEL	;ADD SMALL DELTA TO SUM
	CMP	DX,WORD PTR MAXDEL	;TIME TO UPDATE MINOR?
	JB	LINLOP		;NO, UPDATE MAJOR AND CONTINUE
	SUB	DX,WORD PTR MAXDEL	;UPDATE SUM FOR NEXT POINT
	CALL	 WORD PTR MINUPD+1	;ADVANCE MINOR AXIS
LINLOP:	CALL	 WORD PTR MAXUPD+1	;UPDATE MAJOR AXIS
	LOOP	LINLP3		;CONTINUE UNTIL COUNT EXHAUSTED
	RET	
	PAGE	
	SUBTTL  VARPT2 - VARPTR$ Function

	PUBLIC	VARPT2
	EXTRN	PTRGTN:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	VALTYP:WORD,DSCPTR:WORD
DSEG	ENDS

;VARPTR$(x)
; Called after VARPTR sees next char is "$"
; Returns 3 byte string as follows:
;  byte 0: type of x
;  byte 1: low-adr of varptr(x)
;  byte 2: high-adr of varptr(x)
; Primary use is so BASCOM can handle DRAW "X"+VARPTR$(A$)
;
VARPT2:
	CALL	CHRGTR		;get byte after "$"
	CALL	SYNCHR
	DB	OFFSET "("	;EAT LEFT PAREN
	CALL	PTRGTN		;GET ADDRESS OF VARIABLE
	CALL	SYNCHR
	DB	OFFSET ")"	;EAT RIGHT PAREN
	OR	DX,DX		;MAKE SURE NOT UNDEFINED VAR
	JNZ	VARRT2		;SET CC'S. ZERO IF UNDEF
	JMP	FCERR		;ALL OVER IF UNDEF (DONT WANT
				;USER POKING INTO ZERO IF HE'S
				;TOO LAZY TO CHECK
VARRT2:
	PUSH	BX		;Save text pntr
	PUSH	DX		;Save Var addr
	MOV	AL,BYTE PTR VALTYP
	PUSH	AX		;Save type
	MOV	AL,LOW 3
	CALL	STRINI		;Get a 3 byte string
	MOV	BX,WORD PTR DSCPTR	;Descriptor in [BX]
	POP	WORD PTR 0[BX]	;Store Type in Byte 1
	INC	BX
	POP	WORD PTR 0[BX]	;Store addr in Bytes 2-3.
	JMP	PUTNEW		;Desc in FAC & ret. ([BX] on stack).

	PAGE	
	SUBTTL  PLAY/SOUND statements

;
; PLAY - MUSIC MACRO LANGUAGE
;
	PUBLIC	PLAYS
	EXTRN	DONOTE:NEAR
	EXTRN	MACLNG:NEAR,MCLXEQ:NEAR,FETCHR:NEAR,DECFET:NEAR,VALSC2:NEAR
	EXTRN	FETCHZ:NEAR

;Low-Level routine required:
; DONOTE(AL: voice (0=forground, 1=back), CX:frequency, DX:duration (1=18.7ms))
; queues note for execution, saves all regs.
;
PLAYS:	MOV	DX,OFFSET PLYTAB	;POINT TO PLAY COMMAND TABLE
	JMP	MACLNG

PLYTAB:	DB	"A"		;THE NOTES A-G
	DW	OFFSET PLYNOT
	DB	"B"
	DW	OFFSET PLYNOT
	DB	"C"
	DW	OFFSET PLYNOT
	DB	"D"
	DW	OFFSET PLYNOT
	DB	"E"
	DW	OFFSET PLYNOT
	DB	"F"
	DW	OFFSET PLYNOT
	DB	"G"
	DW	OFFSET PLYNOT

	DB	"M"		;Music Meta Command
	DW	OFFSET PLYMET

	DB	OFFSET "N"+128D	;PLAY NUMERIC NOTE
	DW	OFFSET PLYNUM
	DB	OFFSET "O"+128D	;OCTAVE
	DW	OFFSET POCTAV
	DB	OFFSET "P"+128D	;PAUSE
	DW	OFFSET PPAUSE
	DB	OFFSET "T"+128D	;TEMPO
	DW	OFFSET PTEMPO
	DB	OFFSET "L"+128D	;LENGTH
	DW	OFFSET PLYLEN
	DB	"X"		;EXECUTE STRING
	DW	OFFSET MCLXEQ
	DB	00		;END OF TABLE

; TABLE OF INDEXES INTO NOTTAB FOR EACH NOTE
; VALUE OF 255 MEANS NOTE NOT ALLOWED.

NOTXLT:	DB	OFFSET 9D*2	;A- (G#)
	DB	OFFSET 10D*2	;A
	DB	OFFSET 11D*2	;A#
	DB	OFFSET 12D*2	;B
	DB	255D		;NO C- OR B#
	DB	OFFSET 1D*2	;C
	DB	OFFSET 2D*2	;C#
	DB	OFFSET 3D*2	;D
	DB	OFFSET 4D*2	;D#
	DB	OFFSET 5D*2	;E
	DB	255D		;NO E# OR F-
	DB	OFFSET 6D*2	;F
	DB	OFFSET 7D*2	;F#
	DB	OFFSET 8D*2	;G
	DB	OFFSET 9D*2	;G#

; TABLE OF NOTE FREQUENCIES
; THESE ARE THE FREQUENCIES IN HERTZ OF THE TOP OCTAVE (6)
; DIVIDED DOWN BY POWERS OF TWO TO GET ALL OTHER OCTAVES
;
NOTTAB:	DW	4186D		;C
	DW	4435D		;C#
	DW	4699D		;D
	DW	4978D		;D#
	DW	5274D		;E
	DW	5588D		;F
	DW	5920D		;F#
	DW	6272D		;G
	DW	6645D		;G#
	DW	7040D		;A
	DW	7459D		;A#
	DW	7902D		;B

PLYLEN:	JNB	PLGOFC		;ERROR IF NO ARG
	CMP	DL,LOW 65D	;ALLOW ONLY UP TO 64
	JNB	PLGOFC		;FC ERROR IF TOO BIG
	OR	DL,DL		;DON'T ALLOW ZERO
	JZ	PLGOFC		;FC ERROR IF ZERO
	MOV	BYTE PTR NOTELN,DL	;STORE NOTE LENGTH
	RET	

PTEMPO:	CMP	DL,LOW 32D	;ALLOW ONLY 32 - 255
	JB	PLGOFC		;FC ERROR IF TOO SMALL
	MOV	BYTE PTR BEATS,DL	;Store Beats per minute
	RET	

NCFCER:
PPAUSE:	JNB	PLGOFC		;ERROR IF NO ARG
	XOR	CX,CX		;PASS FREQ OF 0
	CMP	DL,LOW 65D	;ALLOW ONLY 1-64
	JNB	PLGOFC		;FC ERROR IF TOO BIG
	OR	DL,DL		;SEE IF ZERO
	JZ	PLYRET		;RETURN IF SO - NO PAUSE
	JMP	PPAUS2		;[DX]=PAUSE LENGTH

POCTAV:	JNB	PLGOFC		;ERROR IF NO ARG
	CMP	DL,LOW 7	;ALLOW ONLY OCTAVES 0..6
	JNB	PLGOFC		;FC ERROR IF TO BIG
	MOV	BYTE PTR OCTAVE,DL
PLYRET:	RET	

PLYNUM:	JNB	PLGOFC		;ERROR IF NO ARG
	MOV	AL,DL		;GET NOTE NUMBER INTO [AL]
	OR	AL,AL		;SEE IF ZERO (PAUSE)
	JZ	PLYNO3		;DO THE PAUSE
	CMP	AL,LOW 85D	;ALLOW ONLY 0..84
	JNB	PLGOFC		;FC ERROR IF TOO BIG
	CBW			;CLEAR HI BYTE FOR DIVIDE
	DEC	AX		;MAP TO 0..83
	MOV	DL,LOW 12D	;DIVIDE BY 12
	DIV	DL
	MOV	DH,AL		;OCTAVE TO [DH]
	MOV	AL,AH		;NOTE NUMBER IS REMAINDER
	INC	AL		;ADD ONE
	ADD	AL,AL		;DOUBLE TO MAKE INDEX
	JMP	SHORT PLYNU3	;PLAY NOTE [AL], OCTAVE [DH]

PLGOFC:	JMP	FCERR		;GIVE FUNCTION CALL ERROR

PLYNOT:	SUB	CL,LOW OFFSET "A"-1	;MAP TO 1..7
	ADD	CL,CL		;MAP TO 2..14 (THIS ASSUMES SHARP)
	CALL	FETCHR		;GET NEXT CHARACTER
	JZ	PLYNO2		;END OF STRING - NO SHARP OR FLAT
	CMP	AL,LOW "#"	;CHECK FOR POSSIBLE SHARP
	JZ	PLYSHP		;SHARP IT THEN
	CMP	AL,LOW "+"	;"+" ALSO MEANS SHARP
	JZ	PLYSHP
	CMP	AL,LOW "-"	;"-" MEANS FLAT
	JZ	PLYFLT
	CALL	DECFET		;PUT CHAR BACK IN STRING.
	JMP	SHORT PLYNO2	;TREAT AS UNMODIFIED NOTE.
PLYFLT:	DEC	CL		;DECREMENT TWICE TO FLAT IT
PLYNO2:	DEC	CL		;MAP BACK TO UNSHARPED
PLYSHP:	MOV	AL,CL		;INTO [AL] FOR XLAT
	MOV	BX,OFFSET NOTXLT	;POINT TO TRANSLATE TABLE
?CSLAB:				; Code segment dummy label
	XLAT	BYTE PTR ?CSLAB	;TRANSLATE INTO NOTE TABLE INDEX
	OR	AL,AL		;SEE IF LEGAL NOTE
	JS	PLGOFC		;NOTE'S OK IF NOT .GT. 127
;
; ENTER HERE WITH NOTE TO PLAY IN [AL]
; NOTE 0 IS PAUSE, 2,4,6,8..10,12 ARE A-G AND FRIENDS.
;
PLYNO3:
	MOV	DH,BYTE PTR OCTAVE	;GET OCTAVE INTO [DH] FOR LATER MATH
PLYNU3:
	PUSH	AX		;Save Note
	PUSH	DX		;Save Octave
	MOV	AL,BYTE PTR NOTELN
	MOV	BYTE PTR NOTE1L,AL	;One note duration = Note length
	CALL	FETCHR
	JZ	PLYNU4		;Brif end of string
	CALL	VALSC2		;See if possible number
	CMP	DL,LOW 65D	;If was .gt. 64
	JNB	PLGOFC		; then error
	OR	DL,DL		;Any Length?
	JZ	PLYNU4		;Brif not, just do note
	MOV	BYTE PTR NOTE1L,DL	;Store duration for this note
PLYNU4:
	POP	DX		;Get Octave
	POP	AX		;Restore Note
	CBW			;FILL [AH] WITH ZEROS
	MOV	BX,AX		;TRANSFER TO BX FOR INDEXING
	OR	BX,BX		;SEE IF PAUSE (NOTE # 0)
	JZ	PLYNO4		;IF PAUSE, PASS [BX]=0
	MOV	BX,WORD PTR NOTTAB-2[BX]	;FETCH FREQUENCY
	MOV	CL,LOW 6	;CALCULATE 6-OCTAVE
	SUB	CL,DH		;FOR # OF TIMES TO SHIFT FREQ.
	SHR	BX,CL		;DIVIDE BY 2^(6-OCTAVE)
	ADC	BX,0		;ADD IN CARRY TO ROUND UP
PLYNO4:
	MOV	CX,BX		;FREQUENCY INTO [CX] FOR DONOTE
	MOV	DL,BYTE PTR NOTE1L	;Get this note's length
PPAUS2:
	MOV	AL,BYTE PTR BEATS	;GET BEATS PER UNIT TIME
	MUL	DL		;CALC NOTE LENGTH * BEATS
	PUSH	CX		;SAVE [CX] WHILE WE DIVIDE
	MOV	CX,AX		;CALC TIME CONST/(BEATS * NOTE LENGTH)
	MOV	DX,1		;[DX:AX]=96000 (4*60*400.0) and will
	MOV	AX,73400O	; cause DONOTE [DX]=1 to play 2.5 milliseconds
	DIV	CX		; (in other words [DX]=400 will play 1 second)
	POP	CX		;RESTORE FREQUENCY
	OR	AX,AX		;IF DURATION IS ZERO, GET OUT.
	JZ	PLYNO8
	PUSH	CX		;Save Freq
PLYDOT:
	PUSH	AX		;Save duration
	CALL	FETCHR
	JZ	PLYDOX		;Brif EOS
	CMP	AL,LOW "."	;Note duration extender?
	JNZ	PLYDO2		;Brif not
	POP	AX		;Get duration
	MOV	CX,3
	MUL	CX
	SHR	AX,1		;Duration = Duration * 1.5
	SHR	DX,1		;Ovf/2
	OR	DX,DX		;Still too big?
	JZ	PLYDOT		;Itterate if not
	JMP	FCERR		; else complain..
PLYDO2:
	CALL	DECFET		;Put char back
PLYDOX:
	POP	AX		;Duration
	POP	CX		;Get freq
	OR	CX,CX
	JZ	PLYNO9		;Brif Pause
	CMP	BYTE PTR MSCALE,LOW 1
	JZ	PLYNO9		;Brif Legatto
	PUSH	AX		;Save Duration
	PUSH	CX		;Save Frequency
	MOV	CL,BYTE PTR MSCALE	;Using scale for shift count
	MOV	BX,3		;Stecatto multiplier
	CMP	CL,LOW 2
	JZ	PLYNO6		;Brif Stecatto
	MOV	BX,7		; else Normal
PLYNO6:
	MUL	BX		;Duration * 7/8 or 3/4
	SHR	AX,CL
	OR	AX,AX
	JNZ	PLYNO7		;If zero
	INC	AX		; then make 1
PLYNO7:
	POP	CX		;Get Freq
	CALL	PLYNO9		;Send note
	POP	AX		;Original duration
	MOV	CL,BYTE PTR MSCALE
	SHR	AX,CL		;pause after note is 1/8 or 1/4
	XOR	CX,CX		;Freq = 0 for pause
	OR	AX,AX		;Pause = 0?
	JNZ	PLYNO9		;Brif not
PLYNO8:
	RET			; else do nothing
PLYNO9:
	MOV	DX,AX		;DONOTE wants [CX]=freq, [DX]=duration.
	JMP	SHORT DOSND	;Play freq [CX] for time [DX]

PLYMER:
	JMP	FCERR

; PLYMET -      Process Music Meta Commands.

PLYMET:
	CALL	FETCHZ		;Get Meta action or error
	MOV	CL,LOW 1	;Factor for Legatto (1/1): MSCALE=1
	CMP	AL,LOW "L"
	JZ	PLYDUR		;Brif Legatto (Full note)
	INC	CL		;Factor for Stecatto (3/4): MSCALE=2
	CMP	AL,LOW "S"
	JZ	PLYDUR		;Brif Stecatto (3/4)
	INC	CL		;Factor for Normal (7/8): MSCALE=3
	CMP	AL,LOW "N"
	JZ	PLYDUR		;Brif Normal (7/8)
	XOR	CL,CL		;MMODE=0 for Forground
	CMP	AL,LOW "F"
	JZ	PLYMOD		;Brif Foreground Music
	INC	CL		;MMODE=1 for Background
	CMP	AL,LOW "B"
	JNZ	PLYMER		;Brif not Background Music
PLYMOD:
	MOV	BYTE PTR MMODE,CL	;Store Music Mode (0=FG, 1=BG)
	RET	
PLYDUR:
	MOV	BYTE PTR MSCALE,CL	;Store Duration Scaling factor
	RET	

;SNDINI is called to set OCTAVE, BEATS, NOTELN, NOTE1L, MSCALE, and MMODE
;to appropriate initial settings.  SNDINI is called at CLEARC and during
;initialization.
;Entry - none
;Exit  - all registers preserved
;
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	NOTELN:WORD,NOTE1L:WORD,BEATS:WORD,OCTAVE:WORD,MSCALE:WORD
	EXTRN	MMODE:WORD
DSEG	ENDS
PUBLIC	SNDINI
SNDINI:	MOV	BYTE PTR BEATS,LOW 120D
	MOV	BYTE PTR MSCALE,LOW 3D
	MOV	BYTE PTR MMODE,LOW 0D
	MOV	BYTE PTR NOTELN,LOW 4D
	MOV	BYTE PTR NOTE1L,LOW 4D
	MOV	BYTE PTR OCTAVE,LOW 4D
	CALL	SNDRST		;Turn off sound
	RET	

;SNDRST is called to reset background music.  It is called during
; initialization from INIT and during the processing of CTL-C
; from POLKEY
; Entry - none
; Exit  - All registers preserved
;
PUBLIC	SNDRST
SNDRST:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSHF	
	MOV	AL,LOW 255D
	CALL	DONOTE		;Disable background music, init music queue
	POPF	
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET	

	PUBLIC	BEEPS,BEEP,SOUNDS
	EXTRN	DONOTE:NEAR,FRQINT:NEAR,FRCSNG:NEAR,GETIN2:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FAC:WORD
DSEG	ENDS

BEEP:
BEEPS:	MOV	CX,800D		; 800 Hz
	MOV	DX,100D		; .. for 1/4 second.
	XOR	AL,AL		;[AL]=Music Mode (0=Forground)
	JMP	SHORT JDNOTE

DOSND:	MOV	AL,BYTE PTR MMODE	;[AL]=Music Mode (0=Forground, 1=background)
JDNOTE:	CALL	DONOTE		;start new sound.
	JNB	DNOTOK		;No errors detected by DONOTE
	JMP	FCERR		;Function call error detected
DNOTOK:
	JMP	POLKEY		;Allow CTL-C to interrupt and return
; SOUND  -      Make SOUNDs with the speaker.
;
;       Syntax: SOUND x,y
;
;       Where:  x is the Frequency in Hertz.
;               y is the Duration in Clock ticks. (currently 18.2/sec).
;
;               Frequency must be at least 37 Hz.
;               If Duration is 0, then just turn off current sound...
;
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	$FACLO:WORD,$FACM1:WORD
DSEG	ENDS
	EXTRN	$FMULS:NEAR
SOUNDS:
	CALL	GETIN2		;Get frequency.
	CMP	DX,37D
	JB	SNDFCE		;Must be at least 37 Hz..
	PUSH	DX		;Save frequency
	CALL	SYNCHR
	DB	OFFSET ","
	CALL	FRMEVL		;Get duration.
	CALL	EOSCHK		;Syntax Error if not end-of-statement
	PUSH	BX		;Text pointer
	CALL	FRCSNG		;Make Single Precision
	MOV	BX,OFFSET FAC	;Point at Exponent
	CMP	BYTE PTR 0[BX],LOW 0	;Will turn sound off if 0.
	JNZ	SOUNL4		; Brif not, start new sound.
	POP	BX		;Text pointer
	POP	DX		;Frequency (not used)
	JMP	SHORT SNDRST	;Turn off sound, initialize the queue

SOUNL4:
	CMP	BYTE PTR 0[BX],LOW 221O	;Duration .gt. 65535?
	JNB	SNDFCE		;Brif so, too big for *32
	PUSH	BX		;Save FAC address
	PUSH	WORD PTR $FACM1	;Push FAC on the stack
	PUSH	WORD PTR $FACLO
	MOV	BX,22D		;Mult by ^D22
	CALL	MAKINT
	CALL	FRCSNG		;Get s.p. ^D22
	POP	DX		;Get low mantissa bits
	POP	BX		;Exp sign and high mantissa bits
	CALL	$FMULS		;MULTIPLY
	POP	BX		;FAC address
	CMP	BYTE PTR 0[BX],LOW 221O	;Overflow?
	JB	SOUNL5		;Brif not
	MOV	WORD PTR -1[BX],110177O	; else
	MOV	WORD PTR -3[BX],177400O	; force to 65535
SOUNL5:
	CALL	FRQINT		;Convert back to Integer
	MOV	DX,BX		; in [DX]
	POP	BX		;Text pointer
	POP	CX		;[CX]=Frequency, [DX]=Duration
	JMP	SHORT DOSND	;play the note
SNDFCE:
	JMP	FCERR		; Complain


	PAGE	
	SUBTTL General Event Trapping Code

	PUBLIC	ONGOTP,SETGSB
	EXTRN	STPTRP:NEAR,ONTRP:NEAR,OFFTRP:NEAR,REQTRP:NEAR,FRETRP:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	$ON:WORD,$OFF:WORD,$STOP:WORD
DSEG	ENDS
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	TRPTBL:WORD
DSEG	ENDS

;Event flags can have one or more of the following bits set:
; They are defined in BIMISC.MAC
;
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	T_ON:WORD	;1 event trapping on
DSEG	ENDS
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	T_STOP:WORD	;2 event trapping stopped (remembers but doesn't report)
DSEG	ENDS
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	T_REQ:WORD	;4 event trap requested (this event has happend)
DSEG	ENDS

;To support EVENT TRAPPING, The following switches should be defined
; in the machine dependant Switch File:
;
;       NMKEYT = number of soft keys
;       NMCOMT = number of COMmunications ports
;       NMPENT = number of light pens (0 or 1)
;       NMSTRT = number of joysticks
;       NUMTRP = total of all of the above
;       ONGOSB should be 1
;

;To support EVENT TRAPPING, The following variables should be defined
; in the machine dependant RAM module:
;
;       ONGSBF: BLOCK   1       ;some-event happend flag (see NEWSTT)
;       TRPTBL: BLOCK   3*NUMTRP
;                               ;event flags and GOSUB line ptrs
;

	PENOFF=0		;offset for PEN event id's
	KEYOFF=PENOFF+NMPENT	;offset for KEY event id's
	COMOFF=KEYOFF+NMKEYT	;offset for COM event id's
	STROFF=COMOFF+NMCOMT	;offset for STRIG event id's

	PUBLIC	CHKINT
	EXTRN	POLKEY:NEAR,POLLEV:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	AUTFLG:WORD,SEMFLG:WORD,SAVTXT:WORD,SAVSTK:WORD,CURLIN:WORD
DSEG	ENDS

;CHKINT is called from BASIC's NEWSTT loop to see if any trappable
; condition has occured.  It traps active function keys, COM input,
; light pen interrupts, joystick triggers, CTL-C, CTL-S, and
; it queues vanilla keys for CHSNS.  For efficiency, it calls POLLEV
; which looks at flag which gets set by BIOS when some interrupt occurs.
; This routine would not be necessary in a stand-alone environment since
; BASIC would manage its own interrupts.
;
CHKINT:
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	MSDCCF:WORD	;MSDOS Ctl-C flag
DSEG	ENDS
	TEST	BYTE PTR MSDCCF,LOW 255D	;Test for MSDOS-received Ctl-C
	JNZ	CHKIN1
	CALL	POLLEV		;Test for occurance of trapable events
	JZ	CHKINX		;Exit - no trapable event
CHKIN1:	PUSH	BX
	PUSH	CX
	PUSH	DX
	CALL	POLKEY		;trap Function keys, CTL-C, CTL-S
	EXTRN	POLCOM:NEAR
	CALL	POLCOM		;trap COM interrupts
NOACOM:
	CALL	POLPEN		;trap PEN interrupts
	CALL	POLSTR		;trap STRIG interrupts
	POP	DX
	POP	CX
	POP	BX
CHKINX:	RET	

;SEVSTT - Set Event Status
; Common code for parsing event-id ON/OFF/STOP
; Entry - [CL]=number of legal events for device
;         [CH]=event-id offset for device
;
SEVSTT:	PUSH	CX		;save maximum and offset for class
	CALL	SYNCHR
	DB	OFFSET "("
	CALL	GETBYT		;[AL]=class-relative event-id
	PUSH	AX		;save it
	CALL	SYNCHR
	DB	OFFSET ")"
	PUSH	AX		;save [AL]=$ON, $OFF, or $STOP
	CALL	EOSCH1		;skip past $ON, $OFF, or $STOP
				;error if not end of statement
	POP	DX		;restore $ON, $OFF, or $STOP
	POP	AX		;[AL]=class-relative event-id
	POP	CX		;restore maximum, offset for class
	CMP	CH,LOW OFFSET STROFF	;Special check for STRIG(x)
	JNZ	SEVST1		;Brif not
	ROR	AL,1		;Divide by 2 so get 0,1,2 or 3
	JMP	SHORT SEVST2
SEVST1:
	OR	AL,AL
	JZ	SEVALL		;branch if parm was 0
	DEC	AL		;make parm 0-relative
SEVST2:
	PUSH	DX		;save $ON, $OFF, or $STOP
	CMP	AL,CL		;compare with maximum
	JGE	FCERR1		;branch if not in range
	ADD	AL,CH		;add in offset to get event id
	CALL	EVADR		;[DX]=adr of event flag
	POP	AX		;[AL]=ON, OFF, or STOP
				;fall into SET1EV

;SET1EV - Set One Event
; Entry - [DX]=adr of event flag
;         [AL]=$ON, $OFF, or $STOP
;
SET1EV:	CALL	EVSET		;set event flags to ON, OFF, or STOP
	RET	

FCERR1:	JMP	FCERR
SNERR1:	JMP	SNERR

;Set status for all events of a class
; Entry - [DL]=$ON, $OFF, or $STOP token
;         [CH]=class event-id offset
;         [CL]=number of events in class
;
SEVALL:	PUSH	DX		;save $ON, $OFF, or $STOP
	MOV	AL,CH		;[AL]=class offset
	XOR	CH,CH		;[CX]=number of entries in class
	CALL	EVADR		;[DX] points to 1st event flag
	POP	AX		;[AL]=ON, OFF, or STOP
SEVAL1:	CALL	EVSET		;set event for key 9-[B]
	ADD	DX,3		;[DX] points to next entry
	LOOPNE	SEVAL1
	RET	

;EVSET changes the status of 1 event.
; Entry - [AL]=$ON, $OFF, or $STOP
;         [DX] points to event flag
; Exit -  All registers preserved.
;
EVSET:	PUSH	DX		;save caller's registers
	PUSH	CX
	PUSH	BX
	PUSH	AX
	MOV	BX,DX		;[BX]=adr of event flag
	CMP	AL,LOW OFFSET $ON
	JZ	EVON
	CMP	AL,LOW OFFSET $OFF
	JZ	EVOFF
	CMP	AL,LOW OFFSET $STOP
	JNZ	SNERR1

EVSTP:	CALL	STPTRP		;stop event pointed to by [BX]
	JMP	SHORT EVONX
EVON:	CALL	ONTRP		;enable event pointed to by [BX]
	JMP	SHORT EVONX
EVOFF:	CALL	OFFTRP		;disable event pointed to by [BX]
EVONX:	POP	AX		;restore all caller's registers
	POP	BX
	POP	CX
	POP	DX
	RET	

;EVADR transforms event-id to event-flag-pointer.
; Entry - [AL] = event id
; Exit  - [DX]=adr of event flag, [AX] is used, all other regs preserved
;
EVADR:	XOR	AH,AH		;[AX] = event id
	MOV	DX,AX
	ADD	AX,AX
	ADD	AX,DX		;[AX] = 3*event id
	ADD	AX,OFFSET TRPTBL
	MOV	DX,AX
	RET	

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	$KEY2B:WORD,$PEN2B:WORD,$STR2B:WORD,$COM2B:WORD
DSEG	ENDS
	EXTRN	DERDNA:NEAR

;ONGOTP routine is called from ON GOTO code within BINTRP
;       Do syntax checks for event traps and return.
;       Carry set indicates it was not a trap gosub definition.
;       else carry is clear
;
; Syntax:       ON [Event] GOSUB line no.
;
;       WHERE:  Event is one of following:
;               COM(x)
;               PEN
;               STRIG(x) x = 0 for Trigger A, or 2 for Trigger B.
;               KEY(x)   x = 1..NMKEYT-1
;
;       If one of the Event verbs does not follow the ON
;       keyword, then go back to Level 1 "ONGOTO" to
;       process ON ### GOSUB... or GOTO.
;
ONGOTP:	PUSH	BX		;Text pointer in case not us.
	XOR	CH,CH		;Assume one byte token
	CMP	AL,LOW 375O	;check for 2-byte token
	JB	NT2BTK		;branch if not FF, FE or FD
	MOV	CH,AL		;[CH] = 1st byte
	CALL	CHRGTR		;[AL] = 2nd byte of 2-byte token
	MOV	AH,CH		;[AH] = 1st byte
NT2BTK:
	CMP	AX,OFFSET $KEY2B
	MOV	CX,OFFSET (400O*KEYOFF)+NMKEYT
	JZ	ONFUN		;Brif ON KEY...
	CMP	AX,OFFSET $COM2B
	MOV	CX,OFFSET (400O*COMOFF)+NMCOMT
	JZ	ONFUN		;Brif ON COM...
	CMP	AX,OFFSET $PEN2B
	MOV	CX,OFFSET 400O*PENOFF
	JNZ	NTONPN		;BRIF not ON PEN...
	CALL	CHRGTR		;get next token
	JMP	SHORT ONSTM	;Brif ON PEN...
NTONPN:
	CMP	AX,OFFSET $STR2B
	MOV	CX,OFFSET (400O*STROFF)+NMSTRT
	JZ	ONFUN
	STC			;set carry - indicates not event
	POP	BX		;Restore Entry Text pointer
	JMP	SHORT ONGOTX

FCERR2:	JMP	FCERR

JERDNA:	JMP	DERDNA		;Device unavailable error if PEN

ONFUN:
	CALL	GETSUB		;Get Event no. in (x).
	DEC	AL		;Want base 0. (If not STRIG(x))
	CMP	CH,LOW OFFSET STROFF	;Special check for STRIG(x)
	JNZ	ONFUN1		;Brif not
	INC	AL		;Restore STRIG #
	ROR	AL,1		;Divide by 2 so get 0,1,2 or 3
ONFUN1:
	CMP	AL,CL		;Value [AL] .gt. MAX [CL]?
	JNB	FCERR2		;If so, then Ill fun error.
	MOV	CL,AL		;Save Event index in [CL]
ONSTM:
	ADD	CH,CL		;[CH]=event-id
	MOV	CL,LOW 1	;[CL]=maximum number of line#'s in gosub
	POP	DX		;discard saved text pointer
	DEC	BX		;backup for CHRGET
	OR	AL,AL		;clear carry - indicates it was event
ONGOTX:	MOV	AL,BYTE PTR 0[BX]	;Restore Token
	RET	

GETSUB:	PUSH	CX
	CALL	CHRGTR		;skip current token
GETSU2:	CALL	SYNCHR
	DB	OFFSET "("
	CALL	GETBYT		;get event-class index
	PUSH	AX		;save it
	CALL	SYNCHR
	DB	OFFSET ")"
	POP	AX
	POP	CX
	RET	

;Set gosub entry
; Entry - [AL]=trap id, [DX]=line pointer
; Exit  - [AX], [FLAGS] used, All other registers preserved.
;
SETGSB:	PUSH	SI
	PUSH	DX		;save gosub line pointer
	CALL	EVADR		;[DX] points to event flag
	MOV	SI,DX		;[SI] points to event flags
	POP	DX		;restore GOSUB line pointer
	INC	SI		;[SI] points to gosub line ptr entry
	MOV	WORD PTR 0[SI],DX	;put trap adr in table for this entry
	POP	SI
	RET	

;EVTRP is called to signal that an event has occured.
; Entry - [AL] = event id
; Exit  - If NZ, the event is not being trapped (not ON)
;         AX is used.  All other registers are preserved.
;
EVTRP:	PUSH	DX
	PUSH	CX
	PUSH	BX
	MOV	BX,WORD PTR CURLIN
	INC	BX
	JZ	NOT_ON		;branch if in direct mode (no event trapping)
	CALL	EVADR		;[DX] points to event flag
	MOV	BX,DX		;[BX] points to event flag
	MOV	AL,BYTE PTR 0[BX]	;[AL]=event flag
	AND	AL,LOW OFFSET T_ON	;NZ if trapping enabled for key
	JZ	NOT_ON		;branch if event is not on
	PUSHF	
	CALL	REQTRP		;Trap enabled, Issue Request
	POPF	
NOT_ON:	POP	BX
	POP	CX
	POP	DX
	RET	

;EVCLR is called to reset an event
; Entry - [AL] = event id
; Exit  - Flags, AX are used.  All other registers are preserved.
;
EVCLR:	PUSH	DX
	PUSH	CX
	PUSH	BX
	CALL	EVADR		;[DX] points to event flag
	MOV	BX,DX		;[BX] points to event flag
	CALL	FRETRP		;Reset Trap Request
	JMP	SHORT NOT_ON

;TSTCEV is called to Test-and-Clear an event.
; Entry - [AL] = 0-relative event index
; Exit  - [BX] = -1 if event had occured
;              =  0 if event had not occured
;         bit T.REQ of TRPTBL+3*index is cleared
;
TSTCEV:
	CALL	EVADR		;[DX] [points to event flag
	MOV	BX,DX		;[BX] points to event flag
	MOV	AL,BYTE PTR 0[BX]	;[AL] = current event state
	PUSH	AX
	CALL	FRETRP		;Reset Trap Request (clear T.REQ)
	POP	AX
	XOR	BX,BX		;prepare to return negative result
	AND	AL,LOW OFFSET T_REQ
	JE	TSTEVX
	DEC	BX		;[BX]=-1 (indicates event has occured)
TSTEVX:	RET	

	PAGE	
	SUBTTL COM Statement and Event Trapping

	PUBLIC	COMS
	PUBLIC	COMTRP

;COM statement
;
COMS:	MOV	CX,OFFSET (400O*COMOFF)+NMCOMT
	JMP	SEVSTT		;branch to common code

;COMTRP is called by COM interrupt service routine to signal trapping.
; Entry - [AL]=0-relative com channel id.
; Exit  - NZ is true if key trapping is enabled.
;         All other regs preserved.
;
COMTRP:	PUSH	AX
	ADD	AL,LOW OFFSET COMOFF	;[AL]=event id
	CALL	EVTRP		;Signal the occurance of a COM EVENT
	POP	AX
	RET	

	PAGE	
	SUBTTL SOFT KEY Statement and Event Trapping

	PUBLIC	KEYS
	EXTRN	LINPRT:NEAR,OUTDO:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	$ON:WORD,$OFF:WORD,$LIST:WORD
DSEG	ENDS
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	STRTAB:WORD,KEYSW:WORD,FKCNUM:WORD
DSEG	ENDS
	EXTRN	SCROUT:NEAR,CLREOL:NEAR
	PUBLIC	KEYTRP
	EXTRN	MAKINT:NEAR

;SET KEY STATUS - KEY(n) (status)
;
KEYSTT:	MOV	CX,OFFSET (400O*KEYOFF)+NMKEYT
	JMP	SEVSTT		;branch to common code



;KEYTRP is called whenever CHGET receives a SOFTKEY from the keyboard.
; Entry - [AL] = Soft key id (0..NMKEYT-1)
; Exit  - If NZ, key was trapped and should not be expanded.
;         Otherwise, CHGET should expand key.
;         All other registers are preserved.
;
KEYTRP:	PUSH	AX
	ADD	AL,LOW OFFSET KEYOFF	;[AL] = 0-relative event id
	CALL	EVTRP		;Signal the occurance of a KEY EVENT
	POP	AX
	RET	

	EXTRN	FKYADV:NEAR

;KEY Statement
;
KEYS:
	CMP	AL,LOW "("
	JZ	KEYSTT		;set key status
	CMP	AL,LOW OFFSET $ON
	JZ	KEYON		;Brif Enable Soft Key Display Line.
	CMP	AL,LOW OFFSET $OFF
	JZ	KEYOF		;Brif Disable Soft Key Display line.
	CMP	AL,LOW OFFSET $LIST
	JZ	KEYLSI		;Brif LIST Soft Keys.
	CALL	GETBYT		; else Key defn, get key number.
	OR	AL,AL
	JZ	KEYFCE
	SUB	AL,LOW OFFSET STKEYF	;Get zero relative key number
	CMP	AL,LOW OFFSET NMKEYF
	JNB	KEYFCE		;Must be STKEYF - NMKEYF+STKEYF, else error.
	MOV	DX,16D
	MUL	DL		; (16 * Key number).
	MOV	DX,AX
	ADD	DX,OFFSET STRTAB	;Index into Soft Key table
	PUSH	DX		;Save addr
	CALL	SYNCHR
	DB	OFFSET ","
	CALL	FRMEVL
	PUSH	BX		;Save Text pntr.
	CALL	FRESTR		;Get String Descriptor
	MOV	CL,BYTE PTR 0[BX]
	CMP	CL,LOW 15D
	JB	KEY1
	MOV	CL,LOW 15D	;String may be 0 to 15 chars.
KEY1:
	INC	BX
	MOV	SI,WORD PTR 0[BX]	;Get addr of string
	POP	BX		;Text pntr
	POP	DI		;STRTAB addr
	PUSH	BX
	MOV	CH,LOW 0
	CLD	
                     ;Move new softkey
 REP	MOVSB			;to Softkey table
	MOV	BYTE PTR 0[DI],CH	;Terminate entry with 0.
	MOV	AL,BYTE PTR KEYSW	;Are the key definitions being
	OR	AL,AL		;displayed?
	JZ	NODSPK		;No, don't call DSPKEY since it would
				;erase the bottom line of the screen.
	CALL	KEYDSP		;Yes, update the display.
NODSPK:	POP	BX		;Text pntr
	RET	
KEYFCE:
	JMP	FCERR		;complain..
KEYLSI:	JMP	SHORT KEYLST

KEYON:	CALL	SKEYON
	JMP	SHORT KEYOXX	;non-zero = ON

KEYOF:	MOV	AH,LOW 1D	;Prepare to inc scroll limit
	MOV	AL,LOW 0	;zero = OFF
	CALL	KEYOX
KEYOXX:	CALL	CHRGTR		;over ON/OFF token.
	RET	

PUBLIC	SKEYON
SKEYON:	MOV	AH,LOW -1D	;Prepare to dec scroll limit
	MOV	AL,LOW 377O
KEYOX:				;AH=scroll limit diff., AL=new KEYSW
	CMP	AL,BYTE PTR KEYSW	;State change?
	MOV	BYTE PTR KEYSW,AL
	JZ	KEYXX		;Brif same, do nothing
	CMP	BYTE PTR KEYSW,LOW 255D	;Test if change to ON
	JNZ	KEYOX1		;Change is to OFF - do not call FKYADV
	CALL	FKYADV
KEYOX1:
	CALL	KEYDSP		;On, Display on 25th line.
KEYXX:	RET	

;List Function Keys
;
KEYLST:
	PUSH	BX
	MOV	SI,OFFSET STRTAB	;List 10 Special Function
	MOV	CX,OFFSET NMKEYF+(STKEYF*400O)
KEYLS0:
	PUSH	SI
	MOV	AL,LOW "F"
	CALL	OUTDO
	PUSH	CX
	MOV	BL,CH
	MOV	BH,LOW 0
	CALL	LINPRT		;Display the Key number.
	MOV	AL,LOW " "
	CALL	OUTDO
	POP	CX
	POP	SI
	PUSH	SI
	PUSH	CX
KEYLS1:
	CLD	
	LODSB
	OR	AL,AL
	JZ	KEYLS2		;Brif end of String.
	CALL	KEYLSP
	JMP	SHORT KEYLS1
KEYLS2:
	MOV	AL,LOW 13D	;Output carriage return
	CALL	OUTDO
	MOV	AL,LOW 10D	;Output a line feed
	CALL	OUTDO
	POP	CX
	POP	SI
	ADD	SI,16D		;Next key address
	INC	CH		;Next key number
	DEC	CL
	JNZ	KEYLS0
	POP	BX
	JMP	KEYOXX

KEYLSP:
	PUSH	SI
	CMP	AL,LOW 13D	;check for Carriage-Return
	JNZ	KEYLSQ
	MOV	AL,LOW 33O
KEYLSQ:	CALL	OUTDO
	POP	SI
	RET	
	PAGE	
	SUBTTL  KEYON,  KEYOFF, and KEYDSP

	PUBLIC	KEYDSP,TKEYOF
	EXTRN	FKYFMT:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FKCNUM:WORD
DSEG	ENDS

;TKEYOF is called to turn function key display off
;
TKEYOF:	MOV	BYTE PTR KEYSW,LOW 0	;turn function key display switch off

; KEYDSP -      Display Softkeys on last line of Screen.

	REVNMS=1		;Key Numbers are normal video, contents are rev-video
KEYDSP:	PUSH	DX
	MOV	DH,LOW 1D	;Set for col = 1
	MOV	DL,BYTE PTR LINCNT	;Set for last line
	MOV	AL,BYTE PTR KEYSW
	OR	AL,AL		;Key on or off?
	JNZ	KEYDS0		;Softkey display switch on
	CALL	CLREOL		;Clear from (DH,DL) to EOL
	POP	DX
	RET	


KEYDS0:
	EXTRN	SETCSR:NEAR
	MOV	BYTE PTR CSRTYP,LOW 0D	;Set off mode cursor
	CALL	SETCSR		;Turn the cursor off
	PUSH	BX
KEYDS1:	CALL	GETFMT		;Get function key display format
KNXTST:	PUSH	AX		;Save Key disp no.
	CMP	AH,LOW "0"	;Single digit case?
	JZ	SINDIG		;Print only one digit
	XCHG	AH,AL
	CALL	KEYDCH		;Display first digit
	XCHG	AH,AL
SINDIG:	CALL	KEYDCH		;Display last digit
	PUSH	SI
	MOV	CL,BYTE PTR FKCNUM	;Count of chars per fun. key (set by GETFMT
	CALL	XFGBG		;Swap Forground & background colors
KNXTCH:				;Write the next key character
	PUSH	CX
	CLD	
	LODSB
	OR	AL,AL		;End of string?
	PUSHF	
	PUSH	SI
	JNZ	KEYDS4		;No, Display char
	XOR	AL,AL		;else blank
KEYDS4:
	CALL	KEYDCH		;Display char, adv cursor
	POP	SI
	POPF	
	JNZ	KEYDS5		;Brif not EOS
	DEC	SI
KEYDS5:
	POP	CX
	DEC	CL
	JNZ	KNXTCH		;Loop for next character
	CALL	XFGBG		;Swap Forground & background colors
	CALL	KEYDB		;Follow with blank
	POP	SI
	POP	AX
	CALL	KEYADV		;Advance to next key
	DEC	CH
	JNZ	KNXTST		;Loop for next key string
KEYDSX:	POP	BX		;Retrieve cursor position
	POP	DX
	MOV	BYTE PTR CSRTYP,LOW 3D	;Set user mode cursor
	CALL	SETCSR		;Turn on cursor
	RET	

KEYDB:	XOR	AL,AL		;For Blank at end of Key field
KEYDCH:
	PUSH	AX
	PUSH	BX
	OR	AL,AL		;Separating keys?
	JNZ	KEYDC1		;Brif not.
	MOV	AL,LOW " "	;else write space
KEYDC1:	CMP	AL,LOW OFFSET CR	;CR?
	JNZ	KEYNCR		;Not CR.
	MOV	AL,LOW OFFSET FKEYCR	;Subs Greater-Than-Sign
KEYNCR:	CMP	AL,LOW OFFSET LF	;Line feed?
	JNZ	KEYNLF		;Not line feed
	MOV	AL,LOW 74O	;Substitute Greater-Than-Sign
KEYNLF:	PUSH	CX
	MOV	AH,LOW 0
	CALL	SCROUT		;Write the character at (DH,DL)
	INC	DH
	POP	CX
	POP	BX
	POP	AX		;Restore key number
	RET	
	PAGE	
;Get function key display format
;
GETFMT:	PUSH	BX
	CALL	FKYFMT		;OEM routine
	MOV	CX,WORD PTR 0[BX]	;CH=key count, CL=Chrs/key
	PUSH	CX
	MOV	BYTE PTR FKCNUM,CL
	MOV	SI,OFFSET STRTAB	;SI=address of first fkey in table
	MOV	AL,BYTE PTR 2[BX]
	CBW	
	PUSH	AX		;Save number of first function key
	DEC	AL		;Set to zero relative
	MOV	CL,LOW 4D	;Multiply by 16 (bytes/key)
	SHL	AX,CL		;AX = index of first display key
	ADD	SI,AX
	POP	AX
	CALL	INTOCH		;Get key number to character code
	CMP	AH,LOW "0"
	JZ	ONEDIG		;Only one digit
	DEC	BYTE PTR FKCNUM	;Adjust function key format for two digits
ONEDIG:	CALL	KADNRM		;Normalize key address
	POP	CX
	POP	BX
	RET	
;INTOCH: Translate integer AL to characters in AX.
;        Integers must be in the range (100,0].
;        Radix is 10.
;USES -  none
;
INTOCH:	PUSH	CX
	XOR	AH,AH
	MOV	CL,LOW 10D	;Load radix
	DIV	CL
	ADD	AX,30060O	;3030H forms character codes
	XCHG	AH,AL		;AH represents significant digit
	POP	CX
	RET	
;KEYADV - Advance to next key
;Entry - AX = key number characters
;        SI = index into STRTAB (key code table)
;
KEYADV:	ADD	SI,16D		;Move to next key table entry
	INC	AL
	CMP	AL,LOW "9"
	JLE	KADNRM
	MOV	AL,LOW "0"
KADNRM:
	CMP	SI,OFFSET STRTAB+NMKEYF*16D
	JB	KADNMX
	MOV	SI,OFFSET STRTAB	;Wrap around to the first function key
				;Print function key 10 number as 0
				; except when it is the first key
	CMP	AH,LOW "1"	;Only true if 1st function key is key 10
	JNZ	KADNMX		; all other wraps are for 1 digit only
	MOV	AH,LOW "0"
	MOV	AL,LOW "1"
	INC	BYTE PTR FKCNUM	;Re-adjust format
KADNMX:	RET	
	PAGE	
	SUBTTL  Swap Forground & Background Colors

;Swap Forground & Background Colors (Toggle Reverse Video Mode)
;
	EXTRN	GETFBC:NEAR,SETFBC:NEAR	;Get and set forground/background attributes

XFGBG:	CLC			;Signal text attributes
	CALL	GETFBC		;Get forground/background attributes
	XCHG	AX,BX
	CALL	SETFBC		;Set forground/background attributes
	RET	
	PAGE	
	SUBTTL PEN Statement and Event Trapping

	PUBLIC	PENS,PENF
	EXTRN	MAKINT:NEAR

; Dispatch PEN statement depending upon following clauses:
;
; PEN   ON      Enable  PEN Trapping.
; PEN   OFF     Disable PEN Trapping.
; PEN   STOP    Suspend PEN Trapping.
;
;               Attempts to read Light pen when off
;               result in "Illegal Function Call" Error.
;
PENS:
	JZ	SNERR2		;Syntax error if end-of-statement
	PUSH	AX		;save $ON/$OFF/$STOP
	CALL	EOSCH1		;Syntax Error if not End-Of-Statement
	MOV	DX,OFFSET TRPTBL+(3*PENOFF)	;[DX]=adr of event flag
	POP	AX		;[AL]=$ON, $OFF, or $STOP
	CMP	AL,LOW OFFSET $STOP
	JE	NTONOF		;branch if not ON/OFF
	PUSH	AX
	SUB	AL,LOW OFFSET $ON
	JE	PENS1		;branch if "PEN ON"
	MOV	AL,LOW 1	;better be OFF
PENS1:	SUB	AL,LOW 2	;Map (ON, OFF) to (254, 255)
	PUSH	BX		;preserve text pointer (destroyed by RDPEN)
	CALL	RDPEN		;enable/disable light pen interrupts
	POP	BX
	POP	AX		;restore [AL] = $ON/$OFF
NTONOF:
	JMP	SET1EV		;Set Event Flag

SNERR2:	JMP	SNERR
FCERR3:	JMP	FCERR

;PEN Function:
; Syntax: x=PEN(n)
;         n=0: Return -1 if pen was down since last poll, else 0.
;         n=1: Return X Graphics Coordinate where pen was last activated.
;         n=2: Return Y Graphics Coordinate where pen was last activated.
;         n=3: Return -1 if pen is currently down, 0 if currently up.
;         n=4: Return last known valid X Graphics Coordinate.
;         n=5: Return last known valid Y Graphics Coordinate.
;         n=6: Return character row where pen was last activated.
;         n=7: Return character column where pen was last activated.
;         n=8: Return last known character row.
;         n=9: Return last known character column.
;
	EXTRN	RDPEN:NEAR
PENF:
	CALL	ONESUB		;[AL] = pen function
	PUSH	BX		;save text pointer
	CMP	AL,LOW 10
	JB	PENOK
	JMP	FCERR3		;Error if Parm exceeds 9
PENOK:
	OR	AL,AL
	JNE	NPEN0		;branch if not PEN(0)

;Whenever a PEN interrupt occurs, it is detected by POLPEN (called by CHKINT).
; PEN(0) tells whether a PEN event has occured since the last PEN(0).
; It determines this by testing-and-clearing the bit set by POLPEN.
; NOTE: PEN(0) always returns false when event trapping has been enabled
;       (by PEN ON statement)
;
	MOV	AL,LOW OFFSET PENOFF
	CALL	TSTCEV		;test and clear event [AL]
	JMP	SHORT PENRET	;return -1 in BX if event has occured
NPEN0:
	CALL	RDPEN
PENRET:	CALL	MAKINT		;Return [BX] as signed integer
	POP	BX		;restore text pointer
	RET	

;POLPEN is called by CHKINT at beginning of every BASIC statement (NEWSTT).
; If a PEN interrupt has occured, it sets the appropriate bit in TRPTBL
; which will cause the BASIC program's pen service routine (ON PEN GOSUB)
; to be invoked.
; Exit - AX, BX, CX, DX can be used (restored by CHKINT).
;        All other registers are preserved.
;
POLPEN:
	XOR	AL,AL		;See if lightpen has interrupted
	CALL	RDPEN
	OR	BX,BX
	JE	NOPENI		;branch if no lightpen interrupt
	MOV	AL,LOW OFFSET PENOFF
	CALL	EVTRP		;Signal the occurance of a PEN EVENT
NOPENI:	RET	
;Parse "(n)" and return n in [AL]
ONESUB:
;In non-IBMTOK versions, EVAL doesn't parse the argument
	EXTRN	INTFR2:NEAR
	PUSH	DX
	CALL	INTFR2		;[DX] = function to be performed (argument)
	JNE	FCERRI		;branch if [DX] is not [0..255]
	MOV	AL,DL		;return argument in [AL]
	POP	DX		;restore caller's [DX]
	RET	
	PAGE	
	SUBTTL STRIG Statement and Event Trapping

	PUBLIC	STRIGS,STRIGF,STICKF
	EXTRN	RDSTIK:NEAR,RDTRIG:NEAR

;STRIG statement
;
; Syntax:
;
;   In IBM BASIC, STRIG ON enables trigger trapping while STRIG OFF
;     disables trigger event trapping.
;   It is parsed in GW-BASIC for syntax compatibility only.
;
;   STRIG(n)      ON      Enable  STRIG(n) Trapping.
;   STRIG(n)      OFF     Disable STRIG(n) Trapping.
;   STRIG(n)      STOP    Suspend STRIG(n) Trapping.
;
;       WHERE:
;               (n) is Trigger 0 for joystick trigger #1,
;                              2 for joystick trigger #2,
;                              4 for joystick trigger #3, etc.
;
STRIGS:
	CMP	AL,LOW "("
	JNE	STRIG1		;branch if STRIG ON or STRIG OFF
	MOV	CX,OFFSET (400O*STROFF)+NMSTRT
	JMP	SEVSTT		;branch to common code
STRIG1:
	CMP	AL,LOW OFFSET $ON
	JE	STROK
	CMP	AL,LOW OFFSET $OFF
	JE	STROK
	JMP	SNERR		;SYNTAX ERROR if not $ON or $OFF or (n)
STROK:	JMP	EOSCH1		;SYNTAX ERROR if not end-of-statement

;STRIG Function:
;
; Syntax:
;
;  x=STRIG(n)
;    n=0: return -1 if button 1 was pressed since last STRIG(0), else 0.
;    n=1: return -1 if button 1 is currently pressed, else 0.
;    n=2: return -1 if button 2 was pressed since last STRIG(0), else 0.
;    n=3: return -1 if button 2 is currently pressed, else 0.
;         etc.
;
STRIGF:
	CALL	ONESUB		;Parse "(n)", [AL] = n
	PUSH	BX		;save text pointer
	MOV	AH,AL		;Map AL to AH: (0,1,2,...) to (1,0,1,...)
	INC	AH
	AND	AH,LOW 1	;[AH] = 1 for latched, 0 for current
	SHR	AL,1		;[AL] = 0 relative joystick trigger id
	CMP	AL,LOW OFFSET NMSTRT
	JB	STRGOK
FCERRI:	JMP	FCERR		;branch if illegal trigger id
STRGOK:
	OR	AH,AH
	JE	NSTR0		;brif current (not latched) was requested
	PUSH	AX
	ADD	AL,LOW OFFSET STROFF	;see if STRIG(n) ON has been executed
	CALL	EVADR		;if not, POLSTR will not call RDTRIG for
	MOV	BX,DX		; this trigger, so we must call it directly
	TEST	BYTE PTR 0[BX],LOW OFFSET T_ON
	POP	AX
	JE	NSTR0		;branch if event is not enabled

;Whenever a STRIG interrupt occurs, it is detected by POLSTR (called by CHKINT).
; STRIG(0) tells whether a STRIG event has occured since the last STRIG(0).
; It determines this by testing-and-clearing the bit set by POLSTR.
; NOTE: STRIG(0) always returns false when event trapping has been enabled
;       (by STRIG(n) ON statement)
;
	ADD	AL,LOW OFFSET STROFF	;[AL]=0 relative event index
	CALL	TSTCEV		;test and clear event [AL]
	JMP	SHORT STRRET	;return -1 in BX if event has occured
NSTR0:	CALL	RDTRIG		;[AL] = 0/1 for not-pressed/pressed
	CBW			;[AX] = 0/1 for not-pressed/pressed
	NEG	AX		;[AX] = 0/-1 for not-pressed/pressed
	MOV	BX,AX
STRRET:	CALL	MAKINT		;return [BX] as signed integer
	POP	BX		;restore text pointer
	RET	

;STICK Function:
;
; Syntax:
;
;  x=STICK(n)
;    n=0:    return x coordinate for joystick 1.
;    n=1:    return y coordinate for joystick 1.
;    n=2:    return x coordinate for joystick 2.
;    n=3:    return y coordinate for joystick 2.
;            etc.
;
STICKF:
	CALL	ONESUB		;AL=stick id
	PUSH	BX		;save text pointer
	CALL	RDSTIK		;[BX] = stick coordinate
	JAE	STKOK
	JMP	FCERR		;branch if bad parameter
STKOK:
	CALL	MAKINT		;return [BX] as signed integer
	POP	BX		;restore text pointer
	RET	

;POLSTR is called by CHKINT at beginning of every BASIC statement (NEWSTT).
; If a STRIG interrupt has occured, it sets the appropriate bit in TRPTBL
; which will cause the BASIC program's pen service routine (ON STRIG(N) GOSUB)
; to be invoked.
; Exit - AX, BX, CX, DX can be used (restored by CHKINT).
;        All other registers are preserved.
;
POLSTR:
	XOR	AX,AX		;[AL] = joystick trigger #0 (for RDTRIG)
	INC	AH		;[AH] = latched (not current) flag
STRILP:
	PUSH	AX		;save current trigger id
	ADD	AL,LOW OFFSET STROFF
	CALL	EVADR		;[DX] points to event mask
	MOV	BX,DX		;[BX] points to event mask
	TEST	BYTE PTR 0[BX],LOW OFFSET T_ON	;see if STRIG(n) ON has been done
	POP	AX
	PUSH	AX
	JE	STRI1		;don't call RDTRIG if event not enabled
	CALL	RDTRIG		;[AL]=0/1 if trig is not-pressed/pressed
	OR	AL,AL
	JE	STRI1		;brif this trigger has not interrupted
	POP	AX		;restore [AL] = joystick trigger id
	PUSH	AX
	ADD	AL,LOW OFFSET STROFF	;[AL] = global event id
	CALL	EVTRP		;Signal the occurance of a TRIGGER EVENT
STRI1:	POP	AX
	INC	AL
	CMP	AL,LOW OFFSET NMSTRT
	JB	STRILP		;brif there are more triggers to poll
	RET	

	SUBTTL DATE - Get/Set Date.

	PUBLIC	DATES,DATEF
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	DAYSPM:WORD
DSEG	ENDS

;DATE$="[M]M/[D]D/[YY]YY" or "[M]M-[D]D-[YY]YY"USA Date format
;
DATES:	CALL	PRSDAT		;CX=year, DH=month, DL=day
	JMP	SETDAT		;set system date

;X$=DATE$ returns "YYYY-MM-DD" if KANABS&KANADT else "MM-DD-YYYY"
;
DATEF:
	CALL	CHRGTR		;skip DATE$
	PUSH	BX		;Save Text pointer
	MOV	AL,LOW 10D
	CALL	STRINI		;Get space for 10 char string
	PUSH	DX		;save adr of string
	CALL	GETDAT		;CX=year, DH=month, DL=day
	POP	BX		;[BX]=adr of string
	SUB	CX,1900D	;Reduce year by two digits
	CMP	CL,LOW 100D	;See if in 20th century
	MOV	CH,LOW 19D	;Setup 20th century in case
	JB	DATEF2		;Brif so.
	SUB	CL,LOW 100D	;subtract into next century
	INC	CH		;21st century
DATEF2:
	MOV	AL,DH
	CALL	PUTCHR		;Store ascii month
	MOV	AL,LOW "-"
	CALL	PUTCH2		;put separater
	MOV	AL,DL
	CALL	PUTCHR		;Store ascii day
	MOV	AL,LOW "-"
	CALL	PUTCH2		;put separater
	MOV	AL,CH
	CALL	PUTCHR		;Store ascii century
	MOV	AL,CL
	CALL	PUTCHR		;Store ascii year.
	JMP	PUTNEW		;Put result and ret (Txt ptr on stack).

PUTCHR:
	AAM			;Convert to unpacked BCD
	XCHG	AL,AH
	OR	AX,30060O	;Add "0" bias to both digits.
	CALL	PUTCH2
	MOV	AL,AH
PUTCH2:
	MOV	BYTE PTR 0[BX],AL	;store char in string
	INC	BX
	RET	


;PRSDAT parses a string containing
;   "[YY]YY/MM/DD" if KANABS&KANADT else "MM/DD/[YY]YY"
; Exit - CX=year, DH=month, DL=day,
;         [BX]=new text pointer.  All other regs preserved.
;
PRSDAT:
	CALL	SYNCHR
	DB	OFFSET EQULTK	;Must be DATE$ = string
	CALL	FRMEVL
	PUSH	BX		;Save Text pointer
	CALL	FRESTR
	MOV	CL,BYTE PTR 0[BX]	;Save string len in [CL]
	CMP	CL,LOW 1	;String must not be null
	JB	DATERR		;Brif null str
	MOV	SI,WORD PTR 1[BX]	;[SI] has addr of string.
	MOV	BL,CL		;Working reg for string len.
	CALL	GNUM8		;[AX]=month
	MOV	DH,AL		;[DH] = month
	CALL	DATSEP		;skip / or -
	CALL	GNUM8		;[AL]=day of month
	MOV	DL,AL		;[DL] = day
	CALL	DATSEP		;skip / or -
	CALL	GNUM16		;[AX]=year (16 BITS)
	CMP	AX,1978D
	JNB	DATE2		;branch if .GE. 1978
	CMP	AX,100D
	JNB	DATERR		;error if between 100 and 1977
	CMP	AX,78D
	JNB	DATE1		;add 1900 if .GE. 78
	ADD	AX,100D		;add 2000 if .LE. 77
DATE1:	ADD	AX,1900D
DATE2:
	CMP	AX,2100D
	JNB	DATERR		;branch if year too large
	MOV	CX,AX		;CX=year
	POP	BX		;Text pointer
	RET			;Exit.

;DATSEP checks for a date separator (- or /) and returns if found.
;
DATSEP:
	OR	BL,BL
	JZ	DATERR		;Error if string empty.
	MOV	AL,BYTE PTR 0[SI]
	CMP	AL,LOW "/"
	JZ	DIGITX
	CMP	AL,LOW "-"
	JZ	DIGITX		;branch if found
	JMP	SHORT DATERR

GNUM8:	CALL	GNUM16		;[AX]=16-bit number
	OR	AH,AH
	JNZ	DATERR		;error if larger than 255
	RET	

GNUM16:	PUSH	CX		;save caller's [CX], [DX]
	PUSH	DX
	MOV	AX,0		;initialize accumulator
GNUML:	CALL	DIGIT		;[CX]=0..9
	JB	GNUMX		;branch if not legal digit
	MOV	DX,10D
	MUL	DX		;[AX]=[AX]*10
	JO	DATERR		;branch if overflow
	ADD	AX,CX		;add in new digit
	JMP	SHORT GNUML
GNUMX:	POP	DX
	POP	CX
RET2:	RET	

DIGIT:	CMP	BL,LOW 1	;End-of-string?
	JB	RET2		;Brif END-OF-STRING
	MOV	CL,BYTE PTR 0[SI]
	SUB	CL,LOW "0"
	JB	RET2		;branch if illegal digit
	CMP	CL,LOW 10D
	CMC	
	JB	RET2		;branch if illegal digit
	MOV	CH,LOW 0	;[CX]=digit
DIGITX:	DEC	BL		;Length -1
	INC	SI		;[SI] points to next byte in string
	RET	

DATERR:	JMP	FCERR

IFE	IBMTOK OR CPM86  
;DYOFYR converts YEAR, MONTH, DAY to binary DAY-OF-YEAR
; Entry - [CX]=binary year (19xx/20xx)
;         [DH]=binary month (1..12)
;         [DL]=binary day-of-month (1..31)
; Exit  - [BX]=binary day of year (0..364/365)
;         [CX] is preserved, all other registers are destroyed.
;
DYOFYR:	SUB	CX,1978D	;[CX]=year - 1978
	DEC	DL		;[DL]=day of month - 1
	DEC	DH		;[DH]=month - 1
	MOV	BL,DL
	XOR	BH,BH		;[BX]=day accumulator=day-of-month - 1
	MOV	AH,BH
	MOV	AL,DH		;[AX]=month - 1
	MOV	SI,AX		;[SI]=month - 1
	CALL	SETFEB		;DAYSPM(2)=28 or 29
	CMP	DH,LOW 12D
	JNB	DATERR		;error if month is too large
	CMP	DL,BYTE PTR DAYSPM[SI]
	JNB	DATERR		;error if day-of-month too large
	OR	SI,SI
MONTHL:	JNZ	MONTHS
	RET	
MONTHS:	MOV	AL,BYTE PTR DAYSPM-1[SI]
	ADD	BX,AX		;days=days+DAYSPM(month)
	DEC	SI
	JMP	SHORT MONTHL

;SETFEB sets DAYSPM(2) to 28 or 29 depending on year
;
SETFEB:	CALL	CKLEAP		;[AX]=1 if [CX]=leap-year
	ADD	AL,LOW 28D	;[AL]=29 if leap, 28 if not
	MOV	BYTE PTR DAYSPM+1,AL	;DAYSPM(2)=28 or 29
	RET	

;CKLEAP returns with [AX]=1 if [CX]+1978 is a leap year, else [AX]=0.
;
CKLEAP:	MOV	AH,LOW 0
	MOV	AL,CL
	AND	AL,LOW 3
	SUB	AL,LOW 2	;[AX]=0 if leap year
	JZ	CKLEA1		;branch if it is leap-year
	MOV	AL,LOW 377O
CKLEA1:	INC	AL
	RET	
ENDIF 

IF	CPM86  
;SETDAT sets the system clock's date.
; Entry - [CX]=year (19xx/20xx)
;         [DH]=month (1..12)
;         [DL]=binary day-of-month (1..31)
; Exit  - [BX] preserved.  All other registers destroyed.
;
SETDAT:	PUSH	BX		;save BX
	CALL	GDTIME		;get current date/time into DATIME
	CALL	DYOFYR		;[BX]=day of year (0..364/365)
				;[CX]=year - 1978
	OR	CX,CX		;test year
	JZ	YEARSX		;branch if 1978
	JMP	SHORT YEARS1
YEARSL:	CALL	CKLEAP		;[AX]=1 if CX is leap-year
	ADD	BX,AX		;days=days+1 if leap-lear
YEARS1:	ADD	BX,365D		;days=days+365
	LOOPNZ	YEARSL
YEARSX:	MOV	WORD PTR DATIME,BX	;DATIME=count of days since 1/1/1978
	CALL	SDTIME		;set current date/time from DATIME
	POP	BX		;restore text pointer
	RET	

;GETDAT returns with [CX]=year, DH=month, DL=day-of-month.
; Exit - BX, AX are used.
;
GETDAT:	CALL	GDTIME		;get current date/time into DATIME
	MOV	DX,WORD PTR DATIME	;[DX]=no of days since JAN 1,1978
	MOV	CX,0		;years=0
FNDYR:	CALL	CKLEAP		;[AX]=1 if leap-year
	ADD	AX,365D		;[AX]=366 if leap-year
	CMP	DX,AX
	JB	GOTYR		;branch if CX=year
	SUB	DX,AX		;days=days-365 or 366
	INC	CX		;year=year+1
	JMP	SHORT FNDYR

GOTYR:	CALL	SETFEB		;set DAYSPM(2)=28 or 29
	MOV	BX,0
	MOV	AH,BH
FNDMON:	MOV	AL,BYTE PTR DAYSPM[BX]	;[AX]=days in month BX
	INC	BX
	CMP	DX,AX
	JB	GOTMON		;branch if BX is month
	SUB	DX,AX
	JMP	SHORT FNDMON

GOTMON:	MOV	DH,BL		;[DH]=month (1..12)
	INC	DL		;[DL]=day of month (1..31)
	ADD	CX,1978D	;[CX]=year
	RET	
ENDIF 
SETDAT:	PUSH	BX
	DOSIO	SDAT		;Give Date to MS-DOS.
	OR	AL,AL		;Date OK?
	JNZ	DATERR		;Brif not.
	POP	BX
	RET	

;GETDAT returns with [CX]=year, DH=month, DL=day-of-month.
; Exit - BX, AX are used.
;
GETDAT:	DOSIO	GDAT		;Get Date from MS-DOS
	RET	
	PAGE	
	SUBTTL TIME - Get/Set Time.

	PUBLIC	TIMES,TIMEF
	EXTRN	STRINI:NEAR,PUTNEW:NEAR,FCERR:NEAR
	EXTRN	CHRGTR:NEAR,SYNCHR:NEAR,GETYPR:NEAR,FRMEVL:NEAR,FRESTR:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	DATIME:WORD,EQULTK:WORD
DSEG	ENDS

; TIME$=[H]H[:[M]M[:[S]S[:[T]T]]]
;
TIMES:	CALL	PRSTIM		;CH=hour, CL=min, DH=sec, DL=.01sec
	JMP	SETTIM		;set system time

;X$=TIME$ returns "HH:MM:SS"
;
TIMEF:
	CALL	CHRGTR		;skip TIME$ (it was CPI'ed in FRMEVL)
	PUSH	BX		;Save Text pointer
	MOV	AL,LOW 8D
	CALL	STRINI		;Get space for 8 char string
	PUSH	DX		;Save addr of string
	CALL	GETTIM		;CH=hour, CL=min, DH=sec
	POP	BX		;Restore addr of String
	MOV	AL,CH
	CALL	PUTCHR		;Store ascii hours
	MOV	AL,LOW ":"
	CALL	PUTCH2
	MOV	AL,CL
	CALL	PUTCHR		;Store ascii minutes
	MOV	AL,LOW ":"
	CALL	PUTCH2
	MOV	AL,DH
	CALL	PUTCHR		;Store ascii seconds.
	JMP	PUTNEW		;Put result and ret (Txt ptr on stack).

	EXTRN	FMULT:NEAR,CONIA:NEAR,FRCSNG:NEAR,FADD:NEAR,PUSHF:NEAR


;PRSTIM parses a string containing "HH[:MM[:SS[.TT]]]
; Exit - CH=hours, CL=minutes, DH=seconds, DL=.01 secs,
;         [BX]=new text pointer.  All other regs preserved.
;
PRSTIM:
	CALL	SYNCHR
	DB	OFFSET EQULTK	;Must be TIME$ = string
	CALL	FRMEVL
	PUSH	BX		;Save Text pointer
	CALL	FRESTR
	MOV	CL,BYTE PTR 0[BX]	;Save string len in [CL]
	CMP	CL,LOW 1	;String must not be null
	JB	TIMERR		;Brif null str
	MOV	SI,WORD PTR 1[BX]	;[SI] has addr of string.
	MOV	BL,CL		;Working reg for string len.
	CALL	GNUM8		;[AX]=hours
	CMP	AL,LOW 24D
	JNB	TIMERR
	MOV	CH,AL		;[CH] = hours
	CALL	TIMSEP
	CALL	GNUM8
	CMP	AL,LOW 60D
	JNB	TIMERR
	MOV	CL,AL		;[CL] = minutes
	CALL	TIMSEP
	CALL	GNUM8
	CMP	AL,LOW 60D
	JNB	TIMERR
	MOV	DH,AL		;[DH] = seconds.
	CALL	TIMSEP
	CALL	GNUM8
	CMP	AL,LOW 100D
	JNB	TIMERR
	MOV	DL,AH		;[DL] = 100ths.
	POP	BX		;Text pointer
	RET			;Exit.

TIMSEP:
	OR	BL,BL
	JZ	TIMSXX
	DEC	BL
	CLD			;Set to increment
	LODSB
	CMP	AL,LOW ":"
	JZ	TIMSXX
	CMP	AL,LOW "."
	JNZ	TIMERR
TIMSXX:
	RET	

TIMERR:	JMP	FCERR


IF	CPM86  
SETTIM:	CALL	GDTIME		;get current date/time into DATIME
	PUSH	BX		;save text pointer
	MOV	BX,OFFSET DATIME+2	;BX points to hours digit of buffer
	MOV	AL,CH
	CALL	BINBCD		;DT.HRS=BINBCD(CH)
	MOV	AL,CL
	CALL	BINBCD		;DT.MIN=BINBCD(CL)
	MOV	AL,DH
	CALL	BINBCD		;DT.SEC=BINBCD(DH)
	CALL	SDTIME		;set current date/time from DATIME
	POP	BX		;restore text pointer
	RET	

;BINBCD converts [AL] to 2-digit BCD and stores the result at [BX]
; Exit  - BX is incremented
;
BINBCD:
	PUSH	DX		;save caller's [DX]
	MOV	AH,LOW 0
	MOV	DL,LOW 10D
	DIV	DL		;[AL]=[AX]/10, [AH]=remainder
	ADD	AL,AL		;[AL]=1st digit * 2
	ADD	AL,AL		; * 4
	ADD	AL,AL		; * 8
	ADD	AL,AL		; * 16
	ADD	AL,AH		; + second digit
	POP	DX		;restore caller's [DX]
	JMP	PUTCH2

GETTIM:	CALL	GDTIME		;get current date/time into DATIME
	MOV	BX,OFFSET DATIME+2	;BX points to hours digit of buffer
	CALL	BCDBIN
	MOV	CH,AL		;[CH]=BCDBIN(DT.HRS)
	CALL	BCDBIN
	MOV	CL,AL		;[CL]=BCDBIN(DT.MIN)
	CALL	BCDBIN
	MOV	DH,AL		;[DH]=BCDBIN(DT.SEC)
	RET	

;GDTIME sets DATIME to the current date-time.
; Exit - All registers preserved.
;
GDTIME:	PUSH	ES
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	CLD			;Because of Melco BIOS Bug
	MOV	DX,OFFSET DATIME
	CPMXIO	155D		;CPM86 system call
	JMP	SHORT SDTIMX

;SDTIME sets the system clock to DATIME
; Exit - All registers preserved.
;
SDTIME:	PUSH	ES
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	MOV	DX,OFFSET DATIME
	CPMXIO	104D		;CPM86 system call
SDTIMX:	POP	DX
	POP	CX
	POP	BX
	POP	AX
	POP	ES
	RET	

;BCDBIN converts [[BX]] from 2-digit BCD to binary and
; returns it in [AL]
; Exit  - BX is incremented, AH, DL are destroyed.
;
BCDBIN:	MOV	AL,BYTE PTR 0[BX]
	INC	BX
	MOV	AH,AL		;[AH]=copy of input parameter
	AND	AL,LOW 360O	;[AL]=D1*16 (most significant digit)
	ROR	AL,1		;[AL]=D1*8
	MOV	DL,AL		;[DL]=D1*8
	ROR	AL,1		;[AL]=D1*4
	ROR	AL,1		;[AL]=D1*2
	ADD	AL,DL		;[AL]=D1*10
	AND	AH,LOW 17O	;[AH]=D2
	ADD	AL,AH		;[AL]=10*D1+D2=binary result
	RET	
ENDIF 
SETTIM:	PUSH	BX
	DOSIO	STIM		;Give Time to MS-DOS.
	OR	AL,AL		;Date OK?
	JNZ	TIMERR		;Brif not.
	POP	BX
	RET	

GETTIM:	DOSIO	GTIM		;Get Time from MS-DOS
	RET	

	SUBTTL  Error Handlers for Features not supported in a version

	EXTRN	DERDNA:NEAR
	JMP	DERDNA		;Device unavailable error

PUBLIC	PALETE
PALETE:
	JMP	SNERR


DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	ERRADV:WORD
DSEG	ENDS
	EXTRN	ERROR:NEAR

PUBLIC	TIMER
TIMER:
PUBLIC	ERDEV
ERDEV:
PUBLIC	IOCTL
IOCTL:
PUBLIC	CHDIR
CHDIR:
PUBLIC	MKDIR
MKDIR:
PUBLIC	RMDIR
RMDIR:
PUBLIC	SHELL
SHELL:
PUBLIC	ENVIRON
ENVIRON:
PUBLIC	VIEW
VIEW:
PUBLIC	WINDOW
WINDOW:
PUBLIC	PMAP
PMAP:
ADVERR:
	MOV	DL,LOW OFFSET ERRADV
	JMP	ERROR

CSEG	ENDS
	END
                                                                                                                              