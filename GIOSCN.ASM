; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   GIOSCN - Screen Machine Independent Device Driver Code

COMMENT	*

--------- --- ---- -- ---------
COPYRIGHT (C) 1982 BY MICROSOFT
--------- --- ---- -- ---------

	*
	INCLUDE	GIO86U
	.SALL

CPM86=0				;CPM86 Operating System
IBMCSR=IBMLIK			;IBM compatibile cursor control interface

;Definition of scroll types
; Choice of scroll type is by switch SCROLT.
; Switches defined here are used to implement a specific SCROLT type.
; If other scroll types are needed then additional SCROLT types should be
;   defined here.
	INVLIN=SCROLT		;Invisible (function key) Line
	FKFSRL=(SCROLT-1) AND 1	;Clear fkeys/full scroll/rewrite fkeys

	INCLUDE	MSDOSU		;Operating System Constants

	PUBLIC	SCNDSP,SCNINI,SCNTRM
	EXTRN	DERBFM:NEAR,INIFDB:NEAR
	EXTRN	DEVBIN:NEAR,DEVBOT:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	ASSUME DS:DSEG
	EXTRN	TWOBYT:WORD
DSEG	ENDS

;Screen Dispatch Table
;
SCNDSP:
	DW	(DERBFM)	;test EOF for file opened to this device
	DW	(DERBFM)	;LOC
	DW	(DERBFM)	;LOF
	DW	(SCNCLS)	;perform special CLOSE functions for this device
	DW	(SCNSWD)	;set device width
	DW	(DERBFM)	;GET/PUT random record from/to this device
	DW	(SCNOPN)	;perform special OPEN functions for this device
	DW	(DERBFM)	;input 1 byte from file opened on this device
	DW	(SCNSOT)	;output 1 byte to file opened on this device
	DW	(SCNGPS)	;POS
	DW	(SCNGWD)	;get device width
	DW	(SCNSCW)	;set device comma width
	DW	(SCNGCW)	;get device comma width
	DW	(DEVBIN)	;block input from file opened on this device
	DW	(DEVBOT)	;block output to file opened on this device
	PUBLIC	SCNSWD,SCNSOT,SCNGPS,SCNGWD,SCNSCW,SCNGCW
	PAGE	
	SUBTTL CRT Primitive I/O Routines

;SCNINI is called to initialize Screen when BASIC comes up
;
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	WDTFLG:WORD
DSEG	ENDS
SCNINI:
	MOV	AL,BYTE PTR LINLEN	; Get CRT logical line length
	MOV	BYTE PTR WDTFLG,AL	; Default width of device SCRN:
	RET	

;SCNTRM is called to Clean-up Screen when BASIC terminates
;
	EXTRN	TKEYOF:NEAR
SCNTRM:	CALL	TKEYOF		;Turn off KEY display
	EXTRN	SCNPOS:NEAR
	CALL	SCNPOS		;[DX]=current cursor location
	RET	

;SCNCLS - perform any device dependent close functions.
; Entry - SI points to File-Data-Block.
; Exit  - All registers preserved.
;         This routine is called before BASIC releases the
;         file-data-block associated with this file.
;
SCNCLS:	RET	

;SCNSWD - set device width
; Entry - [DX] = new device width
; Exit  - All registers preserved
;
SCNSWD:
	EXTRN	SWIDTH:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	LINCNT:WORD,WDTFLG:WORD
DSEG	ENDS
	MOV	BYTE PTR WDTFLG,DL	;Set/Reset infinite length flag
	CMP	DL,LOW 255D
	JNZ	SCNWD1		;BRIF not infinite length
	RET	
SCNWD1:	PUSH	CX
	PUSH	AX
	MOV	AL,DL		;pass Width in AL
	MOV	CL,BYTE PTR LINCNT	;pass Height in CL
	CALL	SWIDTH		;Let screen editor set width
	POP	AX
	POP	CX
	RET	

;SCNOPN - perform any device dependent open functions.
; Entry - [AL]=  device id
;                0 if default device,
;                1..n for Disk A:, B:, ...
;                -1..-n for non-disk devices
;         [BX] = file number (0..n)
;         [CX] = random record size if [FILMOD] = random
;                (if [CX] = 0, use default record size)
;         [DI] = device offset (2=SCND, 4=SCRN, etc.)
;         [FILMOD] = file mode
;                    MD.SQI = 1 ;sequential input
;                    MD.SQO = 2 ;sequential output
;                    MD.RND = 3 ;random
;                    MD.APP = 4 ;append
;         [FILNAM] = filename
;         [FILEXT] = 1..3 byte filename extension
; Exit  - [SI] points to new FDB
;         FDB is linked into FDB chain with all standard
;         fields initialized.
;         All other registers are preserved.
;
SCNOPN:
	CALL	SCNGPS		;[AH]=current column position
	MOV	DH,AH		;[DH]=current column position
	MOV	AH,LOW OFFSET MD_SQO	;allow open for output only
	MOV	DL,BYTE PTR WDTFLG	;initial file logical width
	JMP	INIFDB

	PUBLIC	CALTTY,$CATTY

;CALTTY IS A SPECIAL ROUTINE TO OUTPUT ERROR MESSAGE TO TTY, REGARDLESS
;   OF CURRENT FILE I/O.
; Entry - [AL] = byte to be output
; Exit  - All registers preserved
;
	EXTRN	OUTDO:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	PTRFIL:WORD
DSEG	ENDS
$CATTY:
CALTTY:	PUSH	WORD PTR PTRFIL
	MOV	WORD PTR PTRFIL,0	;Make sure we go to the "TTY"
	CALL	OUTDO
	POP	WORD PTR PTRFIL
	RET	

;SCNSOT - Sequential Output.
; Entry - SI points to File-Data-Block.
;         [AL] = byte to be output.
; Exit  - SI, DI can be changed.
;         All other registers preserved
;         This routine expands tabs if appropriate.
;         It need not force a carriage return when width
;         exceeded as this is handled at a lower level.
;
SCNSOT:
	EXTRN	SCNOUT:NEAR
	PUSHF	
	PUSH	AX

;If last char SCNSOT was called with was the 1st byte of a 2-byte char,
; SCNSOT saved it in TWOBYT so they be both output as one 16-bit character.
;
	MOV	AH,BYTE PTR TWOBYT	;If two byte, put first in [AH]
	OR	AH,AH
	JZ	SCNSO1		;BRIF not second of two bytes
	MOV	BYTE PTR TWOBYT,LOW 0	;Clear TWOBYT flag
	JMP	SHORT SCNSO3	;Output both bytes at once
SCNSO1:
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	F_EDIT:WORD
DSEG	ENDS
	TEST	BYTE PTR F_EDIT,LOW 377O
	JZ	SCNS1A		;BRIF not in editor, don't collect FF codes
	CMP	AL,LOW 255D
	JZ	SCNS1B		;BRIF is first of two bytes
SCNS1A:
	JMP	SHORT SCNSO2	;branch if not 1st of 2-bytes
SCNS1B:
	MOV	BYTE PTR TWOBYT,AL	;save char for next time
	JMP	SHORT SCNSOX	;Set two byte flag and return
SCNSO2:
	XOR	AH,AH		;clear high-byte (not 2-byte char)
SCNSO3:	CALL	SCNOL1
SCNSOX:	POP	AX
	POPF	
	RET	

;SCNSOT level 1
; Outputs AX, destroys AX
;
SCNOL1:
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	LSTCHR:WORD
DSEG	ENDS
;For IBM Compatibility, the following filter performs the following translations
;    x x x CR x x x    === x x x CR LF x x x
;    x x x CR LF x x x === x x x CR LF x x x
;
;    If (Char = CR) then
;       output CR : output LF
;    else if (char <> LF) or (LSTCHR <> CR) then
;       output char
;    else
;       {eat the LF which follows a CR}
;    LSTCHR = CHR
;
	CMP	BYTE PTR LSTCHR,LOW OFFSET ASCCR
	MOV	BYTE PTR LSTCHR,AL	;save this char for comparison with next
	JNE	NTCRLF		;branch if not LF after CR
	CMP	AL,LOW OFFSET ASCLF
	JE	RET22		;eat LF if it follows CR
NTCRLF:
	PUSH	AX
	CALL	SCNOL2		;output this char
	POP	AX
	CMP	AL,LOW OFFSET ASCCR
	JNE	RET22		;if not CR, just output char
	MOV	AX,OFFSET ASCLF	;else map CR to CR LF
	CALL	SCNOL2
RET22:	RET	

;SCNSOT level 2
; Output [AX], destroys AX
;
SCNOL2:
	OR	SI,SI
	JZ	SCNSO8		;BRIF is not file I/O
	CMP	AL,LOW OFFSET ASCCR
	JZ	SCNSO8		;BRIF CR, don't do wrap
	PUSH	AX		;save char to be output
	MOV	AL,BYTE PTR CSRX
	OR	AH,AH		;see if 2-byte char
	JZ	SCNSO4		;BRIF not DBLCHR
	INC	AL		;Need two char posns for DBLCHR
SCNSO4:
	CMP	AL,BYTE PTR F_WID[SI]	;Compare posn with file width
	JA	SCNSCR		;Beyond max, force CR
	CMP	AL,BYTE PTR LINLEN
	JBE	SCNSO7		;Within line, go ahead and output
	DEC	AL
	MOV	BYTE PTR CSRX,AL	;Make sure there's room before end of line
SCNSO7:	POP	AX		;restore char to be output
SCNSO8:
	JMP	SCNOUT		;Output the char in [AX] and return


SCNSCR:	CMP	AL,BYTE PTR LINLEN
	JZ	SCNSO7		;BRIF file width .EQ. device width, use wrap code
	MOV	AX,OFFSET ASCCR
	CALL	SCNOUT		;Force new line
	MOV	AX,OFFSET ASCLF
	CALL	SCNOUT
	JMP	SHORT SCNSO7	;Output the character


;POS(X) function
;
	PUBLIC	POS
	EXTRN	SNGFLT:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	LINLEN:WORD
DSEG	ENDS
POS:	MOV	AL,BYTE PTR CSRX	;[AL]=current 1 relative position
	CMP	AL,BYTE PTR LINLEN
	JBE	POS0		;BRIF not beyond end of line
	MOV	AL,LOW 1	;Else next char will go in first column
POS0:	JMP	SNGFLT		;return result to user

;SCNGPS - return current file position.
; Entry - SI points to File-Data-Block.
; Exit  - [AH] = current file column. (0-relative)
;         All other registers preserved
;
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CSRX:WORD
DSEG	ENDS
SCNGPS:	MOV	AH,BYTE PTR CSRX
	PUSHF	
	CMP	AH,BYTE PTR LINLEN
	JBE	SCNGP1		;BRIF not beyond edge of screen
	MOV	AH,BYTE PTR LINLEN	;Force posn within screen
SCNGP1:	POPF	
	DEC	AH		;Make it 0 relative
	RET	

;SCNGWD - get device width
; Exit  - [AH] = device width as set by xxxSWD
;         All other registers preserved
;
SCNGWD:
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	LINLEN:WORD
DSEG	ENDS
	MOV	AH,BYTE PTR LINLEN
	OR	SI,SI
	JZ	SCNGWX		;BRIF not file I/O, use device width
	MOV	AH,BYTE PTR F_WID[SI]	;Is file I/O, use FDB width
SCNGWX:	RET	

;SCNSCW - set device comma width
; Entry - [BX] = new device comma width
; Exit  - SI, DI can be changed.
;         All other registers preserved
;
SCNSCW:	RET	

;SCNGCW - get device comma width
; Exit  - [BX] = device comma width as set by xxxSCW
;         All other registers preserved
;
SCNGCW:	RET	

CSEG	ENDS
	END
                                                                          