; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	SUBTTL  GLOBAL TEMPS and DEFS
	TITLE   GIODSK - BASIC-86 Generalized I/O Disk Driver

COMMENT	*

--------- --- ---- -- ---------
COPYRIGHT (C) 1982 BY MICROSOFT
--------- --- ---- -- ---------

        T. Corbett      Microsoft   for BASIC-86 Generalized I/O
                        Based on code written for BASCOM-86
        *
	INCLUDE	GIO86U

CPM86=0

	INCLUDE	MSDOSU

	.SALL
	.RADIX	10


	EXTRN	CHRGTR:NEAR,SYNCHR:NEAR,OUTDO:NEAR
	EXTRN	DERNMF:NEAR,DERBFM:NEAR,DERBRN:NEAR,DERFAO:NEAR,FCERR:NEAR
	EXTRN	DERTMF:NEAR
	EXTRN	DERFAE:NEAR,DERFNF:NEAR,DERIOE:NEAR,DERDFL:NEAR,DERFOV:NEAR
	EXTRN	CONIA:NEAR,MAKINT:NEAR,MOVE1:NEAR,$NORMD:NEAR
	EXTRN	DEVBOT:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'		
	ASSUME DS:DSEG
	EXTRN	DFACLO:WORD,FAC:WORD,VALTYP:WORD
	EXTRN	RECRD:WORD,LBUFF:WORD,PBUFF:WORD
	EXTRN	FILNAM:WORD,FILNA2:WORD
DSEG	ENDS

	ASCCR=13D		;Ascii carriage return
	ASCCTZ=26D		;END OF FILE CHARACTER

;Disk Dispatch Table
;
	PUBLIC	DSKDSP
DSKDSP:
	DW	(DSKEOF)	;test EOF for file opened to this device
	DW	(DSKLOC)	;LOC - sequential records / last random record
	DW	(DSKLOF)	;LOF - file size
	DW	(DSKCLS)	;perform special CLOSE functions for this device
	DW	(FCERR)		;set device width
	DW	(DSKRND)	;GET/PUT random record from/to this device
	DW	(DSKOPN)	;perform special OPEN functions for this device
	DW	(DSKSIN)	;input 1 byte from file opened on this device
	DW	(DSKSOT)	;output 1 byte to file opened on this device
	DW	(DSKGPS)	;POS
	DW	(DSKGWD)	;get device width
	DW	(DSKSCW)	;set device comma width
	DW	(DSKGCW)	;get device comma width
	DW	(DFSTLD)	;block input from file opened on this device
	DW	(DEVBOT)	;block output to file opened on this device

	SUBTTL  Misc. Disk Routines

;DSKEOF - test for End-Of-File on device.
; Entry - SI points to File-Data-Block.
; Exit  - [BX] = -1 if EOF, 0 if not EOF
;
DSKEOF:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQO	;EOF( ) is Illegal
	JE	ER_BFM		; for Sequential Output
ORNCHK:
	XOR	AL,AL
	CMP	BYTE PTR F_ORCT[SI],AL	;zero if End of File
	JE	WASEOF		;Brif EOF
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_RND	;If mode is Random
	JZ	NOTEOF		; then don't return true EOF
	CMP	BYTE PTR F_BREM[SI],AL	;Any bytes left in buffer?
	JNZ	CHKCTZ		;Yes, look for Control-Z
	CALL	$READS		;Fill the Buffer
	JMP	SHORT ORNCHK	; and try again...
CHKCTZ:
	MOV	BX,OFFSET DATPSC
	SUB	BL,BYTE PTR F_BREM[SI]	;[BX] = char offset
	CMP	BYTE PTR DATOFS[BX+SI],LOW OFFSET ASCCTZ	;check for EOF
	JNZ	NOTEOF		;Brif next char not EOF
WASEOF:
	MOV	BX,-1		; -1 if EOF
	RET	
NOTEOF:
	XOR	BX,BX		;0 = not EOF
	RET	

ER_BFM:	JMP	DERBFM		;"Bad File mode"

;DSKLOC - Number of Bytes in input buffer.
; Entry - SI points to File-Data-Block.
; Exit  - [BX] = result.
;
DSKLOC:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_RND
	MOV	BX,WORD PTR F_CLOC[SI]	;Use current for Sequential
	JNE	LOC1
	MOV	BX,WORD PTR FD_LOG[SI]	;Use logical for Random
LOC1:	RET	

;DSKLOF - return file size in bytes.
; Entry - SI points to File-Data-Block.
; Exit  - [Floating-Point-Accumulator] = result.
;
DSKLOF:
	LEA	DX,DWORD PTR FCB_FS[SI]	;[DX] points to file size
	MOV	BX,OFFSET DFACLO-1	;[BX] Target
	MOV	BYTE PTR 0[BX],LOW 0	;zero overflow byte
	INC	BX
	MOV	CH,LOW 4
	CALL	MOVE1		;Move file length to FAC
	MOV	BYTE PTR FAC+1,CH	;zero sign
	MOV	WORD PTR 0[BX],CX	;zero high bytes of FAC
	MOV	WORD PTR 2[BX],OFFSET ((128+56)*256)	;Initialize Exponent
	MOV	BYTE PTR VALTYP,LOW 8	;Dbl prec value
	JMP	$NORMD		;Normalize value
;DSKGPS - return current file position.
; Entry - SI points to File-Data-Block.
; Exit  - [AH] = current file column. (0-relative)
;         All other registers preserved
;
DSKGPS:	MOV	AH,BYTE PTR F_POS[SI]	;[AH]=current column
	RET	

;DSKGWD - get device width
; Exit  - [AH] = device width as set by xxxSWD
;         All other registers preserved
;
DSKGWD:	MOV	AH,LOW 255D	;disk files always have infinite width
	RET	

;DSKSCW - set device comma width
; Entry - [BX] = new device comma width
; Exit  - SI, DI can be changed.
;         All other registers preserved
;
DSKSCW:

;DSKGCW - get device comma width
; Exit  - [BX] = device comma width as set by xxxSCW
;         All other registers preserved
;
DSKGCW:	RET	

	SUBTTL  OPEN hook for Disk and all Directory handling

	EXTRN	INIFDB:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FILMOD:WORD,FREFDB:WORD
DSEG	ENDS


;DSKOPN - perform any device dependent open functions.
; Entry - [AL] = FILDEV = device id
;                0 if default device,
;                1..n for Disk A:, B:, ...
;                -1..-n for non-disk devices
;         [BX] = file number (0..n)
;         [CX] = random record size if [FILMOD] = random
;                (if [CX] = 0, use default record size)
;         [DI] = device offset (2=DSKD, 4=SCRN, etc.)
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
DSKOPN:				;note: save [AL]=device ID till INIFDB
	CMP	BYTE PTR FILMOD,LOW OFFSET MD_RND
	JNZ	DSKOP2		;branch if not OPEN RANDOM
	OR	CX,CX
	JNZ	DSKOP2		;branch if user requested Record-Size
	MOV	CX,OFFSET DATPSC	;default to Bytes per Sector
DSKOP2:	PUSH	CX		;save user requested Random-Record-Size
	ADD	CX,OFFSET FD_DAT-FDBSIZ	;add standard Disk FDB requirements
	MOV	AH,LOW 255D	;all file-modes are legal for Disk
	MOV	DX,255D		;[DH]=initial file column position
				;[DL]=initial file width
	CALL	INIFDB		;SI points to new file's FDB
	MOV	WORD PTR FREFDB,SI	;save pointer to FDB so FINPRT will
				;release it if error occurs before file
				;gets completely opened.
	PUSH	SI		;save FDB pointer
	LEA	DI,DWORD PTR FCB_DV[SI]	;DI points to filename field within FDB
	MOV	SI,OFFSET FILNAM
	MOV	CX,OFFSET FNAML+1	;Moving drive,name,ext
	CLD			;Set Post-Increment mode
 REP	MOVSB			; to FDB's FCB
	MOV	BYTE PTR 0[DI],CL	;Make sure ext field is zero
	ADD	DI,OFFSET FCB_NR-FCB_EX	;Advance to NR field
	MOV	AX,CX		;[AX]=0
	CLD			;Set Post-Increment mode
	STOSW
	STOSW
	STOSB			;zero random record fields
	POP	SI		;SI points to new FDB
	POP	AX		;[AX]=random record size
	MOV	WORD PTR FD_SIZ[SI],AX	;save in FDB
	CALL	SETBUF		;Set Buffer addr
	MOV	AL,BYTE PTR FILMOD	;[AL]=file mode
	CMP	AL,LOW OFFSET MD_APP
	JNZ	NTOAPP		;Brif not open append
	CALL	CHKFOP		;check for file already open
NTOAPP:
	LEA	DX,DWORD PTR F_FCB[SI]	;[DX] = FCB for DOS calls
	CMP	AL,LOW OFFSET MD_SQO
	JNZ	OPNFIL		;Brif not sequential output
	CALL	CHKFOP		;must be unique
	CALLOS	C_DELE		;Delete file if exists
MAKFIL:
	CALLOS	C_MAKE		;Create file
	INC	AL		;Too many files?
	JNZ	OPNSET		;No, continue
	JMP	DERTMF		;"Too many files"
OPNFIL:
	CALLOS	C_OPEN		;Try OPEN
	INC	AL
	JNZ	OPNSET		;Brif found
	MOV	AL,BYTE PTR FILMOD	;Mode
	CMP	AL,LOW OFFSET MD_APP
	JNZ	NTAPNF		;Brif not append
	MOV	AL,LOW OFFSET MD_SQO	; else change to seq output
	JMP	SHORT MAKFIL
NTAPNF:
	CMP	AL,LOW OFFSET MD_RND	;If not Random
	JNZ	ER_FNF		; then File not found error
	JMP	SHORT MAKFIL	;and create new
ER_FNF:
	JMP	DERFNF		;"File not found"
OPNSET:
	MOV	WORD PTR FCB_RC[SI],128	;Record len = 128
	XOR	CX,CX
	MOV	WORD PTR F_CLOC[SI],CX	;Clear curloc
	MOV	WORD PTR F_CLOC+2[SI],CX	;Clear numloc
	MOV	AL,BYTE PTR FILMOD
	CMP	AL,LOW OFFSET MD_RND
	JZ	RNDFIN		;Brif finish random open
	CMP	AL,LOW OFFSET MD_APP
	JZ	APPFIN		;Brif finish append open
	CMP	AL,LOW OFFSET MD_SQI
	JNZ	OPNFIN		;If not input get text pointer/exit
	CALL	$READS		;Read 1st data block into buffer
OPNFIN:	MOV	WORD PTR FREFDB,0	;file is completely open.
				;FINPRT won't release FDB.
	RET	
RNDFIN:
	LEA	DI,DWORD PTR FD_PHY[SI]	;zero FD.PHY, FD.LOG, FD.OPS, sector buffer
	MOV	CX,OFFSET (FD_DAT-FD_PHY)	;number of bytes to be cleared
	XOR	AX,AX		;zeros
	CLD			;Set Post-Increment mode
 REP	STOSB			;zero data buffer and variable cells
	JMP	SHORT OPNFIN

; Append - Seek to eof, read a sector, find byte eof,
;          correct no. of bytes remaining, finish up
;          by changing file mode to sequential output.
APPFIN:
	CMP	WORD PTR FCB_FS[SI],CX	;Test for empty file
	JNZ	NTZRF1		;Brif file not empty
	CMP	WORD PTR FCB_FS+2[SI],CX
	JNZ	NTZRF1
	MOV	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQO	;Change mode to Seq output
	JMP	SHORT OPNFIN	; and exit
NTZRF1:
	LEA	DI,DWORD PTR FCB_RN[SI]	;DI points to random record# field
	PUSH	SI		;Save FDB pointer
	ADD	SI,OFFSET FCB_FS	;Move to File Size
	TEST	BYTE PTR 0[SI],LOW 127D	;See if multiple of 128
	CLD			;Set Post-Inc mode for next 10 lines
	PUSHF			;and remember
	LODSB			;Get low order of size
	ADD	AL,AL		;Rotate hi bit into carry
	LODSW			;Get middle word
	ADC	AX,AX		;carry in, hi bit out
	STOSW			;Save low word of rec no.
	LODSB			;Get high byte
	MOV	AH,LOW 0	;Clear hi byte of rec no.
	ADC	AX,AX		;consider carry
	STOSW			;Store hi word of rec no.
	POPF			;get record flag
	POP	SI
	JNZ	NOMTRC		;Brif record not empty
	CALL	BAKURN		; else backup so can align
NOMTRC:
	CALL	$READS		;read a sector
	CALL	BAKURN		;back up 1 record
	XOR	DX,DX		;clear count of chars in buff
REDEOF:
	CALL	DSKINP		;read until EOF
	JB	SETSQM		;Brif physical EOF
	CMP	AL,LOW OFFSET ASCCTZ	;check for logical eof (ctl Z)
	JZ	SETSQO		;Brif found eof
	INC	DX
	JMP	SHORT REDEOF
SETSQM:
	XOR	DX,DX		;zero count since next sector
	CALL	BAKURN		;backup since read to far
SETSQO:
	MOV	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQO	;now we're Seq output
	LEA	DI,DWORD PTR F_CLOC[SI]
	XOR	AX,AX
	CLD			;Set Post-Increment mode
	STOSW			;zero curloc since empty
	MOV	BYTE PTR 0[DI],DL	;store no. of bytes left
	MOV	BYTE PTR F_POS[SI],AL	;zero print position
	JMP	SHORT OPNFIN
BAKURN:
	SUB	WORD PTR FCB_RN[SI],1	;Random rec no. -1
	JAE	BAKRET		;Brif no underflow
	DEC	WORD PTR FCB_RN+2[SI]	;hi word -1
BAKRET:	RET	

	SUBTTL  CLOSE (CLSFIL) hook for Disk files

;DSKCLS - perform any device dependent close functions.
; Entry - SI points to File-Data-Block.
; Exit  - All registers used.
;         This routine is called before BASIC releases the
;         file-data-block associated with this file.
;
DSKCLS:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQO
	JNE	NOFORC		;Don't dump buffer unless Seq Output
	MOV	AL,LOW OFFSET ASCCTZ
	CALL	FILOU4		;Write EOF char
	CMP	BYTE PTR F_ORCT[SI],LOW 0
	JE	NOFORC		;Brif buffer flushed
	CALL	$WRITS		;Flush the buffer
NOFORC:
	CALL	SETBUF		;Set DMA addr
	LEA	DX,DWORD PTR F_FCB[SI]	;[DX] = FCB
	CALLOS	C_CLOS		;Close the file
	RET	

	SUBTTL Disk Sequential Input

;DSKSIN - Sequential Input.
; Entry - SI points to File-Data-Block.
; Exit  - [AL] = next byte from file,
;         carry set if EOF.
;         All other registers preserved
;
DSKSIN:	CALL	DSKINP		;get next byte from file
	JB	DSYEOF		;branch if End-Of-File
	CMP	AL,LOW OFFSET ASCCTZ	;check for CTL-Z
	JNE	DSNEOF		;branch if not
	CMP	BYTE PTR F_CODE[SI],LOW OFFSET FC_BIN
	JE	DSNEOF		;CTL-Z is not EOF for Binary files
DSYEOF:	STC			;set carry indicating EOF
	RET	
DSNEOF:	OR	AL,AL		;clear carry (no eof)
	RET	

;DSKINP - get next byte from file [SI]
; Exit  - Carry set if EOF, else [AL]=next byte from file
;         All other registers preserved
;
DSKINP:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_RND
	JNE	SINP1		;Brif not Random
	JMP	SHORT SINP50	;Do Serial input from random
SINP1:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQO	;If trying input on output file
	JE	FILLS1		; then give "Input past end"
	CMP	BYTE PTR F_BREM[SI],LOW 0
	JE	FILLSQ		;If buffer empty, get another
	PUSH	BX
	XOR	BX,BX
	MOV	BL,BYTE PTR F_ORCT[SI]
	SUB	BL,BYTE PTR F_BREM[SI]
	DEC	BYTE PTR F_BREM[SI]	;number left -1
	MOV	AL,BYTE PTR DATOFS[BX+SI]	;Get the character
	POP	BX
	OR	AL,AL		;Clear carry
	RET	
FILLSQ:
	CMP	BYTE PTR F_ORCT[SI],LOW 0
	JE	FILLS1		;Brif EOF
	CALL	$READS		;read next sector
	JNE	SINP1		;If not EOF try again
FILLS1:
	STC			;Return with carry
	MOV	AL,LOW OFFSET ASCCTZ	; and EOF character
	RET	

SINP50:				;Serial Input from Random File
	PUSH	BX
	CALL	FOVCHK		;Field overflow check
	MOV	AL,BYTE PTR FD_DAT-1[BX+SI]	;Get character
	CLC	
	POP	BX
	RET	
FOVCHK:
	MOV	BX,WORD PTR FD_OPS[SI]	;Get current posn
	CMP	BX,WORD PTR FD_SIZ[SI]	;check for end of field
	JE	ER_FOV		;Brif field overflow
	INC	BX		;posn +1
	MOV	WORD PTR FD_OPS[SI],BX	;store new posn
	RET	
ER_FOV:
	JMP	DERFOV		;"Field Overflow"

	SUBTTL Disk Sequential Output

;DSKSOT - Sequential Output.
; Entry - SI points to File-Data-Block.
;         [AL] = byte to be output.
; Exit  - All registers preserved.
;
DSKSOT:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQI	;If input then must be echoing
	JZ	FILOUX		; or "Extra ignored", so toss it
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_RND
	JNZ	FILOU4		;branch if sequential access
	PUSH	BX		;Do Serial output to random
	CALL	FOVCHK		;check for FIELD overflow
	MOV	BYTE PTR FD_DAT-1[BX+SI],AL	;store character
	POP	BX
	JMP	SHORT SOUTPS	;Update posn and exit
FILOU4:
	CMP	BYTE PTR F_ORCT[SI],LOW OFFSET DATPSC
	JNE	SOUT2		;Brif not at end of sector
	CALL	$WRITS		;Write previous sector
SOUT2:
	PUSH	BX
	XOR	BX,BX
	MOV	BL,BYTE PTR F_ORCT[SI]	;[BX] = Buffer offset
	MOV	BYTE PTR DATOFS[BX+SI],AL	;store char
	POP	BX
	INC	BYTE PTR F_ORCT[SI]
SOUTPS:
	CMP	AL,LOW OFFSET ASCCR
	JNE	SOUT3
	MOV	BYTE PTR F_POS[SI],LOW 0	;reset posn on CR
FILOUX:
	RET	

SOUT3:
	CMP	AL,LOW " "
	CMC	
	ADC	BYTE PTR F_POS[SI],LOW 0	;posn +1  if printable char
	RET	


	SUBTTL GET and PUT for Disk Files

	PGFLAG=1		;On = PUT, Off = GET
	RELFLG=2		;On = Relative, Off = Sequential
	DIRFLG=4		;On = Write, Off = Read

ER_BRN:	JMP	DERBRN		;bad record number error
ER_FC:	JMP	FCERR		;function call error

;DSKRND - perform random I/O.
; Entry  - [AL] = function to be performed:
;                 0: get next record
;                 1: put next record
;                 2: get record [DX] (1-relative)
;                 3: put record [DX] (1-relative)
;          [SI] points to File-Data-Block
; Exit   - All registers are used.
;
DSKRND:
	TEST	AL,LOW OFFSET RELFLG
	JNZ	RAND1		;Brif not relative I/O
	MOV	DX,WORD PTR FD_LOG[SI]	;[DX] = current logical record
	INC	DX		;Logical +1
	JMP	SHORT RAND2
RAND1:
	OR	DX,DX		;See if ok
	JLE	ER_BRN		;Error if record number .LEQ. 0
RAND2:
	MOV	WORD PTR FD_LOG[SI],DX	;Store next logical
	DEC	DX		;[DX] = current logical
	MOV	WORD PTR FD_OPS[SI],0	;Clear output posn
	MOV	BX,WORD PTR FD_SIZ[SI]	;[BX] = logical record length
	PUSH	BX
	CMP	BX,OFFSET DATPSC	;Logical = Physical?
	JE	RAND3		;Brif so
	XCHG	AX,BX		;Save flags
	MUL	DX		;Logical * physical (byte off)
	XCHG	AX,BX		;[DX,BX] = result
	ADD	BX,BX		;Offset *2 (for /128)
	ADC	DX,DX		;consider overflow
	OR	DH,DH
	JNZ	ER_FC		;Brif too big
	MOV	DH,DL
	MOV	DL,BH		;[DX] = physical record no.
	SHR	BL,1
	XOR	BH,BH		;[BX] = offset into physical rec
	JMP	SHORT RAND4
RAND3:
	XOR	BX,BX		;[BX] (offset = 0)

; [DX] = physical record number
; [BX] = offset into physical record
RAND4:
	MOV	WORD PTR RECRD,DX	;Save record no.
	LEA	CX,DWORD PTR FD_DAT[SI]	;[CX] = Field buffer addr
	MOV	WORD PTR LBUFF,CX	;Save Logical buffer addr
	POP	DX		;Get record length

; [DX] = bytes left to transfer (initially record length)
; [BX] = offset into current record
NXTOPD:
	LEA	CX,DWORD PTR DATOFS[SI]	;[CX] = Physical buffer addr
	ADD	CX,BX		;       + offset
	MOV	WORD PTR PBUFF,CX	;Save physical offset
	MOV	CX,OFFSET DATPSC
	SUB	CX,BX		;[CX] = bytes left in buffer
	CMP	CX,DX		;want smaller of bufl, recl
	JB	DATMOF		;[CX] = left in buffer
	MOV	CX,DX		;[CX] = left in record
DATMOF:
	TEST	AL,LOW OFFSET PGFLAG
	JZ	FIVDRD		;Brif read (GET)
	CMP	CX,OFFSET DATPSC
	JAE	NOFVRD		;Brif writing entire sector
	CALL	GETSUB		; else read current sector
NOFVRD:
	PUSH	SI
	PUSH	CX
	MOV	SI,WORD PTR LBUFF
	MOV	DI,WORD PTR PBUFF
	SHR	CX,1
	CLD			;Set Post-Increment mode
 REP	MOVSW
	JNB	EVENLP
	MOVSB
EVENLP:
	POP	CX
	POP	SI
	CALL	PUTSUB		;Write thru to current sector
	JMP	SHORT NXFVBF

FIVDRD:
	CALL	GETSUB		;Read current record
	PUSH	SI
	PUSH	CX
	MOV	SI,WORD PTR PBUFF
	MOV	DI,WORD PTR LBUFF
	SHR	CX,1
	CLD			;Set Post-Increment mode
 REP	MOVSW
	JNB	EVENPL
	MOVSB
EVENPL:
	POP	CX
	POP	SI
NXFVBF:
	INC	WORD PTR RECRD	;current record +1
	ADD	WORD PTR LBUFF,CX	;logical offset +length
	SUB	DX,CX		;offset - bytes transfered
	XOR	BX,BX		;zero buffer offset
	OR	DX,DX		;More to transfer?
	JNZ	NXTOPD		; then continue
	RET	

; Sector I/O routines for Random

PUTSUB:
	OR	AL,LOW OFFSET DIRFLG	;Set write flag
	JMP	SHORT PGSUB1
GETSUB:
	AND	AL,LOW OFFSET 255-DIRFLG	;Clear write flag (read)
PGSUB1:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	MOV	BX,WORD PTR RECRD	;Get record no.
	INC	BX
	CMP	BX,WORD PTR FD_PHY[SI]	;current record in buffer?
	JNE	NTREDS		;Brif not
	TEST	AL,LOW OFFSET DIRFLG	;Was it read?
	JZ	PGRET		; then got it
NTREDS:
	DEC	BX
	MOV	WORD PTR F_CLOC[SI],BX	;Set CURLOC to physical rec.
	MOV	BYTE PTR F_ORCT[SI],LOW OFFSET DATPSC
	MOV	BYTE PTR F_BREM[SI],LOW OFFSET DATPSC
	MOV	WORD PTR FCB_RN[SI],BX	;Set record number
	MOV	WORD PTR FCB_RN+2[SI],0
	TEST	AL,LOW OFFSET DIRFLG
	JZ	GET1		;Brif read
	CALL	$WRITS		; else Write it
	JMP	SHORT PGRET
GET1:
	CALL	$READS		;Read it
PGRET:	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET	

	SUBTTL Primitive Disk sector I/O routines

;$READS - Read sector from file
; Entry - SI points to FDB
; Exit  - [AL] = 0 if no error.  FLAGS used.
;         All other registers are preserved
;
$READS:
	PUSH	CX
	PUSH	DI
	INC	WORD PTR F_CLOC[SI]	;Logical record +1
	MOV	CX,OFFSET DATPSC/2
	XOR	AX,AX
	LEA	DI,DWORD PTR DATOFS[SI]
	CLD			;Set Post-Increment mode
 REP	STOSW			;zero physical buffer
	CALL	SETBUF		;Set DMA
	MOV	AH,LOW OFFSET C_RNDR
	CALL	ACCFIL		;Read random
	OR	AL,AL
	MOV	AL,LOW 0	;Len = 0 for EOF
	JNZ	READ1
	MOV	AL,LOW OFFSET DATPSC	; else len = sector size
READ1:
	MOV	BYTE PTR F_ORCT[SI],AL	;Clear offset into buffer
	MOV	BYTE PTR F_BREM[SI],AL	;Set number of bytes left
	OR	AL,AL		;zero if EOF
	POP	DI
	POP	CX
	RET	

;$WRITS - Write sector to file
; Entry - SI points to FDB
; Exit  - All registers preserved
;
$WRITS:
	PUSH	AX
	MOV	BYTE PTR F_ORCT[SI],LOW 0	;Clear buffer offset
	CALL	SETBUF		;Set DMA
	MOV	AH,LOW OFFSET C_RNDW
	CALL	ACCFIL		;Write Random
	CMP	AL,LOW 255D
	JZ	ER_TMF		;Brif "Too many Files"
	DEC	AL
	JZ	ER_IOE		;Brif error extending file
	DEC	AL
	JNZ	WRITE1
	MOV	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQI	;So CLOSE won't give same error
				;when it tries to output CTL-Z EOF
	JMP	DERDFL		;"Disk Full"
WRITE1:
	INC	WORD PTR F_CLOC[SI]	;Logical record +1
	POP	AX
	RET	

ER_TMF:	JMP	DERTMF		;"Too many Files"
ER_IOE:	JMP	DERIOE		;"Device I/O error"

;Set OS I/O buffer address to DATOFS(.SI)
;
SETBUF:
	PUSH	DX
	LEA	DX,DWORD PTR DATOFS[SI]	;[DX] = Data buffer addr
	CALLOS	C_BUFF
	POP	DX
	RET	

ACCFIL:
	PUSH	DX
	LEA	DX,DWORD PTR F_FCB[SI]	;[DX] = FCB
	CALLOS			;Do OS I/O Op
	INC	WORD PTR FCB_RN[SI]	;Record no. +1
	JNZ	ACCFL1
	INC	WORD PTR FCB_RN+2[SI]	;High order +1
ACCFL1:
	CMP	AH,LOW OFFSET C_RNDW	;Was it Random Write?
	JNE	ACCFL2		;Brif not
	OR	AL,AL		; else map into 1.4 errors
	JZ	ACCRET		;Brif no errors
	CMP	AL,LOW 5
	JE	ER_TMF		;5 - Too many files
	CMP	AL,LOW 3
	MOV	AL,LOW 1	;Map 5 to 1
	JE	ACCRET
	INC	AL		; else Disk full
	JMP	SHORT ACCRET
ACCFL2:
	CMP	AL,LOW 3	;Partial sector read?
	JNE	ACCRET		;Brif not
	XOR	AL,AL		;Map 3 to 0 (no error)
ACCRET:
	POP	DX
	RET	

	SUBTTL CHKFOP - Check for file already OPEN

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FILTAB:WORD,STKLOW:WORD
DSEG	ENDS

; Entry: SI points to FDB in question
; Exit:  Control returns to DERFAO if file is open
; Uses:  CX,DI
;
CHKFOP:
	PUSH	AX
	CMP	BYTE PTR FCB_DV[SI],LOW 0	;Default Drive?
	JNE	NTCRDV
	CALLOS	C_GDRV
	INC	AL		;Convert A: to 1.. etc.
	MOV	BYTE PTR FCB_DV[SI],AL	;Store real drive no.
NTCRDV:
	MOV	DI,WORD PTR FILTAB	;Start with first FDB in chain
CHKNFL:
	CMP	DI,WORD PTR STKLOW
	JE	CHKFLX		;branch if at end of FDB chain
	CMP	SI,DI
	JE	IGNTFL		;branch if same as FDB in question
	PUSH	SI
	PUSH	DI
	ADD	SI,OFFSET F_FCB
	ADD	DI,OFFSET F_FCB
	MOV	CX,OFFSET FNAML+1
;compare filenames, mapping lower case to upper case
CMPLOP:
	MOV	AL,BYTE PTR 0[SI]	;get char from filename1
	CALL	MAKUPC		;[AL]=uppercase([AL])
	MOV	AH,AL
	MOV	AL,BYTE PTR 0[DI]	;get char from filename2
	CALL	MAKUPC		;[AL]=uppercase([AL])
	CMP	AL,AH
	JNE	NTSAME		;branch if not the same filename
	INC	SI		;bump filename1 pointer
	INC	DI		;bump filename2 pointer
	LOOP	CMPLOP		;compare all characters in filenames
	JMP	DERFAO		;error, file already open
NTSAME:	POP	DI
	POP	SI
IGNTFL:
	MOV	DI,WORD PTR F_NEXT[DI]	;get next FDB in chain
	JMP	SHORT CHKNFL
CHKFLX:
	POP	AX
	RET	

MAKUPC:
	CMP	AL,LOW "a"
	JB	NOTLC		;branch if not a..z
	CMP	AL,LOW OFFSET "z"+1
	JNB	NOTLC		;branch if not a..z
	AND	AL,LOW 337O	;map a..z to A..Z
NOTLC:
	RET	

	SUBTTL  DFSTLD - Fast Binary Program Load (from DISK)

	PUBLIC	DFSTLD
	EXTRN	OUTLOD:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FRETOP:WORD,PTRFIL:WORD
DSEG	ENDS

;DFSTLD - read block of memory from Disk
; Entry - [BX] = offset of destination
;         [CX] = maximum number of bytes to read
;         [DX] = data segment of destinanation
;         PTRFIL points to FDB of file to be loaded
; Exit  - BX points 1 byte beyond last byte read
;         Carry set reached end-of-file before CX bytes were read
;
DFSTLD:
	PUSH	BX		;save start adr
	PUSH	CX		;save max byte count
	PUSH	DS		;save BASIC's Data Segment adr
	PUSH	BX		;save start adr
	PUSH	DX		;save block read Data Segment adr
	MOV	SI,WORD PTR PTRFIL	;SI points to current FDB
	MOV	AL,BYTE PTR F_ORCT[SI]
	SUB	AL,BYTE PTR F_BREM[SI]	;[AL]=# bytes read so far
	MOV	BYTE PTR FCB_RN[SI],AL	;set next rec #
	MOV	WORD PTR FCB_RC[SI],1	;Set File logical record size = 1 byte
	POP	DS		;[DS]=segment adr of block read
	POP	DX		;[DX]=start adr
	CALLOS	C_BUFF		;Set DMA to TXTTAB
	POP	DS		;restore BASIC's data segment adr
	LEA	DX,DWORD PTR F_FCB[SI]	;FCB
	POP	CX		;[CX]=max number of bytes to read
	CALLOS	C_RBR		;Load the Program!
	POP	BX		;BX points to start of load
	ADD	BX,CX		;BX points 1 byte beyond last byte read
	CMP	AL,LOW 1
	CMC			;set carry if [AL] exceeds 1 (EOF)
	RET	

	SUBTTL  PROSAV - Protected SAVE
	PUBLIC	PROSAV,CMPFBC
	EXTRN	SCCPTR:NEAR,GTMPRT:NEAR,BINPSV:NEAR,$EXPCN:NEAR,$LOGP:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	TXTTAB:WORD,VARTAB:WORD,CURLIN:WORD,PROFLG:WORD,TEMP:WORD
DSEG	ENDS

PROSAV:	CALL	CHRGTR		;skip "P"
	MOV	WORD PTR TEMP,BX	;Save text pointer
	CALL	SCCPTR		;Get rid of GOTO pointers
	CALL	PENCOD		;Encode binary
	MOV	AL,LOW 254D	;ID byte for Protected files
	CALL	BINPSV		;Do the SAVE
	CALL	PDECOD		;Decode binary
	JMP	GTMPRT		;return to NEWSTT

GETFSZ:	MOV	BX,OFFSET FD_SIZ	;Point to record size
	JMP	SHORT GETFP1	;Continue
GETFPS:	MOV	BX,OFFSET FD_OPS	;Point to output position
GETFP1:	ADD	BX,CX		;Add offset into buffer
	MOV	DX,WORD PTR 0[BX]	;Get value
	RET	

CMPFBC:	MOV	CX,BX		;Copy file data block into [CX]
CMPFPS:	CALL	GETFPS		;Get present posit
	PUSH	DX		;Save it
	CALL	GETFSZ		;Get file size
	MOV	BX,DX		;into [BX]
	POP	DX		;Get back posit
	CMP	BX,DX		;See if were at end
RET12:	RET	

	N1=11D			;Number of bytes to use from ATNCON
	N2=13D			;Number of bytes to use from SINCON

	PUBLIC	PENCOD
PENCOD:	MOV	CX,OFFSET N1+N2*256D	;Initialize both counters
	MOV	BX,WORD PTR TXTTAB	;Starting point
	MOV	DX,BX		;Into [DX]
ENCDBL:	MOV	BX,WORD PTR VARTAB	;At end?
	CMP	BX,DX		;Test
	JZ	RET12		;Yes
	MOV	BX,OFFSET $EXPCN
	MOV	AL,CL		;Use [CL] to index into it
	CBW	
	ADD	BX,AX
	MOV	SI,DX
	CLD			;Set Post-Increment mode
	LODSB			;[AL]=byte from program
	SUB	AL,CH		;Subtract counter for no reason
	XOR	AL,BYTE PTR CS:0[BX]	;XOR entry
	PUSH	AX		;Save result
	MOV	BX,OFFSET $LOGP
	MOV	AL,CH
	CBW	
	ADD	BX,AX
	POP	AX		;Get back current byte
	XOR	AL,BYTE PTR CS:0[BX]	;XOR on this one too
	ADD	AL,CL		;Add counter for randomness
	MOV	DI,DX
	CLD			;Set Post-Increment mode
	STOSB			;store back in program
	INC	DX		;Incrment pointer
	DEC	CL		;decrment first table index
	JNZ	CNTZER		;Still non-Zero
	MOV	CL,LOW OFFSET N1	;Re-initialize counter 1
CNTZER:	DEC	CH		;dedecrement counter-2
	JNZ	ENCDBL		;Still non-zero, go for more
	MOV	CH,LOW OFFSET N2	;Re-initialize counter 2
	JMP	SHORT ENCDBL	;Keep going until done
	PUBLIC	PROLOD
PROLOD:
PDECOD:	MOV	CX,OFFSET N1+N2*256	;Initialize both counters
	MOV	BX,WORD PTR TXTTAB	;Starting point
	MOV	DX,BX		;Into [D,E]
DECDBL:	MOV	BX,WORD PTR VARTAB	;At end?
	CMP	BX,DX		;Test
	JZ	RET12		;Yes
	MOV	BX,OFFSET $LOGP
	MOV	AL,CH
	CBW	
	ADD	BX,AX
	MOV	SI,DX
	CLD			;Set Post-Increment mode
	LODSB			;[AL]=byte from program
	SUB	AL,CL		;Subtract counter for randomness
	XOR	AL,BYTE PTR CS:0[BX]	;XOR on this one too
	PUSH	AX		;Save result
	MOV	BX,OFFSET $EXPCN
	MOV	AL,CL		;Use [CL] to index into it
	CBW	
	ADD	BX,AX
	POP	AX		;Get back current byte
	XOR	AL,BYTE PTR CS:0[BX]	;XOR entry
	ADD	AL,CH		;Add counter for no reason
	MOV	DI,DX
	CLD			;Set Post-Increment mode
	STOSB			;store [AL] back in program
	INC	DX		;Increment pointer
	DEC	CL		;decrment first table index
	JNZ	CNTZR2		;Still non-Zero
	MOV	CL,LOW OFFSET N1	;Re-initialize counter 1
CNTZR2:	DEC	CH
	JNZ	DECDBL		;Decrement counter-2, Still non-zero, go for more
	MOV	CH,LOW OFFSET N2	;Re-initialize counter 2
	JMP	SHORT DECDBL	;Keep going until done

	PUBLIC	PROCHK,PRODIR
PRODIR:	PUSH	BX		;Save [H,L]
	MOV	BX,WORD PTR CURLIN	;Get current line #
	INC	BX		;Direct? (if BX=0, direct)
	POP	BX		;Restore [H,L]
	JZ	PROCHK
	RET	

PROCHK:	PUSHF			;Save flags
	MOV	AL,BYTE PTR PROFLG	;Is this a protected file?
	OR	AL,AL		;Set CC's
	JNZ	FCERRA		;Yes, give error
	POPF			;Restore flags
	RET	

FCERRA:	JMP	FCERR
	PAGE	
	SUBTTL  KILL, FILES, NAME commands

	PUBLIC	FILES,KILL,NAME
	EXTRN	FRMEVL:NEAR,FRESTR:NEAR,CRDO:NEAR,POLKEY:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	LINLEN:WORD,BUF:WORD
DSEG	ENDS

;Assumptions:
; FILNAM and FILNA2 are 33 byte buffers (for temp FCBs)

;FILES [ filename ]
; FILES command [List the Directory]
; If filename is omitted, all files on the logged
; disk are listed.
; If supplied, all files matching filename or wildcards
; are listed.
;
FILES:
	JE	NOARG		;Brif no filename argument given
	CALL	NAMFIL		;[SI] points to 1st byte of filename
				;[CX] = number of bytes in filename
	CMP	CL,LOW 2
	JNE	GOTNAM		;branch if not "<drive>:"
	MOV	AX,WORD PTR 0[SI]	;[AX]=filename
	CMP	AH,LOW ":"
	JNE	GOTNAM		;branch if not "<drive>:"
	MOV	SI,OFFSET FILNA2+2	;[SI] points to buffer for building filename
	MOV	WORD PTR FILNA2,AX	;Store <drive>: in filename buffer
	JMP	SHORT ALFILS	;append "*.*" to name
NOARG:
	MOV	SI,OFFSET FILNA2	;[SI] points to buffer for building filename
	XOR	CX,CX
ALFILS:
	MOV	WORD PTR 0[SI],OFFSET (400O*".")+"*"
	MOV	WORD PTR 2[SI],"*"
	ADD	CX,3		;[CX] = number of bytes in filename
	MOV	SI,OFFSET FILNA2	;[SI] points to filename
GOTNAM:
	CALL	FILFCB		;FILNAM=un-opened FCB for filename
	MOV	DX,OFFSET FILNA2	;tells OS to put FCB for matching directory
	CALLOS	C_BUFF		; entries in FILNA2
	MOV	DX,DI		;[DX] = search FCB (FILNAM)
	CALLOS	C_SEAR		;Search 1st
	INC	AL
	JNZ	FILNXT		;Brif found
	JMP	DERFNF		; else complain
FILNXT:
	CALL	POLKEY		;Allow CTL-C, CTL-S between every filename
	MOV	SI,OFFSET FILNA2+1	;Point at name
	MOV	CX,OFFSET FNAML	;Characters in name
MORNAM:
	CLD			;Set Post-Increment mode
	LODSB			;Get character
	CALL	OUTDO		;Output it
	CMP	CX,4
	JNE	NOTEXT		;Not at extension break
	MOV	AL,BYTE PTR 0[SI]	;Get 1st char of extension
	CMP	AL,LOW " "
	JE	PRISPA		;Blank extension - print space
	MOV	AL,LOW "."	;Print .
PRISPA:
	CALL	OUTDO		;Print blank or dot
NOTEXT:
	LOOP	MORNAM		;Loop until 11 characters
EXTRN	PTRWID:NEAR
	CALL	PTRWID		;[AH]=line width
	MOV	CH,AH		;[CH]=line width
EXTRN	PTRGPS:NEAR
	CALL	PTRGPS		;[AL]=current column
	ADD	AL,LOW 14D	;Position after next file name
	CMP	AL,CH
	JAE	NWFILN		;Force CR/LF
	MOV	AL,LOW " "
	CALL	OUTDO
	JMP	SHORT NEXTFL
NWFILN:
	CALL	CRDO		;Type CR/LF
NEXTFL:
	MOV	DX,OFFSET FILNAM	;[DX] points to search template
	XOR	AL,AL
	CALLOS	C_SEAR+1	;Search next
	CMP	AL,LOW 255D
	JNE	FILNXT		;branch if still more
EXTRN	CRDONZ:NEAR
	JMP	CRDONZ		;carriage return if not in column 0

;KILL filename
; Entry - [BX] = text pointer
; Exit -  [BX] = text pointer
;
KILL:
	CALL	NAMFIL		;[SI] points to 1st byte of filename
				;[CX] = number of bytes in filename
	CALL	FILFCB		;FILNAM=un-opened FCB for filename
	PUSH	BX		;save text pointer
	MOV	DX,OFFSET FILNAM
	PUSH	DX		;Save FCB pointer
	CALLOS	C_OPEN		;Open file
	INC	AL
	JNZ	KILL2		;Brif file found
	JMP	DERFNF		;File not found
KILL2:	POP	DX		;DX points to FCB
	PUSH	DX
	CALLOS	C_CLOS		;Close file
	MOV	SI,OFFSET FILNAM-F_FCB	;Pretend we are FDB
	CALL	CHKFOP		;Check for conflict with open files
				;jumps to error if file is now opened
	POP	DX		;DX points to FCB
	CALLOS	C_DELE		;Delete file
	POP	BX		;text pointer
	RET	

;NAME oldname AS newname
; Entry - [BX] = text pointer
; Exit  - [BX] = text pointer
;
NAME:
	CALL	NAMFIL		;[SI] points to 1st byte of old filename
				;[CX] = number of bytes in filename
	PUSH	BX		;save text pointer
	CALL	FILFCB		;FILNAM=un-opened FCB for old filename
	MOV	DX,OFFSET FILNA2	;tells OS to put FCB for matching directory
	CALLOS	C_BUFF		; entries in FILNA2
	MOV	DX,DI		;[DX] = search FCB (FILNAM)
	CALLOS	C_SEAR		;Search 1st
	INC	AL
	JZ	NA_FNF		;File not found
	MOV	SI,OFFSET FILNAM-F_FCB	;Pretend we are FDB
	CALL	CHKFOP		;Check for conflict with open files
				;jumps to error if file is now opened
	MOV	SI,OFFSET FILNAM	;save old filename in FILNA2
	MOV	DI,OFFSET FILNA2
	MOV	CX,OFFSET FNAML+1	;+1 for drive
	CLD			;Set Post-Increment mode
 REP	MOVSB			;Move drive,name,ext from FILNAM to FILNA2
	POP	BX		;text pointer
	CALL	SYNCHR
	DB	OFFSET "A"	; must see "AS"
	CALL	SYNCHR
	DB	OFFSET "S"
	CALL	NAMFIL		;[SI] points to 1st byte of newfilename
				;[CX] = number of bytes in filename
	PUSH	BX		;text pointer
	CALL	FILFCB		;FILNAM=un-opened FCB for new filename
	MOV	AL,BYTE PTR FILNAM	;[AL]=drive for New filename
	OR	AL,AL		;test drive id of New filename
	JZ	SAMDRV		;branch if default drive
	CMP	AL,BYTE PTR FILNA2	;Compare with drive of original name
	JZ	SAMDRV		;branch if both drives are the same
EXTRN	DERRAD:NEAR
	JMP	DERRAD		;Rename Across Disks Error
SAMDRV:
	MOV	SI,OFFSET FILNAM+1	;move new filename,ext to FILNA2+17
	MOV	DI,OFFSET FILNA2+17D	;[DI] = dest for new file name
	MOV	CX,OFFSET FNAML	;No drive code
	CLD			;Set Post-Increment mode
 REP	MOVSB			;Move name
	MOV	DX,OFFSET FILNA2	;Point to FCB which contains both filenames
	CALLOS	C_RENA		;Rename file
	INC	AL		;error if attempted to create file which
	JE	NA_FAE		; already existed
	POP	BX		;text pointer
	RET	

NA_FNF:	JMP	DERFNF		;file not found
NA_FAE:	JMP	DERFAE		;file already exists

;NAMFIL - Scan a file name for NAME, KILL, or FILES command
; Entry - [BX] = text pointer
; Exit  - [BX] = text pointer
;         [SI] points to 1st byte of filename
;         [CX] = number of bytes in filename string
; Uses  - [AX]
;
NAMFIL:
	CALL	FRMEVL		;Evaluate string
	PUSH	BX		;save text pointer
	CALL	FRESTR		;Free the temp
	MOV	CL,BYTE PTR 0[BX]
	XOR	CH,CH		;[CX] = String len
	JCXZ	ER_NMF		;If null then bad name
	MOV	SI,WORD PTR 1[BX]	;[SI] = Filename string
	POP	BX
	RET	

ER_NMF:	JMP	DERNMF		;"Bad file name"

;FILFCB - Given filename "d:name:ext", create an un-opened FCB
; Entry - [SI] = points 1st byte of filename
;         [CX] = number of bytes in filename string
; Exit  - FILNAM is un-opened FCB equivalent for filename
;         [DI] points to 1st byte of FCB FILNAM
;         [AL] = FF if illegal drive or filename,
;                 1 if filename contained any "?" or "*" characters
;                 0 otherwise
; Uses  - BUF
;
FILFCB:
	MOV	DI,OFFSET BUF	;move filename to BUF buffer
	CLD			;Set Post-Increment mode

STRTNM:	XOR	AH,AH		;Count of chars in name portion:=0.
NAMORE:	OR	CX,CX		;Anything left?
	JE	TRMSTR		;No, go terminate the string in BUF.
	MOV	AL,BYTE PTR 0[SI]	;Yes, AL:=get next char of string.
	MOVSB			;Copy it to BUF.
	DEC	CX		;Decrement the length.
	CMP	AL,LOW ":"	;Colon indicating we were looking at a
				;device name?
	JE	STRTNM		;Yes, restart the count since we are now
				;looking at the filename.
	CMP	AL,LOW "."	;No, dot indicating start of extension?
	JE	FINNAM		;Yes, end of name.
	CMP	AL,LOW "*"	;The asterisk wild card also terminates the
	JE	FINNAM		;name for our purposes.
	CMP	AH,LOW 8D	;Have we already seen 8 name characters?
	JAE	LNGNAM		;Yes, the excess chars become the extension.
	INC	AH		;No, increment the name character count.
	JMP	SHORT NAMORE	;Go look at the next char.

LNGNAM:	MOV	BYTE PTR -1[DI],LOW "."	;Put in the dot so the extra chars look
	MOV	BYTE PTR 0[DI],AL	;like an extension.
	INC	DI
FINNAM:	OR	CX,CX		;Anything left?
	JE	TRMSTR		;No, terminate the string.  (Avoid REP with
                     ;a zero count.)
 REP	MOVSB			;Copy the remainder of the string to BUF.
TRMSTR:	MOV	BYTE PTR 0[DI],LOW 0	;store string terminator
	MOV	SI,OFFSET BUF	;parse 0 terminated filename in BUF
	MOV	DI,OFFSET FILNAM	; filling FDB FILNAM
	XOR	AL,AL		; don't skip any separators
	CALLOS	C_PARS
	OR	AL,AL		;test for legal filename
	JNE	FLFCBX		;branch if error or non-empty filename
	CMP	BYTE PTR FILNAM+1,LOW " "	;test 1st byte of filename
	JNE	FLFCBX		;branch if non-empty filename
	DEC	AL		;[AL] = FF (illegal filename)
FLFCBX:
	RET	

	SUBTTL  RESET and SYSTEM statements
;
; Entry/exit:   [BX] = text pointer

	PUBLIC	RESET
	EXTRN	CLSALL:NEAR,TKEYOF:NEAR

RESET:
	JNZ	RESETX		;if wasn't EOS
	PUSH	BX		;text pointer
	CALL	CLSALL		;Close all files
	CALLOS	C_GDRV		;Get drive number
	PUSH	AX
	CALLOS	C_REST		;Restore
	POP	AX
	MOV	DL,AL
	CALLOS	C_SDRV		;Set drive number
	POP	BX		;text pointer
RESETX:
	RET	


; SYSTEM - Exit BASIC

	PUBLIC	SYSTEM,SYSTME

	EXTRN	GWTERM:NEAR

SYSTEM:
	JNZ	RESETX		;If wasn't EOS
	CALL	CLSALL		;Close all files
SYSTME:
EXTRN	GIOTRM:NEAR
	CALL	GIOTRM		;call device termination routines
	CALL	GWTERM		;Do OEM specific termination processing
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CPMEXT:WORD	;MSDOS exit jump vector.
DSEG	ENDS
;translator can't handle JMPI ,adr yet
	PUSH	WORD PTR CPMEXT+2	;put segment adr on stack
	PUSH	WORD PTR CPMEXT	;put offset on stack
dumy  PROC    FAR
	RET			;intra-segment return
dumy  ENDP

CSEG	ENDS
	END
                                                                                       