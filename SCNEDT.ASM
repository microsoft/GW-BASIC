; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   SCNEDT  Screen Oriented Editor for GW-BASIC
	SUBTTL  DATA DEFINITIONS


COMMENT	*
        --------- --- ---- -- ---------
        COPYRIGHT (C) 1982 BY MICROSOFT
        --------- --- ---- -- ---------
        *

	INCLUDE	GIO86U
	.RADIX	8
	.SALL

;OEM IFNDEF'S:
MELCO=0
HAL=0

;GENERIC IFNDEF'S:
TERMSW=0
HLPTRP=0
STPTRP=0
HLPEDT=0
SCRKEY=0
NMPAGE=0
IBMCSR=IBMLIK



;INTERNAL ROUTINES:

	PUBLIC	PINLIN		; Program line input
				;on exit:       BX=addr of input -1

	PUBLIC	INLIN		; BASIC INPUT Statements line input
				;on exit:       BX=addr of input -1

	PUBLIC	SINLIN		; BASIC INPUT Statements redo line input
				;on exit:       BX=addr of input -1

	PUBLIC	QINLIN		; BASIC INPUT Statements with output of "?" first
				;on exit:       BX=addr of input -1

	PUBLIC	SCNSEM		; BASIC INPUT statement scan for semicolon
				;on exit:       SEMFLG flag set
	PUBLIC	EDTBRK		; BASIC received break, reinitialize routine

	PUBLIC	ERREDT		; BASIC Syntax error auto-edit on ERRLIN
				;on exit:       Removes return and jumps to MAIN after
				;               listing ERRLIN and positioning cursor at
				;               start of line.

	PUBLIC	EDIT		; EDIT Statement
				;on exit:       Same as ERREDT, except takes line number
				;               to list as argument.

;       INTERN  EDITRT          ; AUTO Program line input processing
				;on exit:       BX=addr of input(BUF)
				;               it also puts PSW on stack with carry
				;               set and jumps to EDENT for exit


;EXTERNAL ROUTINES:

	EXTRN	OUTDO:NEAR	; Character output(GIO86)
	EXTRN	KEYIN:NEAR	; Key input(expands any string keys-GIOKYB)
	EXTRN	SCNMRK:NEAR	; Mark current posn as start of line(SCNDRV)
	EXTRN	SCNRDL:NEAR	; Read current logical line(SCNDRV)
	EXTRN	CRDO:NEAR	; BASIC new line routine
	EXTRN	CHRGTR:NEAR	; BASIC character scan routine

;DATA (DEFINED IN RAM MODULE)
DSEG	SEGMENT PUBLIC 'DATASG'		
	ASSUME DS:DSEG
	EXTRN	F_EDPG:WORD	; Flag - =^O377 indicates program statement edit
	EXTRN	SEMFLG:WORD	; Flag - zero indicates INPUT; statement(no crlf
				;       at end of input line)
	EXTRN	F_INST:WORD	; Flag - =^O377 indicates insert mode
	EXTRN	BUF:WORD	; Buffer where line of data is returned
				;   NOTE: assumes non-blank at BUF-1
	EXTRN	F_EDIT:WORD	; Flag - non-zero indicates INLIN active
	EXTRN	AUTFLG:WORD	; AUTO mode flag
	EXTRN	CSRX:WORD	; Cursor column (1..n)
	EXTRN	CSRY:WORD	; Cursor line (1..n)
DSEG	ENDS
;LITERALS NEEDED ELSEWHERE
	PUBLIC	CHRLNF		; Line feed character
	PUBLIC	CHRRET		; Carriage return character


;CHARACTER DEFINITIONS
;
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
	CHRLDL=21D		; Line DeLete
	CHRADV=28D		; cursor RiGhT
	CHRREG=29D		; cursor LeFT
	CHRUP=30D		; cursor UP
	CHRDWN=31D		; cursor DoWN
	CHRDEL=127D		; DELete
	SUBTTL  Entry points for editing



;ENTRY: PINLIN, QINLIN, INLIN, SINLIN
;
;PROGRAM STATEMENT INPUT
PUBLIC	PINLIN
PINLIN:	CALL	DSKCHI		; Don't return if Loading ASCII File
	STC			; Indicate program statement input
	JMP	SHORT INLIN0

;PRINT "?" BEFORE GETTING INPUT
PUBLIC	QINLIN
QINLIN:	MOV	AL,LOW "?"
	CALL	OUTDO		; Output a "?"
	MOV	AL,LOW " "
	CALL	OUTDO		; Followed by a space

;INPUT STATEMENT
PUBLIC	INLIN
INLIN:

;INPUT STATEMENT REDO
PUBLIC	SINLIN
SINLIN:	OR	AL,AL		; Indicate INPUT statement line input

INLIN0:
	SBB	AL,AL		; If INPUT statement AL=0, else AL=-1
	MOV	BYTE PTR F_EDPG,AL	; Save flag
	MOV	AL,BYTE PTR F_EDIT	; Get old value of F.EDIT(in case of EDIT statement)
	MOV	BYTE PTR F_EDIT,LOW 377O	; Indicate executing INLIN
	CALL	SCNMRK		; Set up for edit
				;   If AL=1 then move cursor to start of logical
				;       line which preceeds current.
				;   Else if ZF=1 then set up FSTPOS, LSTPOS
				;        if ZF=0 then FSTPOS=0,0; LSTPOS=max,max
	SUBTTL  MAIN loop of editor



;WHILE EOL.NE.TRUE BEGIN
;** GET A KEY
INLLOP:
	EXTRN	STCTYP:NEAR
	CLC			; Signal for insert or overwrite cursor
	CALL	STCTYP		; Set new cursor type
	CALL	KEYIN		; AX=key value
;At this point we can have three classes of characters:
;   CF=1 indicates 2 byte char with 2 sub classes:
;       AH=FF indicates editor control function
;       AH<>FF indicates 2 byte character to echo
;   CF=0 indicates 1 or 3 byte key
;       AL=FF indicates a 3 byte key with scan code in DX - these are ignored
;       AL<>FF indicates a 1 byte key to echo, except if char is CR.
	JB	INL2BY		; BRIF 2-byte character, check for editor controls
	CMP	AL,LOW OFFSET CHRRET
	JZ	INLRET		; BRIF CR, terminate line input
;** IF CURRENT_CHAR IS SPECIAL THREE BYTE CHAR
	CMP	AL,LOW 254D	; Test for 3-byte character
;** *** IGNORE THIS CHAR
	JZ	INLLOP		; BRIF to ignore 3-byte character
	JMP	SHORT INLOP0	; Not 3-bytes, just echo single byte
INL2BY:
;** IF CURRENT_CHAR IS CONTROL_CHAR
	CMP	AH,LOW 255D
	JNZ	INLOP0		; BRIF not editor control character, echo char
	CMP	AL,LOW 177O
	JZ	INLP0		; BRIF is a control character
	CMP	AL,LOW " "
	JNB	INLOP0		; BRIF is not a control character
INLP0:
;** IF CURRENT_CHAR IS <CR> RETURN CURRENT LOGICAL LINE
	CMP	AL,LOW OFFSET CHRRET
	JZ	INLRET		; BRIF is carriage return(EOL)
;** IF (CURRENT_CHAR=<HELP> AND INPUT_MODE=PROGRAM) DO EDIT ON KBUF
	CMP	AL,LOW OFFSET CHREDT
	JNZ	INLOP0
	JMP	INLHLP		; BRIF help char, do edit on KBUF
;Echo character in AX
INLOP0:
	OR	AH,AH
	JZ	INLOP3		; Single byte character
	XCHG	AL,AH		; Output AH first
	CALL	OUTDO		; Output a char
	XCHG	AL,AH		; Restore AL
INLOP3:	CALL	OUTDO		; Output a char
	JMP	SHORT INLLOP
;** END

;SCAN FOR SEMICOLON
;
SCNSEM:	CMP	AL,LOW ";"
	JNZ	SCNSMR		; BRIF not semicolon, return
	MOV	BYTE PTR SEMFLG,AL
	JMP	CHRGTR		; Skip semicolon and return
SCNSMR:	RET	
	SUBTTL  Exit, return current logical line



;READ LOGICAL LINE INTO BUF
INLRET:	MOV	BX,OFFSET BUF	; Put data into BUF
	MOV	CX,255D		; CX=Max number of bytes to move
	TEST	BYTE PTR F_EDPG,LOW 377O	; Set zero flag if program statement input
	PUSHF	
	MOV	DL,BYTE PTR CSRY	; (DH,DL) = (CSRX,CSRY)
	MOV	DH,BYTE PTR CSRX
	CALL	SCNRDL		; Read the logical line into BUF
				; BX=address of last char in BUF plus one
;IF PROGRAM_STATEMENT_INPUT BEGIN
	POPF	
	JZ	INCRTX		; BRIF not statement input
;** WHILE POSN.NE.BEGIN_OF_LINE AND [POSN].NE.BLANK AND [POSN].NE.LF BEGIN
	MOV	CX,BX
	SUB	CX,OFFSET BUF	; CX=count of chars in BUF
	JZ	INCRTX		; BUF is empty
	PUSH	DI
	MOV	DI,BX
	DEC	DI		; Start scan at last valid data
INLOT0:	MOV	AL,LOW " "
;** *** POSN=POSN-1
INLOT1:	STD			; Scan backwards
 REPE	SCASB			; This works for blank line("," at BUF-1)
	INC	DI		; [DI] = last valid data
	MOV	AL,LOW " "
	CMP	BYTE PTR 0[DI],AL
	JZ	INLOT2		; BRIF more trailing blanks
	MOV	AL,LOW OFFSET CHRLNF
	CMP	AL,BYTE PTR 0[DI]
	JNZ	INLOT3		; BRIF not more trailing linefeeds
INLOT2:	OR	CL,CL
	JNZ	INLOT1		; BRIF not at beginning of buffer
;** *** END
;** END
INLOT3:	MOV	BX,DI
	POP	DI
	INC	BX
INCRTX:	MOV	BYTE PTR 0[BX],LOW 0	; Terminate BUF
;** UPDATE CURSOR POSN, RETURN
	TEST	BYTE PTR SEMFLG,LOW 377O
	JNZ	INCRTF		; BRIF if INPUT<semicolon> statement
	MOV	AX,OFFSET CHRAPP
	CALL	OUTDO		; Move to end of logical
	MOV	BYTE PTR F_EDIT,LOW 0
	CALL	CRDO		; Move to first posn beyond this logical
INCRTF:	MOV	BX,OFFSET BUF-1	; Return BUF - 1
	PUSHF	
	CALL	CLRFLG		; Clear miscellaneous status flags
	POPF	
	RET	


;SUBROUTINE EDTBRK              ; Routine which initializes when break detected
;**                             ; This is called by the STOP code
;**
EDTBRK:
	EXTRN	SETCSR:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CSRTYP:WORD
DSEG	ENDS
	MOV	BYTE PTR CSRTYP,LOW 0D	; Indicate cursor off
	CALL	SETCSR
	CALL	CLRFLG		; Clear editor flags
	PUSH	AX
	MOV	AL,LOW OFFSET CHRAPP
	MOV	BYTE PTR F_EDIT,AL
	CALL	OUTDO		; Move cursor to end of logical line
	MOV	BYTE PTR F_EDIT,LOW 0	; Reset edit mode
	CALL	CRDO		; Move cursor to next physical line
	POP	AX
	MOV	BYTE PTR AUTFLG,LOW 0	; Reset AUTO mode
	RET	
;** END SUBROUTINE EDTBRK

;SUBROUTINE CLRFLG              ; Routine which clears flags
;**
CLRFLG:	MOV	BYTE PTR F_EDIT,LOW 0	; No longer in INLIN
	MOV	BYTE PTR F_EDPG,LOW 0	; Not program edit
	MOV	BYTE PTR F_INST,LOW 0	; Not insert mode
	MOV	BYTE PTR SEMFLG,LOW 0	; Not INPUT; statement
	RET	
;** END SUBROUTINE CLRFLG

	SUBTTL  EDIT code



	EXTRN	MAIN:NEAR,LINSPC:NEAR,FNDLIN:NEAR,DEPTR:NEAR,LISPRT:NEAR
	EXTRN	LINPRT:NEAR,FCERR:NEAR,USERR:NEAR,BUFLIN:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	DOT:WORD,ERRFLG:WORD,ERRLIN:WORD
DSEG	ENDS

;EDIT COMMAND
;
PUBLIC	EDIT
EDIT:	CALL	LINSPC		; LINE NUMBER IN DE
	JNZ	EFCERR		; STATEMENT MUST HAVE ENDED
EREDIT:	POP	BX		; REMOVE NEWSTT(OR CALL FROM MAIN)RETURN
	MOV	WORD PTR DOT,DX
	CALL	FNDLIN		; FIND LINE
	JNB	EUSERR		; LINE DOES NOT EXIST
	MOV	BX,CX		; CX=LINE PTR
ERED2:	INC	BX
	INC	BX
	MOV	DX,WORD PTR 0[BX]	; DE=LINE NUMBER
	INC	BX
	INC	BX
ERED3:	PUSH	BX
	MOV	BYTE PTR F_EDIT,LOW 1	; SET FLAG INDICATING IN EDIT MODE
				; (FORCES OPEN LINES DURING LIST)
				; (AND TELLS INLIN TO START AT BEGIN OF LOGICAL)
	XCHG	BX,DX
ERED4:	CALL	LINPRT		; PRINT THE LINE NUMBER
	POP	BX
	CMP	BYTE PTR 0[BX],LOW 9D	; LINE START WITH TAB?
	JZ	ERED5
	MOV	AL,LOW " "
	CALL	OUTDO		; NO, PUT SPACE OUT
;ENTRY FOR EDIT ON KBUF IS HERE
ERED5:
	MOV	BYTE PTR F_EDIT,LOW 1	; SET FLAG INDICATING IN EDIT MODE
				; (FORCES OPEN LINES DURING LIST)
				; (AND TELLS INLIN TO START AT BEGIN OF LOGICAL)
	CALL	BUFLIN		; PUT LINE IN BUF AND SET UP HLPBFA
	MOV	BX,OFFSET BUF
	CALL	LISPRT		; PRINT THE LINE AND SET UP HLPCSR
	MOV	BL,BYTE PTR CSRY
	MOV	BH,BYTE PTR CSRX
	JMP	MAIN
EFCERR:	JMP	FCERR		; Indirect jump to FCERR
EUSERR:	JMP	USERR		; Indirect jump to USERR

;Help key edit
;
INLHLP:	TEST	BYTE PTR F_EDPG,LOW 377O
	JNZ	INLHL0		; BRIF do help edit on program statement
;Help during input statement
	JMP	INLOP3		; Just output char


;DO EDIT ON DOT
INLHL0:	POP	AX		; Remove call to this routine

;See if edit on error line number
	MOV	DX,WORD PTR ERRLIN
	CALL	ERRED2		; If exists,do edit on error line number

;See if edit on current line number
	MOV	DX,WORD PTR CURLIN
	CALL	ERRED2		; If exists,do edit on current line number
;ERRLIN AND CURLIN ARE DIRECT, DO EDIT ON KBUF
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	KBUF:WORD,CURLIN:WORD
DSEG	ENDS
	EXTRN	SCNEXT:NEAR,DEPTR:NEAR
	CALL	DEPTR		; Remove line pointers from program
	MOV	BX,OFFSET KBUF
	PUSH	BX
	DEC	BX
	CALL	SCNEXT		; Remove any line pointers from KBUF
	POP	BX
	JMP	SHORT ERED5

;AUTOMATIC EDIT FOR ERRORS
;
PUBLIC	ERREDT
ERREDT:	MOV	BYTE PTR ERRFLG,AL	; Reset the flag to call edit
	MOV	DX,WORD PTR ERRLIN	; Get the line number
ERRED2:	CMP	DX,177777O	; See if it was direct
	JZ	ERRED3		; Go back if direct
	OR	DX,DX
	JZ	ERRED3		; Go back if zero
	JMP	EREDIT
ERRED3:	RET	
	SUBTTL  ASCII LOAD and SAVE line handler



;LOAD ASCII:
;  PROGRAM LINE INPUT FROM DISK
;
	EXTRN	ISFLIO:NEAR,OUTDO:NEAR,INCHR:NEAR,LBOERR:NEAR
DSKCHI:
	CALL	ISFLIO		; Set FLAGS.NZ if PTRFIL points to active file
	JNZ	ISLOAD		; BRIF LOAD statement
	RET			; If so use special screen io
ISLOAD:	POP	AX		; Discard Return Address
	MOV	CL,LOW OFFSET BUFLEN	; Setup the maximum character count
	MOV	BX,OFFSET BUF	; Place we are going to stoer the line
LOPBUF:	CALL	INCHR		; Get a character from the file
				; (will call indskc and handle eof)
	MOV	BYTE PTR 0[BX],AL	; Store the character
	CMP	AL,LOW 13D	; Is it the end (a CR)
	JNZ	INOTCR		; Not a [CR]
	CMP	BYTE PTR -1[BX],LOW 10D	; Preceeded by a line feed?
	JZ	LOPBUF		; Yes, ignore the [CR]
	JMP	SHORT FINLIN	; No, this is the end of a line
INOTCR:
	OR	CL,CL
	JE	LTLONG		; Branch if line is too long to fit in BUF
	CMP	AL,LOW 10D	; LEADING LINE FEEDS MUST BE IGNORED
	JNZ	INOTLF
	CMP	CL,LOW OFFSET BUFLEN	; CL=BUFLEN if this is the 1st char on the line
	JZ	LOPBUF		; Branch if this was a leading line-feed
INOTLF:	INC	BX		; ADVANCE THE POINTER
	DEC	CL
	JMP	SHORT LOPBUF	; DO NEXT CHAR
	DEC	CL
FINLIN:
	MOV	BYTE PTR 0[BX],LOW 0
	MOV	BX,OFFSET BUF-1	; POINT AT BUFMIN
	RET	

LTLONG:	JMP	LBOERR		; Report LINE BUFFER OVERFLOW error
				; (This program wasn't created by BASIC)

;SAVE ASCII:
;   PROGRAM LISTING CHAR OUTPUT TO DISK(CONVERT <LF> TO <LF><CR>)
;
PUBLIC	OUTCH1
OUTCH1:	CMP	AL,LOW OFFSET CHRLNF
	JZ	OUTCH0		; IS LF
	JMP	OUTDO
OUTCH0:
	EXTRN	ISFLIO:NEAR
	CALL	ISFLIO
	JNZ	OUTCH2		; branch if outputting to file
	CALL	OUTDO
	RET	

OUTCH2:	CALL	OUTDO
	MOV	AL,LOW OFFSET CHRRET
	CALL	OUTDO
	MOV	AL,LOW OFFSET CHRLNF
	RET	
CSEG	ENDS
	END
                                                                  