; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   GIOLPT - Line Printer Machine Independent Device Driver Code

COMMENT	*

--------- --- ---- -- ---------
COPYRIGHT (C) 1982 BY MICROSOFT
--------- --- ---- -- ---------

	*
	INCLUDE	GIO86U
	.SALL

MELCO=0
TETRA=0
ZENITH=0
CPM86=0
	INCLUDE	MSDOSU

;OEM Switches
;

	PUBLIC	LPTDSP,LPTINI,LPTTRM
	EXTRN	DERBFM:NEAR,INIFDB:NEAR,UPDPOS:NEAR,$_LPT1:NEAR
	EXTRN	DEVBOT:NEAR,DEVBIN:NEAR

;Line Printer Dispatch Table
;
LPTDSP:
	DW	(DERBFM)	;test EOF for file opened to this device
	DW	(DERBFM)	;LOC
	DW	(DERBFM)	;LOF
	DW	(LPTCLS)	;perform special CLOSE functions for this device
	DW	(LPTSWD)	;set device width
	DW	(DERBFM)	;GET/PUT random record from/to this device
	DW	(LPTOPN)	;perform special OPEN functions for this device
	DW	(DERBFM)	;input 1 byte from file opened on this device
	DW	(LPTSOT)	;output 1 byte to file opened on this device
	DW	(LPTGPS)	;POS
	DW	(LPTGWD)	;get device width
	DW	(LPTSCW)	;set device comma width
	DW	(LPTGCW)	;get device comma width
	DW	(DEVBIN)	;block input from file opened on this device
	DW	(DEVBOT)	;block output to file opened on this device

LPTTRM:	RET	
	PAGE	
	SUBTTL Line Printer Primitive I/O Routines

DSEG	SEGMENT PUBLIC 'DATASG'
	ASSUME DS:DSEG
	EXTRN	LP1DCB:WORD
DSEG	ENDS

;LPT Device Control Block field definitions:
;
	_LPWID=0		;device width (columns per line)
	_LPPOS=1		;current column device is in
	_LPFLG=2		;Boolean attributes mask for this device
	_LPCRF=1		;non-zero=last char sent was Carriage Return

;LPTINI - called during BASIC initialization
; Entry - DI = -2*device id
;
LPTINI:	PUSH	DI
	CALL	GLPDCB		;DI points to device control block
	MOV	BYTE PTR _LPWID[DI],LOW 80D	;default width = 80 chars / line
	MOV	BYTE PTR _LPPOS[DI],LOW 0	;initial position = 0
	MOV	BYTE PTR _LPFLG[DI],LOW 0	;reset device Flags
	POP	DI
	RET	

;LPTCLS - perform any device dependent close functions.
; Entry - SI points to File-Data-Block.
;         DI = -2*device id
; Exit  - All registers preserved.
;         This routine is called before BASIC releases the
;         file-data-block associated with this file.
;
LPTCLS:	RET	

;LPTSWD - set device width
; Entry - [DX] = new device width
;         DI = -2*device id
;
LPTSWD:
	CALL	GLPDCB		;DI points to device control block
	MOV	BYTE PTR _LPWID[DI],DL
	RET	

	EXTRN	DERIFN:NEAR,SCDBIN:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FILOPT:WORD
DSEG	ENDS

;LPTOPN - perform any device dependent open functions.
; Entry - [AL]=  device id
;                0 if default device,
;                1..n for Disk A:, B:, ...
;                -1..-n for non-disk devices
;         [BX] = file number (0..n)
;         [CX] = random record size if [FILMOD] = random
;                (if [CX] = 0, use default record size)
;         [DI] = device offset (2=LPTD, 4=SCRN, etc.)
;         [FILMOD] = file mode (one of the following)
;                    MD.SQI     ;sequential input
;                    MD.SQO     ;sequential output
;                    MD.RND     ;random
;                    MD.APP     ;append
;         [FILNAM] = filename
;         [FILEXT] = 1..3 byte filename extension
; Exit  - [SI] points to new FDB
;         FDB is linked into FDB chain with all standard
;         fields initialized.
;         All other registers are preserved.
;
LPTOPN:	PUSH	AX		;save device id for INIFDB
	CALL	GLPDCB		;DI points to device control block
	MOV	SI,OFFSET FILOPT	;SI points to options string
	MOV	AH,LOW 337O	;0DFH - Mask for mapping lower to upper case
	CLD			;use Post-Increment addressing
	LODSB			;[AL]=1st byte of option string
	AND	AL,AH		;Map Lower to Upper Case (turn off b6)
	PUSHF			;remember if BIN option was selected
	JE	NOOPT		;branch if no option specified
	CMP	AL,LOW "B"
	JNE	IFNERR		;Bad File Name error if option not BIN
	LODSB			;[AL]=next byte of option string
	AND	AL,AH		;Map Lower Case to Upper Case
	CMP	AL,LOW "I"
	JNE	IFNERR		;Bad File Name error if option not BIN
	LODSB			;[AL]=next byte of option string
	AND	AL,AH		;Map Lower Case to Upper Case
	CMP	AL,LOW "N"
	JNE	IFNERR		;Bad File Name error if option not BIN
	LODSB			;[AL]=next byte of option string
	OR	AL,AL
	JNE	IFNERR		;Error if not end of options
NOOPT:
	MOV	DH,BYTE PTR _LPPOS[DI]	;initial file column position
	MOV	DL,BYTE PTR _LPWID[DI]	;initial file width
	POPF	
	POP	AX		;[AL]=device id
	PUSHF			;remember if BIN option was selected
	MOV	AH,LOW OFFSET MD_SQO OR MD_RND	;allow open for output/random
	CALL	INIFDB
	POPF	
	JE	NOBIN		;branch if BIN option was not selected
	CALL	SCDBIN		;set BINARY file mode
NOBIN:
	RET	

IFNERR:	JMP	DERIFN		;"illegal filename" error

;LPTSOT - Sequential Output.
; Entry - SI points to File-Data-Block.  0 if Pseudo FDB (for LLIST/LPRINT)
;         DI = -2*device id
;         [AL] = byte to be output.
; Exit  - SI, DI can be changed.
;         All other registers preserved
;         This routine keeps track of column position,
;         expands tabs, and forces a carriage return when line width
;         is exceeded.
;
LPTSOT:	PUSH	BX		;save caller's BX
	PUSH	AX		;save char to be output
	CALL	GLPDCB		;DI points to line printer DCB
	MOV	BL,AL		;[BL] = device id
	POP	AX		;[AL] = byte to be output
	MOV	AH,BL		;[AH] = device id
	POP	BX		;restore caller's BX
	OR	SI,SI
	JZ	NOTBIN		;branch if not binary mode
	CMP	BYTE PTR F_CODE[SI],LOW OFFSET FC_BIN
	JE	LPROUT		;if binary, branch to Raw-Output routine
NOTBIN:	PUSH	BX
	PUSH	DX
	MOV	DX,WORD PTR _LPWID[DI]	;[DL]=device width, [DH]=current column
	MOV	BX,OFFSET LPOUT1	;BX points to Raw Output Routine
	JZ	PSDFDB		;branch if Pseudo FDB (LLIST/LPRINT)
				;*** CAREFUL *** FLAGS must be preserved
				; from OR SI,SI Above.
	MOV	DL,BYTE PTR F_WID[SI]	;Get width from FDB
PSDFDB:
	EXTRN	CRIFEL:NEAR
	CALL	CRIFEL		;force CR if End-Of-Line
	MOV	BYTE PTR _LPPOS[DI],DH	;save new column position
	POP	DX
	POP	BX
	RET	

;Low-Level Line Printer Output (updates column position)
;For IBM Compatibility, the following filter performs the following translations
;    x x x CR x x x    === x x x CR LF x x x
;    x x x CR LF x x x === x x x CR LF x x x
;If LPT was opened for RANDOM mode, and WIDTH=255, then suppress LF which
;   follow carriage returns for IBM compatibility.
;
; Eat all LineFeeds which follow CarriageReturns with following algorithm:
; if (Char <> LF) or (LastWasCR = 0) then output (Char)
; if (Char = CR) then
;    Begin
;    LastWasCR = 1
;    if FDB.MODE<>RANDOM or FDB.WIDTH<>255 then
;       output(LF)
;    End
; else
;    LastWasCR = 0
;
; The only case where this is not compatible with IBM is when the user executes:
; PRINT CHR$(13);CHR$(10);...
;
; The best way this could have been done was by setting CRONLY=1 in the
; switch files and letting the device drivers append Line-Feeds if necessary.
; It was considered too late to make a change this drastic
;
LPOUT1:	CALL	UPDPOS		;[DH]=new column position(AL, DH)
	PUSH	AX		;save character to be output
	CMP	AL,LOW OFFSET ASCLF
	JNE	LPOUT2		;branch if not attempting to output LF
	TEST	BYTE PTR _LPFLG[DI],LOW OFFSET _LPCRF
	JNE	LPOUT3		;brif last byte out was CR (eat LF)
LPOUT2:
	CALL	LPROUT		;output the character
LPOUT3:
	POP	AX		;restore [AL]=char which was output
	AND	BYTE PTR _LPFLG[DI],LOW OFFSET 255D-_LPCRF	;reset last byte out was CR flag
	CMP	AL,LOW OFFSET ASCCR
	JNE	LPOUTX		;return if wasn't carriage return
	OR	BYTE PTR _LPFLG[DI],LOW OFFSET _LPCRF	;set last byte out was CR flag
	OR	SI,SI
	JZ	OUTLF		;branch if Pseudo FDB (LLIST/LPRINT)
	CMP	BYTE PTR F_WID[SI],LOW 255D
	JNE	OUTLF		;output LF if width is not 255
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_RND
	JE	LPOUTX		;suppress LF following CRs
OUTLF:
	PUSH	AX
	MOV	AL,LOW OFFSET ASCLF
	CALL	LPROUT
	POP	AX
LPOUTX:
	RET	

;Raw Line Printer Output routine
; Entry - [AL]=byte to be sent to current line printer
;         [AH]=device id (0..n)
; Exit  - Flags used, All other registers preserved.
;
	EXTRN	SNDLPT:NEAR,ERROR:NEAR,ERRDNA:NEAR,ERRDTO:NEAR,ERROTP:NEAR
	EXTRN	ERRDIO:NEAR
LPROUT:
	PUSH	AX
	CALL	SNDLPT		;Call OEM routine to output to printer
	OR	AH,AH
	JNE	LPERR		;branch if OEM routine detected error
	POP	AX
	RET	
LPERR:
	MOV	AL,AH
	XOR	AH,AH		;[AX]=error code 1..n
	DEC	AX		;[AX]=error code 0..n
	MOV	DI,OFFSET LPERRT
	ADD	DI,AX		;[DI] points to BASIC Error code
	MOV	DL,BYTE PTR CS:0[DI]
	CMP	AL,LOW 3
	JB	ERROR1		;branch if legal error code
	MOV	DL,LOW OFFSET ERRDIO	;map all other error codes to I/O error
ERROR1:	JMP	ERROR

LPERRT:	DB	OFFSET ERRDNA
	DB	OFFSET ERRDTO
	DB	OFFSET ERROTP

;LPOS(X) function
;
	PUBLIC	LPOS
	EXTRN	SNGFLT:NEAR,CONINT:NEAR
LPOS:	PUSH	BX
	CALL	CONINT		;Force FAC to byte integer in AL
	CBW	
	OR	AX,AX		;Test for LPT number 0 to map to 1
	JZ	LPTN0		;n = 0, so map to 1
	DEC	AX
	SHR	AX,1		;Offset to correct DCB
LPTN0:	MOV	BX,OFFSET LP1DCB+_LPPOS	;Get address of LPOS in first LPT DCB
	ADD	BX,AX		;Get address of LPOS in current LPT DCB
	MOV	AL,BYTE PTR 0[BX]	;[AL]=current 0 relative position
	INC	AL		;return 1 relative number
	POP	BX
	JMP	SNGFLT		;return result to user

;LPTGPS - return current file position.
; Entry - SI points to File-Data-Block.
; Exit  - [AH] = current file column. (0-relative)
;         All other registers preserved
;
LPTGPS:	CALL	GLPDCB		;DI points to device control block
	MOV	AH,BYTE PTR _LPPOS[DI]
	RET	

;LPTGWD - get device width
; Entry - DI = -2*device id
; Exit  - [AH] = device width as set by xxxSWD
;         All other registers preserved
;
LPTGWD:	CALL	GLPDCB		;DI points to device control block
	MOV	AH,BYTE PTR _LPWID[DI]
	RET	

;LPTSCW - set device comma width
; Entry - [BX] = new device comma width
;         DI = -2*device id
; Exit  - SI, DI can be changed.
;         All other registers preserved
;
LPTSCW:	RET	

;LPTGCW - get device comma width
; Entry - DI = -2*device id
; Exit  - [BX] = device comma width as set by xxxSCW
;         All other registers preserved
;
LPTGCW:	RET	

;GLPDCB - get pointer to line printer device control block
; Entry - [DI] = -2*device id (2,4,..n)
; Exit  - DI points to the device control block for device DI.
;         [AX] = 0..n for LPT1, LPT2, ...
;
;************************************************************************
;* Note: IF LPT DCB size changes from 4, this routine should be changed *
;************************************************************************
;
GLPDCB:
	MOV	AX,OFFSET ($_LPT1-400O)	;[AX]=-device id for LPT1
	SHL	AX,1		;[AX]=-2*device id for LPT1
	ADD	AX,DI		;[AX]=0, 2, ... for LPT1, LPT2, ...
	MOV	DI,AX		;[DI]=0, 2, ... for LPT1, LPT2, ...
	SHL	DI,1		;[DI]=0, 4, ... for LPT1, LPT2, ...
	SHR	AX,1		;[AX]=0, 1, ... for LPT1, LPT2, ...
	ADD	DI,OFFSET LP1DCB	;[DI] points to LPTx device ctl block
	RET	
;
CSEG	ENDS
	END
                                           