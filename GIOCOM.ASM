; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   GIOCOM - Communications Machine Independent Device Driver Code

COMMENT	*

--------- --- ---- -- --------- -----------
COPYRIGHT (C) 1982 BY MICROSOFT CORPORATION
--------- --- ---- -- --------- -----------

        by Tom Corbett  Microsoft Corp.
        *

	INCLUDE	GIO86U
	.SALL

CPM86=0
COMPAQ=0			;Include IBM 1.0/1.1 Bugs for compatibility


	INCLUDE	MSDOSU


	PUBLIC	COMDSP,COMINI,COMTRM
	EXTRN	DERBFM:NEAR,INIFDB:NEAR,UPDPOS:NEAR,$_COM1:NEAR,BCHRSI:NEAR
	EXTRN	MAKINT:NEAR
	EXTRN	DEVBIN:NEAR,DEVBOT:NEAR

;Communications Dispatch Table
;
COMDSP:
	DW	(COMEOF)	;test EOF for file opened to this device
	DW	(COMLOC)	;LOC
	DW	(COMLOF)	;LOF
	DW	(COMCLS)	;perform special CLOSE functions for this device
	DW	(COMSWD)	;set device width
	DW	(COMRND)	;GET/PUT random record from/to this device
	DW	(COMOPN)	;perform special OPEN functions for this device
	DW	(COMSIN)	;input 1 byte from file opened on this device
	DW	(COMSOT)	;output 1 byte to file opened on this device
	DW	(COMGPS)	;POS
	DW	(COMGWD)	;get device width
	DW	(COMSCW)	;set device comma width
	DW	(COMGCW)	;get device comma Width
	DW	(DEVBIN)	;block input from file opened on this device
	DW	(DEVBOT)	;block output to file opened on this device
	PAGE	
	SUBTTL Communications Generalized I/O Routines

; RS232 Device Control Block Definition:
;
;   mneumonic offset    use
;   --------- ------    ---------------------------------------
	_DEVID=0D		;RS232 Channel ID (0..n)
	_BAUDR=1D		;baud rate (least significant byte 1st)
				;(0=disable device, 9600=9600 baud etc.)
	_BYTSZ=3D		;bits per byte (4..8)
	_PARIT=4D		;parity (0..4)=...(NONE, ODD, EVEN, MARK, SPACE)
	_STOPB=5D		;(0..2)= (1, 1.5, 2) stop bits
	_RLSTO=6D		;RLSD (rec. line signal detect) timeout
	_CTSTO=8D		;CTS (clear to send) timeout
	_DSRTO=10D		;DSR (data set ready) timeout
				;All timeout values are in milliseconds.
				;0=infinite, LSB is always 1st.
				;Support of Timeout Flags by BIOS is
				;optional.
	_CMFLG=12D		;Boolean attributes mask for this device
	_CMBIN=1O		;(0/1)=ASCII/BINARY (ASC option not in filename)
	_CMRTS=2O		;non-zero=Suppress Request-To-Send (RS option)
	_CMCOD=20O		;non-zero=user specified ASC or BIN in filename
	_CMCTS=40O		;non-zero=CTS parm not defaulted
	_CMCLF=100O		;non-zero=Send line feed after CR
	_CMCRF=200O		;non-zero=last char sent was Carriage Return

;If COM filename contains "ASC", .CMBIN=0, .CMCOD=1
;If COM filename contains "BIN", .CMBIN=1, .CMCOD=1
;If COM filename contains neither "ASC" nor "BIN", .CMBIN=1, .CMCOD=0
;If COM filename contains both "ASC" and "BIN", Illegal Filename occurs

;COM DCB Entries which are only of interest to BASIC (Not OEM routines)
;
				;*********************************************
				;*** .CMPOS must immediately follow .CMWID ***
				;*********************************************
	_CMWID=13D		;device width (columns per line)
	_CMPOS=14D		;current column device is in **must follow .CMWID**
	_CMFDB=15D		;points to FDB for file (0=not opened)

	CDCBSZ=24D		;bytes per COM Device Control Block (room for growth)

	EXTRN	INICOM:NEAR,RECCOM:NEAR,SNDCOM:NEAR,STACOM:NEAR,TRMCOM:NEAR	;OEM routines
	EXTRN	POLKEY:NEAR,DERIFN:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	ASSUME DS:DSEG
	EXTRN	CM1DCB:WORD
DSEG	ENDS

;COMINI - called during BASIC initialization
; Entry - DI = -2*device id
;
	PUBLIC	COMINI,COMTRM
COMINI:	PUSH	DI
	CALL	GCMDCB		;DI points to device control block
	MOV	BYTE PTR _CMWID[DI],LOW 255D	;default is infinite width
	MOV	WORD PTR _CMFDB[DI],0	;mark this device as available for open
	POP	DI
COMTRM:				;Com Termination Routine (End-of-BASIC)
	RET			; No action required


;POLCOM is called by CHKINT at beginning of every BASIC statement (NEWSTT).
; For each COM device which is opened to a device, it calls COMTRP if that
; device has input data waiting.
; Exit - AX, BX, CX, DX can be used (restored by CHKINT).
;        All other registers are preserved.
;
	PUBLIC	POLCOM
	EXTRN	COMTRP:NEAR

POLCOM:	PUSH	DI
	PUSH	SI
	MOV	DI,OFFSET CM1DCB	;DI points to device control block 1
	MOV	DX,OFFSET NMCOMT	;[DH]=COM unit#, [DL]=number of COM units
POLCML:	CALL	POLCM1		;test unit 1 for trap
	ADD	DI,OFFSET CDCBSZ	;DI points to next device control block
	INC	DH		;Bump unit id
	DEC	DL		;Decrement unit counter
	JNZ	POLCML		;branch if any more to test
	POP	SI
	POP	DI
	RET	

;POLCM1 checks 1 COM device to see if input is waiting, if so, it calls COMTRP
;
POLCM1:	MOV	SI,WORD PTR _CMFDB[DI]	;SI points to FDB (if device is opened)
	OR	SI,SI
	JZ	PLCM1X		;return if device not opened
	TEST	BYTE PTR F_FLGS[SI],LOW OFFSET FL_BKC
	JNE	POLTRP		;branch if backup-char present
	MOV	AH,DH		;[AH]=Unit#
	PUSH	DX		;save Unit#
	CALL	GCOMSZ		;[DX]=number of bytes queued
	OR	DX,DX		;test it
	POP	DX		;restore Unit#
POLTRP:	MOV	AL,DH		;[AL]=trap id (0..n)
	JE	PLCM1X		;branch if no com data queued
	CALL	COMTRP		;so ON-COM service routine will be called
PLCM1X:	RET	

;Get COM bytes in queue
;       On entry: AH = unit number
;       On return: DX=bytes in queue
;                  CX=free bytes in queue
;                   Does error processing if gets error from COM channel
GCOMSZ:	PUSH	AX
	CALL	STACOM
	OR	AH,AH		;Check status here even though
				;CKCMER does for speed.
	JNZ	CKCMER		;branch if got error from COM
	POP	AX
RET14:	RET	

; Check for COM I/O error and output COM Error Message if error occured.
; Entry - [AH] = non-zero if error occured
;
	EXTRN	STROUT:NEAR,OUTDO:NEAR,ERROR:NEAR
	EXTRN	ERRCBO:NEAR,ERRDPE:NEAR,ERRDTO:NEAR,ERRDIO:NEAR
CKCMER:
	OR	AH,AH
	JE	RET14		;branch if no COM I/O error detected
	MOV	AL,AH
	XOR	AH,AH		;[AX]=error code 1..n
	DEC	AX		;[AX]=error code 0..n
	MOV	DI,OFFSET CMERRT
	ADD	DI,AX		;[DI] points to BASIC Error code
	MOV	DL,BYTE PTR CS:0[DI]
	CMP	AL,LOW 5
	JB	ERROR1		;branch if legal error code
	MOV	DL,LOW OFFSET ERRDIO	;map all other error codes to I/O error
ERROR1:	JMP	ERROR

CMERRT:	DB	OFFSET ERRCBO	;buffer overflow error
	DB	OFFSET ERRDPE	;parity error
	DB	OFFSET ERRDTO	;device timeout
	DB	OFFSET ERRDTO	;device timeout
	DB	OFFSET ERRDTO	;device timeout
	PAGE	
	SUBTTL  COM OPEN
;
;    Syntax:   OPEN "COMn: [speed] [,parity] [,data] [,stop]
;              [,RS]  [,CS[n]]  [,DS[n]]  [,CD[n]] [,LF] [,BIN] [,ASC]" AS
;              [#]filenum
;
;                   SPEED     baud rate in bits per second
;                   PARITY    N, E, O (none, even, odd)
;                   DATA      5,6,7,8 bits per byte
;                   STOP      1, 1.5, 2 stop bits.
;                             Default for baud greater than 110 is 1.
;                             Default for 110 baud or lower & 5 data bits is 1.5
;                             Default for 110 baud or lower & 6-8 data bits is 2
;                   RS        Suppress RTS (Request To Send).
;                   CS[n]     Controls CTS (Clear To Send).
;                   DS[n]     Controls DSR (Data Set Ready).
;                   CD[n]     Controls CD (Carrier Detect).
;                             This is also referred to as RLSD
;                             (Received Line Signal Detect).
;                   LF        Send a Line-Feed character (X'0A')
;                             following a Carriage Return (X'0D').
;                   BIN       Open COM file in BINARY mode
;                   ASC       Open COM file in ASCII mode
;
;              The RTS (Request To Send)  line  is turned on
;              when you execute  an  OPEN  "COM... statement
;              unless you include the RS option.
;
;              If CD is omitted, it defaults to CS0.
;              If DS is omitted, it defaults to DS1000.
;              If CS is omitted, it defaults to CS1000.
;              If RS is specified and CS is omitted, then
;              CS defaults to 0.
;
;              Normally I/O  statements  to  a communication
;              file will fail if the CTS (Clear To Send)  or
;              DSR (Data Set Ready) lines  are  not  cabled.
;              The CS and DS options allow you to avoid this
;              problem by ignoring these  lines.  If the [n]
;              argument is included, it specifies the number
;              of milliseconds to wait for the signal before
;              returning a "Device Timeout"  error.
;
;              If the argument [n] in the CS, DS, and CD options
;              is omitted, or equal to 0, then that line's status
;              is not checked at all.
;
;              Note:   The  speed,  parity,  data, and  stop
;              parameters  are  positional, but RS, CS,  DS,
;              and CD may appear in any order after STOP.
;
;              The LF parameter is intended for  those using
;              communication files as a means of printing to
;              a serial line  printer.  When included in the
;              parameter list, LF will  cause  a  Line  Feed
;              character to be sent after a  Carriage return
;              character.

;COMOPN - perform any device dependent open functions.
; Entry - [AL]=  device id
;                0 if default device,
;                1..n for Disk A:, B:, ...
;                -1..-n for non-disk devices
;         [BX] = file number (0..n)
;         [CX] = random record size if [FILMOD] = random
;                (if [CX] = 0, use default record size)
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
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
;         All registers are used.
;

	EXTRN	DERFAO:NEAR

COMOPN:	MOV	AH,BL		;[AH]=file number
	PUSH	AX		;save file number, device id
	PUSH	CX		;save variable record len (if random)
	CALL	GCMDCB		;AX = 0, 1, ... for COM1, COM2, ...
				;DI points to Device Control Block
	CMP	WORD PTR _CMFDB[DI],0	;see if device is opened to another file
	JE	STUNIT		;not opened to another file
ERFAO1:	JMP	DERFAO		;File Already Opened
STUNIT:	MOV	BYTE PTR _DEVID[DI],AL	;set unit field of Device Control Block
	CALL	PCOMOP		;parse options (fill in DCB fields)
	TEST	BYTE PTR _CMFLG[DI],LOW OFFSET _CMRTS
	JE	NORTSO		;branch if RS option not specified
	TEST	BYTE PTR _CMFLG[DI],LOW OFFSET _CMCTS
	JNE	NORTSO		;branch if CTS parm specified
	MOV	WORD PTR _CTSTO[DI],0	;else default CTS to 0 seconds
NORTSO:
	CMP	BYTE PTR _STOPB[DI],LOW 255D
	JNE	STPNDF		;brif stop not defaulted
	INC	BYTE PTR _STOPB[DI]	;.STOPB=0 (1 stop bit)
	CMP	WORD PTR _BAUDR[DI],110D
	JA	STPNDF		;brif baud rate exceeds 110 (1 stop)
	INC	BYTE PTR _STOPB[DI]	;.STOPB=1 (1.5 stop bit)
	CMP	BYTE PTR _BYTSZ[DI],LOW 5
	JBE	STPNDF		;brif 4 or 5 bits per byte (1.5 stop)
	INC	BYTE PTR _STOPB[DI]	;110 baud & 6,7,8 data bits=2 stop bits
STPNDF:	MOV	BYTE PTR _CMPOS[DI],LOW 0	;reset column to 0
	MOV	BX,DI		;BX points to DCB
	CALL	INICOM		;call machine dependent OPEN routine
				;destroys FLAGS, AX..DX
	INC	AH
	JE	ERIFN1		;branch if Illegal Filename
	DEC	AH
	CALL	CKCMER		;see if INICOM didn't like options
	POP	CX		;[CX]=record length
	CMP	BYTE PTR FILMOD,LOW OFFSET MD_RND
	JNZ	NOTRND		;branch if not OPEN RANDOM
	OR	CX,CX
	JNZ	NOTDEF		;branch if user requested Record-Size
	MOV	CX,OFFSET DATPSC	;default to 128 (same as disk)
NOTDEF:	ADD	CX,OFFSET FD_DAT-FDBSIZ	;add standard Disk FDB requirements
NOTRND:	POP	AX		;[AL]=device id
	MOV	DX,WORD PTR _CMWID[DI]	;[DL]=width, [DH]=init position
				;from Device Control Block
	MOV	BL,AH
	MOV	BH,LOW 0	;[BX]=file number
	MOV	AH,LOW 255D	;allow all file modes
	PUSH	CX		;save Random Record Size
	CALL	INIFDB		;Initialize FDB
	POP	CX
	OR	CX,CX
	JZ	NTRND		;branch if mode is not random
	SUB	CX,OFFSET FD_DAT-FDBSIZ	;CX=record size requested by user
	MOV	WORD PTR FD_SIZ[SI],CX	;save in FDB
NTRND:	MOV	WORD PTR _CMFDB[DI],SI	;save FDB pointer in DCB
	TEST	BYTE PTR _CMFLG[DI],LOW OFFSET _CMBIN
	JZ	CMOPNX		;branch if user wants ASCII mode
EXTRN	SCDBIN:NEAR
	CALL	SCDBIN		;set CODE atr for file PTRFIL to BINARY
CMOPNX:
RET21:	RET	

ERIFN1:	JMP	DERIFN		;Illegal File Name

;Parse COM Open Options "baud, data, parity, stop"
;
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FILOPT:WORD
DSEG	ENDS
PCOMOP:	MOV	WORD PTR _BAUDR[DI],300D	;default baud rate = 300
	MOV	BYTE PTR _STOPB[DI],LOW 255D	;mark STOP bits as Default
	MOV	BYTE PTR _BYTSZ[DI],LOW 7D	;default physical byte size = 7
	MOV	BYTE PTR _PARIT[DI],LOW 2	;default parity = Even
	MOV	BYTE PTR _CMFLG[DI],LOW OFFSET _CMBIN	;default BINARY, CRLF = off
	MOV	WORD PTR _RLSTO[DI],0	;default Carrier Detect timeout=0
	MOV	WORD PTR _CTSTO[DI],1000D	;default Clear-To-Send timeout=1 sec
	MOV	WORD PTR _DSRTO[DI],1000D	;default Data Set Ready timeout=1 sec
	MOV	SI,OFFSET FILOPT	;SI points to options string
	CALL	GETPR0		;Get 1st char in Filename
	JZ	RET21		;Brif EOS
	JB	COMOP3		;Brif default Baud (Saw ",")
	DEC	SI		;Adjust for GETPRM
	CALL	VALGET		;Get Rate in [DX]
	MOV	WORD PTR _BAUDR[DI],DX	;save baud rate code
	CALL	GETPRM
	JZ	RET21		;branch if EOS
COMOP3:
	CALL	SYNPRM		;"," must follow or Illegal File Name
	MOV	CH,LOW 2	;Default parity=Even(2)
	JB	DFTPTY		;Brif Default (saw ",")
	XOR	CH,CH		;Map parity parameter to internal code
	CMP	AL,LOW "N"
	JZ	GOTPTY		;Map NONE to 0
	INC	CH
	CMP	AL,LOW "O"
	JZ	GOTPTY		;Map ODD to 1
	INC	CH
	CMP	AL,LOW "E"
	JZ	GOTPTY		;Map EVEN to 2
	INC	CH
	CMP	AL,LOW "M"
	JZ	GOTPTY		;Map MARK to 3
	INC	CH
	CMP	AL,LOW "S"
	JZ	GOTPTY		;Map SPACE to 4
ERIFN2:
	JMP	DERIFN		;Complain ("Illegal File Name")
DFTPTY:
	DEC	SI		;Adjust for GETPRM
GOTPTY:
	MOV	BYTE PTR _PARIT[DI],CH	;save parity in DCB
	CALL	GETPRM		;Scan off end of Parity field
	JZ	COMOP5		;Brif EOS, Default Data/Stop bits
	CALL	SYNPRM		; else Data bits must follow
	JB	COMOP4		;Brif saw "," try for Stop bits
	SUB	AL,LOW "0"	;map ("4".."8") to (4..8)
	CMP	AL,LOW 4
	JB	ERIFN2		; Error if less than "4"
	CMP	AL,LOW 9D
	JNB	ERIFN2		; or greater than "8"
	MOV	BYTE PTR _BYTSZ[DI],AL	;save Data bits
	CALL	GETPRM		; Look for no. of stop bits or EOS
	JZ	COMOP5		;Brif EOS
COMOP4:
	CALL	SYNPRM		;Stop bits must follow
	JB	COMOP5		;Brif saw "," Default Stop bits
	SUB	AL,LOW "1"	;Strip ASCII bias ("1", "2")=(0,1)
	CMP	AL,LOW 2	;Must be "1" or "2"
	JNB	ERIFN2		; else error
	ADD	AL,AL		;map ("1","2") to (0,2)
	MOV	BYTE PTR _STOPB[DI],AL	;set STOP bits field in DCB
	JNZ	LPARM		;branch if "2"
	CALL	GETPRM		;[AL]=EOS, "," or "."
	JZ	RET24		;return if End-Of-String
	CMP	AL,LOW "."
	JNZ	LPARM2		;it had better be a comma
	CALL	GETPRM
	CMP	AL,LOW "5"
	JNZ	ERIFN2		;illegal filename error if not 1.5
	INC	BYTE PTR _STOPB[DI]	;map ("1", "1.5", "2") to (0,1,2)
	INC	SI
COMOP5:
	DEC	SI		;adjust for GETPRM

;This routine parses the position independent parameters RTS, DSR, ...
;
LPARM:
	CALL	GETPRM		;Get parm, EOS, or ","
	JZ	RET24		;Brif no more parms
LPARM2:
	CALL	SYNPRM		;Check "," then get parm
	CMP	AL,LOW "R"	;RS?
	JNZ	LPARDS		;no, try DS/CS/CD/LF/BIN
	CALL	LPTRYS		; S?
	JNZ	PARIFN		;no, error
	OR	BYTE PTR _CMFLG[DI],LOW OFFSET _CMRTS	;set RTS bit
	JMP	SHORT LPARM	;get next parm
LPARDS:
	CMP	AL,LOW "D"	;DS?
	JNZ	LPARCD		;No, try CS/CD/LF/BIN
	CALL	LPTRYS		; S?
	JNZ	PARIFN		;no, error
	CALL	VALGET		;[DX] = Timeout
	MOV	WORD PTR _DSRTO[DI],DX	;set DSR timeout
	JMP	SHORT LPARM	;get next parm

LPARCD:
	CMP	AL,LOW "C"	;CS/CD?
	JNZ	LPARLF		;no, try LF/BIN
	CALL	LPTRYS		; S?
	JZ	LPARCS		;Brif CS
	CMP	AL,LOW "D"	; D?
	JNZ	PARIFN		;no, error
	CALL	VALGET		;[DX] = Timeout
	MOV	WORD PTR _RLSTO[DI],DX	;set RLSD timeout
	JMP	SHORT LPARM	;get next parm
LPARLF:
	CMP	AL,LOW "L"	;LF?
	JNZ	LPRBIN		;no, try BINary
	CALL	LPTRYS
	CMP	AL,LOW "F"	;"F" must follow
	JNZ	PARIFN		;no, error
	OR	BYTE PTR _CMFLG[DI],LOW OFFSET _CMCLF	;set send LF after CR flag
	JMP	SHORT LPARM	;get next parm
LPARCS:
	CALL	VALGET		;[DX] = Timeout
	MOV	WORD PTR _CTSTO[DI],DX	;set CTS timeout
	OR	BYTE PTR _CMFLG[DI],LOW OFFSET _CMCTS	;indicates CTS not defaulted
	JMP	SHORT LPARM	;get next parm
PARIFN:
	JMP	DERIFN		;Illegal File Name error

LPTRYS:
	CALL	GETPRM
	CMP	AL,LOW "S"	;set cond codes for S (Frequent letter)
RET24:	RET	

LPRBIN:	CMP	AL,LOW "B"	;BIN?
	JNZ	LPRASC		;Branch if not
	CALL	LPTRYS
	CMP	AL,LOW "I"	; I?
	JNZ	PARIFN		;no, error
	CALL	LPTRYS
	CMP	AL,LOW "N"	; N?
	JNZ	PARIFN		;no, error
;;; Binary mode is the default mode, next line for Documentation Purposes
;;;     ORBI    .CMFLG(.DI),.CMBIN      ;set binary mode
	JMP	SHORT TSTCOD	;get next parameter

LPRASC:	CMP	AL,LOW "A"	;ASC?
	JNZ	PARIFN		;Illegal filename if not
	CALL	LPTRYS
	CMP	AL,LOW "S"	; S?
	JNZ	PARIFN		;no, error
	CALL	LPTRYS
	CMP	AL,LOW "C"	; C?
	JNZ	PARIFN		;no, error
	AND	BYTE PTR _CMFLG[DI],LOW OFFSET 255D-_CMBIN	;reset binary mode
TSTCOD:	TEST	BYTE PTR _CMFLG[DI],LOW OFFSET _CMCOD
	JNE	PARIFN		;bad filename if ASC and BIN specified
	OR	BYTE PTR _CMFLG[DI],LOW OFFSET _CMCOD
	JMP	LPARM		;get next parameter

SYNPRM:
	CMP	BYTE PTR 0[SI],LOW ","
	JZ	GETPRM		;Brif found ","
	JMP	SHORT PARIFN	; else "Bad File Name" if no comma
CHKPRM:
	DEC	SI

GETPRM:
	CMP	BYTE PTR 0[SI],LOW 0
	JZ	GETPRX		;Brif EOS

;Get Next Option Char skipping blanks and forcing upper case
; Exit - Carry = comma, Z = end-of-statement, else [AL]=byte
;
GETPRI:
	INC	SI
GETPR0:
	MOV	AL,BYTE PTR 0[SI]	;Get next char
	CMP	AL,LOW " "
	JZ	GETPRM		;Ignore Blanks
	CMP	AL,LOW ","
	JNZ	GETPR1		;Brif not ","
	OR	AL,AL		;set NZ (not end-of-statement)
	STC			;set carry
	RET			;Comma returns: NZ and TC
GETPR1:
	CMP	AL,LOW "a"	;Case convert?
	JB	GETPR2		;Brif not
	XOR	AL,LOW 40O	;Convert to Uppercase
GETPR2:
	OR	AL,AL		;Chars return NZ and NC
GETPRX:
	RET			;EOS returns TZ and NC

;Parse decimal number returning result in [DX]
;
VALGET:
	PUSH	BX
	XOR	DX,DX		;INITIAL VALUE OF ZERO
	MOV	AH,LOW 6	;MAXIMUM 5 DIGITS.
VALLOP:
	CALL	GETPRI		;Get next char in [AL]
	CMP	AL,LOW OFFSET "9"+1	;NOW SEE IF ITS A DIGIT
	JNB	VALXIT		;IF NOT, RETURN
	CMP	AL,LOW "0"
	JB	VALXIT
	MOV	BX,DX		;ARG=ARG*10+DIGIT
	ADD	BX,BX		;*5
	ADD	BX,BX
	ADD	BX,DX
	ADD	BX,BX		;*2
	SUB	AL,LOW "0"	;ADD IN THE DIGIT
	MOV	DL,AL
	XOR	DH,DH		;[DX]=new digit
	ADD	BX,DX
	XCHG	DX,BX		;VALUE SHOULD BE IN [DX]
	DEC	AH		;Max digits -1
	JNZ	VALLOP		;WILL FALL THRU IF MORE THAN 5 DIGITS
	JMP	DERIFN		;TOO MANY DIGITS. Illegal File Name
VALXIT:
	DEC	SI		;Adjust for GETPRM
	POP	BX
	RET	

;COMEOF - test for End-Of-File on device.
; Entry - SI points to File-Data-Block.
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - [BX] = -1 if EOF, 0 if not EOF
;
	EXTRN	INCHSI:NEAR
COMEOF:
	CMP	BYTE PTR F_CODE[SI],LOW OFFSET FC_BIN
	JE	BINEOF		;Branch if not ASCII file mode

;The following code is removed so we won't say EOF is false and then
; give user Input-Past-End error when CTL-Z finally comes through.
; This also means EOF function will hang waiting for input, but
; presumably, user wants device to look like sequential file, not
; a dynamic COM-I/O device if he is using EOF function.
;
	XOR	BX,BX		;assume no EOF
	CALL	INCHSI		;[AL]=next byte from COM device
	JB	YCMEOF		;branch if next char = EOF
	CALL	BCHRSI		;put this back in queue
CMEOFX:	RET			;BX=0,  end-of-file is false

;   In BINARY mode, GW-BASIC EOF is compatible with IBM-PC Basic
;   That is, EOF is true when no data is in input queue.
;
BINEOF:
	CALL	COMLOC		;[BX]=number of bytes in input queue
	OR	BX,BX
	JE	YCMEOF		;branch if input queue is empty
	MOV	BX,1		;return with [BX]=0 (false)
YCMEOF:	DEC	BX		;BX=-1 if end-of-file is true
	RET	

;COMLOC - Number of Bytes in input buffer for device.
; Entry - SI points to File-Data-Block.
;         DI = device offset
; Exit  - [BX] = result.
;
COMLOC:	CALL	GCMUID		;AL=Unit ID
	MOV	AH,AL
	CALL	GCOMSZ		;[DX]=number of bytes in input buffer
	MOV	BX,DX		;return result in BX
	TEST	BYTE PTR F_FLGS[SI],LOW OFFSET FL_BKC
	JZ	CMLOCX		;branch if char not backed up
	INC	BX
CMLOCX:	RET	

;COMLOF - number of bytes free in input buffer.
; Entry - SI points to File-Data-Block.
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - [Floating-Point-Accumulator] = result.
;
COMLOF:	CALL	COMLOC
	MOV	BX,CX		;Prep to move free bytes to FAC
	JMP	MAKINT		;return result in FAC

;COMCLS - perform any device dependent close functions.
; Entry - SI points to File-Data-Block.
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - All registers preserved.
;         This routine is called before BASIC releases the
;         file-data-block associated with this file.
;
COMCLS:	CALL	GCMDCB		;DI points to device control block
	MOV	WORD PTR _CMFDB[DI],0	;mark device as not-in-use
	CMP	BYTE PTR F_CODE[SI],LOW OFFSET FC_BIN
	JE	COMCLX		;Branch if BINARY file mode
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQI
	JE	COMCLX		;don't send EOF if input mode
	MOV	AL,LOW OFFSET ASCCTZ	;else send CTL-Z indicating EOF
	MOV	AH,BYTE PTR _DEVID[DI]	;[AH]=device ID
	CALL	SNDCOM		;output CTL-Z to COM channel
				;ignoring error conditions
COMCLX:	MOV	AH,BYTE PTR _DEVID[DI]	;[AH]=device ID
	CALL	TRMCOM		;terminate COM channel
	JMP	CKCMER		;Check for COM I/O Error

;COMSWD - set device width
; Entry - SI points to File-Data-Block.
;         [DX] = new device width
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - All registers preserved
;
COMSWD:	CALL	GCMDCB		;DI points to device control block
	MOV	BYTE PTR _CMWID[DI],DL	;set device width
RET12:	RET	

;COMRND - perform random I/O.
; Entry - [AL] = function to be performed:
;                0: get next record
;                1: put next record
;                2: get record [DX] (1-relative)
;                3: put record [DX] (1-relative)
;         [SI] points to File-Data-Block
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - All registers are used.
;
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FILMOD:WORD
DSEG	ENDS
COMRND:	CMP	AL,LOW 2
	JAE	CMRND1		;branch if user specified byte count
	MOV	DX,WORD PTR FD_SIZ[SI]	;default to record-size
CMRND1:	LEA	BX,DWORD PTR FD_DAT[SI]	;BX points to random record buffer
	MOV	CX,DX		;CX=byte count
	TEST	AL,LOW 1
	JNZ	PUTRND		;branch if PUT requested
GETLOP:	PUSH	DI		;[AL]=next byte from com port
	CALL	COMSIN		;[AL]=next byte from com port
	POP	DI
	MOV	BYTE PTR 0[BX],AL	;save byte in buffer
	INC	BX		;bump buffer pointer
	LOOP	GETLOP
	RET	
PUTRND:	CALL	GCMDCB		;DI points to COMx DCB
PUTLOP:	MOV	AL,BYTE PTR 0[BX]	;[AL]=next byte from buffer
	CALL	CMROUT		;output to com port
	INC	BX		;bump buffer pointer
	LOOP	PUTLOP
	RET	

;COMSIN - Sequential Input.
; Entry - SI points to File-Data-Block.
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - [AL] = next byte from file,
;         carry set if EOF.
;         All other registers preserved
;
COMSIN:
CSWAIT:	CALL	GCMUID		;[AL]=Com Unit ID(DI)
	MOV	AH,AL		;[AH]=Com Unit ID(DI)
	CALL	RECCOM		;[AL]=input byte (if data is ready)
	PUSHF	
	CALL	CKCMER		;Check for COM I/O Error
	POPF	
	JNZ	CSGOT1		;wait if none ready to be read
	CALL	POLKEY		;allow CTL-Z to break in
	JMP	SHORT CSWAIT
CSGOT1:
	CMP	AL,LOW OFFSET ASCCTZ	;check for CTL-Z
	JNE	CMNEOF		;branch if not
	CMP	BYTE PTR F_CODE[SI],LOW OFFSET FC_BIN
	JE	CMNEOF		;CTL-Z is not EOF for Binary files
	STC			;CTL-z is EOF for ASCII files
	JMP	SHORT CMSINX	;restore registers and exit
CMNEOF:	OR	AL,AL		;clear carry (no eof)
CMSINX:	RET	

;COMSOT - Sequential Output.
; Expand tab to spaces, force carriage return before outputting char
; if char is printable (greater than 20h) and column exceeds width.
; Since CRONLY is false in GW versions, COMSOT always gets CR-LF for
; end-of-line.  To be as close to IBM Basic as possible, the following
; algorithm is used:
;   Eat LF if last-char-was-CR
;   clear last-char-was-CR flag
;   if char is CR
;       set last-char-was-CR flag
;       if LF-option was set in filename,
;           output a LF
;   The only known case where this is different from IBM is if the file
;   is opened without the LF option and the user executes
;   PRINT CHR$(13);CHR$(10);.  On IBM, 13-10 would be output.
;   On GW, 13 would be output.  The ultimate solution would be for GW
;   to be compiled with CRONLY=1 and change disk code to insert LF after
;   CR.
; Entry - SI points to File-Data-Block.
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
;         [AL] = byte to be output.
; Exit  - SI, DI can be changed.
;         All other registers preserved
;         This routine keeps track of column position,
;         expands tabs, and forces a carriage return when line width
;         is exceeded.
;
COMSOT:	PUSH	AX
	CALL	GCMDCB		;DI points to COMx DCB
	POP	AX		;restore [AL]=byte to output
	TEST	BYTE PTR _CMFLG[DI],LOW OFFSET _CMCOD
	JE	NOTBIN		;brif user didn't explicitly specify BIN
	CMP	BYTE PTR F_CODE[SI],LOW OFFSET FC_BIN
	JE	CMROUT		;if BIN, branch to Raw-Output routine
NOTBIN:	PUSH	BX
	PUSH	DX
	MOV	BX,OFFSET CMOUT1	;BX points to Raw Output Routine
	MOV	DL,BYTE PTR F_WID[SI]	;[DL]=device width (from FDB)
	MOV	DH,BYTE PTR _CMPOS[DI]	;[DH]=current column (from DCB)
	EXTRN	CRIFEL:NEAR
	CALL	CRIFEL		;force CR if End-Of-Line, output char

	MOV	BYTE PTR _CMPOS[DI],DH	;save new column position
	POP	DX
	POP	BX
RET11:	RET	

;Low-Level RS232 Output (updates column position)
; If LF option was not set in COMOPN (OPEN "COM1:,,,,LF), eat all LineFeeds
;    which follow CarriageReturns with following algorithm:
; if (Char <> LF) or (LastWasCR = 0) then output (Char)
; if (Char = CR) then LastWasCR = 1 else LastWasCR = 0
; if (LastWasCR) and COMOPN.LF then output(LF)
;
; The best way this could have been done was by setting CRONLY=1 in the
; switch files and letting the device drivers append Line-Feeds if necessary.
; It was considered too late to make a change this drastic
;
;
CMOUT1:	CALL	UPDPOS		;[DH]=new column position(AL, DH)
	PUSH	AX		;save character to be output
	CMP	AL,LOW OFFSET ASCLF
	JNE	CMOUT2		;branch if not attempting to output LF
	TEST	BYTE PTR _CMFLG[DI],LOW OFFSET _CMCRF
	JNE	CMOUT3		;brif last byte out was CR
CMOUT2:
	CALL	CMROUT		;output the character
CMOUT3:
	POP	AX		;restore [AL]=char which was output
	AND	BYTE PTR _CMFLG[DI],LOW OFFSET 255D-_CMCRF	;reset last byte out was CR flag
	CMP	AL,LOW OFFSET ASCCR
	JNE	CMOUTX		;return if wasn't carriage return
	OR	BYTE PTR _CMFLG[DI],LOW OFFSET _CMCRF	;set last byte out was CR flag
	TEST	BYTE PTR _CMFLG[DI],LOW OFFSET _CMCLF
	JE	CMOUTX		;brif CR is not to be mapped to CR-LF
	PUSH	AX
	MOV	AL,LOW OFFSET ASCLF
	CALL	CMROUT
	POP	AX
CMOUTX:
	RET	

;Output byte [AL] to device with COM DCB pointed to by [DI].
;If error occurs, jump to ERROR
;
CMROUT:	MOV	AH,BYTE PTR _DEVID[DI]	;[AH]=device ID
	PUSH	AX
	CALL	SNDCOM		;output [AL] to COM and return
	CALL	CKCMER		;Check for I/O errors and return
	POP	AX
	RET	

;COMGPS - return current file position.
; Entry - SI points to File-Data-Block.
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - [AH] = current file column. (0-relative)
;         All other registers preserved
;
COMGPS:	CALL	GCMDCB		;DI points to Device Control Block
	MOV	AH,BYTE PTR _CMPOS[DI]
	RET	

;COMGWD - get device width
; Entry - SI points to File-Data-Block.
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - [AH] = device width as set by xxxSWD
;         All other registers preserved
;
COMGWD:	CALL	GCMDCB		;DI points to Device Control Block
	MOV	AH,BYTE PTR _CMWID[DI]	;get width
	RET	

;COMSCW - set device comma width
; Entry - [BX] = new device comma width
;         SI points to File-Data-Block.
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - SI, DI can be changed.
;         All other registers preserved
;
COMSCW:	RET	

;COMGCW - get device comma width
; Entry - SI points to File-Data-Block.
;         [DI] = device offset (2=COMD, 4=SCRN, etc.)
; Exit  - [BX] = device comma width as set by xxxSCW
;         All other registers preserved
;
COMGCW:	RET	

;GCMDCB - get pointer to COM Device Control Block
; Entry - [DI] = -2*device id (2,4,..n)
; Exit  - DI points to the device control block for device DI.
;         [AX] = 0..n for COM1, COM2, ...
;
GCMDCB:	CALL	GCMUID		;[AX]=unit id (0..n)
	PUSH	AX		;save unit id
	MOV	AH,LOW OFFSET CDCBSZ	;AX = bytes per COM DCB
	MUL	AH		;AX = unit ID * CDCBSZ
	ADD	AX,OFFSET CM1DCB
	MOV	DI,AX		;DI points to COMx device ctl block
	POP	AX		;[AX]=unit id
	RET	

;GCMUID - get COM Unit Id
; Entry - [DI] = -2*device id (2,4,..n)
; Exit  - [AX] = 0..n for COM1, COM2, ...
;
GCMUID:	MOV	AX,DI
;       ADDI    AX,$CODE+2*<$.COM1-^O400>   ;[DI]=0, 2, ... for COM1, COM2, ...
	SHR	AX,1
	ADD	AX,OFFSET ($_COM1-400O)	;[AX]=0, 1, ... for COM1, COM2, ...
	RET	

CSEG	ENDS
	END
                                                      