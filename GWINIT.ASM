; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   GWINIT GW-BASIC-86 Initialization

;Assumes LEN2, FIVMEM, FIVEO, I8086, PURE


TRACEF=0			;for Debugging when DEBUG can't be used
CPM86=0
DYNBUF=0
BSEGSZ=0			;Size of Buffer segment for Misc. Buffers

	.RADIX	10

DSEG	SEGMENT PUBLIC 'DATASG'		
	ASSUME DS:DSEG
	EXTRN	LSTVAR:WORD	;Last variable in RAM
	EXTRN	FILTAB:WORD,STKLOW:WORD,MAXMEM:WORD
	EXTRN	TSTACK:WORD,ERRFLG:WORD
	EXTRN	MEMSIZ:WORD,TOPMEM:WORD,SAVSTK:WORD,FRETOP:WORD,TXTTAB:WORD
	EXTRN	PROFLG:WORD,CHNFLG:WORD,MRGFLG:WORD,ERRFLG:WORD
	EXTRN	CHNFLG:WORD,MRGFLG:WORD,ERRFLG:WORD
	EXTRN	PRMSTK:WORD,PRMPRV:WORD
DSEG	ENDS

	EXTRN	FCERR:NEAR,SNERR:NEAR

;
	SWTCHR=57O		;DEFAULT SWITCH CHARACTER IS SLASH
	EXTRN	MAKUPL:NEAR
	EXTRN	CNSGET:NEAR
	EXTRN	CHRGTR:NEAR
	EXTRN	OUTDO:NEAR,LINPRT:NEAR,CRDO:NEAR,OMERRR:NEAR
	EXTRN	REASON:NEAR
	EXTRN	READY:NEAR,STKINI:NEAR
	EXTRN	DCOMPR:NEAR
	EXTRN	SYNCHR:NEAR

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	BUF:WORD
DSEG	ENDS
	EXTRN	SNERR:NEAR,FCERR:NEAR,ATN:NEAR,COS:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	MSWFLG:WORD,MSWSIZ:WORD,CSWFLG:WORD,CSWSIZ:WORD,NEWDS:WORD
DSEG	ENDS
	EXTRN	MAPCLC:NEAR,MAPINI:NEAR
	EXTRN	INITSA:NEAR
	PAGE	
	SUBTTL  INIT - System Initialization Code

	PUBLIC	INIT
	EXTRN	STROUT:NEAR,HEDING:NEAR,WORDS:NEAR
	EXTRN	GWINI:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	BUF:WORD,KBUF:WORD
DSEG	ENDS

INIT:
; For safety, a label has been defined in BINTRP.MAC that contains the
; start of the data segment.  That is where the O.S. control block will
; be copied to, so it MUST be first in the DSEG.
; BEGDSG is declared as a code segment external here even though it
; really is in the data segment.  This makes it easier to get the offset
; of the beginning of the data segment from the beginning of the code
; segment.  The beginning of DATASG MUST be within 64K of the beginning
; of CODESG for this to work.  No error will be generated, so be careful.
;
	EXTRN	BEGDSG:NEAR	;Beg. of the data segment, offset from CS
	INS86	272,,BEGDSG	;MOVI DX,BEGDSP
	INS86	261,4		;MOVI CL,4   Divide by 16 to ...
	INS86	323,352		;SHR  DX,CL  get paragraph address
	INS86	214,311		;MOV  CX,CS  add in code segment
	INS86	3,321		;ADD  DX,CS
	INS86	264,46		;MOVBI AH,38 SPECIAL FUNCTION TO CALC END
				;            OF CS AND RETURN START OF DS
	INS86	315,41		;INT  33     CALL SCP DOS
	INS86	214,330		;MOV  AX,DS  SAVE DS FOR EXIT VECTOR
	INS86	216,332		;MOV  DS,DX  SET UP SEG REGS
	INS86	216,302		;MOV  ES,DX
;Initialize the jump vector for exit to MSDOS.  MSDOS 2.0 requires that
; exit is made through the segment prefix table which is located at DS:0.
; For .EXE files, DS is not the same as CS at program initiation time (NOW).
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CPMEXT:WORD
DSEG	ENDS
	INS86	307,6,CPMEXT	;MOVI CPMEXT,^D0
	INS86	0,0		;            INS86 has 4 params
				;            & some may not be words
	INS86	220,243,CPMEXT+2	;NOP         NOP - pad to item 3 of INS86
				;MOV  CPMEXT+2,AX
	CLI			;Setting the stack segment and stack
				;pointer must be an indivisable
				;operation.
	INS86	216,322		;MOV SS,DX
	MOV	BX,OFFSET BUF+128D	;Use BUF for a temporary stack.
	MOV	MEMSIZ,BX
	MOV	SP,BX
	XOR	AL,AL		;INITIALIZE PROTECT FLAG
	MOV	BYTE PTR PROFLG,AL
	MOV	BYTE PTR MSWFLG,AL	;Init /M: flag
	MOV	BYTE PTR CSWFLG,AL	;Init /C: flag
	EXTRN	CNSLEN:NEAR,CONSTR:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	ENDBUF:WORD,RAMLOW:WORD
DSEG	ENDS
	MOV	CH,LOW OFFSET CNSLEN+3	;Get number of bytes to move
	MOV	BX,OFFSET RAMLOW	;WHERE THE CONSTANTS ARE STORE IN RAM
	MOV	DX,OFFSET CONSTR	;WHERE THE CONSTANTS ARE HELD IN ROM
MORMOV:				;MOVE ROM INITIALIZATION VALUES TO RAM
	INS86	213,362,56,254	;CODE SEGMENT FETCH
	MOV	BYTE PTR [BX],AL	;STORE IT AWAY IN RAM
	INC	BX
	INC	DX
	DEC	CH
	JNZ	SHORT MORMOV	;IF NOT, KEEP SHOVELING THEM DOWN
	STI
	EXTRN	SCNIPL:NEAR
	CALL	SCNIPL		;Screen editor initialization
	CALL	GWINI		;OEM specific initialization
	EXTRN	SNDRST:NEAR
	CALL	SNDRST		;reset sound queue, disable speaker
	EXTRN	GIOINI:NEAR
	CALL	GIOINI
	MOV	BX,MEMSIZ
	MOV	TOPMEM,BX
	MOV	BX,OFFSET KBUF-1	;INITIALIZE KBUF-1 WITH A COLON
	MOV	BYTE PTR [BX],LOW ":"	;DIRECT INPUTS RESTART OK.
	CALL	STKINI		;REALLY SET UP INIT'S TEMPORARY STACK
;
;       Check CP/M Version Number

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CPMREA:WORD
DSEG	ENDS

	MOV	BX,OFFSET 34*256+33+0	;2.x Read / Write
CPMVR1:	MOV	CPMREA,BX	;Save Read/Write Codes
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CNTOFL:WORD
DSEG	ENDS
	XOR	AL,AL
	MOV	BYTE PTR CNTOFL,AL
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	ENDBUF:WORD
DSEG	ENDS
	MOV	BYTE PTR ENDBUF,AL	;MAKE SURE OVERRUNS STOP
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	DSEGZ:WORD
DSEG	ENDS
	MOV	BYTE PTR DSEGZ,AL	;(DS) LOCATED ZERO
	MOV	BYTE PTR CHNFLG,AL	;MAKE SURE CHAINS AND MERGES
	MOV	BYTE PTR MRGFLG,AL	;DONT TRY TO HAPPEN
	MOV	BYTE PTR ERRFLG,AL	;DON'T ALLOW EDIT TO BE CALLED ON ERRORS
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	TEMPST:WORD,TEMPPT:WORD
DSEG	ENDS
	MOV	BX,OFFSET TEMPST
	MOV	TEMPPT,BX
	MOV	BX,OFFSET PRMSTK	;INITIALIZE PARAMETER BLOCK CHAIN
	MOV	PRMPRV,BX


	SUBTTL Read Operating System Parameters (memsiz etc.)


; THE FOLLOWING CODE SCANS A CP/M COMMAND LINE FOR BASIC.

; THE FOLLOWING SWITCHES ARE RECOGNIZED:
;
;       /M:<TOPMEM>
;       /F:<FILES>
;       /S:<MAX RECORD SIZE>
;       /C:<COM INPUT QUEUE SIZE>
;
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CPMMEM:WORD
DSEG	ENDS
	MOV	BX,CPMMEM	;Load bytes free within segment
;For DYNCOM, CPMMEM holds the last segment addr of the system(i.e. CPMMEM=2)
	EXTRN	SEGOFF:NEAR
	CALL	SEGOFF		;Return byte offset of segment from current DS
	MOV	MEMSIZ,BX	;USE AS DEFAULT
	MOV	MAXMEM,BX	;set MAX DS size for CLEAR statement
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	DSEGZ:WORD
DSEG	ENDS
	MOV	BX,OFFSET DSEGZ	;IN THE DATA SEGMENT
	MOV	TEMP8,BX	;SO IF RE-INITAILIZE OK
	EXTRN	CPMWRM:NEAR
	TBUFF	EQU	CPMWRM+128D	;WHERE CP/M COMMAND BUFFER IS LOCATED

	MOV	BX,OFFSET TBUFF	;POINT TO FIRST CHAR OF COMMAND BUFFER
	MOV	AL,BYTE PTR [BX]	;WHICH CONTAINS # OF CHARS IN COMMAND
	OR	AL,AL		;IS THERE A COMMAND?
	MOV	TEMP8,BX	;SAVE POINTER TO THIS ZERO
	JNZ	SHORT ??L000
	JMP	DONCMD		;NOTHING IN COMMAND BUFFER
??L000:
	MOV	CH,BYTE PTR [BX]	;AND [B]
	INC	BX		;POINT TO FIRST CHAR IN BUFFER
TBFLP:	MOV	AL,BYTE PTR [BX]	;GET CHAR FROM BUFFER
	DEC	BX		;BACK UP POINTER
	MOV	BYTE PTR [BX],AL	;STORE CHAR BACK
	INC	BX		;NOW ADVANCE CHAR TO ONE PLACE
	INC	BX		;AFTER PREVIOUS POSIT.
	DEC	CH
	JNZ	SHORT TBFLP	;KEEP MOVING CHARS
	DEC	BX		;BACK UP POINTER
ENDCMD:	MOV	BYTE PTR [BX],LOW 0	;STORE TERMINATOR FOR CHRGET (0)
	MOV	TEMP8,BX	;SAVE POINTER TO NEW ZERO (OLD DESTROYED)
	MOV	BX,OFFSET TBUFF-1	;POINT TO CHAR BEFORE BUFFER
	CALL	CHRGTR		;IGNORE LEADING SPACES
	OR	AL,AL
	JNZ	SHORT ??L001
	JMP	DONCMD		;END OF COMMAND
??L001:
	CMP	AL,LOW OFFSET SWTCHR	;IS IT A SLASH
	JZ	SHORT FNDSLH	;YES
	DEC	BX		;BACK UP POINTER
	MOV	BYTE PTR [BX],LOW 34	;STORE DOUBLE QUOTE
	MOV	TEMP8,BX	;SAVE POINTER TO START OF FILE NAME
	INC	BX		;BUMP POINTER
ISSLH:	CMP	AL,LOW OFFSET SWTCHR	;OPTION?
	JZ	SHORT FNDSLH	;YES
	CALL	CHRGTR		;SKIP OVER CHAR IN FILE NAME
	OR	AL,AL		;SET CC'S
	JNZ	SHORT ISSLH	;KEEP LOOKING FOR OPTION
	JMP	DONCMD		;THATS IT
FNDSLH:	MOV	BYTE PTR [BX],LOW 0	;STORE TERMINATOR OVER "/"
SCANSW:
	CALL	CHRGTR		;GET CHAR AFTER SLASH
SCANS1:
	CALL	MAKUPL		;CONVERT SWITCH TO UPPER CASE
	CMP	AL,LOW "S"	;IS IT /S: ? (SET MAX RECORD SIZE)
	JZ	SHORT WASS
	CMP	AL,LOW "C"	;COM buffer size option
	JZ	SHORT WASC
	CMP	AL,LOW "F"	;FILES OPTION
	JZ	SHORT WASF
	CMP	AL,LOW "M"	;MEMORY OPTION
	JZ	SHORT ??L002
	JMP	SNERR		;Branch if couldn't recognize option
??L002:
	CALL	GETVAL		;[DX]=requested MEMSIZ
	MOV	MSWSIZ,DX	;Record memory request
	MOV	AL,LOW 377O
	MOV	BYTE PTR MSWFLG,AL	;Set /M: option flag
FOK:	DEC	BX		;RESCAN LAST CHAR
	CALL	CHRGTR		;BY CALLING CHRGET
	JZ	SHORT DONCMD	;END OF COMMAND
	CALL	SYNCHR
	DB	OFFSET SWTCHR	;SLASH SHOULD FOLLOW
	JMP	SHORT SCANS1	;SCAN NEXT SWITCH

WASC:	MOV	AL,LOW 377O
	MOV	BYTE PTR CSWFLG,AL	;Set /C: option flag
	CALL	GETVAL		;Get COM request to D,E
	MOV	CSWSIZ,DX	;Record for future memory map calc.
	JMP	SHORT FOK
WASS:				;GIO has dynamic record size
WASF:				;GIO has dynamic number of files
	CALL	GETVAL		;Get value
	JMP	SHORT FOK	;Any value OK (and ignored)

GETVAL:	CALL	CHRGTR		;skip M,F or S
	CALL	SYNCHR
	DB	OFFSET ":"	;MAKE SURE COLON FOLLOWS
	JMP	CNSGET		;[DE]=VALUE FOLLOWING COLON
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	TEMP8:WORD	;POINTER TO BASIC LOAD FILE
DSEG	ENDS
ERRCMD:
DONCMD:
	CALL	MAPCLC		;Calc. (but don't set) the new mem. map

;Now copy the command line file name (if there is one) to BUF
;Move required since DS: segment header will be overwritten when the
;DS: is coppied to the new DS: location.

	MOV	BX,TEMP8	;Load address of command line file name
	MOV	DX,OFFSET BUF	;Destination address
	MOV	TEMP8,DX	;New command line buffer address
NXTBYT:	MOV	AL,BYTE PTR [BX]	;File name character
	XCHG	BX,DX
	MOV	BYTE PTR [BX],AL	;Store at BUF
	INC	BX
	XCHG	BX,DX
	INC	BX
	OR	AL,AL		;Test for zero byte terminator
	JNZ	SHORT NXTBYT	;Get next file name character

	SUBTTL Allocate Space for Disk Buffers

; Disk Initialization Routine

; setup  file info blocks
; the number of each and information for
; getting to pointers to each is stored. no locations are
; initialized, this is done by nodsks, first closing all files.
; the number of files is the file pointer table
;
	MOV	BX,MEMSIZ	;get size of memory
	DEC	BX		;always leave top byte unused because
				;val(string) makes byte in memory
				;beyond last char of string=0
	MOV	MEMSIZ,BX	;save in real memory size
	DEC	BX		;one lower is stktop
	PUSH	BX		;save it on stack


	SUBTTL INIT TXTAB, STKTOP, VARTAB, MEMSIZ, FRETOP, STREND

; Memory map for GW-BASIC:
;
;               [MAXMEM]--}     highest byte of physical memory in system
;                               user managed memory
;               [TOPMEM]--}     highest byte available to BASIC
;                               basic stack
;               [STKLOW]--}     lowest byte available for STACK
;                           +--}FDB---}[STKEND] {end of chain}
;                           +---FDB{--+
;               [FILTAB]-------}FDB---+ (FILTAB points to lowest byte of lowest FDB)
;                               0 (1 byte string space terminator for VAL)
;               [MEMSIZ]--}     highest byte of IN-USE string space
;               [FRETOP]--}     highest byte of FREE string space
;               [STREND]--}     lowest  byte of FREE string space
;               [ARYTAB]--}     lowest  byte of Array Table
;               [VARTAB]--}     lowest  byte of Variable Table
;               [TXTTAB]--}     lowest  byte of BASIC Program Text
;
; note:  when [FILTAB] = [STKLOW], no FDB's are allocated.
;        when [FRETOP] = [MEMSIZ], IN-USE string space is empty.
;        when [SP] = [STKLOW], STACK is full.

; At this point, MEMSIZ-1 is on stack, [HL]=TXTTAB-1
;
	MOV	BX,OFFSET LSTVAR	;LSTVAR resides in last linked module with DS:
	MOV	TXTTAB,BX	;save bottom of memory
	POP	DX		;GET CURRENT MEMSIZ
	MOV	AL,DL		;WANT AN EVEN STACK PTR. FOR 8086
	AND	AL,LOW 254D	;SO WE'LL CLEAR LOW BIT
	MOV	DL,AL		;OF THE STACK PTR.
	MOV	AL,DL		;CALC TOTAL FREE/8
	SUB	AL,BL
	MOV	BL,AL
	MOV	AL,DH
	SBB	AL,BH
	MOV	BH,AL
	JAE	SHORT ??L003
	JMP	OMERRR
??L003:
	MOV	CL,LOW 3	;SHIFT RIGHT THREE BITS (DIVIDE BY 8)
	INS86	323,353		;SHR BX,CL
	MOV	AL,BH		;SEE HOW MUCH
	CMP	AL,LOW 2	;IF LESS THAN 512 USE 1 EIGHTH
	JB	SHORT SMLSTK
	MOV	BX,512D
SMLSTK:	MOV	AL,DL		;SUBTRACT STACK SIZE FROM TOP MEM
	SUB	AL,BL
	MOV	BL,AL
	MOV	AL,DH
	SBB	AL,BH
	MOV	BH,AL
	JAE	SHORT ??L004
	JMP	OMERRR
??L004:

	MOV	STKLOW,BX	;Save lowest legal value for [SP]
	MOV	FILTAB,BX	;Initially there are no FDB's
	DEC	BX
	MOV	BYTE PTR [BX],LOW 0	;String space should be terminated by 0 for VAL
	DEC	BX
	MOV	MEMSIZ,BX	;Save highest byte to be used by strings
	XCHG	BX,DX
	MOV	TOPMEM,BX
	MOV	FRETOP,BX	;REASON USES THIS...
	MOV	SP,BX		;SET UP NEW STACK
	MOV	SAVSTK,BX
	MOV	BX,TXTTAB
	XCHG	BX,DX
	CALL	REASON
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FREFLG:WORD	;Print free bytes flag
DSEG	ENDS
	XOR	AL,AL
	MOV	BYTE PTR FREFLG,AL	;Clear to print free bytes message
	EXTRN	GETHED:NEAR	;OEM heading retrieval routine
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	KEYSW:WORD	;Function key on flag
DSEG	ENDS
	MOV	AL,LOW 255D	;if heading is printed, display Fn keys also
	MOV	BYTE PTR KEYSW,AL
	CALL	GETHED		;Get OEM specific portion of the heading
	JNZ	SHORT PRNTIT	;Always print the heading option
	PUSH	BX		;Print heading if no program option
	MOV	BX,TEMP8	;Get pointer to file or 0
	MOV	AL,BYTE PTR [BX]	;Test for file on command line
	POP	BX		;Retrieve OEM heading pointer
	OR	AL,AL
	JZ	SHORT PRNTIT	;No program - go print heading
	MOV	BYTE PTR FREFLG,AL	;Set to inhibit free bytes message
	XOR	AL,AL		;Turn keys off if there is a program
	MOV	BYTE PTR KEYSW,AL	; otherwise allow OEM default
	JMP	SHORT PRNTND	;Skip heading

PRNTIT:	CALL	STROUT		;Print it
	MOV	BX,OFFSET HEDING	;GET HEADING ("BASIC VERSION...")
	CALL	STROUT		;PRINT IT
PRNTND:
	EXTRN	SKEYON:NEAR
	MOV	AL,BYTE PTR KEYSW	;Get function key display switch
	OR	AL,AL		;Keys need to be turned on?
	JNZ	SHORT ??L005
	JMP	KEYSOF		;Leave keys off
??L005:
	XOR	AL,AL
	MOV	BYTE PTR KEYSW,AL	;Show current status of keys
	CALL	SKEYON		;Set function key display on
KEYSOF:	MOV	AL,LOW 377O
	MOV	BYTE PTR INITFG,AL	;Set the initialization complete flag
				;indicating errors no longer result in an exit
				;to the OS
	JMP	INITSA
	PAGE	
;CMDERR This routine is called when an error is detected before the
;       completion of initialization (before INITFG is set to non-zero).
;       CMDERR performs the following:
;               1. Write the heading
;               2. Write an error message implicating the command line.
;               3. Exit to the operating system through SYSTME

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	INITFG:WORD
DSEG	ENDS
	EXTRN	SYSTME:NEAR,CERMSG:NEAR
	PUBLIC	CMDERR

CMDERR:	MOV	BX,OFFSET HEDING	;Get heading ("BASIC VERSION...")
	CALL	STROUT		;Print it
	MOV	BX,OFFSET CERMSG	;Get command error message
	CALL	STROUT		;Print it
	JMP	SYSTME		;Exit to the OS

PUBLIC	$LAST
	$LAST=$
PUBLIC	LASTWR
	LASTWR=$
CSEG	ENDS
	END
                                                                                