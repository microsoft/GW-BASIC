; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   GIO86   - BASIC-86 Interpreter Device Independent I/O Module

COMMENT	*

--------- --- ---- -- ---------
COPYRIGHT (C) 1982 BY MICROSOFT
--------- --- ---- -- ---------

        T. Corbett      Microsoft Inc.

        *
	INCLUDE	GIO86U
	.SALL


CPM86=0
IBMCSR=IBMLIK			;IBM Compatible Cursor Handling

	INCLUDE	MSDOSU

DSEG	SEGMENT PUBLIC 'DATASG'		
	ASSUME DS:DSEG
	EXTRN	DEVPTR:WORD,DEVTBL:WORD,DEVINI:WORD,DEVTRM:WORD
	EXTRN	NLONLY:WORD,RUNFLG:WORD
	EXTRN	FILMOD:WORD,FILDEV:WORD,FILNM:WORD,FILEXT:WORD
	EXTRN	PTRFIL:WORD,FILTAB:WORD,STKLOW:WORD
DSEG	ENDS

	EXTRN	SNERR:NEAR,FCERR:NEAR
	EXTRN	FRESTR:NEAR,GETYPR:NEAR
	EXTRN	$_KYBD:NEAR,$_LPT1:NEAR,$_NDEV:NEAR
	EXTRN	DERBFM:NEAR,DERBFN:NEAR,DERFAO:NEAR,DERFNO:NEAR,DERIFN:NEAR
	EXTRN	DERDNA:NEAR,DERFDR:NEAR

DOSIO	MACRO	DFUN
	MOV	AH,LOW OFFSET DFUN
	INT	33D		;MS-DOS system call
ENDM 



	SUBTTL OPEN statement

	PUBLIC	OPEN
	EXTRN	$LEN:NEAR,EQULTK:NEAR,$FOR:NEAR,$INPUT:NEAR,GETBYT:NEAR
	EXTRN	GWWID:NEAR

; OPEN Statement
; Syntax:
;  OPEN filespec FOR mode AS fnum [LEN=random-record-length]
;  OPEN mode,fnum,filespec[,random-record-length]
;
OPEN:	CALL	FRMEVL		;read the file mode or filename
	MOV	AL,BYTE PTR 0[BX]	;get terminator
	CMP	AL,LOW 54O	;followed by comma? (then
				; non-spcdsk open...)
	JNZ	NOTNSO		;nope, must be SPCDSK form
	PUSH	BX		;save the text pointer
	CALL	FRESTR		;free string temp & check string
	MOV	AL,BYTE PTR 0[BX]	;make sure its not a null string
	OR	AL,AL
	JZ	ERBFM0		;if so, "bad file mode"
	INC	BX
	MOV	BX,WORD PTR 0[BX]	;[BX] points at mode character
	MOV	AL,BYTE PTR 0[BX]	;[A]=mode character
	AND	AL,LOW OFFSET -1-" "	;force to upper case
	MOV	DH,LOW OFFSET MD_SQO	;assume its "O"
	CMP	AL,LOW "O"	;is it?
	JZ	HAVMOD		;[D] has correct mode
	MOV	DH,LOW OFFSET MD_SQI	;assume sequential
	CMP	AL,LOW "I"	;is it?
	JZ	HAVMOD		;[D] says sequential input
	MOV	DH,LOW OFFSET MD_APP	;append?
	CMP	AL,LOW "A"	;test
	JZ	HAVMOD		;allow it
	MOV	DH,LOW OFFSET MD_RND	;must be random
	CMP	AL,LOW "R"
	JNZ	ERBFM0		;if not, no match so "bad file mode"
HAVMOD:	MOV	BYTE PTR FILMOD,DH	;set file mode
	POP	BX		;get back the text pointer
	CALL	SYNCHR
	DB	OFFSET 54O	;skip comma before file number
HAVMD1:	CALL	POFNUM		;[AL]=the file number
	PUSH	AX		;save file number
	CALL	SYNCHR
	DB	OFFSET 54O	;skip comma before name
	CALL	NAMSCN		;parse filename setting FILDEV, FILNM, FILEXT
	CALL	PORLEN		;parse reclen parm
	JMP	SHORT OPEN1	;branch to common code (with Fnum on stack)

ERBFM0:	JMP	DERBFM		;bad file mode error

NOTNSO:	CALL	NAMSC1		;parse filename setting FILDEV, FILNM, FILEXT
	MOV	DH,LOW OFFSET MD_RND	;Assume there is no FOR, in which
				;case the default mode is random.
	MOV	AL,BYTE PTR 0[BX]
	CMP	AL,LOW OFFSET $FOR	;Is there a 'FOR'?
	JNZ	GOTMOD		;No, better see 'AS'
	CALL	CHRGTR
	CMP	AL,LOW OFFSET $INPUT	;Input mode?
	MOV	DH,LOW OFFSET MD_SQI	;Assume it is
	JZ	GOTMD1		;Yes, have file mode
	CMP	AL,LOW "A"	;test
	JNE	NTAPP		;branch if not append (might be OUTPUT)
	CALL	SYNCHR
	DB	OFFSET "A"
	CALL	SYNCHR
	DB	OFFSET "P"
	CALL	SYNCHR
	DB	OFFSET "P"
	CALL	SYNCHR
	DB	OFFSET "E"
	CALL	SYNCHR
	DB	OFFSET "N"
	CALL	SYNCHR
	DB	OFFSET "D"
	MOV	DH,LOW OFFSET MD_APP	;append file mode
	JMP	SHORT GOTMOD	;allow it
NTAPP:
	CALL	SYNCHR
	DB	OFFSET "O"	;it must be OUTPUT
	CALL	SYNCHR
	DB	OFFSET "U"
	CALL	SYNCHR
	DB	OFFSET "T"
	CALL	SYNCHR
	DB	OFFSET "P"
	CALL	SYNCHR
	DB	OFFSET "U"
	CALL	SYNCHR
	DB	OFFSET "T"
	MOV	DH,LOW OFFSET MD_SQO
	JMP	SHORT GOTMOD

GOTMD1:	CALL	CHRGTR
GOTMOD:	MOV	BYTE PTR FILMOD,DH	;set file mode
	CALL	SYNCHR
	DB	OFFSET "A"
	CALL	SYNCHR
	DB	OFFSET "S"	;Must have 'AS'
	CALL	POFNUM		;[AL]=file #
	PUSH	AX		;save file#
	CALL	PNRLEN		;parse new reclen parameter
OPEN1:	DEC	BX
	CALL	CHRGTR
	JNZ	SNERR1		;error if not end-of-statement
	POP	AX		;[AL]=file number
	CALL	OPNFIL		;branch to general file-open code
	JMP	FINPRT		;reset PTRFIL to 0 (keyboard/crt)

;PORLEN - parse old variable record length field
; Entry - [FILMOD]=file mode
; Exit  - [CX]=reclen if reclen parm included, else 0
;
PORLEN:	CALL	PRLENC
	JZ	PRLENX
	CALL	SYNCHR
	DB	OFFSET 54O
	JMP	SHORT VARECS

;PNRLEN - parse new variable record length field
; Entry - [FILMOD]=file mode
; Exit  - [CX]=reclen if reclen parm included, else 0
;
PNRLEN:	CALL	PRLENC
	JZ	PRLENX
	CALL	SYNCHR
	DB	OFFSET 377O	;else parse "LEN=record-length"
	CALL	SYNCHR
	DB	OFFSET $LEN	;LEN is a 2-byte token
	CALL	SYNCHR
	DB	OFFSET EQULTK
	EXTRN	INTID2:NEAR
VARECS:	CALL	INTID2		;[DX]=record size (0..32767)
	MOV	CX,DX		;return it in CX
	OR	CX,CX
	JZ	FCERR1		;0 is illegal value
PRLENX:	RET	

;PRLENC - see if reclen parm is expected
;
PRLENC:
	MOV	CX,0		;indicates reclen parm not included
	MOV	AL,BYTE PTR FILMOD	;[AL]=requested file mode
	CMP	AL,LOW OFFSET MD_RND
	JNZ	NOLEN		;branch if file mode is not RANDOM
	DEC	BX		;decrement text pointer
	CALL	CHRGTR		;re-get last character parsed
	JZ	NOLEN		;branch if end-of-statement
	MOV	CL,LOW 1	;indicates reclen parm included
NOLEN:	OR	CX,CX		;set NZ if reclen parm included
	RET	

FCERR1:	JMP	FCERR		;function call error

SNERR1:	JMP	SNERR		;syntax error

	SUBTTL CLOSE, WIDTH Statements

	PUBLIC	CLOSE

; CLOSE Statement
;  Syntax: CLOSE [[#]n [,[#]n ...]]
;
CLOSE:	JNZ	CLOS1		;branch if statement has parm
	JMP	CLSALL		;close all files if no parm given
CLOS1:	CMP	AL,LOW "#"
	JNZ	NOLBS		;branch if no #
	CALL	CHRGTR		;skip #
NOLBS:
	CALL	GETBYT		;[AL]=file#
	CALL	CLSFIL		;close file [AL] and return
	DEC	BX
	CALL	CHRGTR
	CMP	AL,LOW 54O	;check for comma
	JNZ	RET6		;branch if end of file list
	CALL	CHRGTR		;skip comma
	JMP	SHORT CLOS1	;close next file in list

	PUBLIC	WIDTHS

; WIDTH Y[,X]/[#fnum,]/[device,]   Statement
; Entry - (BX) = text pointer
;
WIDTHS:	CMP	AL,LOW "#"
	JZ	FILWID		;Is files WIDTH specification
	CMP	AL,LOW 54O
	JZ	CRTWD1		;branch if Comma
	EXTRN	$LPRINT:NEAR,$_LPT1:NEAR
	CMP	AL,LOW OFFSET $LPRINT
	JNZ	NOTLPR		;branch if not WIDTH LPRINT
	CALL	CHRGTR		;skip LPRINT
	MOV	AL,LOW OFFSET $_LPT1
	JMP	SHORT ITSWLP
NOTLPR:
	PUSH	BX		;save Text Pointer in case CRT width
	CALL	FRMEVL		;evaluate string or number
	CALL	GETYPR
	JNZ	CRTWD		;brif not string argument. CRT width
	POP	SI		;discard old text pointer
	PUSH	BX		;save text pointer
	CALL	FRESTR		;release temporary string descriptor
				;[BX] points to string descriptor
	MOV	CL,BYTE PTR 0[BX]
	MOV	CH,LOW 0	;[CX]=length of string
	MOV	SI,WORD PTR 1[BX]	;SI points to start of string
	CALL	PARDEV		;AL=-(device number)
	POP	BX		;restore text pointer
	PUSH	AX		;save device id
	CALL	SYNCHR
	DB	OFFSET 54O
	POP	AX		;[AL]=device id
ITSWLP:
	PUSH	AX		;save device id
	CALL	GETWDT		;[DL]=width
	POP	AX		;[AL]=device id
	CALL	CDEVID		;[DI]=device dispatch table offset
	JZ	ERIFN0		;illegal file name if device=disk
	MOV	AH,LOW OFFSET G_SWD	;select set-width function
	JMP	TBLDSP		;dispatch function [AH] for device [DI]

FILWID:	CALL	PRFNUM		;[AL]=file number
	CALL	FDBPTR		;[SI] points to file-data-block
	JZ	ERFNO1		;branch if file not opened
	PUSH	SI
	CALL	SYNCHR
	DB	OFFSET 54O
	CALL	GETWDT		;[AL]=width (1..255)
	POP	SI		;SI points to file data block
	MOV	BYTE PTR F_WID[SI],AL	;save width in FDB
RET6:	RET	

GETWDT:	CALL	GETBYT
	OR	AL,AL
	JZ	FCERR2		;width of 0 is illegal
	RET			;return if width is between 1 and 255

CRTWD:	POP	BX		;restore text pointer
CRTWD1:	JMP	GWWID

FCERR2:	JMP	FCERR
ERIFN0:	JMP	DERIFN		;illegal file name error
ERFNO1:	JMP	DERFNO		;file not open error
ERDNA1:	JMP	DERDNA		;Device not available

	SUBTTL BSAVE, BLOAD Statements


	PUBLIC	BLOAD,BSAVE
	EXTRN	GETBYT:NEAR,SYNCHR:NEAR,MAKINT:NEAR,CHRGTR:NEAR,SNERR:NEAR
	EXTRN	PRODIR:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	SAVLEN:WORD,SAVSEG:WORD
DSEG	ENDS

; BSAVE Statement - Save memory image to file
; Syntax: BSAVE name, start-adr, byte-count
;
BSAVE:	CALL	BPARMS		;parse parms
	INC	AL
	JNZ	SNERR2		;Error if 1 or no parms.
	PUSH	BX		;save text pointer
	PUSH	CX		;SAVE start-adr
	MOV	AL,LOW OFFSET MD_SQO	;open file 0 for output
	CALL	NULOPM
	CALL	SCDBIN		;set file-code to binary
	MOV	AL,LOW OFFSET BSVFID	;output binary file ID
	CALL	OUTDO		;output to file
	MOV	AX,WORD PTR SAVSEG	;DX=Segment from DEF SEG statement
	CALL	OUT16		;write segment adr to file
	POP	AX		;[AX]=start-adr
	PUSH	AX
	CALL	OUT16		;output start adr
	MOV	AX,WORD PTR SAVLEN	;[DX]=number of bytes
	MOV	CX,AX		;[CX]=length
	CALL	OUT16		;output end adr + 1
	POP	BX		;[BX]=start-adr
	MOV	DX,WORD PTR SAVSEG	;DX=Segment adr
	CALL	OUTBLK		;output binary
	JMP	LODEND		;exit

SNERR2:	JMP	SNERR

; BLOAD Statement - load memory image from disk
; Syntax: BLOAD name[, start-adr]
;
BLOAD:
	CALL	BPARMS		;Get Parms if any.
	OR	AL,AL
	JZ	BLODP		;Will set -1 if start-adr only given.
	INC	AL
	JZ	SNERR2		;error if 2 parms given
BLODP:	DEC	AL		;AL=1: no start-adr parm, -1: start-adr parm
	PUSH	BX		;save text pointer
	PUSH	AX		;save Parm Switch
	PUSH	CX		;save start-adr parm
	MOV	AL,LOW OFFSET MD_SQI
	CALL	NULOPM		;Open File 0 for INPUT
	CALL	SCDBIN		;set file code to binary
	CALL	INCHR		;[A]=1st byte from file
	CMP	AL,LOW OFFSET BSVFID	;make sure this was created by BSAVE
	JNZ	ERBFM2		;else BAD FILE MODE
	POP	CX		;[CX]=start-adr parm
	CALL	INP16		;[AX]=next 16 bits from file
	MOV	DX,AX		;[DX]=default segment
	CALL	INP16		;[AX]=next 16 bits from file
	MOV	BX,AX		;[BX]=default start-adr
	POP	AX		;AL=1: no start-adr parm, -1: start-adr parm
	DEC	AL
	JZ	DEFSAD		;branch if no start-adr parm given
	MOV	DX,WORD PTR SAVSEG	;[DX]=segment parm
	MOV	BX,CX		;[BX]=start-adr parm
DEFSAD:	CALL	INP16		;[AX]=file length
	MOV	CX,AX		;[CX]=file length
	CALL	INPBLK		;do the load
LODEND:
	POP	BX		;restore text pointer
	JMP	FINPRT		;close file 0, reset PTRFIL

ERBFM2:	JMP	DERBFM		;bad file mode error

;BPARMS - Parse parms for BLOAD and BSAVE
; Exit  - [AL]=(1,0,-1) if 0,1,2 parameters parsed.
;         [BX] is preserved (text pointer)
;         [CX] = start-adr
;         [SAVLEN] = file size (if BSAVE)
;
BPARMS:
	CALL	PRODIR		;Don't allow in direct mode if protected
	CALL	NAMSCN		;scan file name and disk number
				;setting FILDEV, FILNM, FILEXT
	JB	BNAMOK		;Extension supplied by user
	CALL	NAMBAS		;Supply ".BAS" default extension
BNAMOK:
	DEC	BX
	CALL	CHRGTR		;See if any parms
	JNZ	BPARM2		;Brif parms follow
	MOV	AL,LOW 1	;No Parms, use file header if BLOAD.
	RET			; else exit.
BPARM2:
	CALL	SYNCHR
	DB	OFFSET ","	;Must see comma first
	CALL	ADRGET		;get start-adr (0..65535)
	PUSH	DX		;save it
	DEC	BX
	CALL	CHRGTR
	JNZ	BPARM3		;Brif 2nd Parm given.
	POP	CX		;[CX]=start adr
	XOR	AL,AL		;Set 0 if 1 parm only given.
	RET	
BPARM3:
	CALL	SYNCHR
	DB	OFFSET ","
	CALL	ADRGET		;[DX]=number of bytes for bsave (0..65535)
	XCHG	BX,DX
	MOV	WORD PTR SAVLEN,BX	;Save end ADDRESS+1(start+count)
	XCHG	BX,DX		;[BX]=text pointer
	DEC	BX
	CALL	CHRGTR
	JNZ	SNERR3		;must be end of statement
	POP	CX		;[CX]=start-adr
	MOV	AL,LOW 377O	;Set -1 if 2 parms given.
	RET	

SNERR3:	JMP	SNERR

	SUBTTL LPRINT, PRINT Statements

	PUBLIC	LPRINT,PRINT
	EXTRN	PRINUS:NEAR,IMOD:NEAR,FOUT:NEAR,STRLIT:NEAR,STRPRT:NEAR
	EXTRN	USINTK:NEAR,TABTK:NEAR,SPCTK:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FACLO:WORD
DSEG	ENDS

JPRINU:	JMP	PRINUS		;Print Using

PRINTX:	CALL	CRDO		;output terminating CR
PRNTX1:	POP	CX		;discard line width, last comma column
	JMP	FINPRT		;close file#0, reset PTRFIL to keyboard

LPRINT:	MOV	WORD PTR PTRFIL,-1	;future output will go to Line Printer
	JMP	SHORT PRINT1
PRINT:
	MOV	CL,LOW OFFSET MD_SQO	;setup output file
	CALL	FILGET
PRINT1:	CALL	PTRWDC		;[CH]=width, [CL]=last comma column
	PUSH	CX		;save on stack
NEWCHR:	DEC	BX
	CALL	CHRGTR		;get another character
	JZ	PRINTX		;print CR if end without punctuation
PRINTC:	JZ	PRNTX1		;branch if end of statement
	POP	CX		;refresh [CH]=width, [CL]=last comma column
	CMP	AL,LOW OFFSET USINTK	;is it "print using" ?
	JZ	JPRINU		;IF SO, USE A SPECIAL HANDLER
	PUSH	CX		;save [CH]=width, [CL]=last comma column
	CMP	AL,LOW OFFSET TABTK
	JZ	TABERJ		;the TAB function?
	CMP	AL,LOW OFFSET SPCTK
	JZ	TABERJ		;the SPC function?
	PUSH	BX		;save the text pointer
	CMP	AL,LOW 44D
	JZ	COMPRT		;Print Comma
	CMP	AL,LOW 59D	;is it a ";"
	JNZ	PRTS
	JMP	NOTABR
TABERJ:	JMP	TABER
PRTS:	POP	DX		;get rid of old text pointer
	CALL	FRMEVL		;evaluate the formula
	PUSH	BX		;save text pointer
	CALL	GETYPR		;see if we have a string
	JZ	STRDON		;if so, print special
	DEC	BX
	CALL	CHRGTR		;[BX]=addr of number terminator(non-blank)
	CMP	BYTE PTR 0[BX],LOW 54O
	PUSHF			;remember if value was comma terminated
	CALL	FOUT		;make a number into a string
	CALL	STRLIT		;make it a string
	MOV	BYTE PTR 0[BX],LOW " "	;put a space at the end
	POPF	
	POP	BX
	POP	CX		;restore [CH]=width, [CL]=last comma column
	PUSH	CX
	PUSH	BX
	MOV	BX,WORD PTR FACLO	;[BX]=address of string descriptor
	JNZ	INCLEN		;BRIF not comma terminated(print the space too)
	CALL	PTRGPS		;[AL]=file's current position
	ADD	AL,BYTE PTR 0[BX]	;add length of string we will output
;At this point we have [AL]=posn after number is printed(without space),
;  [CH]=device width, [CL]=last comma posn, [BX]=addr of string descriptor.
;IF number output stops at comma column minus one
;THEN don't append blank(This insures that another number will appear at the
;next comma column, instead of the second column posn after this string)
	CMP	CH,LOW 255D	;infinite width?
	JZ	MODCOM		;do modulus to determine next comma column
	CMP	AL,CL		;compare with last comma column
	JNB	INCLEN		;Will do CR after do output,
				; make string include blank
;Determine if posn in [AL] is one less than a comma column
MODCOM:	INC	AL
MODCM1:	SUB	AL,LOW OFFSET CLMWID	;[AL]=modulus CLMWID
	JA	MODCM1
	JZ	STRDON		;BRIF at comma column, exclude trailing space
INCLEN:	INC	WORD PTR 0[BX]	;increment the length to include the space
				;NOTE:number is less than 255(can do INC)
STRDON:	POP	BX
	POP	CX
	PUSH	CX		;refresh [CH]=width, [CL]=last comma column
	PUSH	BX
	MOV	BX,WORD PTR FACLO	;BX points to string descriptor
	INC	CH
	JZ	LINCH2		;branch if infinite (255) line width
	DEC	CH		;restore [CH]=device width
	CALL	PTRGPS		;[AL]=file's current column pos
	OR	AL,AL		;don't CR if string longer than line
	JZ	LINCH2		;  length if position is 0
	ADD	AL,BYTE PTR 0[BX]	;[AL]=column + string size
	CMC			;set nc if overflow on check
	JAE	LINCHK		;start on a new line if overflow
	DEC	AL
	CMP	AL,CH		;check for overlap
LINCHK:	JB	LINCH2		;branch if still on current line
	CALL	CRDO		;else output CR
LINCH2:	CALL	STRPRT		;PRINT THE string/number
	POP	BX		;restore text pointer
	JMP	NEWCHR		;print some more

;PRINT comma (text pointer stacked)
;
COMPRT:	CALL	PTRGPS		;[AL]=file's current column position
	CMP	CH,LOW 255D	;infinite width?
	JZ	MORCOM		;do modulus
	CMP	AL,CL		;compare current with last comma column
CHKCOM:	JB	MORCOM		;branch if not beyond last comma col
	CALL	CRDO		;start new line
	JMP	SHORT NOTABR	;AND QUIT IF BEYOND LAST COMMA FIELD
MORCOM:	SUB	AL,LOW OFFSET CLMWID	;[AL]=MODULUS CLMWID
	JAE	MORCOM
	NEG	AL
	DEC	AL		;fill the print position out
				;to an even CLMWID, so
				;we print CLMWID-[AL] MOD CLMWID spaces
	JMP	SHORT ASPA2	;go print [AL]+1 spaces

;PRINT TAB(N) & SPC(N)
;
TABER:	PUSH	AX		;remember IF [A]=SPCTK or TABTK
	CALL	CHRGTR
	CALL	ADRGET		;[DX]=parameter (0..65535)
	POP	AX		;see if its SPC or TAB
	PUSH	AX
	OR	DX,DX
	JG	TBNONG		;branch if greater than 0
	MOV	DX,0		;map negative parms to 0
	JMP	SHORT SPCNDC
TBNONG:	CMP	AL,LOW OFFSET SPCTK	;if space leave alone
	JZ	SPCNDC
	DEC	DX		;offset TAB by 1
SPCNDC:	PUSH	BX		;save the text pointer
	MOV	BL,CH		;[BL]=file width
	MOV	AL,CH		;[AL]=file width
	INC	AL		;test for width of 255 (no folding)
	JZ	LNOMOD		;if so, don't mod
	MOV	BH,LOW 0	;MOD out by line length
	CALL	IMOD		;[BX]=[DX] MOD filewidth
	XCHG	DX,BX		;set [DL] = position to go to
LNOMOD:	POP	BX		;get back the text pointer
	CALL	SYNCHR
	DB	OFFSET ")"
	DEC	BX
	POP	AX		;get back SPCTK or TABTK
	SUB	AL,LOW OFFSET SPCTK	;was it SPCTK?
	PUSH	BX		;save the text pointer
	JZ	DOSIZT		;value in [AL]
	CALL	PTRGPS		;[AL]=file position
DOSIZT:	NEG	AL		;print [E]-[A] spaces
	DEC	AL
	ADD	AL,DL
	JB	ASPA2		;print if past current
	INC	AL
	JZ	NOTABR		;do nothing if at current
	CALL	CRDO		;go to a new line
	MOV	AL,DL		;get the position to go to
	DEC	AL
	JS	NOTABR
ASPA2:	INC	AL
ASPAC:	MOV	DL,AL		;[B]=number of spaces to print
	MOV	AL,LOW " "	;[A]=space
REPOUT:	CALL	OUTDO		;PRINT [AL]
	DEC	DL		;decrement the count
	JNZ	REPOUT
NOTABR:	POP	BX		;pick up text pointer
	CALL	CHRGTR		;and the next character
	JMP	PRINTC		;and since we just printed
				;spaces, don't call crdo
				;if it's the end of the line

	SUBTTL EOF, LOC, LOF  Functions

	PUBLIC	EOF,LOC,LOF
	EXTRN	CONINT:NEAR

; EOF(n) Function - returns -1 if eof, else 0
; Entry - [FAC] = file number
; Exit  - [FAC] = -1 if EOF, else 0.
;
EOF:	CALL	FACFPT		;[SI] points to FDB for file [FAC]
	JZ	ERFNO4		;error if file not opened
	XOR	BX,BX		;BX=0 (assume not at eof)
	TEST	BYTE PTR F_FLGS[SI],LOW OFFSET FL_BKC
	JNZ	GFUNX		;if character backed up, no eof
	DEC	BX		;[BX]=-1 (EOF true)
	CMP	BYTE PTR F_ORCT[SI],LOW 0
	JE	GFUNX		;branch if FDB EOF flag set
	MOV	AH,LOW OFFSET G_EOF	;End of file function
	CALL	SIDSP
	JMP	SHORT GFUNX	;return result in FAC

ERFNO4:	JMP	DERFNO		;file not open error

; LOC(n) Function
; Entry - [FAC] = file number
; Exit  - [FAC] = current record number
;
LOC:	MOV	AH,LOW OFFSET G_LOC	;LOC function
GENFUN:	CALL	FACDSP		;[BX]=EOF(file [FAC])
GFUNX:	JMP	MAKINT		;return result in FAC

; LOF(n) Function
; Entry - [FAC] = file number
; Exit  - [FAC] = length of file in bytes
;
LOF:	MOV	AH,LOW OFFSET G_LOF	;LOF Function
	JMP	FACDSP		;[FAC]=LOF(file [FAC])

	SUBTTL GET/PUT - Random disk I/O Statements

	PUBLIC	DPUTG

;Syntax - GET fn [,recnum]   (if no recnum next relative record assumed)
;         PUT fn [,recnum]
; Entry - [BX] = text pointer
;         [CX] = 0 for GET, 1 for PUT
;
DPUTG:
	PUSH	CX		;save GET/PUT Flag
	CALL	POFNUM		;[AL]=file number
	CALL	FDBPTR		;[SI] points to File Data Block of file [AL]
	JZ	ERFNO3		;branch if file not open
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_RND
	JNE	ERBFM1		;Not random - bad file mode
	PUSH	SI		;save FDB pointer
	DEC	BX
	CALL	CHRGTR		;reget next character
	JZ	RELRND		;branch if end-of-statement (relative record)
	CALL	SYNCHR
	DB	OFFSET 54O	;parse required comma
	CALL	ADRGET		;[DX]=record number (0..65535)
	POP	SI		;restore FDB pointer
	POP	AX		;restore GET/PUT flag
	ADD	AX,2		;[AX]=2 for GET [DX], 3 for PUT [DX]
	JMP	SHORT RELRN1
RELRND:	POP	SI		;restore FDB pointer
	POP	AX
RELRN1:	PUSH	BX		;save text pointer
				;[AL]=0,1,2,3 for GET PUT GETrel PUTrel
	MOV	AH,LOW OFFSET G_RND	;select Random I/O function code
	CALL	SIDSP		;dispatch to routine for FDB SI
	POP	BX		;restore text pointer
	RET	

ERBFM1:	JMP	DERBFM

	SUBTTL Misc. Parsing Routines

;POFNUM - Parse optional file number "[#]n"
; Entry - [BX] = text pointer
; Exit  - [BX] = updated text pointer, [AL]=file number
;         All other registers preserved
;
POFNUM:	CMP	BYTE PTR 0[BX],LOW "#"	;[AL]=current character
	JNZ	GETNZB		;branch if optional # not included

;PRFNUM - Parse required file number "#n"
; Entry - [BX] = text pointer
; Exit  - [BX] = updated text pointer, [AL]=file number
;         All other registers preserved
;
PRFNUM:	CALL	SYNCHR
	DB	OFFSET "#"

;GETNZB - Parse byte (1..255) expression, returning result in [AL]
; Entry - [BX] = text pointer
; Exit  - [BX] = updated text pointer, [AL]=byte parsed
;         All other registers preserved
;
GETNZB:	PUSH	DX
	PUSH	CX
	CALL	GETBYT		;[AL]=file number
	OR	AL,AL
	JZ	ERBFN1		;bad file number if 0
	POP	CX
	POP	DX
RET9:	RET	

ERBFN1:	JMP	DERBFN		;bad file number

	PUBLIC	FILINP,FILGET,GETPTR,FILSET,FILSCN
FILINP:	MOV	CL,LOW OFFSET MD_SQI	;MUST BE SEQUENTIAL INPUT
FILGET:	CMP	AL,LOW "#"	;NUMBER SIGN THERE?
	JNZ	RET9		;NO, NOT FILE INPUT
	PUSH	CX		;SAVE EXPECTED MODE
	CALL	FILSCN		;READ AND GET POINTER
	JZ	ERFNO3		;ERROR IF FILE NOT OPEN
	POP	DX		;[DL]=FILE MODE
	CMP	AL,DL		;IS IT RIGHT?
	JZ	GDFILM		;GOOD FILE MODE
	CMP	AL,LOW OFFSET MD_RND	;ALLOW STUFF WITH RANDOM FILES
	JNZ	ERBFM3		;IF NOT, "BAD FILE MODE"
GDFILM:
	CALL	SYNCHR
	DB	OFFSET 54O	;GO PAST THE COMMA
FILSET:	MOV	DX,CX		;SETUP PTRFIL
	MOV	WORD PTR PTRFIL,CX
	RET	

ERBFM3:	JMP	DERBFM
ERFNO3:	JMP	DERFNO


;FILSCN - parse file number
; Entry - [BX]=text pointer
; Exit  - [DL]=file number, [SI], [CX] point to file data block for file [DL]
;         [AL]=file mode, FLAGS.Z is set if file is not open.
;         note - if file is not open, no FDB exists
;
FILSCN:	CALL	POFNUM		;[AL]=file number

FILIDX:	MOV	DL,AL		;return file number in [DL]
FILID2:	CALL	FDBPTR		;SI points to FDB for file [AL]
	JZ	NTOPEN		;branch if file is not open
	MOV	CX,SI		;CX  points to FDB
	MOV	AL,BYTE PTR F_MODE[SI]	;[AL]=file mode
	OR	AL,AL		;set non-zero (file is opened)
NTOPEN:	RET	

;GETPTR IS CALLED FROM VARPTR(#<EXPRESSION>)
; Entry - [AL]=file number
; Exit  - [DX] points to random file buffer, or sector buffer of file
;
GETPTR:	CALL	FDBPTR		;SI points to File Data Block
	JZ	ERFNO3		;error if file not open
	MOV	DX,OFFSET F_MODE	;Return pointer to MODE
	ADD	DX,SI		;Return result in [DX]
	RET	

;DIRDO is called to make sure direct statement is not found when loading file
; If device is keyboard, control transfers to GONE with AX used.
;
	PUBLIC	DIRDO
DIRDO:	MOV	AX,WORD PTR PTRFIL
	OR	AX,AX
	JNZ	ERFDR		;if device not keyboard then
				;   error(direct statement in file)
EXTRN	GONE:NEAR
	JMP	GONE		;else OK

ERFDR:	JMP	DERFDR

;ADRGET - parse 16 bit expression
; Entry - [BX]=text pointer
; Exit  - [DX]=result (0..65535)
;         [BX]=updated text pointer
;         AX used, other registers preserved.
;
	PUBLIC	ADRGET
ADRGET:	PUSH	CX
EXTRN	FRMEVL:NEAR
	CALL	FRMEVL
	PUSH	BX
EXTRN	FRQINT:NEAR
	CALL	FRQINT		;Make Unsigned 16 bits
	POP	DX
	XCHG	BX,DX		;Offset in [DX], text pointer in [BX]
	POP	CX
	RET	

	SUBTTL Major I/O Routines

;PRGFIL is called to open file #0 (SAVE/LOAD/MERGE etc.)
; Entry - [BX]=text pointer, pointing at filename
;         [DH]=file mode
; Exit  - [PTRFIL] points to files FDB (directing all future I/O to file)
;         [BX]=[TEMP]=updated text pointer
;         SI may be destroyed.
;
	PUBLIC	PRGFIL
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	TEMP:WORD
DSEG	ENDS
PRGFIL:	MOV	BYTE PTR FILMOD,DH	;save file mode (MD.SQI / MD.SQO)
	CALL	NAMSCN		;scan filename
	MOV	WORD PTR TEMP,BX	;PRGFIN restores text pointer when done
	JB	PRGFIX		;Exit - "." found in name
	CALL	NAMBAS		;Add ".BAS" extension to disk file names
PRGFIX:	JMP	SHORT NULOPN	;open file #0

;NAMBAS is called to add the ".BAS" extension to disk file names
;Entry - FILDEV points to device id
;Exit  - SI destroyed
;
NAMBAS:	MOV	SI,OFFSET FILDEV	;SI points to device id
	TEST	BYTE PTR 0[SI],LOW 377O
	JS	NAMBAX		;Exit if device is not DISK
	ADD	SI,9D		;SI points to Extention
	CMP	BYTE PTR 0[SI],LOW " "	;if blank extention, default to ".BAS"
	JNE	NAMBAX		;Exit if device is not DISK
	MOV	WORD PTR 0[SI],OFFSET (400O*"A")+"B"
	MOV	BYTE PTR 2[SI],LOW "S"
NAMBAX:	RET	

;NULOPN opens File 0 with mode [AL].
; Exit  - [PTRFIL] points to files FDB (directing all future I/O to file)
;
	PUBLIC	NULOPM
NULOPM:	MOV	BYTE PTR FILMOD,AL	;FILMOD=file mode
NULOPN:	XOR	AL,AL		;[AL]=file number
	XOR	CX,CX		;random record length = 0
				;fall into OPNFIL

;OPNFIL - general file-open routine
; Entry - [AL]=file number (0..n)
;         [CX]=record length (0=default)
;         [FILMOD]=mode (MD.SQI / MD.SQO / MD.RND / MD.APP)
;         [FILDEV]=device id
;         [FILNM]=filename
;         [FILEXT]=1..3 byte filename extension
; Exit  - [PTRFIL] points to files FDB (directing all future I/O to file)
;         all registers preserved
;
OPNFIL:	PUSHF	
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	MOV	BL,AL
	MOV	BH,LOW 0	;[BX]=file number
	CALL	FDBPTR		;see if file is already open
	JNZ	ERFAO1		;error if already open
	MOV	AL,BYTE PTR FILDEV	;[AL]=device id
	CALL	CDEVID		;[DI]=device dispatch table offset (AL)
	MOV	AH,LOW OFFSET G_OPN	;open function code (AL is still DEVICE ID)
	CALL	TBLDSP		;call device-dependent open routine
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	POPF	
	RET	

FCERR3:	JMP	FCERR
ERFAO1:	JMP	DERFAO		;file already opened error

;CLSALL - close all opened files
; Entry - none
; Exit  - All registers preserved
;
	PUBLIC	CLSALL
CLSALL:	PUSH	AX
	PUSH	SI
	MOV	SI,WORD PTR FILTAB	;Get address of next file block
CLSAL1:	CMP	SI,WORD PTR STKLOW
	JZ	CLSALX		;Branch if finished
	PUSH	WORD PTR F_NEXT[SI]	;save pointer to next entry in chain
	MOV	AL,BYTE PTR F_NUM[SI]	;[AL]=file number
	CALL	CLSFIL		;Close file [AL]
	POP	SI		;SI points to next FDB in chain
	JMP	SHORT CLSAL1	;Keep looping till all files closed
CLSALX:	POP	SI
	POP	AX
	RET	

;CLSFIL - close file [AL]
; Exit  - Flags, AX, SI used, all other registers are preserved
;
	PUBLIC	CLSFIL
CLSFIL:	MOV	AH,BYTE PTR NLONLY
	TEST	AH,LOW 200O	;see if Chain All / Load, R in progress
	JNZ	RET22		;branch if Dont-Close-Any-Files flag set
	TEST	AH,LOW 1	;see if Load/Merge/Chain is in progress
	JZ	CLSFL1		;branch if Dont-Close-File-0 flag not set
	OR	AL,AL
	JZ	RET22		;branch if trying to close file 0
CLSFL1:	CALL	FDBPTR		;[SI] points to FDB [AL]
	JZ	RET22		;branch if file already closed
	PUSH	BX
	PUSH	CX
	PUSH	DX
	MOV	WORD PTR FREFDB,SI	;So FINPRT will force close file if low-level
				;close routine gets I/O error
	MOV	AH,LOW OFFSET G_CLS
	CALL	SIDSP		;close FDB pointed to by [SI]
	MOV	WORD PTR FREFDB,0
	CALL	FFREE		;Deallocate FDB and remove from FDB Chain
	POP	DX
	POP	CX
	POP	BX
RET22:	RET	

;INCHR - get next byte from file PTRFIL
; Exit  - [AL]=byte, [FLAGS], [AH] destroyed.
;         All other regs preserved
;         if END-OF-FILE then
;            if program load was in progress, file 0 closed etc.
;            else Read-Past-End error is generated
;
	PUBLIC	INCHR
	EXTRN	PRGFIN:NEAR,KYBSIN:NEAR
INCHR:
	PUSH	SI
	CALL	INCHRE		;[AL]=next byte from PTRFIL, carry if EOF
	JAE	INCHRX		;branch if not EOF
	CMP	BYTE PTR F_NUM[SI],LOW 0	;EOF on ASCII file #0 = end of Load/Chain/Merge
	JE	FL0EOF		;branch if EOF reached for file #0
EXTRN	DERRPE:NEAR
	JMP	DERRPE		;Input past end error
FL0EOF:	CMP	BYTE PTR F_CODE[SI],LOW OFFSET FC_BIN
	JNE	LDREOF		;branch if not binary file (must be ascii LOAD)
	STC			;else must be BLOAD/binary LOAD
	RET			;return EOF indication to caller
LDREOF:
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CHNFLG:WORD
DSEG	ENDS
	EXTRN	CHNRET:NEAR
	CMP	BYTE PTR CHNFLG,LOW 0	;chain in progress?
	JE	NOTCHN		;branch if not chaining
	JMP	CHNRET		;perform variable block transfer, etc.
				; close all files
NOTCHN:
	PUSH	BX		;save all registers
	PUSH	CX
	PUSH	DX
	MOV	AL,BYTE PTR NLONLY	;get load flags
	AND	AL,LOW 200O	;leave others open, null gets closed
	MOV	BYTE PTR NLONLY,AL	;allow other files to be closed
	CALL	PRGFIN		;close the file
	POP	DX
	POP	CX
	POP	BX
	MOV	AL,BYTE PTR RUNFLG	;run it or not?
	OR	AL,AL
	JZ	NORUNC		;dont run program
	EXTRN	RUNC:NEAR
	CALL	RUNC		;run it
	EXTRN	NEWSTT:NEAR
	JMP	NEWSTT
NORUNC:	PUSH	BX
	PUSH	CX
	PUSH	DX
	EXTRN	REDDY:NEAR,STROUT:NEAR
	MOV	BX,OFFSET REDDY	;print prompt "ok"
	CALL	STROUT
	POP	DX
	POP	CX
	POP	BX
	MOV	AL,LOW 13D
INCHRX:	POP	SI
	RET	

;INCHRE - get next byte from file PTRFIL.
; Exit  - Carry set if EOF, else [AL]=byte.
;         SI points to FDB
;         All other regs preserved
;
	PUBLIC	INDSKC		;Referenced by DSKCOM
INDSKC:
INCHRE:	MOV	SI,WORD PTR PTRFIL	;SI points to current FDB
				;fall into INCHSI

;INCHSI - get next byte from file SI (CTL Z = end-of-file)
; Exit  - Carry set if EOF, else [AL]=byte.
;         All other regs preserved
;
	PUBLIC	INCHSI
INCHSI:	INC	SI
	JZ	ERBFM6		;branch if Line Printer (can't input)
	DEC	SI
	JNZ	INGFDB		;branch if not Keyboard (got FDB)
	EXTRN	INCHRI:NEAR
	JMP	INCHRI
INGFDB:	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQO
	JZ	ERBFM6
	CMP	BYTE PTR F_ORCT[SI],LOW 0
	JZ	INCEOF		;branch if EOF already reached
	TEST	BYTE PTR F_FLGS[SI],LOW OFFSET FL_BKC
	JNZ	GETBKC		;branch if char backed up
	MOV	AH,LOW OFFSET G_SIN
	CALL	SIDSP		;[AL]=next input from file
	JB	INCEOF		;branch if device detected EOF
	RET	

INCEOF:	MOV	BYTE PTR F_ORCT[SI],LOW 0	;indicates EOF on future calls
	MOV	BYTE PTR F_BREM[SI],LOW 0
	STC			;tells caller EOF reached
	RET	

GETBKC:	AND	BYTE PTR F_FLGS[SI],LOW OFFSET 255D-FL_BKC	;clear Backup Present flag
	MOV	AL,BYTE PTR F_BAKC[SI]	;return Backed-up character
	RET			;with no carry (no-eof)

ERBFM6:	JMP	DERBFM		;bad file mode error

	PUBLIC	CRFIN,CRDONZ,FININL,CRDO
CRFIN:	XOR	AL,AL		;all references should be eliminated
	RET	

;CRDONZ - output carriage return if file PTRFIL is not at left margin
;
CRDONZ:	CALL	PTRGPS		;[AH]=0-relative column for PTRFIL
	OR	AH,AH
	JNZ	CRDO		;if not at column 0, output CRLF
	RET	

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	BUFMIN:WORD
DSEG	ENDS
FININL:	MOV	BYTE PTR 0[BX],LOW 0
	MOV	BX,OFFSET BUFMIN

;CRDO - output ascii carriage return to current file
;
CRDO:	MOV	AL,LOW OFFSET ASCCR
	CALL	OUTDO		;output Carriage Return
	MOV	AL,LOW OFFSET ASCLF	;output Line Feed
	CALL	OUTDO
	XOR	AL,AL		;must return with [AL]=0 and FLAGS.Z true
	RET	

;OUTDO - output [AL] to current file (force CR if end-of-line)
; Exit - All registers preserved (including FLAGS)
;
	PUBLIC	OUTDO,FILOU3
FILOU3:
OUTDO:
	PUSHF	
	PUSH	AX
	MOV	AH,LOW OFFSET G_SOT
	CALL	PTRDSP		;dispatch to function [DL] for PTRFIL
	POP	AX
	POPF	
	RET	

;OUT16 - output data [AX] to current file
;
OUT16:	PUSH	AX
	CALL	OUTDO		;output low-byte first
	XCHG	AH,AL
	CALL	OUTDO		;then output high-byte
	POP	AX
	RET	

;INP16 reads the next 16 bits from file PTRFIL
; Exit  - [AX]=result. Carry set if EOF.
;         All other registers are preserved.
;
INP16:	PUSH	BX
	CALL	INCHR		;get low-byte first
	MOV	BL,AL
	CALL	INCHR		;then get high-byte
	MOV	BH,AL
	MOV	AX,BX
INP16X:	POP	BX
	RET	

;BAKCHR - backup sequential input file
; Entry - [AL] = char to be backed up
;         [PTRFIL] points to FDB of file to be backed up
;
	PUBLIC	BAKCHR,BCHRSI
BAKCHR:	PUSH	SI
	MOV	SI,WORD PTR PTRFIL
	CALL	BCHRSI
	POP	SI
	RET	

;BCHRSI - backup sequential input file
; Entry - [AL] = char to be backed up
;         [SI] points to FDB of file to be backed up
;
BCHRSI:	MOV	BYTE PTR F_BAKC[SI],AL
	OR	BYTE PTR F_FLGS[SI],LOW OFFSET FL_BKC	;set flag indicating char backed up
	RET	

;BINSAV - Binary SAVE support.
;
	PUBLIC	BINSAV,BINPSV
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	TXTTAB:WORD
DSEG	ENDS
	EXTRN	PROCHK:NEAR,SCCPTR:NEAR
BINSAV:	CALL	SCCPTR		;GET RID OF POINTERS BEFORE SAVING
	CALL	PROCHK		;DONT ALLOW BINARY SAVES OF PROTECTED PROGRAMS
	CALL	SCDBIN		;Set attribute CODE to BINARY (not ASCII)
	MOV	AL,LOW 255D	;ALWAYS START WITH 255
BINPSV:	CALL	FILOU3		;SEND TO FILE
	MOV	CX,WORD PTR VARTAB	;GET STOP POINT
	MOV	BX,WORD PTR TXTTAB	;GET START POINT
	SUB	CX,BX		;Calculate bytes to SAVE
	JBE	BINSVX		;Nothing to SAVE
	MOV	DX,DS		;Get Segment for SAVE
	CALL	OUTBLK		;Write the block
BINSVX:	JMP	PRGFIN		;REGET TEXT POINTER AND CLOSE FILE 0

;DEVBIN - General device block input routine.  This routine is called by
;         device code for devices which have no block I/O capability.
; Entry - [BX] = Start adr
;         [CX] = number of bytes to read
;         [DX] = Segment adr
;         [SI] = address of FDB
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - [BX] = End+1
;         Carry set if reached end of data before CX bytes read
;         SI, CX, AX used.
;
	PUBLIC	DEVBIN
DEVBIN:	OR	CX,CX
	JZ	RET27		;Until end.
	MOV	AH,LOW OFFSET G_SIN	;sequential input function
	CALL	PTRDSP		;[AL]=next byte from file PTRFIL
	JB	RET27		;branch if tried to read past end-of-file
	PUSH	DS
	PUSH	DX
	POP	DS		;[DS]=[DX]
	MOV	BYTE PTR 0[BX],AL	;Store Byte
	POP	DS
	INC	BX		;bump destination pointer
	DEC	CX		;decrement byte count
	JMP	SHORT DEVBIN

;DEVBOT - General device block output routine.  This routine is called by
;         device code for devices which have no block I/O capability.
; Entry - [BX] = Start adr
;         [CX] = number of bytes to write
;         [DX] = segment adr
;         [SI] = address of FDB
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - [BX] = End + 1
;
	PUBLIC	DEVBOT
DEVBOT:	OR	CX,CX
	JZ	RET27		;Until Len=0.
	PUSH	DS		;save BASIC's Data Segment
	PUSH	DX
	POP	DS		;DS=DX
	MOV	AL,BYTE PTR 0[BX]
	POP	DS		;restore BASIC's Data Segment
	CALL	OUTDO		;Write Byte from Memory.
	INC	BX
	DEC	CX
	JMP	SHORT DEVBOT
RET27:	RET	

;OUTBLK - Write Block of memory to current file
; Entry - [BX] = Start adr
;         [CX] = number of bytes to write
;         [DX] = segment adr
; Exit  - [BX] = End + 1
;
OUTBLK:	MOV	SI,WORD PTR PTRFIL
	MOV	AH,LOW OFFSET G_BOT	;Block output function
	CALL	PTRDSP
	RET	

; INPBLK - Read block of memory from current file
; Entry - [BX] = Start adr
;         [CX] = number of bytes to read
;         [DX] = Segment adr
; Exit  - [BX] = End+1
;         Carry set if reached end of data before CX bytes read
;         SI, CX, AX used.
;
	EXTRN	DFSTLD:NEAR
INPBLK:	MOV	SI,WORD PTR PTRFIL
	MOV	AH,LOW OFFSET G_BIN	;block input function
	CALL	PTRDSP		;[AL]=next byte from file PTRFIL
	RET	

;FSTLOD - load Binary BASIC program (Called from DSKCOM after LOAD statement)
; Entry - BX points to destination of program
;         [FRETOP] - [BX] - ^D86 = maximum legal size of program
;         [PTRFIL] points to FDB of file to be loaded
;         (note: 1st byte of file has already been read and was ^D254)
;
	PUBLIC	FSTLOD
	EXTRN	OUTLOD:NEAR
FSTLOD:
	MOV	CX,WORD PTR FRETOP	;Bottom of string space
	SUB	CX,86D		;leave a little breathing room
	SUB	CX,BX		;[CX]=maximum legal size of program
	CALL	SCDBIN		;set CODE attribute to Binary
	PUSH	DS
	POP	DX		;[DX]=segment to be used
	CALL	INPBLK		;read block from device to disk
	JB	RET27		;branch if file fits in memory
	JMP	OUTLOD		;ERROR AND WIPE OUT PARTIAL GARBAGE

;PTRGPS - get column position for file PTRFIL
;
; Exit  - [AH] = [AL] = column position
;         FLAGS.Z is true if at column 0
;         All other registers are preserved
;
	PUBLIC	PTRGPS
PTRGPS:	MOV	AH,LOW OFFSET G_GPS	;Get column position request-code
	CALL	PTRDSP		;[AH]=position
	MOV	AL,AH		;[AL]=position
	OR	AL,AL
	RET	

;PTRWDC - get line width and last comma column for file PTRFIL
; Exit  - [CH] = line width
;         [AH] = [CL] = last comma column
;         All other registers are preserved
;
PTRWDC:	CALL	PTRWID		;[AH]=file PTRFIL's line width
	MOV	CH,AH		;[CH]=file width
PTRWDL:	SUB	AH,LOW 14D	;T.B.S. eventually, use G.GCW
	JAE	PTRWDL
	ADD	AH,LOW 28D
	NEG	AH
	ADD	AH,CH
	MOV	CL,AH		;[CL]=last comma column
	RET	

;PTRWID - get line width for file PTRFIL
; Exit  - [AH] = line width
;         All other registers are preserved
;
	PUBLIC	PTRWID
PTRWID:	PUSH	SI		;save caller's SI
	MOV	SI,WORD PTR PTRFIL
	INC	SI
	JZ	PTRWD1		;if LPT Pseudo FDB, use Device width
	DEC	SI
	JZ	PTRWD1		;if KYBD Pseudo FDB, use Device width
	MOV	AH,BYTE PTR F_WID[SI]	;else use FDB width
	POP	SI		;restore caller's SI
	RET	
PTRWD1:	POP	SI		;restore caller's SI
	MOV	AH,LOW OFFSET G_GWD	;Get file width function code
	JMP	PTRDSP		;return with [AH]=device width


	SUBTTL General routines useful to low-level device drivers

	PUBLIC	XTABCR,EXPTAB,CRIFEL,UPDPOS
;XTABCR is called by Device Driver Output routines to Expand Tabs to Spaces
;         and Force a carriage return if end-of-line.
; Entry - [AL]=char to be output
;         [DH]=current column position
;         [DL]=line width
;         BX points to raw-output routine
; Exit  - [DH] is new column position
;         FLAGS are used, All other registers are preserved.
;
XTABCR:	PUSH	CX
	MOV	CX,OFFSET CRIFEL	;EXPTAB will call CRIFEL which will
	CALL	EXPTAB		;call raw-output routine [BX]
	POP	CX
	RET	

;EXPTAB is called by Device Driver Output routines to Expand Tabs to Spaces
; Entry - [AL]=char to be output
;         [DH]=current column position
;         CX points to raw-output routine
; Exit  - [DH] is new column position
;         FLAGS are used, All other registers are preserved.
;
EXPTAB:
	CMP	AL,LOW OFFSET ASCTAB
	JNE	NOTTAB		;branch if not tab
	CMP	DL,LOW 9D
	JB	EXTABX		;branch if width is less than 9
	MOV	AL,LOW OFFSET ASCSPC	;output spaces till next tab stop
EXTABL:	CALL	CX		;output space (update position)
	TEST	DH,LOW 7
	JNZ	EXTABL		;branch if not at MOD 8 column position
	MOV	AL,LOW OFFSET ASCTAB	;restore AL
EXTABX:	RET	

NOTTAB:	JMP	CX		;output char and update position

;CRIFEL - Force a carriage return if end-of-line (Called by device out routines)
; Entry - [AL]=char to be output
;         [DH]=current column position
;         [DL]=line width
;         BX points to raw-output routine
; Exit  - [DH] is new column position
;         FLAGS are used, All other registers are preserved.
;
CRIFEL:	CMP	AL,LOW 32D
	JB	NOCR		;branch if non-printable
	CMP	DL,LOW 255D
	JZ	NOCR		;branch if infinite width (255)
	CMP	DH,DL		;compare Column with Width
	JB	NOCR		;branch if still room on current line
	PUSH	AX
	MOV	AL,LOW OFFSET ASCCR
	CALL	BX		;output Carriage Return
	MOV	AL,LOW OFFSET ASCLF	;output Line Feed
	CALL	BX
	POP	AX		;restore char to be output
NOCR:	JMP	BX		;output char, update position

;UPDPOS - update column position (called by device out routines)
; Entry - [DH] = current 0-relative column position
;         [AL] = byte to be output
; Exit  - [DH] = new column position.  All other registers preserved
;
UPDPOS:	CMP	AL,LOW 32D
	JB	NPRINT		;branch if not printable (CTL CHR)
	INC	DH		;bump column position
	RET	
NPRINT:	CMP	AL,LOW OFFSET ASCCR
	JNE	NOTCR		;branch if not carriage return
ZERPOS:	MOV	DH,LOW 0	;reset to left margin
	RET	
NOTCR:	CMP	AL,LOW OFFSET ASCBS
	JNE	UPPOSX		;branch if not backspace
	OR	DH,DH
	JE	UPPOSX		;don't decrement below 0
	DEC	DH		;decrement position
UPPOSX:	RET	

	SUBTTL File Dispatch Routines

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	IOJUMP:WORD
DSEG	ENDS

ERBFN2:	JMP	DERBFN		;bad file number error

;FACDSP - Dispatch to I/O routine for file number [FAC]
; Entry - [AH]=function code (G.OPN, G.CLS, etc.)
;         [FAC]=file number (note: file must be opened) (0 is illegal)
; Exit  - DX, AL are used.
;         All other registers preserved except those changed by device driver
;
FACDSP:	CALL	CONINT		;[DX]=integer equivalent of FAC (file#)
	OR	DX,DX
	JZ	ERBFN2		;file #0 is unavailable to user (bad file num.)

;FILDSP - Dispatch to I/O routine for file number [DH]
; Entry - [AH]=function code (G.OPN, G.CLS, etc.)
;         [DX]=file number (note: file must be opened)
; Exit  - All registers preserved except those changed by device driver
;
FILDSP:	PUSH	SI
	PUSH	AX
	OR	DH,DH
	JNZ	FCERR9		;error if file# greater than 255
	MOV	AL,DL		;[AL]=file number
	CALL	FDBPTR		;(SI) = file data block pointer
	JZ	ERFNO2		;Error - bad file number
	POP	AX		;restore caller's [AX]
	CALL	SIDSP
	POP	SI
	RET	

FCERR9:	JMP	FCERR		;Function Call Error

;PTRDSP - Dispatch to I/O routine for file with FDB=[PTRFIL]
; Entry - [AH]=function code (G.OPN, G.CLS, etc.)
;         [PTRFIL]=points to file's FDB
; Exit  - All registers preserved except those changed by device driver
;
	PUBLIC	PTRDSP
PTRDSP:	PUSH	SI
	MOV	SI,WORD PTR PTRFIL
	CALL	SIDSP
	POP	SI
	RET	

;SIDSP - Dispatch to I/O routine for file with FDB=[SI]
; Entry - [AH]=function code (G.OPN, G.CLS, etc.)
;         [SI]=points to file's FDB
; Exit  - All registers preserved except those changed by device driver
;
SIDSP:	PUSH	DI
	PUSH	SI
	PUSH	AX
	PUSHF	
	INC	SI
	JZ	LPDSP		;branch if Line Printer Pseudo FDB
	DEC	SI
	JNZ	SIDSP1		;branch if not Keyboard/CRT Pseudo FDB
;        MOVI    DI,$CODE+2*<^O400-$.KYBD>
	MOV	DI,OFFSET $_KYBD
	NEG	DI		; Change neg. dev. # to 0 based offset
	AND	DI,377O
	SHL	DI,1		; ASM86 cann't multiply externals by 2
	JMP	SHORT SIDSP2
LPDSP:
;        MOVI    DI,$CODE+2*<^O400-$.LPT1>   ;SI=0
	MOV	DI,OFFSET $_LPT1
	NEG	DI		; Change neg. dev. # to 0 based offset
	AND	DI,377O
	SHL	DI,1		; ASM86 cann't multiply externals by 2
	JMP	SHORT SIDSP2
SIDSP1:	MOV	AL,BYTE PTR F_DEV[SI]	;(AL) = device number
	CALL	CDEVID		;[DI]=device dispatch table offset
SIDSP2:	POPF	
	POP	AX		;restore caller's [AX]
	CALL	TBLDSP		;function [AH] on device [DI]
	POP	SI
	POP	DI
	RET	

;TBLDSP - Dispatch to I/O routine for device-table [DI]
; Entry - [AH]=function code (G.OPN, G.CLS, etc.)
;         DI = -2 * device id (0=disk, 2=keyboard etc.)
; Exit  - All registers preserved except those changed by device driver
;
TBLDSP:	PUSH	DI
	PUSHF	
	PUSH	AX
	MOV	AX,WORD PTR DEVPTR	;AX points to 1st entry in dispatch table
	ADD	DI,AX		;DI points to dispatch table pointer for device
	MOV	DI,WORD PTR CS:0[DI]	;DI points to dispatch table for device
	OR	DI,DI		;If entry is 0, then
	JZ	ERDNA2		;  Error - device not available
	POP	AX		;restore function code
	PUSH	AX
	XCHG	AH,AL
	CBW			;[AX]=function code
	ADD	DI,AX		;Add function code offset to dispatch
	MOV	AX,WORD PTR CS:0[DI]	;Get address of routine
	MOV	WORD PTR IOJUMP,AX
	POP	AX
	POPF	
	POP	DI
	JMP	 WORD PTR IOJUMP	;jump to routine at address [IOJUMP]

;CDEVID - convert device id to dispatch table address
; Entry - [AL]=device id (0..n for disk, -1..-n for non-disk devices)
; Exit  - [DI]=DEVPTR offset for device (0 for disk, 2 for KYBD, etc.)
;         FLAGS.Z is true if device=disk
;         All other registers are preserved.
;
CDEVID:	PUSH	AX
	OR	AL,AL
	JS	CDEV1		;must be a special device
	XOR	AL,AL		;(AL) = 0 for disks
	JMP	SHORT CDEV2
CDEV1:	NEG	AL		;(AL) = - device number for special
CDEV2:	PUSHF			;save Z=disk
	CBW			;[AX]=device number
	ADD	AX,AX		; * 2
	MOV	DI,AX
	POPF			;restore Z=disk
	POP	AX
	RET	

ERFNO2:	JMP	DERFNO		;file not opened error

ERDNA2:	JMP	DERDNA		;device not available error

	SUBTTL NAMSCN, PARDEV - Device/Filename scanning routines

	EXTRN	FOPTSZ:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FILOPT:WORD
DSEG	ENDS

;T.B.S. - FOPTSZ should eventually be used instead of CMPI CX,^D64, but
; the DEC-Macros don't permit this.

;NAMSCN - parse file-specification [dev:]filename[.extension]
; Entry - [BX] = text pointer
; Exit  - [FILDEV] = 0 if default device,
;                    (1..n) if device=(A:, B:, ...)
;                    (-1..-n) for DEVTBL entry (1..n)
;         [FILNM] = filename
;         [FILEXT] = extention
;         [BX] = updated text pointer
;         [AL]=next character
;         FLAGS.CARRY is set if "." scanned
;         DX is used.
;         All other registers preserved
;
	PUBLIC	NAMSCN
NAMSCN:	CALL	FRMEVL

NAMSC1:	PUSH	BX		;save text pointer
	CALL	FRESTR		;release string descriptor
				;[BX] points to string descriptor
	MOV	CL,BYTE PTR 0[BX]
	MOV	CH,LOW 0	;[CX]=length of string
	MOV	SI,WORD PTR 1[BX]	;SI points to start of string
	CALL	PARDEV		;(AL) = device #
	MOV	BYTE PTR FILDEV,AL	;Save device #
	OR	AL,AL
	JS	NOTDSK		;branch if special device
	XOR	AL,AL		;(AL) = 0 for disks
NOTDSK:	PUSH	AX
	PUSH	DX
	PUSH	DI
	OR	AL,AL
	PUSHF			;save NC - indicates "." not scanned
	MOV	DI,OFFSET FILNM
	MOV	DX,OFFSET FNAML	;filename length
	JNS	SCAN1		;If disk device, put name in FILNM

; This code copies Device Dependent Options to FILOPT which is a
; buffer scanned by device drivers at device open time.
;
	MOV	DI,OFFSET FILOPT
	JCXZ	SCOM1		;Will copy 1 to
	CMP	CX,64D		;compare with option buffer size
	JAE	ERIFN1		;"Bad File Name" if too long
	CLD			;set Post-Increment mode
                             ;Copy string to FILNM
 REP	MOVSB
SCOM1:
	MOV	BYTE PTR 0[DI],CL	;Terminate option string with 0
	JMP	SHORT SCNAM3

SCAN1:	JCXZ	FILSPC		;End of string
	DEC	CX
	CLD			;set Post-Increment mode
	LODSB			;Get filename character
	CMP	AL,LOW "*"	;filename can't have wildcard chars
	JE	ERIFN1
	CMP	AL,LOW "?"
	JE	ERIFN1
	CMP	AL,LOW " "
	JAE	SCNAM2

ERIFN1:	JMP	DERIFN		;Illegal file name error

SCNAM2:	CMP	AL,LOW "."
	JE	FILLNM
	CLD			;set Post-Increment mode
	STOSB			;Store character
	DEC	DX
	JNZ	SCAN1		;Keep looking for characters

SCNAM3:	POPF	
	POP	DI
	POP	DX
	POP	AX
	POP	BX		;restore updated text pointer
	RET	

FILLNM:	POPF	
	STC			;set carry indicating "." scanned
	PUSHF	
FILNM0:	CMP	DX,OFFSET FNAML	;file name length
	JE	ERIFN1		;Error - extension only !
	CMP	DX,3
	JB	ERIFN1		;Error - 2nd dot
	JE	SCAN1		;Scan extension like filename
	MOV	AL,LOW " "
	CLD			;set Post-Increment mode
	STOSB			;Fill with blank
	DEC	DX
	JMP	SHORT FILNM0	;Keep filling

FILSPC:	MOV	AL,LOW " "	;Fill short name with spaces
	CLD			;set Post-Increment mode
	STOSB
	DEC	DX
	JNZ	FILSPC		;Keep filling
	JMP	SHORT SCNAM3	;Done with name

;PARDEV - Parse device name from string
; Entry - (CX) = length of string
;         (SI) = string address
; EXIT  - (AL) = device # (0 = default , - = special)
;         (CX) = remaining count
;         (SI) = address of remaining string

PARDEV:
	PUSH	DX
	PUSH	DI
	PUSH	SI
	MOV	DX,CX		;(DX) = original length
	OR	DX,DX		;test for zero length
	JZ	NODVNM		;If length = 0 , no device name
DEVSCN:	CLD			;set Post-Increment mode
	LODSB			;Get character
	CMP	AL,LOW ":"
	JE	DEVNM		;Found possible name
	LOOP	DEVSCN

NODVNM:	MOV	CX,DX		;No device name - restore everything
	POP	SI
	POP	DI
	POP	DX
	XOR	AL,AL		;Default device to 0
	RET	

DEVNM:	POP	DI		;Restore old string pointer
	XCHG	SI,DI
	PUSH	DI		;Save new string pointer
	SUB	DX,CX		;(DX) = device name length
	JZ	ERIFN2		;Length = 0 - illegal file name
	DEC	CX		;Count off :
	CMP	DX,1
	JE	DSKNAM		;Length = 1 - must be disk name

	MOV	DI,WORD PTR DEVTBL
	DEC	DI
DEVSRC:	PUSH	SI
	PUSH	DX

DEVLOP:	INC	DI
	CLD			;set Post-Increment mode
	LODSB
	CALL	UPCASE		;Convert to upper case
	TEST	BYTE PTR CS:0[DI],LOW 200O	;Check to see if at device (long name)
	JNZ	NMTCH2
	CMP	BYTE PTR CS:0[DI],AL
	JNE	NOMTCH
	DEC	DX
	JNZ	DEVLOP

FNDDEV:	INC	DI
	MOV	AL,BYTE PTR CS:0[DI]	;Get device #
	OR	AL,AL
	JNS	NOMTCH		;Not a device #

	POP	SI
	POP	SI
DEVRET:	POP	SI		;(SI) = pointer after :
	POP	DI
	POP	DX
	RET			;(CX) = chars left , (AL) = device #

NMTCH1:	INC	DI
NOMTCH:
	TEST	BYTE PTR CS:0[DI],LOW 200O	;Check for device #
	JZ	NMTCH1		;  No
NMTCH2:	POP	DX
	POP	SI
	CMP	BYTE PTR CS:1[DI],LOW 0	;End of table?
	JNE	DEVSRC		;  No - check next entry

ERIFN2:	JMP	DERIFN		;Error - bad filename (device name)

DSKNAM:
	CLD			;set Post-Increment mode
	LODSB			;Refetch character
	CALL	UPCASE
	SUB	AL,LOW OFFSET "A"-1	;Convert letter to 1-26 (let @ be 0)
	JB	ERIFN2		;  Less than @
	CMP	AL,LOW OFFSET "Z" AND 37O
	JAE	ERIFN2		;  Greater than Z
	JMP	SHORT DEVRET

UPCASE:	CMP	AL,LOW "a"	;Convert (AL) to upper case
	JB	UPRET
	CMP	AL,LOW "z"
	JA	UPRET
	AND	AL,LOW OFFSET 255D-" "
UPRET:	RET	

	SUBTTL File Data Block Management Routines

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	VARTAB:WORD,ARYTAB:WORD,MEMSIZ:WORD,FRETOP:WORD,SAVFRE:WORD
	EXTRN	FILTAB:WORD,STREND:WORD
DSEG	ENDS
	EXTRN	ERROM:NEAR,ERROR:NEAR
	EXTRN	SKPNAM:NEAR,GARBA2:NEAR
;INIFDB - Special device open common routine
; Allocates, initializes and links new FDB into FDB Chain.
; Entry - (AL) = file device
;         (AH) = valid file modes
;         (CX) = buffer size (not including basic FDB size)
;         (DL) = file width
;         (DH) = initial file position
;         (BX) = file number
; Exit -  SI points to new File Data Block
;         [PTRFIL] points to new FDB
;         All other registers preserved.
;
	PUBLIC	INIFDB
INIFDB:	PUSH	CX
	PUSH	DI
	TEST	BYTE PTR FILMOD,AH	;Check for valid file mode
	JZ	ERBFM4		;  Bad file mode
	ADD	CX,OFFSET FDBSIZ	;(CX) = size of block to allocate
	CALL	FALLOC		;SI points to Allocated block
	MOV	WORD PTR PTRFIL,SI
	MOV	BYTE PTR F_NUM[SI],BL	;Set file number
	MOV	BYTE PTR F_DEV[SI],AL	;Set file device
	MOV	BYTE PTR F_FLGS[SI],LOW 0
	MOV	BYTE PTR F_CODE[SI],LOW OFFSET FC_ASC	;default file-code to ASCII
	MOV	CL,BYTE PTR FILMOD
	MOV	BYTE PTR F_MODE[SI],CL	;Set file mode
	MOV	BYTE PTR F_WID[SI],DL	;Set file width
	MOV	BYTE PTR F_POS[SI],DH	;Set file position
	MOV	BYTE PTR F_ORCT[SI],LOW 1	;indicates not at EOF
	POP	DI
	POP	CX
	RET	

ERBFM4:	JMP	DERBFM		;Bad file mode

;SCDASC - Set file-attribute CODE for file PTRFIL to ASCII
; Exit  - all registers preserved.
;
	PUBLIC	SCDASC
SCDASC:	PUSH	SI
	MOV	SI,WORD PTR PTRFIL
	MOV	BYTE PTR F_CODE[SI],LOW OFFSET FC_ASC
	POP	SI
	RET	

;SCDBIN - Set file-attribute CODE for file PTRFIL to binary
; Exit  - all registers preserved.
;
	PUBLIC	SCDBIN
SCDBIN:	PUSH	SI
	MOV	SI,WORD PTR PTRFIL
	MOV	BYTE PTR F_CODE[SI],LOW OFFSET FC_BIN
	POP	SI
	RET	

;FDBPTR - Transform file number into File-Data-Block pointer
; Entry - [FAC] = file number (0..n)
; Exit  - if File-Data-Block is allocated,
;            SI points to 1st byte of File-Data-Block
;         else FLAGS.Z is true
;         DX, AX are used
;
FACFPT:	CALL	CONINT		;[AL] = file number
				;fall into FDBPTR

;FDBPTR - Transform file number into File-Data-Block pointer
; Entry - [AL] = file number (0..n)
; Exit  - if File-Data-Block is allocated,
;            SI points to 1st byte of File-Data-Block
;         else FLAGS.Z is true
;         All other registers are preserved
;
FDBPTR:	MOV	SI,WORD PTR FILTAB	;[SI] points to 1st file-data-block
GPTRL:	CMP	SI,WORD PTR STKLOW	;compare with nil FDB pointer
	JZ	GPTRX		;branch if at end of FDB chain
	CMP	AL,BYTE PTR F_NUM[SI]
	JZ	GPTRF		;branch if found FDB
	MOV	SI,WORD PTR F_NEXT[SI]	;advance to next FDB in chain
	JMP	SHORT GPTRL
GPTRF:	OR	SI,SI		;set NZ - indicates FDB found
GPTRX:	RET	

;FALLOC(nbytes) {allocate file-data-block and link into chain}
; Entry - CX=size of FDB
; Exit  - SI points to new FDB (which is already linked into FDB chain)
;         SI, DI used.
;
;  if FRETOP-STREND .LEQ. nbytes then
;    perform major string garbage collection
;    if FRETOP-STREND is still .LEQ. nbytes then deverr(Out-of-memory)
;  temp = FILTAB;
;  xfrstr(FILTAB,-nbytes); {move string space down nbytes}
;  FILTAB.F.NEXT := temp; {link new FDB into chain}
;  return FILTAB;
;
FALLOC:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSHF	
	MOV	AX,CX		;[AX]=size of new FDB
	MOV	DL,LOW 1	;Indicates 1st attempt to find space
FALC1:	MOV	BX,WORD PTR FRETOP	;BX points to top of free string space
	SUB	BX,WORD PTR STREND	;BX=number of bytes free - 1
	CMP	AX,BX		;compare with requested amount
	JB	FALCOK		;branch if its available
	DEC	DL
	JZ	FAPAS1		;branch if 1st attempt
	MOV	DL,LOW OFFSET ERROM	;else give Out of Memory error
	JMP	ERROR
FAPAS1:	PUSH	AX
	PUSH	DX
	CALL	GARBA2		;perform major garbage collection
	POP	DX
	POP	AX
	JMP	SHORT FALC1	;now that its compressed, try again

FALCOK:	NEG	AX		;indicates moving strings down
	MOV	SI,WORD PTR FILTAB	;SI points to lowest FDB in chain
	PUSH	SI		;save for link
	CALL	XFRSTR		;move string space
	POP	BX
	MOV	SI,WORD PTR FILTAB	;SI points to new FDB
	MOV	WORD PTR F_NEXT[SI],BX	;link FDB into chain

	PUBLIC	PDCBAX,PCBAX,PBAX	;generally useful routines
PFDCBA:	POPF	
PDCBAX:	POP	DX
PCBAX:	POP	CX
PBAX:	POP	BX
	POP	AX
	RET	


;FFREE(fdbptr) {free file data block}
;              {ffree is called by clsfil only}
; Entry - SI points to FDB to be freed
; Exit  - SI, DI Used
;
;  fdbptr points to low byte of freed file-data-block
;  remove fdbptr from chain of file-data-blocks (FILTAB)
;  nbytes := size of freed file-data-block.
;  xfrstr(fdbptr, nbytes); {move string space and lower-FDB's up nbytes}
;
FFREE:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSHF	
	MOV	AX,WORD PTR F_NEXT[SI]	;AX points to next FDB in chain
	SUB	AX,SI		;AX = size of FDB being freed
	MOV	BX,WORD PTR FILTAB	;BX points to 1st FDB in chain
FFNDL:	CMP	BX,SI		;see if this is the one being freed
	JE	FFOUND		;branch if it is
	JB	STILOK		;branch if still less than expected
BADFDB:	JMP	SHORT BADFDB	;better to halt than destroy other data
STILOK:
	MOV	CX,WORD PTR F_NEXT[BX]	;CX points to next FDB in chain
	ADD	WORD PTR F_NEXT[BX],AX	;update next-ptr to reflect block move
	MOV	BX,CX
	JMP	SHORT FFNDL	;continue quest

FFOUND:
	CALL	XFRSTR		;move strings and lower FDB's up
	JMP	SHORT PFDCBA	;restore registers and exit

;XFRSTR(top, nbytes) {transfer string space}
; Entry - SI points 1 byte above block to be moved
;         AX = direction and number of bytes to be moved {nbytes}
;              (if AX .GT. 0 then strings are moved to a higher adr (UP))
;         FRETOP points 1 byte below bottom of block to be moved
; Exit  - FLAGS, AX, BX, CX, DX used (Others preserved)
;
;  if moving string space down, nbytes .LS. 0, top=FILTAB
;  if moving string space up, top=pointer to FDB being released,
;  perform block move
;  for each string descriptor in VARTAB, ARYTAB, temporaries do
;    if str.adr .LSS. top then
;      str.adr := str.adr + nbytes {update string descriptor}
;    else if str.adr .LSS. top+nbytes then
;      str.len := 0 {reset field variables in released FDB}
;    end; {for each string...}
;  FILTAB := FILTAB + nbytes;
;  MEMSIZ := MEMSIZ + nbytes;
;  FRETOP := FRETOP + nbytes;
;  SAVFRE := SAVFRE + nbytes; (so CHAIN will work)
;  PTRFIL := PTRFIL + nbytes; (if it was pointing to a moved FDB)
;
XFRSTR:	PUSH	SI
	PUSH	DI
	DEC	SI		;SI points to top of block to be moved
	MOV	DI,SI		;DI points to top of block to be moved
	MOV	DX,AX		;DX=byte-count adjustment for block move
	ADD	DI,AX		;DI points to top of dest of block move
	MOV	CX,SI
	SUB	CX,WORD PTR FRETOP	;CX = number of bytes to transfer
	JZ	XFRSTX		;return if string space is empty
	PUSH	SI
	PUSH	DI
	STD			;set Post-Decrement mode
	OR	AX,AX
	JNS	XFRSUP		;brif moving strings up in memory
	CLD			;set Post-Increment mode
	SUB	SI,CX
	SUB	DI,CX		;start transfer from bottom
	INC	SI		;SI points to bottom of SRC block
	INC	DI		;DI points to bottom of DST block
XFRSUP:
 REP	MOVSB			;execute block move
	POP	DI		;restore DI points to TOP of DST block
	POP	SI		;restore SI points to TOP of SRC block

;Update all string descriptors in VARTAB
; SI points to top of source of block move
; DI points to top of destination of block move
; DX = byte count adjustment for block move
;
	MOV	BX,WORD PTR VARTAB	;Look at simple strings
CSVAR:	CMP	BX,WORD PTR ARYTAB	;Done if we have reached array table
	JZ	CAYVAR		;Yes
	CALL	SKPNAM		;Skip name, returns Z if was a string
	JNZ	CSKPVA		;Skip this var, not string
	CALL	UPDSTD		;Update this string descriptor
	XOR	AL,AL		;UPDSTD has already incremented [BX]
CSKPVA:
	MOV	AH,LOW 0
	ADD	BX,AX		;Add length of VALTYP
	JMP	SHORT CSVAR

;Update all string descriptors in ARYTAB
;
CAYVA2:	MOV	BX,AX		;BX points to next string descriptor
CAYVAR:	CMP	BX,WORD PTR STREND	;New limit of search
	JZ	XFRSTX		;branch if done searching arrays
	CALL	SKPNAM		;Skip over name
	PUSHF			;save string-name indicator
	MOV	AX,WORD PTR 0[BX]	;Get length of array
	INC	BX
	INC	BX
	ADD	AX,BX		;AX points to next entry in ARYTAB
	POPF			;String array?
	JNZ	CAYVA2		;No, look at next one
	PUSH	AX		;save pointer to end of array
	MOV	AL,BYTE PTR 0[BX]	;Pick up number of DIMs
	MOV	AH,LOW 0	;Make double with high zero
	ADD	BX,AX		;Go past DIMS
	ADD	BX,AX
	INC	BX		;One more to account for # of DIMs
CAYSTR:	POP	AX		;AX points to end of array
	CMP	BX,AX		;Are we done with this array?
	JZ	CAYVAR		;Get next array
	PUSH	AX
	CALL	UPDSTD		;Update string descriptor
	JMP	SHORT CAYSTR

XFRSTX:	MOV	CX,WORD PTR PTRFIL
	CMP	CX,WORD PTR FRETOP
	JB	XFSTX1		;brif PTRFIL pointed below moved block
	CMP	CX,SI
	JAE	XFSTX1		;brif PTRFIL pointed above moved block
	ADD	WORD PTR PTRFIL,DX	;Adjust PTRFIL for block move
XFSTX1:	ADD	WORD PTR FRETOP,DX	;Adjust FRETOP for block move
	ADD	WORD PTR SAVFRE,DX	;Adjust SAVFRE for block move
	ADD	WORD PTR FILTAB,DX	;Adjust FILTAB for block move
	ADD	WORD PTR MEMSIZ,DX	;Adjust MEMSIZ for block move
	POP	DI
	POP	SI
	RET	


;Update String Descriptor pointed to by BX.
; Entry - BX points to string descriptor
;         SI points to top of source for block move
;         DI points to top of destination for block move
;         DX = size and direction of block move
; Exit  - BX points 1 byte beyond string descriptor
;         if string descriptor pointed inside buffer being released, len=0
;         if descriptor points within block-move, its pointer is adjusted.
;         CX used.  All other registers preserved.
;
UPDSTD:
	MOV	CX,WORD PTR 1[BX]	;CX points to string data
	CMP	CX,WORD PTR FRETOP
	JBE	UPDSTX		;brif string data is below string space
	CMP	CX,SI
	JBE	UPDSTU		;brif string data was block moved
	CMP	CX,DI
	JA	UPDSTX		;brif string not in buffer being freed
	MOV	BYTE PTR 0[BX],LOW 0	;set string len to 0 (reset field buf)
UPDSTU:
	ADD	WORD PTR 1[BX],DX	;adjust pointer for block move
UPDSTX:
	ADD	BX,3		;BX points 1 byte beyond string desc
	RET	

	SUBTTL General Queue support routines

	PUBLIC	INITQ,PUTQ,GETQ,NUMQ,LFTQ

;These routines are all called with SI pointing to an 8-byte queue descriptor
; which is organized (invisibly to the caller) as follows:
;
	Q_PUT=0			;points to the next empty byte in the queue
	Q_GET=2			;points to the next byte to be fetched (oldest data)
	Q_BUF=4			;points to the 1st byte of the physical buffer
	Q_END=6			;points 1 byte beyond the end of the physical buffer

;   Note: if Q.PUT(SI)=Q.GET(.SI), the queue is empty
;         Size of queue buffer is Q.END - Q.BUF
;         Maximum data in queue at any time is Q.END - Q.BUF - 1


;INITQ - initialize queue descriptor for empty queue
; Entry - SI points to 8 byte queue descriptor
;         BX points to 1st byte of queue buffer
;         [AX] = size of queue buffer
; Exit  - AX is used
;
INITQ:	MOV	WORD PTR Q_PUT[SI],BX
	MOV	WORD PTR Q_GET[SI],BX
	MOV	WORD PTR Q_BUF[SI],BX
	ADD	AX,BX
	MOV	WORD PTR Q_END[SI],AX
	RET	

;PUTQ - append data to back of queue
; Entry - SI points to 8 byte queue descriptor
;         [AL]=data to be put in queue
; Exit  - FLAGS.Z is true if queue is full
;
PUTQ:	MOV	BX,WORD PTR Q_PUT[SI]
	MOV	BYTE PTR 0[BX],AL
	CALL	BUMPQP		;advance PUT-POINTER BX
	CMP	BX,WORD PTR Q_GET[SI]
	JE	PQFULL		;brif queue is full (ignore new data)
	MOV	WORD PTR Q_PUT[SI],BX	;save new PUT-POINTER
PQFULL:	RET	

;GETQ - get next byte from front of queue
; Entry - SI points to 8 byte queue descriptor
; Exit  - FLAGS.Z is true if queue is empty
;         otherwise, [AL]=data to be put in queue
;         AX is used
;
GETQ:	MOV	BX,WORD PTR Q_GET[SI]
	CMP	BX,WORD PTR Q_PUT[SI]
	JE	GQEMTY		;branch if queue is empty
	MOV	AL,BYTE PTR 0[BX]	;get next byte from queue
	CALL	BUMPQP		;advance queue pointer BX
	MOV	WORD PTR Q_GET[SI],BX	;save new GET-POINTER
	OR	BX,BX		;set NZ so caller knows AL has data
GQEMTY:	RET	

BUMPQP:	INC	BX
	CMP	BX,WORD PTR Q_END[SI]
	JB	BUMPQX		;branch if no need to Wrap-Around
	MOV	BX,WORD PTR Q_BUF[SI]	;reset pointer to start of buf
BUMPQX:	RET	

;LFTQ - How many times can PUTQ be successfully called for queue SI
; Entry - SI points to 8 byte queue descriptor
; Exit  - [AX] = number of bytes free in queue (0..QueueSize - 1)
;
LFTQ:	MOV	AX,WORD PTR Q_GET[SI]
	DEC	AX
	SUB	AX,WORD PTR Q_PUT[SI]
	JMP	SHORT NUMQ1

;NUMQ - How many times can GETQ be successfully called for queue SI
; Entry - SI points to 8 byte queue descriptor
; Exit  - [AX] = number of bytes of data in queue (0..QueueSize - 1)
;
NUMQ:	MOV	AX,WORD PTR Q_PUT[SI]
	SUB	AX,WORD PTR Q_GET[SI]
NUMQ1:	JAE	NUMQX		;brif PUT-POINTER exceeds GET-POINTER
	ADD	AX,WORD PTR Q_END[SI]
	SUB	AX,WORD PTR Q_BUF[SI]
NUMQX:	RET	

	SUBTTL I/O Initialization Called by INIT

	PUBLIC	GIOINI,GIOTRM

GIOINI:
	CALL	MSISET		;Init MSDOS interrupts &H23 & &H24
	XOR	AX,AX
	MOV	WORD PTR STKLOW,AX
	MOV	WORD PTR FILTAB,0	;so FDBPTR will work during initialization
	MOV	BYTE PTR NLONLY,AL
	MOV	BX,WORD PTR DEVINI	;DI points to array of init routines
	CALL	DOALDV
	JMP	SHORT FINPRT	;reset PTRFIL to Keyboard

GIOTRM:	MOV	BX,WORD PTR DEVTRM	;DI points to array of terminate routines
	CALL	DOALDV
	CALL	MSIRST		;Replace MSDOS int vectors &H23 & &H24
	RET	

DOALDV:	MOV	AL,LOW OFFSET $_NDEV
	CBW			;[CX]=number of devices in system
	ADD	AX,AX
	JZ	DOALLX		;branch if no non-disk devices
	MOV	DI,AX		;[DI]=2*number of non-disk devices
DOALLP:	PUSH	BX
	PUSH	DI
	CALL	 WORD PTR CS:-2[BX+DI]	;Call initialization/termination routine
	POP	DI
	POP	BX
	DEC	DI
	DEC	DI
	JNZ	DOALLP		;Loop until Device ID = 0 (disk)
DOALLX:
	RET	

;FINLPT forces a carriage return on LPT1 if it is not already at left margin.
; It then falls into FINPRT.
; Exit  - AX, SI, DI, FLAGS used, all other registers preserved.
;
FINLPT:	PUSH	AX
	MOV	AH,LOW OFFSET G_GPS	;Get column position request-code
;        MOVI    DI,$CODE+2*<^O400-$.LPT1>
	MOV	DI,OFFSET $_LPT1
	NEG	DI		; Change neg. dev. # to 0 based offset
	AND	DI,377O
	SHL	DI,1		; ASM86 cann't multiply externals by 2
	PUSH	DI		;save Device Code
	CALL	TBLDSP		;function [AH] on device [DI] (LPT1)
	POP	DI
	OR	AH,AH		;test LPT1 current column position
	JZ	FINLPX		;branch if at column 0
	MOV	AX,OFFSET (400O*G_SOT)+13D
	PUSH	DI		;save Device Code
	XOR	SI,SI		;SI=pseudo LPT FDB
	CALL	TBLDSP		;Send CR to LPT
	POP	DI
	MOV	AX,OFFSET (400O*G_SOT)+10D
	XOR	SI,SI		;SI=pseudo LPT FDB
	CALL	TBLDSP		;Send LF to LPT
FINLPX:	POP	AX
				;Fall into FINPRT

;FINPRT is called at the end of every BASIC statement and after ERROR.
; It resets the current file to be Keyboard/Crt.
; It also frees the File-Data-Block pointed to by FREFDB if it is non-zero.
; This is useful for Device-Open routines (xxxOPN).  After calling
; INIFDB to allocate an FDB, they can set FREFDB to point to allocated FDB.
; When the file gets completely opened, they can reset FREFDB to 0.
; Then if some error occurs in between, FINPRT will release the FDB.
; Exit  - AX, SI, DI, FLAGS used, all other registers preserved.
;
	PUBLIC	FINPRT,FINLPT
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FREFDB:WORD
DSEG	ENDS
FINPRT:
	EXTRN	SETCSR:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CSRY:WORD,CSRX:WORD,CSRTYP:WORD
DSEG	ENDS
	PUSH	DX
	MOV	DL,BYTE PTR CSRY
	MOV	DH,BYTE PTR CSRX	;DX=current posn
	MOV	BYTE PTR CSRTYP,LOW 3D	;Set to user cursor
	CALL	SETCSR		;Display the cursor
	POP	DX
	MOV	SI,WORD PTR FREFDB
	OR	SI,SI
	JZ	NFRFDB		;branch if no FDB needs to be released
	CALL	FFREE
NFRFDB:	XOR	AX,AX
	MOV	WORD PTR FREFDB,AX	;reset FREE-FDB flag
	CALL	CLSFIL		;close file #0 (if NLONLY=0)
	XOR	AX,AX
	TEST	BYTE PTR NLONLY,LOW 1
	JNZ	RET45		;don't clear PTRFIL if loading program
	MOV	WORD PTR PTRFIL,AX	;future I/O will use Keyboard/CRT
RET45:	RET	
	PAGE	
	SUBTTL  MSDOS   Abort/Initialization/Termination Processing

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	DINTAD:WORD,CTLCAD:WORD	;MSDOS Ctl-C and disk error vector
DSEG	ENDS
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	MSDCCF:WORD	;MSDOS control C flag
DSEG	ENDS

	EXTRN	ERROR:NEAR
	EXTRN	ERRDWP:NEAR,ERRDNR:NEAR,ERRDME:NEAR	;I/O Error numbers

	PUBLIC	SAVVEC,SETVEC

;DSKERR - Processing for MSDOS interrupt &H23
;         Exit is made through ERROR.  No IRET is executed.
;
DSKERR:	STI	
	MOV	AX,DI		;[AX]= Error code
	ADD	SP,20D		;Adjust stack
	POP	DS		;Get BASIC data segment
	POP	ES		;Get BASIC extra segment
	MOV	DL,LOW OFFSET ERRDWP
	OR	AL,AL		;Test for "Disk write protect"
	JZ	DSKERX		;Disk write protect
	MOV	DL,LOW OFFSET ERRDNR
	CMP	AL,LOW 2D	;Test for "Disk not ready"
	JZ	DSKERX		;Disk not ready
	MOV	DL,LOW OFFSET ERRDME	;Else "Disk media error
DSKERX:	JMP	ERROR		;Go report the error and return
				;Extra stuff on stack is removed by ERROR

;MSCTLC - Processing for MSDOS interrupt &H23
;
MSCTLC:	MOV	BYTE PTR MSDCCF,LOW 377O	;Record control-C event for POLKEY
	IRET	

;MSISET - Set MSDOS termination and Ctl-C processing addresses.
;         The current addresses are saved for restoration upon termination
;         All registers preserved.
;


MSISET:	PUSH	AX
	PUSH	DX
	PUSH	ES
	MOV	AX,36D		;MSDOS fatal error interrupt
	MOV	BX,OFFSET DINTAD	;Get save location for fatal error
	CALL	SAVVEC
	DEC	AX		;MSDOS Ctl-C interrupt
	MOV	BX,OFFSET CTLCAD	;Get save location
	CALL	SAVVEC
	PUSH	CS
	POP	ES		;BASIC code segment to ES
	MOV	DX,OFFSET MSCTLC	;BASIC Ctl-C handler address
	CALL	SETVEC		;BASIC Ctl-C handler vector set
	INC	AX		;MSDOS fatal error interrupt
	MOV	DX,OFFSET DSKERR
	CALL	SETVEC		;BASIC fatal error handler vector set
	POP	ES
	POP	DX
	POP	AX
	RET	

MSIRST:	PUSH	AX
	PUSH	ES
	MOV	AX,36D		;MSDOS fatal error interrupt
	LES	DX,DWORD PTR DINTAD	;Get MSDOS fatal error handler add/par
	CALL	SETVEC
	DEC	AX		;MSDOS Ctl-C interrupt
	LES	DX,DWORD PTR CTLCAD	;Get MSDOS Ctl-C handler add/par
	CALL	SETVEC
	POP	ES
	POP	AX
	RET	
;SAVVEC - Get and store an interrupt vector
;ENTRY  - AX = interrupt
;         BX = CS relative address of vector storage area
;EXIT   - all registers preserved
;
SAVVEC:	PUSH	DX
	PUSH	ES
	CALL	GETVEC
	MOV	WORD PTR 0[BX],DX	;Save address portion
	MOV	DX,ES
	MOV	WORD PTR 2[BX],DX	;Save paragraph portion
	POP	ES
	POP	DX
	RET	

;SETVEC - Set an interrupt vector
;ENTRY  - AX    = interrupt number
;         ES:DX = new interrupt vector
;EXIT   - All registers preserved
;
SETVEC:	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	CALL	XCESDS		;Swap ES and DS
	DOSIO	37D		;Set interrupt
	CALL	XCESDS		;Swap ES and ES back
	JMP	PDCBAX		;POP DX,CX,BX,AX and RET

XCESDS:	PUSH	ES
	PUSH	DS
	POP	ES
	POP	DS
	RET	

;GETVEC - Get current interrupt vector
;ENTRY  - AX    = interrupt number
;EXIT   - ES:DX = interrupt vector
;         All other registers preserved
;
GETVEC:	PUSH	AX
	PUSH	BX
	PUSH	DS
	SHL	AX,1
	SHL	AX,1		;Calculate interrupt address
	MOV	BX,AX
	XOR	AX,AX
	MOV	DS,AX		;Get interrupt paragraph
	LES	DX,DWORD PTR 0[BX]	;Get interrupt vector
	POP	DS
	POP	BX
	POP	AX
	RET	
CSEG	ENDS
	END
                                                                                       