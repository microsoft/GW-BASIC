; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   GIOKYB - Machine Independent Keyboard Device Driver Code

COMMENT	*

--------- --- ---- -- ---------
COPYRIGHT (C) 1982 BY MICROSOFT
--------- --- ---- -- ---------

	*
	INCLUDE	GIO86U
	.SALL

;Generic Switches
;
CPM86=0
IBMCSR=IBMLIK			;IBM compatible cursor interface

;OEM Switches
;
MELCO=0
COMPAQ=0

;Local switches
INTHND=SCP AND GW


	INCLUDE	MSDOSU

	PUBLIC	KYBDSP,KYBINI,KYBTRM
	EXTRN	SCNSWD:NEAR,SCNGWD:NEAR,SCNSOT:NEAR,SCNGPS:NEAR,SCNGCW:NEAR
	EXTRN	SCNSCW:NEAR
	EXTRN	MAKINT:NEAR,INIFDB:NEAR,DERBFM:NEAR
	EXTRN	INITQ:NEAR,GETQ:NEAR,PUTQ:NEAR
	EXTRN	DEVBIN:NEAR,DEVBOT:NEAR
	EXTRN	SCNBRK:NEAR,EDTBRK:NEAR
	CTLBRK=65283D		;&HFF03 is Ctl-Break
	CTLPAS=65299D		;&HFF13 is Ctl-Pause

; Keyboard Data-Flow/Control-Structure for GIO86:
;
;    PLAY, LIST, NEWSTT                                            INCHRI
;    --------+---------                                      (fixed length input)
;            !                                   INLIN               !
;            !                              (Screen Editor)     KYBSIN/CHGET
;         CHKINT                                   !        (Device Indep. input)
;     +-------------+                              !                 !
;     !             !                              +-----------------+
;     !             !                                       !
;     !             !                  INKEY$             KEYIN
;     !           POLKEY                 !                  !
;     !             !                    +--------------+---+
;     !        +----+--------+-------+                  !
;     !        !    !        !       !                CHSNS (get 1 KEY {may be 2 bytes}
;     !        !  CNTCCN  KEYTRP  PKEYQ                 !    function key expansion)
;     !        !    !                !      ------+     !
;     !        +----+              PUTQ --> ! ! ! !--> CONIN (get 1 byte from queue)
;     !             !                       ------+
;  POLLEV         KEYINP(OEM supplied)      (queue)
;(OEM supp.)      (maps to MS Univ keyboard)
;(test for trapable event)

;Keyboard Dispatch Table
;
KYBDSP:
	DW	(KYBEOF)	;test EOF for file opened to this device
	DW	(KYBLOC)	;LOC
	DW	(KYBLOF)	;LOF
	DW	(KYBCLS)	;perform special CLOSE functions for this device
	DW	(SCNSWD)	;set device width
	DW	(DERBFM)	;GET/PUT random record from/to this device
	DW	(KYBOPN)	;perform special OPEN functions for this device
	DW	(KYBSIN)	;input 1 byte from file opened on this device
	DW	(SCNSOT)	;output 1 byte to file opened on this device
	DW	(SCNGPS)	;POS
	DW	(SCNGWD)	;get device width
	DW	(SCNSCW)	;set device comma width
	DW	(SCNGCW)	;get device comma Width
	DW	(DEVBIN)	;block input from file opened on this device
	DW	(DEVBOT)	;block output to file opened on this device

	SUBTTL Keyboard Primitive I/O Routines

	EXTRN	BCHRSI:NEAR

;KYBINI puts the keyboard device server in an initial state.
; It is called at initialization time and after CTL-C.
; On exit, all registers are preserved.
;
	EXTRN	FINPRT:NEAR,PDCBAX:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	ASSUME DS:DSEG
	EXTRN	KYBQDS:WORD,KYBQUE:WORD,KYBQSZ:WORD
DSEG	ENDS
KYBINI:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSHF	
	PUSH	SI
	XOR	AX,AX
	MOV	WORD PTR CMDOFF,AX	;[CMDOFF]=0 (no soft key)
	MOV	SI,OFFSET KYBQDS	;SI = keyboard queue descriptor
	MOV	BX,OFFSET KYBQUE	;BX points to 1st byte of queue buff
	MOV	AX,OFFSET KYBQSZ	;AX = size of keyboard queue
	CALL	INITQ		;Initialize keyboard queue
	CALL	FINPRT		;reset PTRFIL to Keyboard/CRT
	POP	SI
	POPF	
	JMP	PDCBAX		;POP DX, CX, BX, AX and return

	PUBLIC	KYBCLR
;KYBCLR - Clear the keyboard buffer
;This routine has been documented to OEMs.  The routine is intended to support
;the IBM poke which clears the keyboard buffer.
;Entry - none
;Exit  - none
;        Segment registers and stack preserved.
;
KYBCLR:	CALL	KYBINI		;Initialize the keyboard buffer
	RET	
	PAGE	
;KYBEOF - test for End-Of-File on device.
; Entry - SI points to File-Data-Block.
; Exit  - [BX] = -1 if EOF, 0 if not EOF
;
	EXTRN	INCHSI:NEAR

KYBEOF:	XOR	BX,BX		;0 means not at eof
	OR	SI,SI
	JZ	KBEOFX		;branch if not pseudo keyboard FDB
	CALL	INCHSI		;[AL]=next byte from keyboard
	JB	YKYEOF		;branch if next key = CTL-Z
	CALL	BCHRSI		;put this back in queue
KBEOFX:	RET	
YKYEOF:	DEC	BX		;BX=-1, end-of-file is true
KYBTRM:	RET	

;KYBLOC - Number of Bytes in input buffer for KEYBOARD device.
; Entry - SI points to File-Data-Block.
; Exit  - [BX] = result.
;
KYBLOC:	PUSH	SI		;save FDB pointer
	MOV	SI,OFFSET KYBQDS	;SI points to KYB queue descriptor
EXTRN	NUMQ:NEAR
	CALL	NUMQ		;[AX]=number of bytes queued in KYB Q
	POP	SI
	MOV	BX,AX		;return result in BX
	TEST	BYTE PTR F_FLGS[SI],LOW OFFSET FL_BKC
	JZ	KYLOCX		;branch if char not backed up
	INC	BX
KYLOCX:	RET	

;KYBLOF - number of bytes free in KEYBOARD input buffer.
; Entry - SI points to File-Data-Block.
; Exit  - [Floating-Point-Accumulator] = result.
;
KYBLOF:	MOV	SI,OFFSET KYBQDS	;SI points to KYB queue descriptor
EXTRN	LFTQ:NEAR
	CALL	LFTQ		;[AX]=number of bytes free in KYB Q
	MOV	BX,AX
	JMP	MAKINT		;return result in FAC

;KYBCLS - perform any device dependent close functions.
; Entry - SI points to File-Data-Block.
; Exit  - All registers preserved.
;         This routine is called before BASIC releases the
;         file-data-block associated with this file.
;
KYBCLS:
RET11:	RET	

;KYBOPN - perform any device dependent open functions.
; Entry - [AL]=  device id
;                0 if default device,
;                1..n for Disk A:, B:, ...
;                -1..-n for non-disk devices
;         [BX] = file number (0..n)
;         [CX] = random record size if [FILMOD] = random
;                (if [CX] = 0, use default record size)
;         [DI] = device offset (2=KYBD, 4=SCRN, etc.)
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
KYBOPN:
	MOV	AH,LOW OFFSET MD_SQI	;allow input only
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FILMOD:WORD
DSEG	ENDS
	CMP	BYTE PTR FILMOD,LOW OFFSET MD_RND
	JNZ	KYBOPX		;Leave the mode as it is
	MOV	BYTE PTR FILMOD,AH	;Force the mode to INPUT
KYBOPX:
	JMP	INIFDB

;KYBSIN - Sequential Input.
; Entry - SI points to File-Data-Block.
; Exit  - [AL] = next byte from Keyboard File
;         carry set if EOF (CTL-Z read) (only if SI points to FDB (non 0))
;         (Note: SI must be preserved for KYBEOF to work)
;         All other registers preserved
;

	PUBLIC	KYBSIN,INCHRI,CHGET
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	SAVKEY:WORD,SAVKYF:WORD
DSEG	ENDS
	EXTRN	SCNPOS:NEAR

INCHRI:
	EXTRN	INFMAP:NEAR
	MOV	AL,BYTE PTR SAVKEY
	CMP	BYTE PTR SAVKYF,LOW 0D
	MOV	BYTE PTR SAVKYF,LOW 0D
	JNZ	KBSINX		;Send second bytes through unfiltered
KEYGET:
	STC	
	CALL	STCTYP		;Set new cursor type to user mode (PSW.C set)
	CALL	KEYSIN		;Read a key from the OS (could be a null fkey)
	CALL	INFMAP		;OEM fixed length input map routine
	JZ	KEYGET		;OEM filtered out the key - get the next
	JMP	SHORT KYBSI2	;Process as other keys
CHGET:
KYBSIN:	MOV	AL,BYTE PTR SAVKEY
	CMP	BYTE PTR SAVKYF,LOW 0D
	MOV	BYTE PTR SAVKYF,LOW 0	;clear 2nd-byte of 2-byte sequence flag
	JNZ	KBSINX		;branch if 2nd-key of 2-byte sequence
	CALL	STCTYP		;Set to insert or overwrite cursor (PSW.C reset)
	CALL	KEYIN		;[AX]=next character from keyboard
KYBSI2:
	JB	KBSIN2		;branch if got 2-byte sequence (f-key/KANJI)
	PUSHF	
	OR	SI,SI
	JZ	KB1X		;branch if no FDB
	CMP	AL,LOW OFFSET ASCCTZ	;CTL-Z=eof for keyboard
	JNE	KB1X		;branch if not EOF
	POPF	
	STC			;return EOF indication
	JMP	SHORT KBSINX
KB1X:	POPF	
	JMP	SHORT KBSINX
KBSIN2:
	MOV	BYTE PTR SAVKEY,AL	;save 2nd byte of 2-byte sequence
	MOV	BYTE PTR SAVKYF,LOW 255D	;Set saved key flag
	XCHG	AH,AL		;return 1st byte to user
	CLC			;clear carry (not EOF)
KBSINX:	RET	

;KEYIN turns cursor on if no key is available.
; It then waits for key from keyboard (if one wasn't already there).
; Exit - if Z is true, no key was ready, else [AX]=key
;        if C is true, returns 16 bit character
;        Soft keys are expanded if not being trapped, and not null.
;        if NZ AND NC AND [AL] = FF then a two byte character is returned
;               in DX.  The character is an OEM specific special character.
;        All other registers are preserved.
;
	PUBLIC	KEYIN
KEYIN:
IGNNFK:	CALL	KEYSIN		;Get a key (possibly a null function key)
	PUSHF	
	JAE	NOTNFK		;branch if not 2-byte key code
	CMP	AH,LOW 200O
	JNE	NOTNFK		;branch if definitely not a null Function key
	CMP	AL,LOW 40O
	JB	NOTNFK		;branch if definitely not a null Function key
	CMP	AL,LOW 101O
	JAE	NOTNFK		;branch if definitely not a null Function key
	POPF	
	JMP	SHORT IGNNFK	;ignore null Function key

NOTNFK:	POPF	
	RET	

;KEYSIN - Get a key.  This routine will return null function keys.
;Entry - none
;Exit  - PSW.C set indicates a two byte key code
;
KEYSIN:	CALL	CHSNS		;try to get next key
	JNE	KEYINX		;Return with key if there is one.
	PUSH	DX
	CALL	SCNPOS		;[DH]=1 relative column (cursor position)
				;[DL]=1 relative line
	CALL	SETCSR		;Set the cursor
	POP	DX
CHWAIT:	CALL	CHSNS		;Has a key been typed?
	JE	CHWAIT		;No, wait
KEYINX:	PUSHF	
	PUSH	AX
	MOV	BYTE PTR CSRTYP,LOW 3D	;Indicate user cursor
	CALL	SETCSR		;Set the cursor
	POP	AX
	POPF	
	RET	
	PAGE	
	SUBTTL  Keyboard Interrupt/Trap Checking in an Operating System Environment

;POLKEY is called from several places in BASIC to "poll" the keyboard.
; Exit - DI is used.  All other registers are preserved.
;        If CTL C was typed, Control does not return to caller.
;
; Function:
;       get key from operating system
;       while keyboard data is ready to be read begin
;         get key
;         if key is CTL-C, reset soft-key pointer, key-queue, AUTFLG, SEMFLG
;            call SNDRST to reset background sound,
;            and exit to CNTCCN (resets stack and jumps to STOP)
;         if key is CTL-S, pause until non-CTL-S key is pressed
;         if key is 1st byte of Function Key, continue getting keys
;            until it definitely is or is not a function key.
;         if it was a function key then begin
;            if trapping is enabled then
;               trap it
;            else
;               queue function key code for CHSNS
;            end {it was a function key}
;         else {it was not a function key}
;           queue key for CHSNS
;       end {while keyboard data ready}
;
	PUBLIC	POLKEY
	EXTRN	KEYTRP:NEAR,KEYINP:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	AUTFLG:WORD,SEMFLG:WORD,SAVSTK:WORD,SAVTXT:WORD
DSEG	ENDS

POLKEY:	PUSH	DI
	PUSHF	
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
GETKLP:
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	MSDCCF:WORD	;MSDOS Ctl-C Interrupt flag
DSEG	ENDS
	TEST	BYTE PTR MSDCCF,LOW 255D
	JNZ	ITSCTC		;Branch if Ctl-C interrupt detected
	CALL	KEYINP		;[AX]=next key from keyboard if one exists
	JE	POLKXI		;branch if no key present
	JAE	NOTTWO		;branch if not 2-byte key sequence
	CMP	AH,LOW 255D	;Test for control function range
	JNZ	NTCTLFN		;Not a control function
	CALL	TRPCHK		;Check for trapping in this range
	JNZ	GETKLP		;Trap set - get next key
NTCTLFN:
	CMP	AH,LOW 128D
	JNE	NOTFUN		;branch if not function key
	PUSH	AX		;save key-code
	SUB	AL,LOW 32D	;[AL]=0 for 1st function key
	CMP	AL,LOW OFFSET NMKEYT	;see if its a trapable function key
	JAE	NOFUN1		;branch if not
	CALL	KEYTRP		;Trap key if event is ON
	POP	AX		;restore key code
	JNZ	GETKLP		;branch if Key was trapped (don't queue)
	JMP	SHORT NOTFUN	;Not trapped function key (queue key)
POLKXI:	JMP	POLKYX

NOFUN1:	POP	AX		;Restore key code
NOTFUN:
	CMP	AX,OFFSET CTLBRK	;check for Ctl-Break
	JE	ITSCTC		;branch if CTL C
	CMP	AX,OFFSET CTLPAS
	JE	ITSINT		;branch if CTL S
NOTRAP:
	PUSH	AX
	CALL	LFTQ		;[AX]=number of bytes free in KYB Q
	CMP	AX,3D		;Test for space in keyboard queue
	POP	AX		;Restore key code
	JB	GETKLP		;Loop for next key (interrupt?)
	XCHG	AH,AL
	CALL	PKQUE		;append 1st byte of sequence to key queue
	XCHG	AH,AL
	JMP	SHORT QUEKEY	;append 2nd byte of sequence to key queue
NOTTWO:
	CMP	AL,LOW 254D	;Test for three byte char (IBM "scan codes")
	JNZ	QONEBT		;Queue a one byte character
	PUSH	AX
	CALL	LFTQ		;[AX]=number of bytes free in KYB Q
	CMP	AX,4D		;Test for space in keyboard queue
	POP	AX		;Restore key code
	JB	GETKLP		;Loop for next key (interrupt?)
	CALL	PKQUE		;Queue the first byte
	MOV	AX,DX		;Get second and third bytes
	JMP	SHORT NOTRAP	;Go queue the second and third bytes
QONEBT:
	JMP	SHORT QUEKEY	;else queue the key for CHSNS
ITSCTC:
	CALL	KYBINI		;clear keyboard queue, reset PTRFIL
	MOV	BYTE PTR MSDCCF,LOW 0D	;Reset Ctl-Break interrupt flag
	EXTRN	SNDRST:NEAR
	CALL	SNDRST		;reset background music
	MOV	SP,WORD PTR SAVSTK	;[SP]=SP of interrupted statement
	MOV	BX,WORD PTR SAVTXT	;[BX]=text pointer of interrupted stmt
	MOV	AX,OFFSET CTLBRK	;[AX]=Key Code for BREAK (CTL-C)
ITSINT:	CALL	CNTCCN		;process CTL C or S
	JMP	GETKLP		;dont queue CTL-S or CTL-C

QUEKEY:	CALL	PKQUE		;queue key [AL] for CHSNS
	JMP	GETKLP		;get next key

;At this point, Keyboard input queue from OS is flushed.
;
POLKYX:	POP	DX		;restore caller's registers
	POP	CX
	POP	BX
POLKXX:	POP	AX
	POPF	
	POP	DI
RET8:	RET	

;TRPCHK - Check for key trapping
;Entry - AX = key code
;Exit  - PSW.Z set indicates key was not trapped
;
TRPCHK:	PUSH	AX		;Save key code
	MOV	BX,OFFSET TRPKTB-1	;BX points before 1st byte of key trap table
CHKTRP:	INC	BX
	MOV	AH,BYTE PTR CS:0[BX]
	INC	BX		;BX points to Trap Key ID for key [AH]
	OR	AH,AH		;test for end-of-table
	JE	NTRAP		;branch if not a trappable key
	CMP	AH,AL
	JNE	CHKTRP		;branch if they don't match (continue search)
	MOV	AL,BYTE PTR CS:0[BX]	;[AL]=key-trap id
	CALL	KEYTRP		;Trap key if event is ON
NTRAP:	POP	AX		;Restore key code
	RET	
	PAGE	
	SUBTTL  CHKKYB - OEM Version of POLKEY
;CHKKYB - This is the OEM version of POLKEY.  It is documented to the OEM as
;the way to check for keyboard interrupts.
;Entry - All segment registers must be set
;        to the BASIC configuration
;Exit  - All registers and PSW preserved
;
	PUBLIC	CHKKYB
CHKKYB:	PUSH	SI
	PUSH	BP		;For safety
	CALL	POLKEY
	POP	BP
	POP	SI
	RET	
	PAGE	
	SUBTTL  CNTCCN, PKQUE, TRPKTB
;CNTCCN performs special action upon receipt of CTL-S or CTL-C
;
	EXTRN	CTRLPT:NEAR,STOP:NEAR
CNTCCN:
	CMP	AX,OFFSET CTLPAS	;check for PAUSE
	JNZ	NOTCTS		;branch if not
GOTCTS:	CALL	KEYINP
	JZ	GOTCTS		;wait for resume key (anything but CTL S)
	CMP	AX,OFFSET CTLPAS	;check for PAUSE
	JE	GOTCTS		;branch if got another CTL-S
NOTCTS:
	CMP	AX,OFFSET CTLBRK	;check for Ctl-Break
	JNE	RET8		;return if not CTL-C
	CALL	EDTBRK		;Clear editor flags and position cursor
	CALL	SCNBRK		;Clear flags associated with screen driver
	PUSH	AX
	CALL	FINPRT		;Reset I/O
	POP	AX
	MOV	AX,WORD PTR CURLIN	;Print "BREAK" message in program mode only
	AND	AL,AH		;AL=^D255 if direct mode
	XOR	AH,AH		;Set PSW.Z so STOP won't give Syntax Error
	JMP	STOP

;PKQUE appends [AL] to the keyboard circular queue
;
PKQUE:	PUSH	SI
	MOV	SI,OFFSET KYBQDS	;SI = keyboard queue descriptor
	CALL	PUTQ		;append [AL] to keyboard queue (read by CHSNS)
	POP	SI
	RET	

;Keyboard Trap Table (for KEY TRAPPING of non-soft keys)
; Referenced by POLKEY
;
TRPKTB:
	DB	30D,OFFSET NMKEYF+0	;ON KEY (Cursor Up)
	DB	29D,OFFSET NMKEYF+1	;ON KEY (Cursor Left)
	DB	28D,OFFSET NMKEYF+2	;ON KEY (Cursor Right)
	DB	31D,OFFSET NMKEYF+3	;ON KEY (Cursor Down)
	DB	0		;end-of-table
	PAGE	
	SUBTTL  Machine independent Keyboard input routines CHSNS, INKEY$
	PUBLIC	CHSNS
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CMDOFF:WORD,STRTAB:WORD
DSEG	ENDS

;Get key from keyboard if one is ready.
;Exit  - if Z is true, no key was ready, else [AX]=key
;        if C is true, returns 16 bit character
;        Soft keys are expanded if not being trapped, and not null.
;        if NZ AND NC AND [AL] = FF then a two byte character is returned
;               in DX.  The character is an OEM specific special character.
;        All other registers are preserved.
;
CHSNS:	PUSH	BX		;save caller's registers
	PUSH	CX
	PUSH	SI
	PUSH	DI
CHSNSI:	XOR	DL,DL		;clear high byte of 2-byte sequence
CHSNS0:	CALL	CONIN		;check for SOFTKEY
	JNZ	CHSNSS		;BRIF key found
	OR	DL,DL
	JZ	CHSNSX		;BRIF no key sensed and not 2nd of 2 bytes
	JMP	SHORT CHSNS0	;BRIF need 2nd byte of 2 byte character

CHSNSS:	OR	DL,DL
	JNZ	CHSNS2		;BRIF 2nd byte of 2 byte character
	CALL	CKDBLK		;see if this is the 1st byte of 2-byte seq
	JAE	CHSNG1		;branch not
	MOV	DL,AL		;Put first byte in [DL]
	JMP	SHORT CHSNS0	;Go get 2nd byte
CHSNS2:	MOV	AH,DL		;Put 1st byte in [AH]
	CMP	AH,LOW 200O	;Check for 8080 code which represents single 80
	JNZ	CHSN2A
	CMP	AH,AL
	JZ	CHSNG1		;Return 80 for 8080 char code
CHSN2A:	CALL	CHKFKY		;see if AX is a non-null function key
	JZ	CHSNS3		;BRIF not a string key that needs expansion
	JB	CHSNG1		;BRIF is super shift key(return first byte now)
	MOV	BYTE PTR F_SUPR,LOW 0
	JMP	SHORT CHSNSI	;Is string key, get first expansion and return
CHSNS3:
	OR	AH,AH		;else NZ, C Indicates 2 byte character
	STC	
	JMP	SHORT CHSNSX
CHSNG1:	OR	AL,AL		;set NZ, no-carry (got 1 byte)
	MOV	AH,LOW 0	;high-byte = 0 for single byte characters
;Check for 3 byte sequence case
	PUSHF	
	CMP	AL,LOW 254D	;Test for three byte sequence
	JNZ	CHSNG2		;Not a three byte sequence
	PUSH	AX		;Save first byte
	CALL	CONIN		;Get second byte
	MOV	DH,AL
	CALL	CONIN		;Get third byte
	MOV	DL,AL
	POP	AX		;Restore third byte
CHSNG2:	POPF	
CHSNSX:	POP	DI
	POP	SI
	POP	CX
	POP	BX
	RET	


CKDBLK:
;Check for function key (80,nn)
	CMP	AL,LOW 200O	;First check for 80,nn key
	STC	
	JE	CKDBLX		;branch if 1st of 2-byte sequence
	CMP	AL,LOW 255D
	STC	
	JE	CKDBLX		;BRIF 1st byte of two byte control function
	CLC	
CKDBLX:	RET	

;CONIN gets the next key from the soft-key being expanded (if any).
; If no soft-key is active, it calls POLKEY to get and queue key from OS,
; afterwhich it trys to get a key from the keyboard queue.
; On exit, Flags.Z is set if no key is ready, else [AL]=key
;
CONIN:	PUSH	BX
	CALL	GETFKY		;expand soft-key if active
	JNZ	CONINX		;branch if expanding soft-key
	PUSH	SI
	CALL	POLKEY		;try to get and queue key from OS
	MOV	SI,OFFSET KYBQDS
	CALL	GETQ		;[AL]=next key from keyboard queue
	POP	SI
CONINX:	POP	BX
	RET	

;Returns with FLAGS.NZ if AX is Universal key code for non-null Soft-key
;Also sets FLAGS.NC for softkey and FLAGS.C for super shift key
;       (note that for super shift the first character is in AL and must
;           be returned)
;
CHKFKY:	CMP	AH,LOW 200O
	JNE	NTFKYX		;branch if not soft-key
	PUSH	AX
	SUB	AL,LOW 32D
	JB	NTFKY1		;branch if not soft-key
	CMP	AL,LOW OFFSET NMKEYF
	JAE	NTFKY1		;branch if not soft-key
	MOV	BL,LOW 16D	;else, tell CHSNS to expand soft-key
	MUL	BL		;[AX]=16 * function-key id
	ADD	AX,OFFSET STRTAB	;Get soft-key address
	MOV	WORD PTR CMDOFF,AX	;save soft-key pointer for soft-key expansion
	MOV	BX,AX
	POP	AX
	CMP	BYTE PTR 0[BX],LOW 0	;set FLAGS.Z if null soft-key (and FLAGS.NC
	RET			; not super shift)
NTFKY1:
	JB	NTFKY9		;BRIF not super shift key
	POP	AX
	PUSH	AX
	CMP	AL,LOW "A"
	JB	NTFKY9		;BRIF not super shift key
	CMP	AL,LOW OFFSET "Z"+1
	JB	SUPRKY		;BRIF is super shift key
NTFKY9:
	POP	AX
NTFKYX:	XOR	BL,BL		;set FLAGS.Z - not soft-key(and FLAGS.NC not
	RET			;super shift)

	EXTRN	MAPSUP:NEAR,$FN:NEAR,$USR:NEAR,ALPTAB:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	F_SUPR:WORD
DSEG	ENDS
SUPRKY:
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CURLIN:WORD
DSEG	ENDS
	CMP	WORD PTR CURLIN,65535D	;Test for direct mode
	JNZ	NTFKY9		;Not direct mode - don't expand Supershift key
	PUSH	CX
	CALL	MAPSUP		;Map super shift key to letter in AL and count
	XOR	CL,CL		;Interface doc says CH contains count
	JCXZ	SUPKY9		;Request to inhibit SKey expansion
	SUB	AL,LOW "A"	; in CH
;Scan for CHth reserved word in table that includes words starting with letter
;in AL
;Set up for CONIN to return the reserved word letters one at a time and return
;AL now.
	MOV	BH,LOW 0
	MOV	BL,AL
	ADD	BL,AL
	PUSH	BX		;Save ALPTAB offset
	ADD	BX,OFFSET ALPTAB
SUPKY0:
	MOV	BX,WORD PTR CS:0[BX]	;Get start of reserved words for this letter
SUPKY1:
	TEST	BYTE PTR CS:0[BX],LOW 377O
	JZ	SUPKYZ		;BRIF did not find super key definition(abort)
	DEC	CH
	JZ	SUPKYX		;BRIF found the reserved word
	DEC	BX
SUPKY2:	INC	BX
	TEST	BYTE PTR CS:0[BX],LOW 377O
	JNS	SUPKY2		;BRIF not at the end of this reserved word
	INC	BX		;Skip end of string
	INC	BX		;Skip token value
	JMP	SHORT SUPKY1	;Check next reserved word
;Found the reserved word
SUPKYX:	MOV	WORD PTR CMDOFF,BX	;Set up for string key input
	DEC	CH
	MOV	BYTE PTR F_SUPR,CH	;Set super shift key flag
	POP	BX
SUPKY9:	POP	CX
	POP	AX
	OR	AX,AX		;Set FLAGS.NZ
	STC			;Else return AL=first char, FLAGS.NZ and
	RET			;FLAGS.C When key not found then single char
				; returned as first expansion character.  No
				;expansion takes place since expansion table
				;not initialized.
;Did not find reserved word in ALPTAB, perhaps its in ALPTAX
	EXTRN	ALPTAX:NEAR
SUPKYZ:	POP	BX
	OR	BH,BH
	JNZ	SUPKY9		;BRIF already checked ALPTAX, exit
	PUSH	CX		;Put non-zero high byte on stack(so above
				; branch is taken)
	ADD	BX,OFFSET ALPTAX
	JMP	SHORT SUPKY0	;Continue scan of reserved words


;GETFKY: Called to retrieve a character from the SOFTKEY buffer.
;Supershift key strings are expanded to end in a space unless the last character
; is a "(" or if the token is $FN or $USR.
;
; Entry - CMDOFF is the index into the buffer
;         F.SUPR = ^O0   - not a supershift softkey
;                  ^O377 - Supershift (CMDOFF points to character)
;                  Other - Supershift (F.SUPR is the next character)
; Exit  - flags.Z set   - no key available
;                 reset - AL contains character
;         BX is used.
;
GETFKY:	CMP	WORD PTR CMDOFF,0D	;Softkey available?
	JZ	GETFKX		;No special key available
	CALL	GTSFKY		;Get a softkey
	CALL	EOKTST		;Test for end of softkey
GETFKX:	RET	

GTSFKY:	MOV	BX,WORD PTR CMDOFF	;Get char. offset
	MOV	AL,BYTE PTR F_SUPR	;Get super-shift flag
	TEST	AL,LOW 377O	;Super-shift key in progress?
	JZ	NOTSUP		;Not a super-shift key
	CMP	AL,LOW 377O	;F.SUPR is ^O377 or current character
	JNZ	GTSFKX		;Got the key
				;Super-shifts are in the CS:
	DB	2EH		; Code segment override
NOTSUP:	MOV	AL,BYTE PTR 0[BX]	;Get next character
	XOR	AH,AH		;Clear high byte
	INC	BX		;Index to next key
GTSFKX:	RET	

EOKTST:
	TEST	BYTE PTR F_SUPR,LOW 377O	;Super-shift key expansion?
	JZ	EFKTST		;No - testing end of function key
	OR	AL,AL		;Test highbit (indicates end of key word)
	JNS	NOHGBT		;Not highbit terminated
	AND	AL,LOW 177O	;Map out high bit
	CMP	AL,LOW "("	;Supershift key ending in "("?
	JZ	EOKTRU		;Yes, don't end in space
	CMP	BYTE PTR CS:0[BX],LOW OFFSET $USR	;$USR token?
	JZ	EOKTRU		;Yes, don't end in space
	CMP	BYTE PTR CS:0[BX],LOW OFFSET $FN	;$FN token?
	JZ	EOKTRU		;Yes, don't end in space
	MOV	BL,LOW " "	;End in a space
	JMP	SHORT EOKSSX	; and exit

NOHGBT:	INC	BYTE PTR F_SUPR	;Test for last char. in F.SUPR
	DEC	BYTE PTR F_SUPR	;(Depends on 128 chars in keyword char. set)
	JS	EOKTSX		;Last char NOT from F.SUPR (F.SUPR was 377)
	JMP	SHORT EOKTRU	;Last char from F.SUPR - end of supershift
				;Test must always leave FLAGS.Z reset
EFKTST:	OR	AL,AL		;Test for null function key
	JZ	EOKTRU		;Null F key incountered
	TEST	BYTE PTR 0[BX],LOW 377O	;Test for end of function key
	JNZ	EOKTSX		;Not end of function key
	OR	SP,SP		;There is always a character at this point
EOKTRU:	MOV	BX,0D		;Prepare to turn off CMDOFF
EOKSSX:
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	F_SUPR:WORD
DSEG	ENDS
	MOV	BYTE PTR F_SUPR,BL	;Turn off current supershift key expansion
EOKTSX:	MOV	WORD PTR CMDOFF,BX	;Store new softkey expansion index
	RET	


;SFTOFF - Turn off softkey expansion for the current softkey.  This routine
;         has been documented to OEMs for use in implementing PEEK/POKE
;         filters for addresses documented to IBM BASIC users.
;
	PUBLIC	SFTOFF
SFTOFF:	MOV	WORD PTR CMDOFF,0D	;Stop soft key expansion
	MOV	BYTE PTR F_SUPR,LOW 0D	;Turn off super shift flag
	RET	

;KYBSNS - Detect whether keys are available in the keyboard buffer.
;         This routine has been documented to OEMs for use in implementation
;         of PEEK/POKE filters for addresses documented to IBM BASIC users.
;Entry - none
;Exit  - PSW.Z set indicates that the keyboard buffer is empty.
;        all registers preserved
;
	PUBLIC	KYBSNS
	EXTRN	NUMQ:NEAR
KYBSNS:	PUSH	AX
	PUSH	SI
	MOV	SI,OFFSET KYBQDS	;SI = keyboard queue descriptor
	CALL	NUMQ		;Get the number of keys available
	OR	AX,AX		;Set flags
	POP	SI
	POP	AX
	RET	

;FKYSNS - Sense the availability of a softkey.  This routine is documented to
;         IBMLIK OEMs for support of a PEEK/POKE address documented by IBM.
;Entry - none
;Exit  - PSW.C set indicates softkey expansion is in progress
;        PSW.Z set indicates that the next softkey is not the last key
;              of a supershift key.
;        All registers preserved
;
	PUBLIC	FKYSNS
FKYSNS:	CMP	BYTE PTR CMDOFF,LOW 0D	;Test for expansion in progress
	JZ	FKYSNX		;Expansion not in progress
	CMP	BYTE PTR F_SUPR,LOW 255D	;Test for super-shift expansion
	JZ	FKYSNW		;SS key but not last key
	CMP	BYTE PTR F_SUPR,LOW 0D	;Test for super-shift expansion
	JZ	FKYSNW		;Function key expansion in progress
FKYSNW:
	STC	
FKYSNX:	RET	
	PAGE	
;INKEY$ - get key from key-queue if one exists, else return null string.
; Returns 2-byte string for DBLCHR.  For function keys, returns next char
; of function key if key is not null.  If F-key is null, it returns
; 2-byte string which identifies function key.
;
	PUBLIC	INKEY
	EXTRN	INKMAP:NEAR,INFMAP:NEAR
	EXTRN	STRINI:NEAR,STRIN1:NEAR,SETSTR:NEAR,PUTNEW:NEAR,CHRGTR:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	DSCPTR:WORD,VALTYP:WORD,FACLO:WORD
DSEG	ENDS

INKEY:	CALL	CHRGTR
	PUSH	BX		;save text pointer
INKGET:	CALL	CHSNS		;get next key from queue
	JZ	NULRT		;branch if no key is queued
	CALL	INKMAP		;OEM map routine for INKEY$
	JZ	INKGET		;OEM has no associated character
	JAE	INKEY1		;branch if not 2-byte sequence
	PUSH	AX		;save char code
	MOV	AL,LOW 2
	CALL	STRINI		;initialize 2-byte string
	MOV	BX,WORD PTR DSCPTR
	POP	DX		;restore char code
	XCHG	DH,DL		;return high-byte in left end of string
	MOV	WORD PTR 0[BX],DX
	JMP	PUTNEW
INKEY1:	PUSH	AX
	CALL	STRIN1		;MAKE ONE CHAR STRING
	POP	AX
	MOV	DL,AL
	XCHG	AH,AL		;put bytes in correct order
	CALL	SETSTR		;STUFF IN DESCRIPTOR AND GOTO PUTNEW
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	DSEGZ:WORD
DSEG	ENDS
NULRT:	MOV	BX,OFFSET DSEGZ	;GUARANTEED ZERO IN DATA SEGMENT
	MOV	WORD PTR FACLO,BX
	MOV	BYTE PTR VALTYP,LOW 3
	POP	BX		;restore text pointer
	RET	
	PAGE	
	SUBTTL  Cursor Support

;STCTYP Set the new cursor type
;       This routine determines the next cursor type.
;Entry - PSW.C set indicates the cursor must be the user cursor
;        PSW.C reset indicates the cursor must be the insert mode
;              cursor or the overstrike cursor.
;EXIT  - All registers preserved
;
	PUBLIC	STCTYP
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CSRTYP:WORD,F_INST:WORD
DSEG	ENDS
STCTYP:	PUSH	AX
	MOV	AL,LOW 3D	;Assume user cursor
	JB	CSRSET		;Assumption correct
	DEC	AL		;Assume overwrite mode cursor
	TEST	BYTE PTR F_INST,LOW 255D	;Test for insert mode
	JZ	CSRSET		;Ovewrite mode discovered
	DEC	AL		;Set for insert mode
CSRSET:	MOV	BYTE PTR CSRTYP,AL	;Save the type
	POP	AX
	RET	

;SETCSR - Set the cursor to the new cursor type.
;         This routine ensures that the cursor is set to the new cursor type.
;Entry - none
;Exit  - all registers preserved
;
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CSRTYP:WORD,CSRFLG:WORD
DSEG	ENDS
	EXTRN	CSRDSP:NEAR
	PUBLIC	SETCSR
SETCSR:	PUSH	AX
	MOV	AL,BYTE PTR CSRTYP	;Get cursor type
	CMP	BYTE PTR CSRFLG,AL	;Test for cursor change
	MOV	BYTE PTR CSRFLG,AL	;Remember the new cursor type
	JZ	CSROK		;Cursor already set properly
	CALL	CSRDSP		;Display the cursor
CSROK:	POP	AX
	RET	

CSEG	ENDS
	END
                