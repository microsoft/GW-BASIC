; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   SCNDRV  This is the OS independent Screen Driver for GW BASIC
	SUBTTL  DATA DEFINITIONS - Miscellaneous

COMMENT	*
	--------- --- ---- -- ---------
	COPYRIGHT (C) 1982 BY MICROSOFT
	--------- --- ---- -- ---------

	PROGRAMMER: MARC WILSON

	*
	INCLUDE	GIO86U
	.SALL
	.RADIX	8

;OEM IFNDEFs
MELCO=0
CANON=0

;GENERIC IFNDEF'S:
TERMSW=0
HLPEDT=0
NMPAGE=1			;Number of pages
NEWCHP=1			;New change page routine
IBMEOL=IBMLIK			;Clear to EOL for COMPATIBILITY
IBMCSR=IBMLIK			;IBM COMPATIBILITY for cursor

;Definition of scroll types
; Choice of scroll type is by switch SCROLT.
; Switches defined here are used to implement a specific SCROLT type.
; If other scroll types are needed then additional SCROLT types should be
;   defined here.
	INVLIN=SCROLT		;Invisible (function key) Line
	FKFSRL=(SCROLT-1) AND 1	;Clear fkeys/full scroll/rewrite fkeys


;OTHER GENERIC SWITCHES(OEM SPECIFIC)
	TXTWDO=0		;list of OEM's which have window setting capability

	SUBTTL  DATA DEFINITIONS - Internal routines(with usage description)


;Entry points
	PUBLIC	SCNSWI		; Set CRT physical line width
				;on entry:  AL=width, CL=height

	PUBLIC	SCNCLR		; Clear CRT, Refresh Function Key Display,
				; Home Graphics and Text Cursors
				;on entry:  none

	PUBLIC	SCNLOC		; Locate cursor on physical screen(1,1 = HOME)
				;on entry:  AH=column(x), AL=line(y)

	PUBLIC	SCNOUT		; Character output at current position
				;on entry:  AX=character

	PUBLIC	SCNRDL		; Read a physical line at current position
				;on entry:  DI=address of where to put string, CX=max count
				;on exit:   CX=CX-number of characters read
				;           DI=DI+number of characters read


	PUBLIC	SCNPOS		; Return current cursor location
				;on exit:   DL=cursor line, DH=cursor column

	PUBLIC	SCNRDT		; Read terminator for physical line
				;on entry:  DL=line number
				;on exit:   AH= terminator column, AL=terminator value
				;           Flags indicate terminator value:
				;           CF=EOL, ZF=Linefeed

	PUBLIC	SCNGWI		; Read logical width of lines
				;on exit:   AH=logical width of lines

	PUBLIC	SCNMRK		; Mark position as current FSTPOS, LSTPOS
				;on entry:  ZF set indicates use WDOLFT as column
				;           ZF clear indicates use CSRX as column

	PUBLIC	SCNIPL		; Initialize - called during IPL

	PUBLIC	SCNBRK		; Initialize - called when BREAK received by POLKEY
	SUBTTL  DATA DEFINITIONS - External routines and data



;EXTERNAL ROUTINES
	EXTRN	SCROLL:NEAR	; OEM supplied SCROLL routine
	EXTRN	SCROUT:NEAR	; OEM supplied character output
	EXTRN	SCRINP:NEAR	; OEM supplied screen input(read character)
	EXTRN	CLREOL:NEAR	; OEM supplied screen clear to end of line

;THE FOLLOWING IS DATA UNIQUE TO THE SCNDRV MODULE
;       ALL DATA IS ONE BYTE LONG UNLESS STATED OTHERWISE
DSEG	SEGMENT PUBLIC 'DATASG'		
	ASSUME DS:DSEG
	EXTRN	LINCNT:WORD	; Number of lines
	EXTRN	CRTWID:WORD	; Characters per line
	EXTRN	WDOTOP:WORD	; Top line in window(1-[LINCNT])
	EXTRN	WDOBOT:WORD	; Bottom line in window([WDOTOP]-[LINCNT])
	EXTRN	WDOLFT:WORD	; Leftmost column in window(1-[CRTWID])
	EXTRN	WDORGT:WORD	; Rightmost column plus one([WDOLFT]-[LINCNT])
	EXTRN	LINLEN:WORD	; Line max width(1 to CRTWID)
	EXTRN	LINTTB:WORD	; Line terminator table((# lines * 2) bytes long)
				; Two items per entry:
				;   Terminator, last column
	EXTRN	TRMCUR:WORD	; Address of current terminator entry(2 bytes)
	EXTRN	FSTLIN:WORD	; Line number saved by SCNSTM call
	EXTRN	FSTCOL:WORD	; Column saved as above and decreases to WDOLFT
	EXTRN	LSTLIN:WORD	; Line number saved by SCNSTM and grows as the
				;   logical line grows.
	EXTRN	LSTCOL:WORD	; Column saved as above which grows as the logical
				;   line grows(always reflects last col on LSTLIN).
	EXTRN	F_CRET:WORD	; Zero indicates last character output was CR
	EXTRN	CSRY:WORD	; Current line(1-[LINCNT])
	EXTRN	CSRX:WORD	; Current column(1-[CRTWID])
	EXTRN	KEYSW:WORD	; ^O377=Function Keys displayed on bottom line

;THE FOLLOWING DATA IS ACCESSED BY SCNDRV BUT SET ELSEWHERE
	EXTRN	F_EDIT:WORD	; Set to non-zero by INLIN when editing
	EXTRN	F_INST:WORD	; Set to non-zero by INLIN for insert mode
DSEG	ENDS
	SUBTTL  DATA DEFINITIONS - Literals



;CHARACTER DEFINITIONS
;
	CHREDT=1		; EDiT
	CHRBKW=2		; BacK Word
	CHRCAN=3		; CANcel
	CHRHCN=4		; Hard CaNcel
	CHRCLE=5		; CLear to End of line
	CHRFDW=6		; ForwarD Word
	CHRBEL=7		; BELl
	CHRBAK=8D		; BAcKspace
	CHRTAB=9D		; TAB
	CHRLNF=10D		; LiNeFeed
	CHRHOM=11D		; HOMe
	CHRERA=12D		; ERAse
	CHRRET=13D		; RETurn
	CHRAPP=14D		; APPend
	CHRINS=18D		; INSert
	CHRFKD=20D		; Function Key Display key
	CHRLDL=21D		; Line DeLete
	CHRADV=28D		; cursor RiGhT
	CHRREG=29D		; cursor LeFT
	CHRUP=30D		; cursor UP
	CHRDWN=31D		; cursor DoWN
	CHRDEL=127D		; DELete

;TERMINATOR TABLE LITERALS
PUBLIC	TRMLNF
	TRMLNF=10D		; LINEFEED terminator
PUBLIC	TRMEOL
	TRMEOL=177O		; EOL terminator
PUBLIC	TRMWRP
	TRMWRP=0		; WRAP terminator
PUBLIC	TRMNWP
	TRMNWP=1		; NULL WRAP terminator
PUBLIC	TRMNUL
	TRMNUL=200O		; Sign bit indicates initialize line

;DEFAULT SCREEN SIZE
PUBLIC	SCNSIZ
	SCNSIZ=20D+(40D*400O)	; Height = 20, Width = 40

	SUBTTL  SCNIPL, SCNSWI AND SCNWDO   The parameter setting routines



;SUBROUTINE SCNIPL():           ; Initialize
;**
SCNIPL:
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	ESCFLG:WORD
DSEG	ENDS
	MOV	BYTE PTR ESCFLG,LOW 0
	RET	
;** END SUBROUTINE SCNIPL

;BREAK - reset flags etc. when ^C typed.
;
SCNBRK:	MOV	BYTE PTR FSTLIN,LOW 0
	MOV	BYTE PTR LSTLIN,LOW 377O	; Set FSTPOS, LSTPOS to impossible values
	MOV	BYTE PTR F_CRET,LOW 377O	; Clear "last char was CR" flag
	RET	

;SUBROUTINE SCNSWI(WIDTH,HEIGHT):       ; Set screen width(logical/physical) and height
;**                     on entry:   AL=width, CL=height
;**
SCNSWI:	MOV	BYTE PTR CRTWID,AL	; Save physical width
	MOV	BYTE PTR LINLEN,AL	; Set logical line length
	MOV	BYTE PTR LINCNT,CL	; Save physical height
	MOV	BYTE PTR WDOTOP,LOW 1	; Init window top
	PUSH	CX
	DEC	CL		; Reserve status line
	MOV	BYTE PTR WDOBOT,CL	; Set window bottom
	POP	CX
	MOV	BYTE PTR WDOLFT,LOW 1	; Set window left
	MOV	BYTE PTR WDORGT,AL	; Set window right
	RET	
;** *** END
;** END SUBROUTINE SCNSWI


;SUBROUTINE SCNWDO(POSN,COUNT): ; Set text window
;**
;**                             on entry:   AH=column posn, AL=line posn
;**                                         CH=width, CL=height
;**                             on exit:    AX,CX=values actually set
;**                                         CF indicates posn outside screen
;**
;**                             NOTE: This routine truncates width and height.
;**
;** IF POSN IS CONTAINED WITHIN PHYSICAL SCREEN BEGIN
	SUBTTL CURSOR READ/WRITE



;SUBROUTINE SCNLOC(X,Y):        ; Locate cursor on physical screen
;**                         on entry:   AH=column, AL=line(1,1 is home)
;**
SCNLOC:	MOV	BYTE PTR CSRX,AH
	MOV	BYTE PTR CSRY,AL
	RET	
;** END SUBROUTINE SCNLOC

;SUBROUTINE SCNCLR(X,Y):        ; Clear Screen, Home Text & Graphics Cursor,
;                               ; Refresh Function Key Display
;**                         on entry:
;
	EXTRN	KEYDSP:NEAR,GRPINI:NEAR
SCNCLR:
	CALL	TTBINI		;Clear the terminator table
	CALL	GRPINI		;Home the graphics cursor
	CALL	WHOME		;DX=cursor home
	MOV	AX,DX
	CALL	SCNLOC		;set cursor position
	JMP	KEYDSP		;Conditionally display softkeys and return
;** END SUBROUTINE SCNCLR

;SUBROUTINE SCNPOS              ; Read current cursor location
SCNPOS:	MOV	DH,BYTE PTR CSRX
	MOV	DL,BYTE PTR CSRY
	PUSHF	
	CMP	DH,BYTE PTR LINLEN
	JBE	SCNPS1		;BRIF not beyond edge of screen
	MOV	DH,BYTE PTR LINLEN	;Force posn within screen
SCNPS1:	POPF	
	RET	
;** END SUBROUTINE SCNPOS

;SUBROUTINE SCNGWI              ; Read current logical width
;**                         on exit:    AH=width
;**
SCNGWI:	MOV	AH,BYTE PTR LINLEN
	RET	
;** END SUBROUTINE SCNGWI
	SUBTTL  TERMINATOR TABLE READ/WRITE/INITIALIZE


;SUBROUTINE SCNRDT(Y):          ; Read terminator value and column
;**                         on entry:   DL=line number
;**                         on exit:    AH=terminator posn, AL=terminator value
;**                                     If CF=1; EOL
;**                                     If CF=0 and ZF=1; LF terminated
;**
SCNRDT:	PUSH	BX
	MOV	BL,DL		; BX = Displacement into table
	ADD	BL,BL
	MOV	BH,LOW 0
	MOV	WORD PTR TRMCUR,BX	; Save address of terminator reading(for set term)
	MOV	AH,BYTE PTR LINTTB-2[BX]	; Get terminator posn
	MOV	AL,BYTE PTR LINTTB-1[BX]	; Get terminator value
	AND	AL,LOW OFFSET 377O-TRMNUL	; Get rid of initialize line status bit
	CMP	AL,LOW OFFSET TRMEOL
	STC	
	JZ	SCNRTX		; BRIF EOL terminator(CF=1)
	CMP	AL,LOW OFFSET TRMLNF	; CF=0, set ZF if linefeed terminated
	JNB	SCNRTX		; BRIF carry not set
	CMC			; clear carry
SCNRTX:	POP	BX
	RET	
;** END SUBROUTINE SCNRDT


;SUBROUTINE SCNWTT(TERM)        ; Set new value for terminator last read
;**                     on entry:   AH=column where physical line ends
;**                                 AL=terminator type(one of: TRMEOL, TRMLNF
;**                                     TRMWRP, TRMNWP)
;**
SCNWTT:	PUSH	BX
	MOV	BX,WORD PTR TRMCUR	; Get address of terminator last read
	MOV	BYTE PTR LINTTB-2[BX],AH
	AND	BYTE PTR LINTTB-1[BX],LOW OFFSET TRMNUL
	OR	BYTE PTR LINTTB-1[BX],AL	; Write new terminator, leaving NULL bit
	POP	BX
	RET	
;** END SUBROUTINE SCNWTT

;TERMINATOR TABLE INIT
;
TTBINI:	MOV	CX,OFFSET NMLINE+1	; CX=count of line term table entries
	MOV	BX,OFFSET LINTTB	; BX=addr of line term table
TTBIN0:	MOV	BYTE PTR 0[BX],LOW 0	; Clear column number
	MOV	BYTE PTR 1[BX],LOW OFFSET TRMEOL	; Set terminator to <CR>
	INC	BX
	INC	BX
	LOOP	TTBIN0		; Init entire line terminator table
	RET	
	SUBTTL  CHARACTER OUTPUT



;SUBROUTINE SCNOUT(CHAR):       ; Output character
;**                         on entry:   AX= character
;**

SCNOUT:	PUSH	DX
	PUSH	CX
	PUSH	BX
	CALL	CTLDSP		; If control char or ESC sequence, do operation
	JB	SCNOTX		; No char to output
	CALL	CHWRAP		; Do wrap for char in AX, return DX=posn for output
	EXTRN	SETCSR:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CSRTYP:WORD
DSEG	ENDS
	MOV	BYTE PTR CSRTYP,LOW 0D	; Set next cursor type to off
	CALL	SETCSR		; Insure that the cursor is off

	CALL	SCROUT		; Send char in AX to BIOS at DX posn
	MOV	BYTE PTR F_CRET,LOW 377O	; Clear last char was Carriage return flag
SCNOTX:	POP	BX
	POP	CX
	POP	DX
	RET	
;** END SUBROUTINE SCNOUT

;SUBROUTINE MKRMCI              ; Open up sapce for char if insert mode
;
MKRMCI:	PUSHF	
	TEST	BYTE PTR F_INST,LOW 377O
	JZ	MKRCIX		; BRIF not insert mode(do nothing)
	POPF	
	MOV	CH,AL
	INC	CH		; CH=space needed
	CALL	MKRMCH		; Open up space at (DH,DL) for count of CH
	CALL	SCNRDX		; Put terminator table values in CX
	RET	
MKRCIX:	POPF	
	RET	

SCNRDX:	XCHG	AX,CX
	CALL	SCNRDT
	XCHG	AX,CX
	RET	
	SUBTTL  LINE WRAP LOGIC - Character wrap



;THE LINE WRAP LOGIC IS USED PRIOR TO OUTPUTTING CHARACTERS OR STRINGS
;   IT WILL RESERVE THE NECESSARY NUMBER OF CHARACTERS ON THE CURRENT
;   LOGICAL LINE OR WILL RETURN CARRY SET AND DX=POSN WHERE CHARACTER
;   CAN BE OUTPUT(I.E. IT RETURNS A POSN LESS THAN CURRENT POSN)

;SUBROUTINE CHWRAP(CHAR):       ; Do single character wrap
;**                     on entry:   AX=character
;**                                 DH=CSRX, DL=CSRY
;**                     on exit:    if cannot wrap, CF=1
;**                                 DX=posn where character can be output
;**                                 cursor posn and terminator table are updated
;**                     NOTE: if CF=1 then DX may be set to a previous posn
;**                         where there is enough room to EOL.
;**
CHWRAP:	PUSH	AX
	XOR	CH,CH
	OR	AH,AH
	JZ	CHWRP0		; BRIF Single byte character
	MOV	CH,LOW 1	; It's two byte character
CHWRP0:	MOV	CL,CH
	ADD	CH,DH		; CH=column after char is output
	CALL	SCNRDT		; Read terminator
	XCHG	CX,AX
;** IF POSN .LT. EOL BEGIN
;** AT THIS POINT AH=POSN(WHERE GOING TO), DX=CURRENT POSN,
;** AL=LENGTH OF CHARACTER, CX=CURRENT TERMINATORS
	PUSHF	
	CMP	AH,BYTE PTR LINLEN
	JA	CHWRP1		; BRIF not space before end of physical line
	POPF	
	CALL	MKRMCI		; If insert mode, open up space for character
;** *** IF NOT(LINEFEED .EQ. TERMINATOR(CURRENT_LINE) AND POSN .EQ. LINLEN)
;** *** *** RETURN, OUTPUT IS AT CURRENT POSN
	JB	CHWPXI		; EOL terminated, output at current posn
	JZ	CHWPLF		; BRIF LF terminated
	CMP	CL,LOW OFFSET TRMWRP
	JZ	CHWPXI		; BRIF WRAP(always room)
	CMP	AH,BYTE PTR LINLEN
	JB	CHWPXI		; BRIF NUL_WRAP and not overwriting NULL
	MOV	CL,LOW OFFSET TRMWRP
CHWPXI:	JMP	CHWRPX		; Overwriting NULL_WRAP, set to WRAP
CHWPLF:	CMP	AH,BYTE PTR LINLEN
	JAE	CHWPL1		; LF terminated and no room for LF
	INC	AH		; Need to terminate at one past posn printing at
	XCHG	AX,CX
	CMP	AH,CH
	MOV	AH,CH
	JA	CHWPL0		; BRIF current posn below terinator posn
	CALL	SCNWTT		; Terminate line at one more than print posn
CHWPL0:	CLC	
	XCHG	AX,CX
	PUSHF	
	DEC	AH		; Restore column actually printing at
	JMP	CHWRP9		; Update LSTPOS, FSTPOS, cursor posn, exit
;** *** *** ELSE MOVE LINEFEED TO NEXT LINE
CHWPL1:	CALL	WRAPLF		; Move linefeed to next line
	JB	CHWRNI		; Error, output at posn-(char length)
	CLC	
	PUSHF	
	MOV	AH,CH
	JMP	CHWRP9		; Exit without updating terminator
CHWRNI:	JMP	CHWRNO
;** *** END

;** *** DO CASE TERMINATOR(CURRENT_LINE) OF
;** *** There is not enough room on current line for character
CHWRP1:	POPF	
	JB	CHWREL		; BRIF EOL terminated
	JZ	CHWRLF		; BRIF LF terminated
;** *** CASE: WRAP; NULL_WRAP; BEGIN
;** *** *** *** SET WRAP TERMINATOR
CHWRWP:	MOV	CL,LOW OFFSET TRMWRP
	MOV	CH,BYTE PTR LINLEN
	XCHG	AX,CX
	CALL	SCNWTT		; Set wrap terminator at last column
	CMP	DL,BYTE PTR LSTLIN
	JNZ	CHWRN0		; BRIF not on last line
	INC	BYTE PTR LSTLIN	; Wrap LSTLIN
	MOV	BYTE PTR LSTCOL,LOW 0	; Force update of LSTCOL at CHWRPZ
CHWRN0:	INC	DL		; Next line
	CALL	SCNRDT		; Set up for write at new line
	MOV	DH,BYTE PTR WDOLFT	; First column is output posn
	MOV	CH,DH
	ADD	CH,CL		; CH=POSN going to
	XCHG	AX,CX
	CALL	MKRMCI		; If insert mode, open up space for character
	CMP	CL,LOW OFFSET TRMLNF
	JNZ	CHWRPX		; BRIF not linefeed terminated
	XCHG	AX,CX		; CH=POSN, AX=current terminators
	INC	CH		; Need terminator one beyond actual output
	CMP	AH,CH
	MOV	AH,CH
	JA	CHWRN2		; BRIF Current terminator beyond posn for output
	CALL	SCNWTT		; Set current terminator to new max posn
CHWRN2:	DEC	CH		; Restore POSN going to
	XCHG	AX,CX
CHWRPX:	CLC	
	JMP	SHORT CHWRPZ	; All done
;** *** *** *** END
;** *** *** END
;** *** CASE: EOL
CHWREL:	CALL	MKRMNL		; Make room on next line(make it EOL term'd)
	JB	CHWRP3		; If error, make room for char on this line
	CALL	SCNRDX		; Reread terminator for this line
	JMP	SHORT CHWRWP	; Wrap to next line
;** *** CASE: LF
CHWRLF:	XCHG	AX,CX
	CALL	WRAPLF		; First wrap LF to next line
	MOV	AL,LOW OFFSET TRMNWP	; Set to temporary NULL_WRAP at last column
	MOV	AH,BYTE PTR LINLEN
	CALL	SCNWTT
	XCHG	AX,CX
	JNB	CHWRWP		; Go do wrap for char
;No room, abort
CHWRP3:	MOV	AH,BYTE PTR LINLEN	; AH=POSN going to
CHWRNO:	MOV	DH,AH
	SUB	DH,AL		; DH=POSN-(char len)
	STC			; Error return
;** *** END CASE TERMINATOR(CURRENT_LINE)

;** EXIT
CHWRPZ:	PUSHF	
	XCHG	AX,CX		; CH=POSN, AX=current terminators
	CMP	AH,CH
	MOV	AH,CH
	JA	CHWRP9		; BRIF Current terminator beyond posn for output
	PUSH	AX
	CALL	SCNRDT
	POP	AX
	CALL	SCNWTT		; Set current terminator to new max posn
CHWRP9:	MOV	BYTE PTR CSRY,DL
	CMP	DL,BYTE PTR LSTLIN
	JNZ	CHWNTL		; BRIF not on last logical line
	CMP	AH,BYTE PTR LSTCOL
	JB	CHWNTL		; BRIF not new last position
	MOV	BYTE PTR LSTCOL,AH	; Set new last posn
CHWNTL:	CMP	DL,BYTE PTR FSTLIN
	JNZ	CHWNTF		; BRIF not on first logical line
	CMP	DH,BYTE PTR FSTCOL
	JAE	CHWNTF		; BRIF not new first position
	MOV	BYTE PTR FSTCOL,DH
CHWNTF:	INC	AH
	MOV	BYTE PTR CSRX,AH	; Set new posn(one past last posn printed at)
	CMP	BYTE PTR LINLEN,AH
	JAE	CHWNTG		; BRIF does not go beyond end of physical line
	CALL	SCNRDT
	JB	CHWNTG		; BRIF line does not continue
	INC	BYTE PTR CSRY	;   Logical line continues, put cursor at
	MOV	AH,BYTE PTR WDOLFT	;       start of next physical line
	MOV	BYTE PTR CSRX,AH
CHWNTG:	POPF	
	POP	AX
	RET	
;Wrap linefeed on end of line to next line
WRAPLF:	PUSH	WORD PTR TRMCUR
	PUSH	CX
	PUSH	DX
	MOV	DH,BYTE PTR LINLEN
	MOV	CH,LOW 1
	CALL	MKRMCH		; Insert one space before LF
	POP	CX
	MOV	CL,DL
	POP	DX
	XCHG	CX,DX
	POP	WORD PTR TRMCUR
	RET	
	SUBTTL  LINE WRAP LOGIC - Open next line for wrap



;SUBROUTINE MKRMNL(line)        ; Make the next line a blank, empty line
;**                     on entry:   DL=current line number
;**                     on exit:    DL=current line number(may change from entry)
;**                                 if CF=1 no room available
;**
MKRMNL:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
MKRMN0:	CALL	SCNRDT
	JB	MKRMN5
	CMP	DL,BYTE PTR WDOBOT
	JZ	MKRMN6
	JB	MKRMN4
	MOV	DL,BYTE PTR WDOBOT
	JMP	SHORT MKRMN0
MKRMN4:	INC	DL
	JMP	SHORT MKRMN0

;** IF CURRENT_PHYSICAL .LT. WINDOW_BOTTOM
MKRMN5:	CMP	DL,BYTE PTR WDOBOT
MKRMN6:	POP	DX
	PUSH	DX		; Get back posn to scroll from
	JZ	MKRMN7		; BRIF at bottom of window(scroll up)
	CMC	
	JB	MKRMNZ		; BRIF outside of window
	CMP	DL,BYTE PTR WDOTOP
	JB	MKRMNZ		; BRIF outside of window
	TEST	BYTE PTR F_EDIT,LOW 377O
	JZ	MKRMNZ		; BRIF not editing, no need to scroll
	INC	DL		; Scroll down starting at next line
;** *** SCROLL DOWN
	CALL	SCRLD0		; Scroll down to end of window
MKRMNY:	CLC			; Indicate successful
MKRMNZ:	POP	DX		; Restore current line number
	JMP	SHORT MKRMNX
;** *** ELSE IF (FIRST_PHYSICAL(LOGICAL) .NE. WINDOW_TOP) OR NOT(INPUT_EDIT)
MKRMN7:	TEST	BYTE PTR F_EDIT,LOW 377O
	JZ	MKRMN9		; BRIF not input edit, always allow scroll
MKRMN8:	CALL	CSRUP
	JB	MKRMNZ		; BRIF logical line starts at top of window(abort)
	PUSH	AX
	CALL	SCNRDT
	POP	AX
	JNB	MKRMN8		; BRIF previous physical part of this logical
;** *** SCROLL UP
MKRMN9:	POP	DX
	PUSH	DX
	CMP	DL,BYTE PTR WDOBOT	; Full screen scroll?
	JAE	MKRMNF		; BRIF scroll up entire screen
	CALL	SCRLUD		; Scroll up from DL to WDOTOP
	JMP	SHORT MKRMNU
MKRMNF:	CALL	SCRLUP		; Scroll up entire window
MKRMNU:	POP	DX
	CALL	CSRUP		; Return line number of original line
	CLC	
MKRMNX:	POP	CX
	POP	BX
	POP	AX
	RET	
	SUBTTL  SCROLL ROUTINES - Scroll up and down


;Scroll up from DL to WDOTOP
SCRLUD:	PUSH	CX
	MOV	CL,DL
	MOV	DL,BYTE PTR WDOTOP
	JMP	SHORT SCRLU1
;SCROLL UP
SCRLUP:	MOV	DL,BYTE PTR WDOTOP	; Top line number
;Scroll up from DL to bottom
SCRLU0:	PUSH	CX
	MOV	CL,BYTE PTR WDOBOT
SCRLU1:	PUSH	AX
	PUSH	BX
	PUSH	DX
	MOV	AL,DL
	MOV	BL,DL		; From = To = Top line number
	INC	AL		; From = To + 1
	MOV	BH,BYTE PTR WDOLFT
	MOV	AH,BH		; From column = To column = left margin
	SUB	CL,BL		; CL = line count
	JA	SCRUL1		; BRIF two or more line scroll
	JB	SCRUL4		; BRIF TOP > BOTTOM(should never happen)
	PUSH	AX
	MOV	DL,BL
	JMP	SHORT SCRUL3	; TOP=BOTTOM, just init line
SCRUL1:	PUSH	AX
	MOV	CH,BYTE PTR CRTWID	; Scroll entire lines
	CALL	SCROLL		; Scroll screen
;If CSRY, FSTLIN, LSTLIN are within scroll, decrement their values
	ADD	AL,CL		; AL=Last line scrolled + 1
	DEC	AL		; AL=Bottom line scrolled
				; BL=Top line scrolled
	MOV	AH,LOW 255D	; decrement line# variables in scroll window
	CALL	TSTSCR
	MOV	DL,AL		; DL=bottom line of scroll (initialize it)
;Clear the last line of the scroll
SCRUL3:	MOV	DH,BYTE PTR WDOLFT
	POP	AX
	OR	CL,CL
	JE	SCRUL4		; No scroll(one line init)
	CALL	SCRUTT		; Scroll up terminator table
SCRUL4:	CALL	PLINIT		; Init physical line from (DL,DH) to (DL,WDORGT)
	POP	DX
	POP	BX
	POP	AX
	POP	CX
	RET	

;TSTSCR is called after Scrolling Up or Down to update Line Number variables
; which may be in the scroll window
; Entry - BL=top line number of scroll window
;         AL=bottom line number of scroll window
;         AH=1 if line# variables are to be incremented, -1 if decremented
;
TSTSCR:	PUSH	SI
	PUSH	AX
	MOV	SI,OFFSET CSRY
	CALL	TSTWDO		; Adjust CSRY if its within scroll window
	MOV	AH,BYTE PTR WDOTOP
	CMP	BYTE PTR 0[SI],AH
	JB	TCSRY1		; BRIF CSRY above top of window
	MOV	AH,BYTE PTR WDOBOT
	CMP	BYTE PTR 0[SI],AH
	JNA	CSRYOK		; BRIF CSRY didn't increment beyond bottom
TCSRY1:	MOV	BYTE PTR 0[SI],AH	; Bring it back to within scroll window
CSRYOK:	MOV	SI,OFFSET FSTLIN
	POP	AX
	CALL	TSTWDO		; Adjust FSTLIN if its within scroll window
	MOV	SI,OFFSET LSTLIN
	CALL	TSTWDO		; Adjust LSTLIN if its within scroll window
	POP	SI
	RET	

; If BL .LEQ. [SI] .LEQ. AL then [SI]=[SI]+AH
;
TSTWDO:
	CMP	AL,BYTE PTR 0[SI]
	JB	NINWDO		; BRIF [SI] not within scroll
	CMP	BL,BYTE PTR 0[SI]
	JA	NINWDO		; BRIF [SI] not within scroll
	ADD	BYTE PTR 0[SI],AH	; Adjust [SI] for scroll
NINWDO:	RET	



;SCROLL DOWN
SCRLDN:	MOV	DL,BYTE PTR WDOTOP
;Scroll down from DL to WDOBOT
SCRLD0:	PUSH	AX
	PUSH	BX
	PUSH	CX
	MOV	AL,DL
	MOV	BL,DL		; From = To = top of scroll
	INC	BL		; To = From + 1
	MOV	BH,BYTE PTR WDOLFT	; Column = left margin
	MOV	AH,BH
	MOV	CL,BYTE PTR WDOBOT
	SUB	CL,AL		; Count of lines =(window bottom)-top of scroll
	PUSH	AX
	JBE	SCRDL3		; BRIF null scroll, just clear line
	MOV	CH,BYTE PTR WDORGT	; Scroll lines, not columns
SCRLD1:	CALL	SCROLL		; Scroll screen
;If CSRY, FSTLIN, LSTLIN are within scroll, increment their values
	ADD	AL,CL		; AL=Last line scrolled
	DEC	AL
	MOV	AH,LOW 1	; increment line# variables in scroll window
	CALL	TSTSCR
;Clear the last line of the scroll(in DL)
SCRDL3:	MOV	DH,BYTE PTR WDOLFT
	POP	AX
	OR	CL,CL
	JS	SCRDL4		; No scroll(out of window)
	JE	SCRDL4		; No scroll(one line init)
	CALL	SCRDTT		; Scroll down term table(mark last line init'd)
SCRDL4:	CALL	PLINIT		; Init physical line from (DL,DH) to (DL,WDORGT)
	POP	CX
	POP	BX
	POP	AX
	RET	

;SCROLL DOWN current line to next line
SCRDLN:	PUSH	AX
	PUSH	BX
	PUSH	CX
	MOV	AX,DX		; Start of scroll is current line
	MOV	AH,BYTE PTR WDOLFT
	MOV	BX,AX
	INC	BL		; TO start is next line
	MOV	CH,BYTE PTR WDORGT
	MOV	CL,LOW 1	; Scroll one entir line
	PUSH	AX
	JMP	SHORT SCRLD1	; Do scroll and update LSTPOS, FSTPOS, CSRY
	SUBTTL  SCROLL ROUTINES - Support routines: scroll terminator table, line init



;Scroll up terminator table(same parameters as SCROLL)
;                   on entry:   (see SCROLL)
;                   on exit:    modifies AX, BX, CX
;
SCRUTT:	PUSH	DX
	MOV	DL,BL
	CALL	SCNRDT		; TRMCUR=address of top of scroll
	MOV	BX,WORD PTR TRMCUR
	MOV	CH,LOW 0
SCRUTL:	MOV	AX,WORD PTR LINTTB[BX]	; Get a terminator
	MOV	WORD PTR LINTTB-2[BX],AX	; Save a terminator
	INC	BX
	INC	BX
	LOOP	SCRUTL		; Continue till done
	MOV	BYTE PTR LINTTB-2[BX],LOW 0	; Terminate end line of scroll
	MOV	BYTE PTR LINTTB-1[BX],LOW OFFSET TRMEOL
	POP	DX
	RET	

;Scroll down terminator table(same parameters as SCROLL)
;                   on entry:   (see SCROLL)
;                   on exit:    modifies AX, BX, CX
;
SCRDTT:
	PUSH	DX
	MOV	DL,AL
	ADD	DL,CL
	CALL	SCNRDT		; TRMCUR=displacement of bottom of scroll + 2
	MOV	BX,WORD PTR TRMCUR
	MOV	CH,LOW 0
SCRDTL:	SUB	BX,2		; Next posn
	MOV	AX,WORD PTR LINTTB-2[BX]	; Get a terminator
	MOV	WORD PTR LINTTB[BX],AX	; Save a terminator
	LOOP	SCRDTL		; Continue till done
	MOV	BYTE PTR LINTTB-2[BX],LOW 0	; Terminate end line of scroll
	MOV	BYTE PTR LINTTB-1[BX],LOW OFFSET TRMEOL
	MOV	DL,BYTE PTR WDOBOT
	CALL	SCNRTL
	JB	SCRDT1		; EOL term'd, all done
	JNZ	SCRDT1
	DEC	AH
SCRDT1:	MOV	AL,LOW OFFSET TRMEOL
	CALL	SCNWTT		; Make sure last line in window is EOL term'd
	POP	DX
	RET	

;Physical line initialization
;               on entry:   (DH,DL) = start of initialization
;
PLINIT:	PUSH	CX
	PUSH	AX
	CALL	SCNRDT
	MOV	AH,DH
	DEC	AH
	PUSH	BX
	MOV	BX,WORD PTR TRMCUR	; Terminate line to left of DH
	MOV	BYTE PTR LINTTB-1[BX],LOW OFFSET TRMEOL
	MOV	BYTE PTR LINTTB-2[BX],AH
	POP	BX
	POP	AX
PLINI2:	CALL	CLREOL		; Clear to end of line from (DH,DL)
	POP	CX
	RET	
	SUBTTL  LABEL Key Processing


;LABELK - If function key display is off then turn on and exit.
;         If function key display is on then advance display line and
;         redisplay.
;ENTRY  - DX = cursor position
;EXIT   - DX unmodified
;USES   - AX,BX,CX
;
	EXTRN	FKYADV:NEAR,KEYDSP:NEAR,FKYFMT:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	KEYSW:WORD
DSEG	ENDS
LABELK:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	CMP	BYTE PTR KEYSW,LOW 0D	;Test for key on
	CALL	FKYADV		;If KEYSW was 0(ZF=0) then init PF start key,
				;   else advance to next set of PF keys
				;   return ZF=1 if advance beyond last of PF keys
	JZ	LABOFF		;Process key off request
	MOV	BYTE PTR KEYSW,LOW 255D	;Turn on key display flag
LABDSP:	CALL	KEYDSP		;Display function keys
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET	

LABOFF:
	MOV	BYTE PTR KEYSW,LOW 0D	;Turn the key flag off
	JMP	SHORT LABDSP	;Go clear the function key display line
	SUBTTL  Miscellaneous editor interface routines



;SUBROUTINE SCNMRK              ; Mark current position as first posn of logical
;**                 on entry:   ZF=1 indicates INPUT statement, AL=1 indicates
;**                                 EDIT statement.
;**                 on exit:    -
;**
SCNMRK:	PUSHF	
	MOV	DL,BYTE PTR CSRY
	MOV	DH,BYTE PTR CSRX
	DEC	AL
	JNZ	SCNMK0		; Not begin of EDIT statement
	CALL	LSTART		; Set (DH,DL)=start of current line
	PUSH	BX
	JMP	SHORT SCNMK2
;** IF NOT TOP OF WINDOW
SCNMK0:	CALL	CSRUP		; Move to previous line
	JB	SCNMK1		; BRIF at top of window
;** *** TERMINATE PREVIOUS PHYSICAL LINE
	CALL	SCNRTL
	MOV	AL,LOW OFFSET TRMEOL	; Make sure current line is start of logical line
	CALL	SCNWTT
	INC	DL		; Restore current line number
;** IF LINE IS MARKED WITH NULL
SCNMK1:	CALL	SCNRDT
	PUSH	BX
	MOV	BX,WORD PTR TRMCUR
	TEST	BYTE PTR LINTTB-1[BX],LOW OFFSET TRMNUL
	JZ	SCNMK2		; BRIF not specially marked line
	PUSH	DX
	PUSH	CX
;** SCAN LINE FOR NULL CHAR(255 DECIMAL)
	MOV	DH,BYTE PTR WDOLFT
	MOV	CL,BYTE PTR LINLEN
SCNMKL:	CALL	SCRINP
	CMP	AL,LOW 255D
	JZ	SCNML3		; BRIF is specially marked line
SCNML2:	INC	DH
	SUB	CL,LOW 1
	JA	SCNMKL		; BRIF more chars to check
	OR	SP,SP
SCNML3:
	POP	CX
	POP	DX
	JNZ	SCNMK2		; BRIF char was not on line, don't clear line
;** *** DELETE IT
	CALL	LDELET		; Delete this line
;** IF NOT DIRECT, SET LSTPOS, FSTPOS = CURRENT_POSN
SCNMK2:
	MOV	BYTE PTR CSRY,DL
	MOV	BYTE PTR CSRX,DH	; Update CURS_POSN in case of change
	POP	BX
	POPF	
	JZ	SCNMK3		; INPUT statement, use current posn
	MOV	BYTE PTR LSTLIN,LOW 377O	; Direct, set FSTPOS, LSTPOS to min and max
	MOV	BYTE PTR FSTLIN,LOW 0
	JMP	SHORT SCNMKX
SCNMK3:	MOV	BYTE PTR LSTLIN,DL
	MOV	BYTE PTR FSTLIN,DL
	DEC	DH
	MOV	BYTE PTR LSTCOL,DH	; Mark LSTCOL one to left of current posn
	INC	DH
	MOV	BYTE PTR FSTCOL,DH
SCNMKX:	RET	
;** END SUBROUTINE SCNMRK
	SUBTTL  Read logical line



;SUBROUTINE SCNRDL              ; Read a logical line
;**                     on entry:   ZF=1 indicates ignore FSTPOS, LSTPOS(statement
;**                                     line input).
;**                                 DX=current posn(within logical line to return)
;**                                 BX=buffer address
;**                                 CX=max count
;**                     on exit:    BX=last char address plus one
;**                                 CX=CX - (count of chars moved)
;**                                 DX=destroyed
;**
SCNRDL:	PUSHF			; Save statement input flag
;** Set DX=start of move
;** WHILE ((DL .NE FSTLIN) AND DL IN_SAME_LOGICAL_LINE)
SCRD00:	CMP	DL,BYTE PTR FSTLIN
	JZ	SCRD01		; Found first line of logical
;** *** DL = PREVIOUS LINE
	CALL	CSRUP
	JB	SCRD01		; At top of window, stop here
	CALL	SCNRDT
	JNB	SCRD00		; Still same logical, continue
	INC	DL		; Set DL = first physical of logical
;** IF (STATEMENT_INPUT OR (NOT ON FIRST_LINE))
SCRD01:	POPF			; We have start line, now get start column
	PUSHF	
;** *** START_COLUMN=LEFT_MARGIN
	MOV	DH,BYTE PTR WDOLFT	; Assume start at left margin
	JNZ	SCRD02		; BRIF statement input
	CMP	DL,BYTE PTR FSTLIN
	JNZ	SCRD02		; BRIF not on FIRST_LINE
;** *** ELSE START_COLUMN=FIRST_COLUMN
	MOV	DH,BYTE PTR FSTCOL

;** WHILE (POSN IS ON SAME LOGICAL) AND ((POSN .LTE. LSTPOS) OR STATEMENT_INPUT) BEGIN
SCRD02:	POPF	
	PUSHF	
	JNZ	SCRD03		; BRIF statement input, ignore LSTPOS
	CMP	DL,BYTE PTR LSTLIN
	JA	SCRDXZ		; **BRIF passed LSTPOS(was at prev. line term'r)
	JNZ	SCRD03		; BRIF not at LSTPOS
	CMP	DH,BYTE PTR LSTCOL
	JA	SCRDXZ		; BRIF beyond LSTPOS, all done
;** *** READ A CHARACTER INTO THE BUFFER
;** *** DO CASE TERMINATOR OF LINEFEED, NULL_WRAP, WRAP, BEFORE EOL, AT EOL
SCRD03:	CALL	SCNRDT
	PUSH	AX
	JB	SCRD04		; BRIF not reading a linefeed
	JNZ	SCRD04		; BRIF not reading a linefeed
	CMP	AH,DH
	JNZ	SCRD04		; BRIF not reading a linefeed
;** *** *** CASE: LINEFEED
SCRDLF:	MOV	AX,OFFSET CHRLNF+0
	JMP	SHORT SCRD08	; At linefeed terminator, pass linefeed
SCRD04:	CMP	AH,DH
	JA	SCRD07		; BRIF within data on screen
	JB	SCRD06		; BRIF beyond terminator
;** *** *** CASE: NULL_WRAP
	CMP	AL,LOW OFFSET TRMNWP
	JNZ	SCRD07		; BRIF not at NULL_WRAP terminator
SCRD06:	CMP	AL,LOW OFFSET TRMEOL
	POP	AX
	JZ	SCRDXZ		; BRIF beyond EOL
;** *** *** CASE: WRAP
	INC	DL		; Wrap to next line
	MOV	DH,BYTE PTR WDOLFT
	JMP	SHORT SCRD02
;** *** *** CASE: BEFORE EOL
SCRD07:
	CLC			; Indicate call is from Screen Editor
	CALL	SCRINP		; AX=Character at (DH,DL)
SCRD08:	MOV	BYTE PTR 0[BX],AL
	DEC	CX
	POP	AX
	JZ	SCRDEX
	CMP	AL,LOW OFFSET TRMEOL
	JNZ	SCRD09		; BRIF not at EOL
	CMP	AH,DH
	JBE	SCRDEX		; BRIF at EOL(or beyond), all done
SCRD09:	INC	BX
	CALL	CSRADV
	JB	SCRDXZ		; If end of window, all done
	JMP	SHORT SCRD02	; Pass next character
;** *** *** CASE: AT(OR BEYOND) EOL
SCRDEX:	INC	BX		; Set BX= last posn written plus one
SCRDXZ:	POPF	
	CALL	SCNBRK		; Clear any flags associated with INPUT
	RET	
;** *** *** END
;** *** END
;** END SUBROUTINE SCNRDL
	SUBTTL  CONTROL CHARACTER ROUTINES


;CONTROL CHARACTER DISPATCH TABLE
;**
FUNTAB:	DW	OFFSET CTLIGN	; ^@  -  Ignore
	DW	OFFSET CTLIGN	; ^A  -  Ignore
	DW	OFFSET BCKWRD	; ^B  -  Back one word
	DW	OFFSET CTLIGN	; ^C  -  Ignore
	DW	OFFSET CTLIGN	; ^D  -  Ignore
	DW	OFFSET LTRUNC	; ^E  -  Truncate logical line
	DW	OFFSET FWDWRD	; ^F  -  Forward one word
	DW	OFFSET CBEEP	; ^G  -  Beep
	DW	OFFSET BAKSPC	; ^H  -  Destructive backspace
	DW	OFFSET LTAB	; ^I  -  Destructive tab
	DW	OFFSET LFEED	; ^J  -  Linefeed
	DW	OFFSET WHOME	; ^K  -  Home within window
	DW	OFFSET CCLRSN	; ^L  -  Clear window, home cursor
	DW	OFFSET LCARET	; ^M  -  Carriage return
	DW	OFFSET LAPPND	; ^N  -  Append to end of line
	DW	OFFSET CTLIGN	; ^O  -  Ignore
	DW	OFFSET CTLIGN	; ^P  -  Ignore
	DW	OFFSET CTLIGN	; ^Q  -  Ignore
	DW	OFFSET LINSRT	; ^R  -  Insert a blank
	DW	OFFSET CTLIGN	; ^S  -  Ignore
	DW	OFFSET LABELK	; ^T  -  LABEL Key
	DW	OFFSET LDELET	; ^U  -  Delete a line
	DW	OFFSET CTLIGN	; ^V  -  Ignore
	DW	OFFSET WDELET	; ^W  -  Delete a word
	DW	OFFSET CTLIGN	; ^X  -  Ignore
	DW	OFFSET CTLIGN	; ^Y  -  Ignore
	DW	OFFSET WERASE	; ^Z  -  Erase to end of window
	DW	OFFSET CTLIGN	; ^[ or ESC - Ignore
	DW	OFFSET WCSADV	; ^\  -  Cursor advance within window
	DW	OFFSET WCSREG	; ^]  -  Cursor regress within window
	DW	OFFSET WCSUP	; ^^  -  Cursor up within window
	DW	OFFSET WCSDWN	; ^_  -  Cursor down within window
	DW	OFFSET CDELET	; DEL -  Delete a character


;SUBROUTINE CTLDSP(CONTROL_CHAR); Do control char logic
;**                         on entry:   AX=control character
;**                         on exit:    if CF=0 then AX=character to output
;**                                     if CF=1 then AX is undefined
CTLDSP:
	CALL	SCNPOS		; DH=column, DL=row
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CSRTYP:WORD
DSEG	ENDS
	EXTRN	SETCSR:NEAR
	MOV	BYTE PTR CSRTYP,LOW 0D	; Set for off cursor
	CALL	SETCSR		; Ensure that the cursor is off
	MOV	DH,BYTE PTR CSRX	; Set DH=true posn(not width truncated)
	TEST	BYTE PTR ESCFLG,LOW 377O
	JNZ	DOESC		; BRIF in middle of escape sequence
	CMP	AL,LOW 33O
	JZ	DOESC
CTLDS0:

CTLDP0:
CTLDP1:
	EXTRN	EDTMAP:NEAR,PRTMAP:NEAR
	TEST	BYTE PTR F_EDIT,LOW 377O	; Test for Screen Edit mode
	JZ	CTLPRT		; BRIF not edit mode
	CMP	AH,LOW 1D	; Set PSW.C if two byte character
	CMC	
	CALL	EDTMAP		; Map edit function/output character code
	JMP	CTLEDT

CTLPRT:	CMP	AH,LOW 1D	; Set PSW.C if two byte character
	CMC	
	CALL	PRTMAP		; Map print function/output character codes
CTLEDT:	JZ	CTLDPY		; Ignore this character
				; Print or perform the editor function
	CMP	AH,LOW 255D	; Is it an editor function (&HFF)?
	JNZ	CTLDSX		; No - print the character
	XOR	AH,AH		; Clear (no longer needed) editor function flag
	CMP	AL,LOW 177O	; Delete function?
	JNZ	CTLNDL		; BRIF not DEL
	MOV	AL,LOW " "	; DEL code
CTLNDL:	CMP	AL,LOW 255D
	JNZ	CTLNMK		; BRIF not "mark line for deletion"
	PUSH	AX
	PUSH	BX
	CALL	SCNRDT
	MOV	BX,WORD PTR TRMCUR
	OR	BYTE PTR LINTTB-1[BX],LOW OFFSET TRMNUL	; Set "not for input" flag on this line
	POP	BX
	POP	AX
;       STC
	RET	
CTLNMK:	CMP	AL,LOW OFFSET " "+1	; Test for legal function code
	JNB	CTLDPY		; Ignore this code
	PUSH	AX
	CALL	CTLIRS		; Possibly reset insert flag
	ADD	AX,AX		; Two bytes per entry
	MOV	BX,AX
	MOV	AX,OFFSET CTLDPX
	PUSH	AX		; Put return on stack
	MOV	AX,WORD PTR FUNTAB[BX]
	PUSH	AX		; Put routine address on stack
CTLDSX:	CLC	
	RET			; Go do control routine
;** *** UPDATE CURRENT_POSN, RETURN
CTLDPX:	MOV	BYTE PTR CSRY,DL
	MOV	BYTE PTR CSRX,DH	; Update cursor posn
	POP	AX
	SUB	AL,LOW OFFSET CHRRET
	MOV	BYTE PTR F_CRET,AL	; F.CRET = 0 if character was Carriage return
CTLDPY:
	STC	
CTLIGN:
CTLDPZ:	RET	
;** ESCAPE SEQUENCE PROCESSING
DOESC:	CALL	SCROUT		; Returns carry set if continuation of escape sequence
	SBB	AL,AL		; If ESC sequence, AL=FF else AL=0
	MOV	BYTE PTR ESCFLG,AL	; Set/Reset flag
	JMP	SHORT CTLDPY
;** END SUBROUTINE CTLDSP

;THE CONTROL CHARACTERS WHICH RESET INSERT FLAG ARE IN TABLE BELOW:
;
CTLITB:
	DB	OFFSET CHRLDL	; LINE_DELETE
	DB	OFFSET CHRERA	; ERASE_SCREEN
	DB	OFFSET CHRFDW	; FORWARD_WORD
	DB	OFFSET CHRBKW	; BACKWARD_WORD
	DB	OFFSET CHRAPP	; APPEND_TO_LINE
	DB	OFFSET CHREDT	; EDIT_PREVIOUS_LINE
	DB	OFFSET CHRCLE	; CLEAR_TO_END
	DB	OFFSET CHRBEL	; BELL
	DB	OFFSET CHRHOM	; HOME
	DB	OFFSET CHRADV	; CURSOR_ADV
	DB	OFFSET CHRREG	; CURSOR_REG
	DB	OFFSET CHRUP	; CURSOR_UP
	DB	OFFSET CHRDWN	; CURSOR_DOWN
	CTLCNT=$-CTLITB

;SUBROUTINE CTLIRS              ; Reset insert flag for specified characters
;**                 on entry:   AL=character
;**                 on exit:    DI garbaged
;**
CTLIRS:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DI
;** IF (SPECIAL_ACTION(CTLKEY))
	MOV	DI,OFFSET CTLITB	; DI= [control char table]
	MOV	CX,OFFSET CTLCNT	; CX= count of entries in table
	MOV	BX,CX
	PUSH	ES
	PUSH	CS		; Scan in code segment
	POP	ES
	CLD			; Scan forward
 REPNE	SCASB			; Scan for character in table
	POP	ES
	JNE	INCNOT		; BRIF did not find the control character
;** *** F.INSRT=FALSE
	MOV	BYTE PTR F_INST,LOW 0	; Reset insert flag
INCNOT:	POP	DI
	POP	CX
	POP	BX
	POP	AX
	RET	
;** END SUBROUTINE CTLIRS
;** *** END

	SUBTTL  CONTROL CHARACTER ROUTINES - Cursor movement by character, line and TAB



;The control character routines are entered with DH=current column and
;   DL=current line. They return updated posn in the same registers. They
;   can modify AX, BX, CX but must save any other registers used.

;CURSOR CONTROL
;   The cursor control routines are somewhat special. Except for cursor advance,
;   the cursor is made to stay within previously printed data. The cursor
;   advance routine will append blanks by changing the logical right margin,
;   without actually printing anything. All of the cursor control routines
;   will update FSTPOS and LSTPOS as long as the cursor stays within a logical
;   line. When the cursor leaves a logical line, the FSTPOS and LSTPOS values
;   do not change. If the cursor is then moved back onto the original logical
;   line, the values are updated once more.
;
;Cursor advance
WCSADV:	CALL	CSRADV		; Advance cursor
	JB	WCSABT		; BRIF can't do, quit
;       CALL    SCNRDT          ; AH=end of this physical, AL=terminator
;       CMPB    DH,AH
;If cursor beyond previously printed data, don't update LSTCOL
;       JAE     WCSABT          ; BRIF not to left of line terminator posn
;If cursor beyond previous LSTPOS and on same logical, update LSTPOS
UPDPOS:	PUSH	DX
	DEC	DH		; LSTCOL is to left of cursor
	CMP	DL,BYTE PTR LSTLIN
	JB	UPDPS3		; BRIF not new LSTPOS
	JZ	UPDPS2		; BRIF on same line, possibly update LSTPOS
	PUSH	DX
	CALL	LSTART		; Get start line of current logical
	CMP	DL,BYTE PTR LSTLIN
	POP	DX
	JA	UPDPS3		; BRIF LSTPOS not on current logical line
;LSTPOS on current logical, previous physical
	MOV	BYTE PTR LSTLIN,DL	; Set LSTPOS to current
	MOV	BYTE PTR LSTCOL,DH
UPDPS2:	CMP	DH,BYTE PTR LSTCOL
	JBE	UPDPS3		; BRIF not new last posn
	MOV	BYTE PTR LSTCOL,DH	; Set new last posn
;If cursor before previous FSTPOS and on same logical, update FSTPOS
UPDPS3:	INC	DH		; Restore column
	CMP	DL,BYTE PTR FSTLIN
	JNZ	UPDPSX		; BRIF not on same line as first position
	CMP	DH,BYTE PTR FSTCOL
	JAE	UPDPSX		; BRIF not new first position
	MOV	BYTE PTR FSTCOL,DH	; Set new first position to current position
UPDPSX:	POP	DX
WCSABT:	RET	

;Cursor regress
WCSREG:	CALL	CSRREG		; Move cursor
	JB	WCSABT		; Can't move, quit
WCSRET:	CALL	SCNRDT
	CMP	AH,DH
	JNB	UPDPOS		; Within logical, update FSTPOS, LSTPOS, return
;Cursor to right of line terminator, don't update LSTCOL
	JMP	SHORT WCSABT	; Return

;Cursor up
WCSUP:	CALL	CSRUP		; Move cursor
	JNB	WCSRET		; BRIF successful, possibly update FSTPOS, LSTPOS
	RET			; Unsuccessful, return(NOP)

;Cursor down
WCSDWN:	CALL	CSRDWN		; Move cursor
	JNB	WCSRET		; BRIF successful, possibly update FSTPOS, LSTPOS
	RET			; Unsuccessful, return(NOP)

;TAB                            ; Move cursor to next TAB stop
;
LTAB:	TEST	BYTE PTR F_INST,LOW 377O
	JZ	LTABL		; BRIF not insert TAB
;Insert spaces until CSRX is at TAB stop or LINLEN
LTABIL:	MOV	AX," "
	CALL	SCNOUT		; Insert a blank
	MOV	DL,BYTE PTR CSRY
	MOV	DH,BYTE PTR CSRX
	CMP	DH,BYTE PTR LINLEN
	JA	LTABZ		; All done, at end of line
	DEC	DH
	TEST	DH,LOW 7O
	JNZ	LTABIL		; Keep inserting
	INC	DH
	JMP	SHORT LTABZ	; All done, at TAB stop
;Non-insert TAB, just pass over characters
LTABL:	CMP	DH,BYTE PTR LINLEN
	JAE	LTABX0		; BRIF need to wrap
	INC	DH
	TEST	DH,LOW 7O
	JNZ	LTABL
	INC	DH
	JMP	SHORT LTABX	; BRIF reached good posn
LTABX0:	CMP	DL,BYTE PTR WDOBOT
	JAE	LTABZ		; BRIF no room to end of page
	INC	DL
	MOV	DH,BYTE PTR WDOLFT	; Else move to start of next line
LTABX:	CALL	UPDPOS		; Update LSTPOS
LTABZ:	RET	
	SUBTTL  CONTROL CHARACTER ROUTINES - Cursor movement by word


;Advance cursor to beginning of next word within screen
FWDWRD:	PUSH	DX
	PUSH	WORD PTR LSTLIN
	CMP	DL,BYTE PTR LSTLIN
	JNZ	FWDWR0		; BRIF LSTPOS not on this line
	CMP	DH,BYTE PTR LSTCOL
	JB	FWDWR0		; BRIF within logical line
	MOV	BYTE PTR LSTLIN,LOW 377O	; Ignore LSTPOS in scan
FWDWR0:	CLC	
FWDWR1:	CALL	FWDWDL		; Try within logical
	JB	FWDWR2		; BRIF unsuccessful
	POP	WORD PTR LSTLIN
	CALL	UPDPOS
	POP	AX		; Remove old posn from stack
	RET	
;Reached end of logical line, try next logical
FWDWR2:	CALL	CSRDWN
	JB	FWDWRZ		; BRIF end of screen
	MOV	DH,BYTE PTR WDOLFT	; Start scan again at next line
	STC	
	JMP	SHORT FWDWR1	; Continue scan
;Unsuccessful, return cursor to original posn
FWDWRZ:	POP	WORD PTR LSTLIN
	POP	DX
	RET	

FWDWD0:	CALL	LCSADV
	JB	FWDWD3		; At end of logical line
;Advance cursor to beginning of next word within logical line
FWDWDL:	JB	FWDWD2		; Start as though between words
	CALL	ANCHK		; Check if current char is within word
	JNB	FWDWD0		; BRIF still within previous word
;At space between words
FWDWD1:	CALL	LCSADV
	JB	FWDWD3		; At end of logical line, check next logical
FWDWD2:	CALL	ANCHK
	JB	FWDWD1
FWDWDX:	RET			; Return, DX=posn of new word or end of logical line
FWDWD3:	JNZ	FWDWDX		; BRIF not stop at LSTPOS
;Stopped at LSTPOS, continue scan to end of physical line
	CMP	AH,DH
	JA	FWDWD4		; BRIF more this line
	STC	
	RET	
FWDWD4:	MOV	BYTE PTR LSTLIN,LOW 377O	; Ignore LSTPOS from here on
	JMP	SHORT FWDWD1	; Since crossed LSTPOS, passed end of current word

;Regress cursor to start of previous word
BCKWRD:	PUSH	WORD PTR FSTCOL
	PUSH	DX
	CMP	DH,BYTE PTR FSTLIN
	JNZ	BCKWD2
	CMP	DH,BYTE PTR FSTCOL
	JA	BCKWD2
	MOV	BYTE PTR FSTLIN,LOW 0
;Assume passed beginning of current word, continue to start of next
BCKWD2:	CALL	LCSREG
	JB	BCKWD7		; BRIF At start of line
BCKWD4:	CALL	ANCHK
	JB	BCKWD2		; BRIF still between words
;Scanning previous word, any termination is good
BCKWD5:	CALL	LCSREG
	JB	BCKWD6		; BRIF at beginning of line, found previous word
	CALL	ANCHK
	JNB	BCKWD5		; BRIF not at beginning of word
	CALL	CSRADV		; Advance back to start of word
BCKWD6:	POP	AX
	PUSH	DX		; Push new posn on stack
BCKWDX:	POP	DX
	POP	WORD PTR FSTCOL
	CALL	UPDPOS
	RET			; Return, DL=posn of previous word
BCKWD7:	JNZ	BCKWD8		; BRIF not stop at FSTPOS
	MOV	BYTE PTR FSTLIN,LOW 0	; Ignore FSTPOS from here on
	JMP	SHORT BCKWD2	; Since passed begginning of logical, between words
BCKWD8:	CALL	CSRUP		; Try previous logical line
	JB	BCKWDX		; At beginning of screen
	CALL	SCNRDT		; Read previous line teminator
	OR	AH,AH
	JZ	BCKWD8		; Previous line is null, try next previous
	MOV	DH,AH
	JMP	SHORT BCKWD4	; Continue scan
	SUBTTL  CONTROL CHARACTER ROUTINES - Screen home, truncate and clear


	EXTRN	BEEP:NEAR
CBEEP:	CALL	BEEP		; Sound Bell
	JMP	SCNPOS		; return current cursor location

	EXTRN	CLRSCN:NEAR
;Clear the screen
CCLRSN:
	CLC			; no-carry = internal parameter
	MOV	AL,LOW 2	; specify text only
	CALL	CLRSCN		; OEM supplied Clear-Screen Routine
				;fall into WHOME

;Home the cursor
WHOME:	MOV	DL,BYTE PTR WDOTOP
	MOV	DH,BYTE PTR WDOLFT
	RET	

;Erase to the end of the screen
WERASE:	CALL	PLINIT		; Clear current physical to end of line
	PUSH	DX
	MOV	DH,BYTE PTR WDOLFT	; Clear rest of lines from left margin
;WHILE POSN .LTE. WDOBOT
;** IF DATA_EXISTS(POSN) THEN INITIALIZE LINE
WERAS0:	INC	DL
	CMP	DL,BYTE PTR WDOBOT
	JA	WERASX		; Beyond window, exit
	CALL	PLINIT		; Clear this line
	JMP	SHORT WERAS0	; Init next line
WERASX:	POP	DX		; Return DX=cursor posn
	RET	
	SUBTTL  CONTROL CHARACTER ROUTINES - Line truncate and delete



;Delete entire logical line
LDELET:	CALL	LSTART		; Get start of logical line in DX

;Truncate line from posn in DX
LTRUNC:	PUSH	DX
	CALL	SCNRTL		; AH=last valid data on physical line
	PUSHF	
	STC			; Indicate don't clear line by scrolling
	CALL	LCLEAR		; Clear this physical line
	JB	LTRUN9		; Reached LSTPOS, all done
	INC	DL
;"Suck up" remaining physical lines attached to current logical
LTRUN1:	POPF	
	JB	LTRUNX		; Reached end of logical line
	CALL	SCNRTL
	PUSHF	
	MOV	DH,BYTE PTR WDOLFT
	CLC	
	CALL	LCLEAR		; Clear this line from start of line
	JB	LTRUN9		; Reached LSTPOS, all done
	JMP	SHORT LTRUN1
LTRUN9:	POPF	
LTRUNX:	POP	DX
	RET	

;Clear current physical to end of physical or LSTPOS, whichever is smallest
; (DH,DL)=start posn, AH=TERM_POSN, if CF=1, don't scroll
LCLEAR:	PUSHF	
	CMP	DL,BYTE PTR LSTLIN
	JZ	LCLER2		; BRIF clear up to LSTPOS
LCLER0:	CMP	DH,BYTE PTR WDORGT
	JA	LCLER5		; BRIF beyond end of physical(just exit)
	POPF	
	JNB	LCLER1		; BRIF clear line by scroll
	CALL	PLINIT		; Clear this physical line
	CLC	
	RET	
LCLER1:	CALL	SCRLU0		; Scroll up from bottom to current line
	CLC	
	RET	
LCLER2:	POPF	
	CALL	PLINIT
	STC	
	RET	
LCLER5:	POPF	
	CLC	
	RET	


	SUBTTL  CONTROL CHARACTER ROUTINES - Character and word delete



;Word delete
;
WDELET:
	CMP	DH,BYTE PTR LINLEN
	JBE	WDELT0		; BRIF on physical line
	CALL	CSRADV		; Put cursor on next line
	JB	WDELTZ		; BRIF at end of screen
WDELT0:
	CMP	DL,BYTE PTR LSTLIN	; **
	JNZ	WDELT2		; **BRIF not on LSTPOS line
	CMP	DH,BYTE PTR LSTCOL	; **
	JAE	WDELTZ		; **BRIF at or beyond LSTPOS(don't do word delete)
WDELT2:				; **
	PUSH	DX
	CMP	DH,BYTE PTR LINLEN
	JBE	WDELT4		; Good delete posn(within physical line)
	CALL	LCSADV		; Advance cursor to next physical of logical
WDELT4:	PUSH	DX
	CLC	
	PUSH	WORD PTR LSTLIN
	CALL	FWDWDL		; Set (DH,DL)= start of next word or end of line
	POP	WORD PTR LSTLIN
	JNB	WDELT6		; BRIF found another word following
;No word following, just delete to end of line
	INC	DH		; Include terminator in delete
WDELT6:	MOV	CX,DX
	POP	DX
	CMP	CL,BYTE PTR LSTLIN	; **
	JB	WDELT8		; **BRIF not beyond LSTPOS line
	JA	WDELT7		; **BRIF beyond LSTPOS line, use LSTPOS
	CMP	CH,BYTE PTR LSTCOL	; **At LSTPOS line, check if column is OK
	JB	WDELT8		; **BRIF before LSTPOS, column is OK
WDELT7:	MOV	CX,WORD PTR LSTLIN	; **Use LSTPOS as end of delete
	INC	CH		; **INC because delete is up to char before this posn
WDELT8:				; **
	CMP	DL,CL
	JNZ	WDELTC		; BRIF multiple line delete
WDELT9:	SUB	CH,DH		; CH=chars to next word minus one
	JBE	WDELTX		; BRIF no chars to delete
	CALL	CDELLG		; Delete CH chars in this line
WDELTX:	POP	DX
WDELTZ:	RET	
WDELTC:	INC	DL
WDELTD:	PUSH	DX
	PUSH	CX
; Delete across physical lines, delete to end of this line
	CMP	DL,CL
	MOV	DH,BYTE PTR WDOLFT
	JZ	WDELTE
	CALL	SCNRTL
	MOV	CH,AH
	CALL	CDELPH		; Erase intervening line
	POP	CX
	POP	DX
	DEC	CL		; Each erase of intervening line brings CL closer
	JMP	SHORT WDELTD
WDELTE:	CMP	CH,BYTE PTR WDOLFT
	JBE	WDELTF		; BRIF at begin of line
	DEC	CH
	CALL	CDELLG		; Delete up to the next word on this line
WDELTF:	POP	CX
	POP	DX
	DEC	DL		; Go back to original line
	MOV	CH,BYTE PTR LINLEN
	INC	CH
	JMP	SHORT WDELT9	; Delete to end of line



;Destructive back space
;
BAKSPC:
	CALL	LCSREG		; Back space within logical line
	CALL	SCNRTL
	CMP	DH,AH
	JBE	CDELET		; BRIF current posn less than TERM_POSN
	CMP	AH,BYTE PTR WDOLFT
	JAE	BAKSP1		; BRIF not on null line
	MOV	AH,BYTE PTR WDOLFT
BAKSP1:	MOV	DH,AH		; If beyond terminator, set posn to terminator

;Delete character
;
CDELET:	MOV	CH,LOW 1	; Assume one byte char delete
	CMP	DH,BYTE PTR LINLEN
	JBE	CDELT1		; BRIF within physical line
	RET	
CDELT1:

;SUBROUTINE CDELLG:             ; Delete CH characters @(DH,DL) within logical
;                       On entry:   CH=count, CL= flag, (DH,DL)=posn
;                                   If CL is non-zero, remove null line from screen
;
CDELLG:	PUSH	DX
	CALL	SCNRTL		; Get last valid char posn in AH
	PUSHF	
	CALL	CDELPH		; Delete characters from current physical
				;   returns new term posn in AH
	XOR	CL,CL		; CL is iteration counter
	POPF	
	MOV	AL,LOW OFFSET TRMEOL
	JB	CDLGEX		; BRIF was EOL term'd, update terminator, exit
	JNZ	CDLGWP		; BRIF line was WRAP or NULL_WRAP term'd, get
				;       chars from next line
;Line was LF terminated, check for LF delete
	CMP	AH,DH
	MOV	AL,LOW OFFSET TRMLNF
	JA	CDLGEX		; BRIF didn't delete LF, update terminator, exit
	OR	AH,AH
	JZ	CDLGRT		; **BRIF entire line deleted and removed
	MOV	AH,DH
	JMP	SHORT CDLWP1
;Need to get chars from next physical line at (AH,DL) posn to end of physical
CDLGWP:	OR	AH,AH
	JZ	CDLGRT		; BRIF entire line deleted and removed
	INC	AH
CDLWP1:	CMP	DL,BYTE PTR LSTLIN	; **
	JZ	CDLGRT		; **LSTPOS on this line, all done
	PUSH	WORD PTR LSTLIN	; **Save current LSTPOS
	CALL	CDUNWP		; Unwrap the characters desired returns terminator
				;     in (AH,AL) and byte count in CH
	CALL	SCNWTT		; Update terminator
	OR	CH,CH
	JNZ	CDLWP2		; BRIF we have characters to unwrap
	POP	AX		; Restore the stack
	JMP	SHORT CDLGRT	; Return, all done
;Need to delete CH characters unwrapped from next line
CDLWP2:	MOV	DH,BYTE PTR WDOLFT	; Unwrapped from start of line
	INC	DL		; Next line
	DEC	CL		; Update iteration counter
	CALL	SCNRTL		; Read next lines terminator
;Need to restore LSTPOS to old value for character delete
	MOV	DI,WORD PTR LSTLIN	; **Save current value of LSTPOS in SI
	POP	WORD PTR LSTLIN	; **Restore value before CDUNWP so CDELPH works properly
	PUSHF	
	PUSH	DI		; **Save current "true" value of LSTPOS
	XCHG	DI,AX		; **
	CMP	AL,BYTE PTR LSTLIN	; **
	PUSHF			; **
	XCHG	DI,AX		; **
	CALL	CDELPH		; Delete chars to end of line or LSTPOS
	POPF			; **
	POP	DI		; **
	JZ	CDLGNC		; **BRIF CDUNWP did not change LSTPOS
	MOV	WORD PTR LSTLIN,DI	; **Restore CDUNWP value of LSTPOS
CDLGNC:	OR	AH,AH
	JNZ	CDLGW1		; BRIF still chars on this line
	POPF	
	JNB	CDLGRT		; BRIF LF or wrap term'd, already removed
CDLGNL:	DEC	DL
	INC	CL
	CALL	SCNRTL
	JB	CDLGN0		; BRIF previous line EOL term'd, remove null line
	JZ	CDLGRT		; BRIF previous line LF term'd, leave null line
	MOV	AL,LOW OFFSET TRMEOL
	CALL	SCNWTT		; Previous line was wrapped, terminate it and
				;   remove null line
CDLGN0:	INC	DL
	DEC	CL
	CALL	SCRLU0		; Remove null line by scrolling
	JMP	SHORT CDLGRT	; All done

CDLGW1:	POPF	
	JB	CDLGEX		; BRIF at EOL, all done
	JNZ	CDLGWP		; BRIF wrapped, unwrap chars from next line
;We have terminator in (AH,AL), posn in (DH,DL)
CDLGEX:	CALL	SCNWTT		; Update terminator
CDLGRT:	ADD	CL,DL
	POP	DX
	MOV	DL,CL
	RET	



CDUWXI:	MOV	CH,LOW 0	; Indicate no characters unwrapped
	JMP	CDUWPX		; Indirect jump

;SUBROUTINE CDUNWP:             ; "Unwrap" chars from next line
;                       On entry:   (AH,DL)= destination
;                       On exit:    (AH,AL)= new line terminator
;                                   CH=nunber of bytes unwrapped
;
CDUNWP:	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	WORD PTR TRMCUR
	MOV	AL,LOW OFFSET TRMWRP
	MOV	CH,BYTE PTR LINLEN
	SUB	CH,AH
	JB	CDUWXI		; BRIF no space to unwrap characters to, just exit
	CMP	DL,BYTE PTR LSTLIN	; **
	JNZ	CDUWP0		; **BRIF not unwrapping to LSTPOS
	TEST	BYTE PTR LSTCOL,LOW 377O	; **
	JNZ	CDUWP0		; **BRIF have some characters to unwrap
	MOV	AH,BYTE PTR LINLEN	; **
	JMP	SHORT CDUWXI	; **If no characters to unwrap, just exit
CDUWP0:	INC	CH
	MOV	BX,AX		; Put DESTINATION in BX
	MOV	BL,DL
	INC	DL
	CALL	SCNRTL		; Read terminator for next line
	PUSH	AX
	PUSHF	
	CMP	CH,AH
	JBE	CDUWP1		; BRIF enough characters to satisfy demand
	MOV	CH,AH		; Else get all characters in next line
CDUWP1:	MOV	CL,LOW 1
	MOV	DH,BYTE PTR WDOLFT
	MOV	AX,DX		; Put SOURCE in AX
	OR	CH,CH
	JNZ	CDUWPN		; BRIF not a null line following
	POPF	
	PUSHF	
	JZ	CDUWP4		; BRIF LF term'd, don't remove null line
	PUSH	WORD PTR TRMCUR
	CALL	SCRLU0		; Get rid of null line following
	POP	WORD PTR TRMCUR
	JMP	SHORT CDUWP4	; Set up terminator for return
CDUWPN:
	CALL	SCROLL		; Scroll chars from old line to new
	CMP	DL,BYTE PTR LSTLIN
	JNZ	CDUWP4		; BRIF not on LSTPOS line
;If LSTPOS is between WDOLFT and SOURCE+COUNT, unwrap LSTPOS
	PUSH	AX
	ADD	AH,CH
	SUB	AH,BYTE PTR LSTCOL
	POP	AX
	JBE	CDUWP3		; BRIF LSTPOS .GT. SOURCE+COUNT
	SUB	BYTE PTR LSTCOL,AH	; LSTCOL=DESTINATION+(LSTPOS-SOURCE)
	JNB	CDUWPL
	MOV	BYTE PTR LSTCOL,LOW 0	; LSTCOL was zero, don't let it go negative
CDUWPL:	ADD	BYTE PTR LSTCOL,BH
	DEC	BYTE PTR LSTLIN	; LSTLIN is line unwrapped to
COMMENT	%
; Blank from DESTINATION+COUNT-((SOURCE+COUNT)-LSTPOS) to EOL
	PUSH    AX
	PUSH    DX
	PUSH    CX
	ADDB    DH,CH
	SUBB    DH,AH           ; (DH,DL)=start posn for blanking
	MOVB    CH,LINLEN       ; CH=end column
	MOVI    AX," "
CDUWPB: CALL    SCROUT
	INCB    DH
	CMPB    DH,CH
	JBE     CDUWPB          ; Continue blanking to EOL
	POP     CX
	POP     DX
	POP     AX
%
CDUWP3:
;Return terminator for DL-1
CDUWP4:	ADD	BH,CH		; Get new terminator posn into BH
	DEC	BH
	POPF	
	POP	AX		; Restore original terminators for this line
	MOV	BL,LOW OFFSET TRMEOL	; Assume line unwrapped is at EOL
	JB	CDUWPE		; BRIF at EOL
	MOV	BL,LOW OFFSET TRMLNF	; Assume LF was unwrapped on unwrapped line
	JZ	CDUWP6		; BRIF at LF
;WRAP or NULL_WRAP, if BH .NE. LINLEN, then it must be LINLEN-1 and NULL_WRAP
CDUWP5:	MOV	BL,LOW OFFSET TRMWRP	; Assume line is WRAP
	CMP	BH,BYTE PTR LINLEN
	JZ	CDUWP7		; Previous line is full, must be WRAP
	MOV	BL,LOW OFFSET TRMNWP
	MOV	BH,BYTE PTR LINLEN
	JMP	SHORT CDUWP7	; Previous line not full even though we had
				;   enough chars to fill it, must be NULL_WRAP
;EOL terminated
CDUWPE:	OR	AH,AH
	JZ	CDUWP7		; If unwrapped null line, return EOL
;Was EOL or LF terminated, see if entire line was unwrapped
CDUWP6:	CMP	AH,CH
	JNZ	CDUWP5		; BRIF wasn't unwrapped, previous line is WRAP
;terminator=(BH,BL)
CDUWP7:	PUSH	BX
;       ORB     CH,CH
;       JZ      CDUWP8          ; BRIF no chars to delete from here on
;       MOVBI   CL,^O377        ; Set flag indicating can remove lines deleted
;       CALL    CDELLG          ; Delete CH characters at (DH,DL)
CDUWP8:	POP	AX
CDUWPX:	POP	WORD PTR TRMCUR
	POP	DX
	MOV	BH,CH
	POP	CX
	MOV	CH,BH
	POP	BX
	RET	
;Needed one char and first char on next line is DBLCHR
CDUWPF:	POP	AX
	POPF			; Clean up stack
	MOV	AH,BYTE PTR LINLEN
	MOV	AL,LOW OFFSET TRMNWP	; Set terminator to NULL_WRAP
	JMP	SHORT CDUWP7



;SUBROUTINE CDELPH              ; Delete chars on physical line
;                       On entry:   (DH,DL)=posn to start delete from
;                                   (AH,AL)=line terminator for line DL
;                                   CH=count
;                       On exit:    AH=term posn
;                                   (DH,DL)=posn
;
CDELPH:				;PUSH    SI
	XOR	SI,SI		; Set SI to zero(flag no char restore necessary)
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	AX
	CMP	DH,AH
	JA	CDEL9I		; BRIF delete beyond or at physical end
	MOV	BX,DX		; (BH,BL)=DESTINATION
	MOV	AX,DX
	ADD	AH,CH		; (AH,AL)=SOURCE
	POP	CX		; CH=end of physical line
	PUSH	CX
	CMP	AH,CH
	JBE	CDELP0		; BRIF not deleting more than we have
	MOV	AH,CH
	INC	AH		; Delete entire line
CDELP0:	CMP	DL,BYTE PTR LSTLIN
	JNZ	CDELP1		; BRIF not on line with LSTPOS
	CMP	CH,BYTE PTR LSTCOL
	JBE	CDELP1		; BRIF physical end less than LSTPOS
	MOV	CH,BYTE PTR LSTCOL	; Use LSTPOS as end of this line
	CMP	DH,CH
	JA	CDEL9I		; BRIF delete beyond terminator
CDELP1:
	PUSH	CX		; Save last posn of SOURCE
	SUB	CH,AH
	PUSHF	
	MOV	DH,BH
	ADD	DH,CH		; (DH,DL)=end of DESTINATION
	POPF	
	JB	CDELP4		; BRIF SOURCE greater than logical end of physical
	MOV	CL,LOW 1
	INC	CH
	CALL	SCROLL		; Move characters to left
;Blank from end of SOURCE to end of DESTINATION+1
CDELP4:	POP	CX		; CH=end column of SOURCE
	INC	DH		; DH=end column of DESTINATION plus one
	PUSH	DX
	MOV	AX," "
CDELP5:	CMP	DH,CH
	JA	CDELP6
	CALL	SCROUT		; Blank this posn
	INC	DH
	JMP	SHORT CDELP5
CDEL9I:	JMP	SHORT CDELP9	; Indirect to CDELP9
CDELP6:	POP	DX		; Restore end column of DESTINATION plus one
	POP	AX		; Restore terminator passed to routine
;CH=last valid column, DH=first blanking column, AH=term column, AL=term type
	CMP	DL,BYTE PTR LSTLIN
	JNZ	CDELP7		; BRIF was not delete before LSTPOS
	CMP	CH,BYTE PTR LSTCOL
	JB	CDELP7		; BRIF delete up to terminator
;Delete included LSTPOS, subtract total deleted from LSTCOL
	POP	DX
	POP	CX
	SUB	BYTE PTR LSTCOL,CH
	JAE	CDEL8A		; **BRIF LSTCOL valid
	MOV	BYTE PTR LSTCOL,LOW 0	; **Set LSTCOL to 0
	JMP	SHORT CDEL8A	; Delete up to LSTPOS, adjust LSTPOS
;Deleted all data up to terminator, adjust terminator
CDELP7:	MOV	AH,DH
	DEC	AH		; Set terminator to last column of DESTINATION
CDELP8:	POP	DX		; (DH,DL)=original posn(start of DESTINATION)
	POP	CX		; CL=flag
CDEL8A:	CMP	DH,AH
	JBE	CDELPX		; BRIF still data remaining to right
	CMP	DH,LOW 1
	JNZ	CDELPX		; BRIF still data remaining to left
	CMP	AL,LOW OFFSET TRMEOL
	JZ	CDELPX		; BRIF don't remove null line
;We have null line, remove it from the screen
	PUSH	WORD PTR TRMCUR
	CMP	DL,BYTE PTR LSTLIN	; **If LSTPOS is wiped out, put it at
				; ** end of previous line
	JNZ	CDEL8B		; **BRIF not wiped out
	DEC	BYTE PTR LSTLIN	; **
	MOV	BH,BYTE PTR WDOLFT	; **
	MOV	BYTE PTR LSTCOL,BH	; **
CDEL8B:				; **
	CALL	SCRLU0		; Scroll up from bottom of screen to DL
	POP	WORD PTR TRMCUR
	JMP	SHORT CDELPX	; All done
;We are deleting to right of line terminator
CDELP9:	POP	AX		; Restore terminator passed
	CMP	AL,LOW OFFSET TRMLNF
	MOV	DH,AH		; DH=end of valid data plus one
	JZ	CDELP7		; BRIF LF term'd, delete it
	POP	DX		; Delete beyond valid data, ignore it
	POP	CX
CDELPX:	POP	BX
	CMP	DL,BYTE PTR LSTLIN
	JZ	CDELPF		; BRIF not on LSTPOS line, no update
	CMP	AH,BYTE PTR LSTCOL
	JAE	CDELPF		; BRIF LSTPOS is within line, no update
				;POP     SI
CDELPF:	RET	
	SUBTTL  CONTROL CHARACTER ROUTINES - Line append, carriage return and linefeed



;Append to end of logical line
;
LAPPND:
LAPPN0:	CALL	SCNRDT
	JB	LAPPN1		; BRIF we are at last line in logical
	INC	DL
	JMP	SHORT LAPPN0	; See if next line is last line in logical
LAPPN1:	MOV	DH,AH		; Set current posn to EOL
	CMP	AH,BYTE PTR LINLEN
	JNB	LAPPN2		; If end of window, advance cursor posn here
	JMP	WCSADV		; Use logical cursor advance(advances LSTPOS)
;This will set the cursor posn one beyond end(wrap next char typed)
LAPPN2:	INC	DH
	RET	

;Carriage return
;
LCARET:
	CALL	SCNRDT
	JB	LCRET1		; BRIF this line already EOL terminated
	JZ	LCRET0		; BRIF LF terminated
	CMP	AL,LOW OFFSET TRMNWP
	JNZ	LCRET1		; BRIF not NULL_WRAP terminated
LCRET0:	DEC	AH		; Do not include LF or NULL_WRAP in line
LCRET1:	MOV	AL,LOW OFFSET TRMEOL
	CALL	SCNWTT		; Make this line EOL terminated
	MOV	DH,BYTE PTR WDOLFT	; And move posn to left margin
	RET	

;Line feed
;
LFEED:	MOV	SI,0
	TEST	BYTE PTR F_CRET,LOW 377O
	JZ	LFD90I		; BRIF LF following CR
	TEST	BYTE PTR F_INST,LOW 377O
	JZ	LFED30		; BRIF not insert mode
	CALL	SCNRTL
	CMP	AH,DH
	JB	LFED30		; Inserting beyond end of physical(just append)
;Insert mode, move characters from cursor to EOL onto the next line
	CMP	DL,BYTE PTR LSTLIN
	JZ	CBEPI2		; BRIF on LSTPOS line, can't do insert LF
; IMPROVEMENT: Find last physical in this logical and see if it can be moved
;   down one line. If not, abort before any inserts
LFED10:
	CLC			; Indicate call is from Screen Editor
	CALL	SCRINP
	MOV	SI,AX		; Save first char in SI
	MOV	AX," "
	CALL	SCROUT
	PUSH	DX
LFED12:	MOV	CH,LOW 1
	CALL	MKRMCH		; Move everything over one
	INC	DH
	CMP	DH,BYTE PTR LINLEN
	JBE	LFED12		; Keep going until the end of the line
	MOV	AH,DL
	POP	DX		; Restore posn
	MOV	DL,AH
	CALL	PLINIT		; Terminate line at current posn
	CMP	DL,BYTE PTR WDOBOT
	JNZ	LFED43		; Change terminator to LF and goto next line
	JMP	LFEEDX
;No room!!
CBEEPI:	POPF			; Clean stack
CBEPI2:	JMP	CBEEP
LFD90I:	JMP	SHORT LFED90	; Indirect jump to LFED90
;Insert beyond end of physical=append
; Append LF to end of physical line
LFED30:	CALL	SCNRTL
	PUSHF	
	JB	LFED31		; BRIF need one more space to output LF
	JZ	LFED32		; BRIF already LF terminated, don't need space
LFED31:	INC	AH		; Need one more space at terminator posn
LFED32:	CMP	AH,BYTE PTR LINLEN
	JBE	LFED40		; BRIF have room on this line
	CALL	LFWRAP		; Wrap linefeed to next line
	JB	LFED69		; BRIF no room
;The possibilities at this point are WRAP or EOL terminated
	POPF	
	JNB	LFED34		; BRIF not EOL term'd(no change to terminator)
	CALL	SCNRDT
	MOV	AH,BYTE PTR LINLEN	; EOL terminated, change to WRAP at LINLEN
	MOV	AL,LOW OFFSET TRMWRP
	CALL	SCNWTT
LFED34:	MOV	DH,BYTE PTR WDOLFT
	CMP	DL,BYTE PTR LSTLIN
	JNZ	LFED35		; BRIF not extending LSTPOS
	INC	BYTE PTR LSTLIN	; Move LSTPOS with LF
	MOV	BYTE PTR LSTCOL,DH
LFED35:	INC	DL		; Move to new line(created by MKRMNL above)
	MOV	AH,DH
	JMP	SHORT LFED43
LFED40:	POPF	
	JNB	LFED42		; BRIF not EOL, just change terminator to LF
LFED41:	CALL	MKRMNL		; Open up next line
	JB	LFEEDX		; No room for LF
;SUCCESS: terminate current line with LF
LFED42:	MOV	DH,AH
	MOV	AX," "
	CALL	SCROUT		; Put a blank at terminator posn
LFED43:	CALL	SCNRDT		; Reread terminator in case of MKRMNL scroll up
	MOV	AH,DH
	MOV	AL,LOW OFFSET TRMLNF
	CALL	SCNWTT		; And terminate line with LF
	CMP	DL,BYTE PTR LSTLIN
	JNZ	LFED95		; BRIF no LSTPOS update
	MOV	BYTE PTR LSTCOL,LOW 0	; LSTPOS moves to line beyond linefeed
	INC	BYTE PTR LSTLIN
	JMP	SHORT LFED95
LFED90:	PUSH	SI
	CALL	MKRMNL		; Open up next line
	POP	SI
	JB	LFEEDX		; No room
LFED95:	CALL	CSRDWN		; Move to next line
	MOV	DH,BYTE PTR WDOLFT
	OR	SI,SI
	JZ	LFEEDX
	MOV	AX,SI
	CALL	SCROUT		; Restore first char of insert linefeed
LFEEDX:	CMP	DL,BYTE PTR WDOBOT
	JBE	LFEEDZ
	MOV	DL,BYTE PTR WDOBOT
LFEEDZ:	RET	
;No room for linefeed, terminate this line and exit
LFED69:	POP	AX
	JMP	SHORT LFEEDX
	SUBTTL  CONTROL CHARACTER ROUTINES - Insert and MKRMCH


LINSRT:	XOR	BYTE PTR F_INST,LOW 377O	;Toggle insert flag
	RET	

;SUBROUTINE MKRMCH              ; This routine opens up space in logical lines
;**                     On entry:   (DH,DL)=posn to open space
;**                                 CH=number of spaces to open(1 or 2)
;**                     On exit:    (DH,DL)=same posn(DL value can change)
;**
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	BUF:WORD
DSEG	ENDS
MKRMCH:	PUSH	SI
	PUSH	AX
	PUSH	CX
	PUSH	DX
	MOV	SI,OFFSET BUF
	MOV	DI,OFFSET BUF+128D	; SI and DI are overflow character buffers
	CALL	SCNRDT
	PUSHF	
	PUSH	AX
	CALL	MVCHLN		; Move characters over put overflow at [DI]
	XOR	CL,CL		; CL=Iteration depth(and count of physical lines)
MKRMC0:	OR	CH,CH
	JNZ	MKRMC1		; BRIF line overflowed
	POP	AX
	POPF	
MKRMCX:	ADD	CL,DL		; CL=original line number
	POP	DX		; DH=orginal column
	MOV	DL,CL		; DL=original line number
MKRMX2:	POP	CX
	POP	AX
	POP	SI
	RET	
;Line overflow we must wrap char to next line
MKRMC1:	POP	AX
	POPF			; Get back old terminator
	JB	MKRMC3		; BRIF was EOL term'd
	JNZ	MKRMC4		; BRIF was WRAP or NULL_WRAP term'd
;Linefeed, make room for linefeed on next line
	PUSH	AX
	CALL	LFWRAP
	POP	AX
	JB	MKRMCQ		;  No room, throw away overflow
	DEC	CH
	JZ	MKRMCX		; Only wrapped the linefeed, done
	JMP	SHORT MKRMC4	; Pass overflow to next line
;EOL terminatedd
MKRMC3:	PUSH	AX
	CALL	MKRMNL		; Open up next line for overflow
	POP	AX
	JNB	MKRMC4		; BRIF room, wrap overflow
;No room for wrap, terminate this line with EOL and exit
MKRMCQ:	CALL	SCNRDT
	MOV	AL,LOW OFFSET TRMEOL
	CALL	SCNWTT		; No room for overflow, just terminate line
	JMP	SHORT MKRMCX
;Insert overflow on next line
MKRMC4:	CMP	DL,BYTE PTR LSTLIN
	JNZ	MKRMC6		; BRIF not on LSTPOS line
;AH=Old terminator posn, CH=Overflow count
	SUB	AH,CH
	CMP	AL,LOW OFFSET TRMNWP
	JNZ	MKRMC5		; BRIF wasn't NULL_WRAP, don't adjust posn
	DEC	AH
;AH=First position wrapped - 1
MKRMC5:	CMP	AH,BYTE PTR LSTCOL
	JAE	MKRMC6		; BRIF did not wrap LSTCOL
;Wrapped LSTPOS
	MOV	BYTE PTR LSTCOL,LOW 0	; Set LSTPOS to start of next line
	INC	BYTE PTR LSTLIN
MKRMC6:	INC	DL		; (DH,DL)=start of next line
	MOV	DH,BYTE PTR WDOLFT
	DEC	CL		; Decrement interation counter
	XCHG	SI,DI		; Use other overflow buffer for this line
	CALL	SCNRDT
	PUSHF	
	PUSH	AX
	PUSH	CX		; Save char count
	CALL	MVCHLN		; Make room on this line for previous overflow
	MOV	BX,CX		; Save count of overflow
	POP	CX		; Get back overflow count in CH
	PUSH	SI		; Save pointer to characters for insertion
;Loop to output characters which overflowed onto this line from previous line
MKRMC7:	CLD			; Scan forwards
	LODSW			; Get a character
	CALL	SCROUT		; Output it
	INC	DH
	SUB	CH,LOW 1
	JA	MKRMC7		; Output the next char
	POP	SI
	MOV	CH,BH		; Restore overflow count for this line
	JMP	SHORT MKRMC0	; Wrap new overflow

;Wrap a linefeed to next line
LFWRAP:	INC	DL
	CALL	MKRMNL
	JB	LFWPEX		;  room, throw away overflow
	PUSH	DX
	CALL	SCRDLN		; Scroll this line down to next
	POP	DX
	CALL	LFTERM		; Make this line LF term'd
	CLC	
LFWPEX:	DEC	DL		; Restore original line number
	RET	

;SUBROUTINE MVCHLN              ; Open up space in physical line
;**                     On entry:   (DH,DL)=posn to open space at
;**                                 SI=address of buffer to put overflow chars
;**                     On exit:    (DH,DL)=same posn(DL might change if scroll)
;**                                 CH=No. of bytes overflowed
;**                                 BX destroyed
;**
MVC30I:	JMP	MVCH30
;MVC80I: JMP     MVCH80
MVCHLN:	PUSH	DI
	PUSH	CX
	CMP	DL,BYTE PTR LSTLIN
	MOV	CL,BYTE PTR LINLEN
	JNZ	MVCH00		; BRIF within logical EOL(unless beyond TERM_POS)
	MOV	CL,BYTE PTR LSTCOL
MVCH00:	CALL	SCNRTL		; AX=current physical terminator
	CMP	AH,DH
	JB	MVC30I		; BRIF inserting beyond end of physical
	CMP	DL,BYTE PTR LSTLIN
	JNZ	MVCH03
	CMP	CL,AH
	JNB	MVCH03		; BRIF LSTPOS .GTE. TERM_POSN
	MOV	AH,CL		; Else use LSTPOS as TERM_POSN
;We are inserting before end of physical line and LSTPOS .GTE. TERM_POSN
MVCH03:	PUSH	DX
	PUSH	AX
	ADD	CH,AH		; CH=last column for space needed
	SUB	CH,BYTE PTR LINLEN
	JA	MVCH10		; BRIF overflow
	XOR	BH,BH		; Indicate no overflow
	JMP	SHORT MVCH20
;We have overflow bytes to save
MVCH10:	MOV	DH,AH
	SUB	DH,CH
	INC	DH		; DH=column of first overflow to save
	CLC			; Indicate call is from Screen Editor
	CALL	SCRINP		; Read an overflow char
	MOV	BX,CX		; Save overflow count in BH
;Loop to move overflow character to save buffer
MVCH14:	CLD	
	STOSW			; Save overflow char
	DEC	CH
	JZ	MVCH20		; All done with overflow save
	INC	DH
	CLC			; Indicate call is from Screen Editor
	CALL	SCRINP		; Read an overflow char
	JMP	SHORT MVCH14	; And save it
;Move characters in line over
MVCH20:	MOV	CX,BX		; Restore # bytes overflowed to CH
	POP	AX		; AH=term posn
	SUB	AH,CH		; Adjust term posn so move doesn't overflow
	POP	DX		; DH=start column of insert
	POP	BX		; BH=number of bytes to move over
	MOV	CL,BL
	PUSH	CX		; Save overflow count and CL for restore on exit
	MOV	CH,AH		; CH=last column to move
	SUB	CH,DH
	INC	CH		; CH=count of chars from CURPOS to TERMPOS
	PUSHF	
	MOV	CL,LOW 1	; Move on one line
	MOV	AX,DX		; FROM=CURPOS
	MOV	BL,DL
	ADD	BH,DH		; TO=CURPOS+COUNT
	POPF	
	JNZ	MVCH21		; BRIF count not zero, do move
	MOV	BH,DH		; All characters to move overflowed
	JMP	SHORT MVCH22	; Just update terminator to current posn
MVCH21:	CALL	SCROL2		; Move over characters
	ADD	BH,CH		; New TERMPOS=TO+number of characters moved
	DEC	BH
MVCH22:	POP	CX		; CH=-(No. of bytes wrapped)
;CH=overflow count, CL=insert count, BH=terminator posn
MVCH23:	CALL	SCNRDT
	JB	MVCH25
	JZ	MVCH25
;We have wrapped chars, terminate either WRAP or NULL_WRAP
MVCH24:	CMP	BH,BYTE PTR LINLEN
	MOV	AL,LOW OFFSET TRMWRP
	JZ	MVCH26
	OR	CH,CH
	JZ	MVCH26
	MOV	AL,LOW OFFSET TRMNWP	; Null wrap that does not overflow changes to wrap
	MOV	BH,BYTE PTR LINLEN
	PUSH	AX
	PUSH	DX
	MOV	DH,BH
	MOV	AX," "		; Blank DBLCHR destroyed by scroll
	CALL	SCROUT
	POP	DX
	POP	AX
	JMP	SHORT MVCH26
;Was EOL or LF terminated
MVCH25:	OR	CH,CH
	JNZ	MVCH24		; Overflow means WRAP or NULL_WRAP
MVCH26:	CMP	AH,BH
	JA	MVCH27		; Terminator beyond scroll end
	MOV	AH,BH
;AH=New terminator, CL=insert count
	CALL	SCNWTT		; Update terminator
MVCH27:	CMP	DL,BYTE PTR LSTLIN
	JNZ	MVCHEX		; BRIF move is not on LSTPOS line
	CMP	BH,BYTE PTR LSTCOL
	JBE	MVCHEX		; BRIF end of move is before LSTPOS
	MOV	BYTE PTR LSTCOL,BH	; Else add number moved over to LSTPOS
MVCHEX:	POP	DI
	RET	
;Inserting beyond end of logical
MVCH30:	MOV	CL,CH		; Save insert count in CL
	ADD	CH,DH		; CH=end of insert
	CMP	AL,LOW OFFSET TRMLNF
	JZ	MVCH31		; BRIF LF term'd cannot push null off end
	DEC	CH		; Ignore one null push off end of physical
MVCH31:	CMP	CH,BYTE PTR LINLEN
	JBE	MVCH33		; BRIF have room
;No room, return blanks overflow, update terminator
	SUB	CH,BYTE PTR LINLEN	; CH=No. of overflow bytes
	MOV	AX," "
	PUSH	CX
MVCH32:	CLD			; Store overflow bytes(All blanks)
	STOSW
	DEC	CH
	JNZ	MVCH32
	POP	CX		; Restore CH=number of overflow bytes
	POP	BX
	MOV	BH,CH
	PUSH	BX		; Put overflow count with original CL on stack
	MOV	BH,BYTE PTR LINLEN	; BH=term posn, CH=overflow count, CL=insert count
	JMP	SHORT MVCH23	; Update terminator and LSTPOS, exit
;Have room, just update terminator
MVCH33:	POP	BX
	MOV	BH,LOW 0	; Put overflow count(=0) on stack for return
	XCHG	BH,CH		; BH=term posn, CH=overflow count, CL=insert count
	JMP	SHORT MVCH23	; New term posn still .LTE. LINLEN
COMMENT	%
;On LSTLIN, possibly insert to LSTPOS or LSTPOS+COUNT
;N.B. We are guaranteed to be at a posn to left of TERM_POS
;Two cases: insert up to LSTPOS or insert up to LSTPOS+COUNT
MVCH80: PUSH    DX
	PUSH    CX
	PUSH    AX
	MOVB    CL,AH           ; Save TERM_POS in CL for compare
	MOVB    DH,LSTCOL
;Scan from LSTPOS+1 to lesser of (LSTPOS+COUNT,TERM_POS) or non-blank character
MVCH81: INCB    DH              ; Next column
IFN     IBMLIK,<
	CLC                     ; Indicate call is from Screen Editor
>                               ; IFN IBMLIK
	CALL    SCRINP          ; AX=character at this posn
IFN     DBLCHR,<
	JNB     MVCH82          ; BRIF not reading second of double byte char
	INCB    DH              ; Restore DH(SCRINP decremented it)
>                               ; IFN DBLCHR
MVCH82: CMPI    AX," "
	JNZ     MVCH86          ; Found non-blank
	CMPB    DH,CL
	JAE     MVCH84          ; At TERM_POS
MVCH83: DECB    CH
	JNZ     MVCH81          ; Not at LSTPOS+COUNT, continue scan
;Insert to LSTPOS+COUNT [;or TERM_POS+COUNT, whichever is smaller]
MVCH84: POP     AX
	POP     CX
	POP     DX
	MOVB    AH,LSTCOL       ; Change end of FROM insert window to LSTPOS
MVCH85: JMP     MVCH03          ; Insert to LSTPOS
;Insert to last blank after LSTPOS
MVCH86: POP     AX              ; AX=current terminators
	POP     BX              ; BH=Count desired
	MOVB    CH,DH           ; CH=end of TO insert window
	DECB    CH
	POP     DX              ; (DH,DL)=current posn
	ADDB    BH,DH           ; BH=start of TO insert window
	SUBB    CH,BH           ; CH=character count to move
	JB      MVCH89          ; BRIF at end, just overwrite last char
	INCB    CH
	MOVBI   CL,1            ; Move on one line
	MOVB    BL,DL           ; (BH,BL)=start of TO window
	MOV     AX,DX           ; (AH,AL)=start of FROM window
IFN     DBLCHR,<
	PUSH    DX
	PUSH    AX
	MOV     DX,AX
	ADDB    DH,CH
IFN     IBMLIK,<
	CLC                     ; Indicate call is from Screen Editor
>                               ; IFN IBMLIK
	CALL    SCRINP          ; Are we going to scroll half of a double byte char?
	MOVI    AX," "
	JNB     MVCH88
	INCB    DH
MVCH88: CALL    SCROUT          ; Obliterate double byte char scrolled on top of
	POP     AX
	POP     DX
>                               ; IFN DBLCHR
	CALL    SCROL2          ; Move characters over
MVCH89: POP     CX
	XORB    CH,CH           ; No characters wrapped
	JMP     MVCHEX          ; All done
%
;SUBROUTINE SCROL2              ; Used by insert code to move over chars in line
;                           On entry:   AH,BH,CH=scroll parameters
;
	SCROL2	EQU	SCROLL	; No DBLCHR save/restore
;SUBROUTINE SCNRTL              ; Read logical terminator for physical line
;**                     On entry:   DL=line number
;**                     On exit:    AX=terminators
;**                                 CF set indicates EOL terminator
;**                                 CF clear, ZF set indicates LF terminator
;**                                 If NULL_WRAP terminator AH=TERM_POS-1
SCNRTL:	CALL	SCNRDT		; Get terminators
	JB	SCNRT2		; BRIF not NULL_WRAP
	JZ	SCNRT2		; BRIF not NULL_WRAP
	PUSHF	
	CMP	AL,LOW OFFSET TRMNWP
	JNZ	SCNRT1		; BRIF not NULL_WRAP
	DEC	AH		; Is NULL_WRAP, decrement posn
SCNRT1:	POPF	
SCNRT2:	RET	

;Wrap a linefeed(already a successful MKRMNL)
LFTERM:	PUSH	WORD PTR TRMCUR
	PUSH	AX
	CALL	SCNRDT		; Read next line terminator
	MOV	AL,LOW OFFSET TRMLNF
	MOV	AH,BYTE PTR WDOLFT
	CALL	SCNWTT		; Write out LF terminator at left margin plus one
	POP	AX
	POP	WORD PTR TRMCUR
	RET	
	SUBTTL CURSOR MOVEMENT within window



;       These routines return CF=1 when they do not change the posn.
;
;Cursor right within window(or within physical line if outside window)
CSRADV:	INC	DH		; Next column
	CMP	BYTE PTR LINLEN,DH
	JAE	CSRRET		; BRIF Good value
	DEC	DH
	CALL	CSRDWN
	JB	CSRRET		; BRIF can't change physical lines
	MOV	DH,BYTE PTR WDOLFT	; First column
CSRRET:	RET	

;Cursor left within window(or within physical line if outside window)
CSRREG:	DEC	DH		; Previous column
	CMP	DH,BYTE PTR WDOLFT
	JNB	CSRRET		; BRIF good value
	INC	DH		; Restore column
	CALL	CSRUP
	JB	CSRRET		; BRIF can't change physical lines
	MOV	DH,BYTE PTR LINLEN	; Last column
	RET	

;Cursor up within window(or NOP if outside window)
CSRUP:	CMP	BYTE PTR WDOBOT,DL
	JB	CSRRET		; BRIF outside of window
	CMP	DL,BYTE PTR WDOTOP
	JB	CSRRET
	STC	
	JZ	CSRRET		; BRIF at top or outside of window
	CLC	
	DEC	DL
	RET	

;Cursor down within window(or NOP if outside window)
CSRDWN:	CMP	DL,BYTE PTR WDOTOP
	JB	CSRRET		; BRIF outside window
	CMP	BYTE PTR WDOBOT,DL
	JB	CSRRET		; BRIF at bottom or outside of window
	STC	
	JZ	CSRRET
	CLC	
	INC	DL		; Next line
	RET	
	SUBTTL CURSOR MOVEMENT within logical line



;Cursor advance within logical line
;                   on entry:   DH=current column, DL=current line
;                   on exit:    If CF clear, DH=new column, DL=new line
;                                   Else DH=EOL column, DL=EOL line
;                                   ZF=1 if stop at LSTPOS
;                               AH=terminator column, AL=terminator value
;
LCSADV:	CMP	DL,BYTE PTR LSTLIN
	JNZ	LCSAD0		; BRIF not at LSTPOS
	CMP	DH,BYTE PTR LSTCOL
	JB	LCSAD0		; BRIF not at LSTPOS
	CALL	SCNRDT
	CMP	AH,AH		; Set ZF=1 if stop at LSTPOS
	STC	
LCSADX:	RET	
LCSAD0:	CALL	SCNRDT
	JB	LCSAD2		; BRIF at last line
LCSAD1:	CALL	CSRADV
	JB	LCSADA		; BRIF at end of window
	CMP	AH,DH
	JNB	LCSADX		; BRIF within logical line
	INC	DL
	MOV	DH,BYTE PTR WDOLFT	; Else wrap to next physical of logical
	CLC	
	RET	
LCSAD2:	CMP	AH,DH
	JA	LCSAD1		; BRIF not at EOL or beyond
LCSADA:	OR	DH,DH		; ZF=1(not stop at LSTPOS)
	STC	
	RET	
;Cursor regress within logical line
;                   on entry:   DH=current column, DL=current line
;                   on exit:    If CF clear, DH=new column, DL=new line
;                                   Else DH=EOL column, DL=EOL line
;                                   If stop at FSTPOS, ZF is set
;
LCSREG:	CMP	DL,BYTE PTR FSTLIN
	JNZ	LCSRG0		; BRIF not at FSTPOS
	CMP	DH,BYTE PTR FSTCOL
	JA	LCSRG0		; BRIF not at FSTPOS
	STC	
	RET			; ZF=1, CF=1, stop at FSTPOS
LCSRG0:	PUSH	BX
	MOV	BX,DX
	CALL	CSRREG
	JB	LCSRGA		; BRIF at top of window
	CMP	BL,DL
	JZ	LCSRGX		; BRIF on same line, must be good posn
	CALL	SCNRDT
	JNB	LCSRGX		; BRIF still on same logical line
	MOV	DL,BL		; Move back to line we were on
	MOV	DH,BYTE PTR WDOLFT	; And posn at start of that line
LCSRGA:	OR	DH,DH		; ZF=0(not stop at FSTPOS)
	STC	
LCSRGX:	POP	BX
	RET			; Return CF set(at EOL)

LSTART:
LSTRT0:	CMP	DL,BYTE PTR FSTLIN
	JZ	LSTRT1
	CALL	CSRUP
	JB	LSTRT1		; Top of window must be start of line
	CALL	SCNRDT
	JNB	LSTRT0		; BRIF this line is part of logical
	INC	DL
LSTRT1:	MOV	DH,BYTE PTR WDOLFT
	JB	LSTRTX		; BRIF not using FSTPOS, use left margin
	MOV	DH,BYTE PTR FSTCOL
LSTRTX:	RET	
	SUBTTL  MISCELLANEOUS ROUTINES



;*********************************************************
;CHECK FOR WORD OR NON-WORD CHAR(ALPHA NUMERIC)
;
ANCHK:	PUSH	DX
	CLC			; Indicate call is from Screen Editor
	CALL	SCRINP		; Read character at current posn in DX
	JNB	ANCH0		; BRIF DH was not decremented
	INC	DH
ANCH0:	OR	AH,AH
	JNZ	ANCNO		; BRIF is two-byte character - reject
	CMP	AL,LOW 60O
	JB	ANCNO		; BRIF is not alpha-numeric
	CMP	AL,LOW 72O
	JB	ANYES		; BRIF is numeric
	CMP	AL,LOW 101O
	JB	ANCNO		; BRIF is not alpha-numeric
	CMP	AL,LOW 133O
	JB	ANYES		; BRIF is alpha
	CMP	AL,LOW 141O
	JB	ANCNO		; BRIF is not alpha-numeric
	CMP	AL,LOW 173O
	JB	ANYES		; BRIF is small alpha
ANCNO:	STC	
	POP	DX
	RET	

ANYES:	CLC	
	POP	DX
	RET	
CSEG	ENDS
	END
                                                                             