; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   ITSA86 - Resident Initialization for I8086

COMMENT	*

--------- --- ---- -- --------- -----------
COPYRIGHT (C) 1982 BY MICROSOFT CORPORATION
--------- --- ---- -- --------- -----------

        by Len Oorthuys Microsoft Corp.
        *

;************************************************************************
;*                                                                      *
;*  NOTE: Any code linked after this module is discarded after          *
;*        Initialization of BASIC.                                      *
;*                                                                      *
;************************************************************************

	INCLUDE	GIO86U
	.SALL

CPM86=0
TETRA=0				;Save DS in DATSEG(defined in CS and
				;   used by interrupt routine).

	INCLUDE	MSDOSU


DSEG	SEGMENT PUBLIC 'DATASG'
	ASSUME DS:DSEG
	EXTRN	TEMP8:WORD,TXTTAB:WORD
DSEG	ENDS

	EXTRN	NODSKS:NEAR,LRUN:NEAR,READY:NEAR

	PUBLIC	WORDS
WORDS:	DB	" Bytes free"	;WORDS
	DB	0

	PAGE	
	SUBTTL  INITSA
	PUBLIC	INITSA
INITSA:
	CALL	NODSKS
	CALL	MAPINI		;Init the new memory map
	MOV	BX,WORD PTR TXTTAB
	DEC	BX
	MOV	WORD PTR 0[BX],0D
	MOV	BX,WORD PTR TEMP8	;POINT TO START OF COMMAND LINE
	MOV	AL,BYTE PTR 0[BX]	;GET BYTE POINTED TO
	OR	AL,AL		;IF ZERO, NO FILE SEEN
	JZ	GREADY
	JMP	LRUN		;TRY TO RUN FILE
GREADY:	JMP	READY
	PAGE	
;BASVAR - Retrieve or Modify BASIC Internal Data Locations
;This routine provides a method to retrieve or modify certain BASIC internal
;data locations.  This routine is provided as support for PEEK and
;POKE filsters.  These data items have been documented to IBM GW BASIC users
;in the IBM Technical Reference Manual.
;
;Entry - AX = Value to set (if PSW.C set)
;        BX = 0 for current program line number
;             1 for last program line containing an error
;             2 for address of user program text
;             3 for address of user variable table
;        PSW.C set indicates to write the variable
;        PSW.C reset indicates to read the variable
;Exit  - AX = value of appropriate variable
;        BX modified
;
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CURLIN:WORD,ERRLIN:WORD,TXTTAB:WORD,VARTAB:WORD
DSEG	ENDS
	PUBLIC	BASVAR
BVTAB:	DW	OFFSET CURLIN
	DW	OFFSET ERRLIN
	DW	OFFSET TXTTAB
	DW	OFFSET VARTAB

BASVAR:
	PUSHF	
	SHL	BX,1		;make word offset
	POPF			;preserve PSW.C (input parameter)
	MOV	BX,WORD PTR BVTAB[BX]	;Get address of appropriate variable
	JNB	BASVRD		;Performing read function
	MOV	WORD PTR 0[BX],AX	;Perform write function
BASVRD:	MOV	AX,WORD PTR 0[BX]	;Perform read function
	RET	
	PAGE	
	SUBTTL  Initialization Support Routines
DSEG	SEGMENT PUBLIC 'DATASG'		
	EXTRN	CSWFLG:WORD,CSWSIZ:WORD,MSWFLG:WORD,MSWSIZ:WORD,NEWDS:WORD
	EXTRN	STKLOW:WORD,MEMSIZ:WORD,TOPMEM:WORD,SAVSEG:WORD,MAXMEM:WORD
	EXTRN	FILTAB:WORD
	EXTRN	FREFLG:WORD	;BYTES FREE message flag
DSEG	ENDS

	EXTRN	CLEARC:NEAR,OMERR:NEAR
	EXTRN	SETCBF:NEAR	;OEM Set COM Buf (size & location)
	EXTRN	LINPRT:NEAR,STROUT:NEAR,CRDO:NEAR	;COM
	EXTRN	CPMMEM:NEAR


	PUBLIC	MAPCLC,MAPINI

;MAPINI - Set up the final memory map.
;Entry  - NEWDS  = final DS:
;         MSWSIZ = final MAXMEM
;Exit   - DS: and stack moved.
;
MAPINI:
;Move the stack to the end of the new memory map
	POP	BX		;Return address
	CLI			;disable external interrupts
				; while changing memory map
	MOV	AX,WORD PTR NEWDS
	MOV	SS,AX
	MOV	SP,WORD PTR MSWSIZ	;
	PUSH	BX		;Return address

;Move the data segment
	MOV	ES,AX		;NEWDS
	XOR	SI,SI
	MOV	CX,WORD PTR TXTTAB	;Amount of memory to move
	SHR	CX,1		;In words
	CLD	
	MOV	BX,DS
	CMP	AX,BX		;Test for direction of copy
	JB	BLKCPY		;brif destination is below source
	STD			;Copy up
	MOV	SI,WORD PTR TXTTAB	;starting from top
BLKCPY:
	MOV	DI,SI
 REP	MOVSW

;Set new data segment
	MOV	DS,AX		;NEWDS
	EXTRN	SEGINI:NEAR
	CALL	SEGINI
	MOV	AX,DS
	MOV	WORD PTR SAVSEG,AX	;For PEEK/POKE
	STI			;enable external interrupts

;Insure zeros at TXTTAB
	MOV	BX,WORD PTR TXTTAB
	MOV	WORD PTR 0[BX],0D
	MOV	BYTE PTR 2[BX],LOW 0D	;Three zeros necessary

;Call CLEARC to set up stack and finalize the memory map
	MOV	AX,WORD PTR MSWSIZ
;Make sure that [TXTTAB]+<stack size>+32 does not overflow memory
	MOV	BX,WORD PTR TOPMEM
	SUB	BX,WORD PTR STKLOW	;BX=stack size
	JBE	GOMERR		;BRIF illegal stack(0 or less bytes)
	NEG	BX
	ADD	BX,AX		;BX=new stack bottom
	JNB	GOMERR		;BRIF MSWSIZ is less than stack size
	SUB	BX,32D		;Leave a little room for a program
	JB	GOMERR		;BRIF no room left
	CMP	BX,WORD PTR TXTTAB	;Is new MAXMEM big enough?
	JBE	GOMERR		;BRIF new MAXMEM smaller than data area
MAXRQ1:	MOV	BX,AX
	SUB	BX,WORD PTR MAXMEM	;Calc. seg. size difference
	MOV	WORD PTR MAXMEM,AX	;Memory request
	ADD	WORD PTR TOPMEM,BX
	ADD	WORD PTR STKLOW,BX
	ADD	WORD PTR FILTAB,BX
	ADD	WORD PTR MEMSIZ,BX
	POP	BX		;Return address (BX saved by CLEARC)
	CALL	CLEARC
	PUSH	BX		;Return address (BX saved by CLEARC)

;Set up program segment prefix
	MOV	DX,DS
	MOV	AH,LOW 38D	;Function ^H26
	INT	33D		;MSDOS function request

;Print free bytes message
	TEST	BYTE PTR FREFLG,LOW 255D	;BYTES FREE message flag
	JNZ	MAPINX		;Exit - message not to be printed
	MOV	BX,WORD PTR MEMSIZ
	SUB	BX,WORD PTR TXTTAB
	DEC	BX
	DEC	BX
	CALL	LINPRT		;PRINT # OF BYTES FREE
	MOV	BX,OFFSET WORDS	;TYPE THE HEADING
	CALL	STROUT		;"BYTES FREE"
	CALL	CRDO		;PRINT CARRIAGE RETURN
MAPINX:	RET	

GOMERR:	JMP	OMERR
	PAGE	
	SUBTTL  End of the New CS:

;All code loaded after this label is resident only until routine MAPINI
;initializes the new memory map.

CSEND:

;MAPCLC - Calculate the final memory map limits.
;Entry  - CSWFLG = Flag nonzero when /C: option exists
;         CSWSIZ = /C: option size
;         MSWFLG = Flag nonzero when /M: option exists
;         MSWSIZ = /C: option size
;Exit   - NEWDS  = Final DS: address
;         MSWSIZ = Highest memory address (future MAXMEM)
;
MAPCLC:
;Validate/get COM buffer size
	MOV	DX,OFFSET CSEND	;Location of COM buffer (New end of CS:)
	ADD	DX,15D		;Round to next higher paragraph
	MOV	CL,LOW 4D
	SHR	DX,CL
	MOV	CX,CS
	ADD	CX,DX		;Segment offset of COM buffer
	MOV	DX,WORD PTR CSWSIZ	;Segment size request
	TEST	BYTE PTR CSWFLG,LOW 255D	;Was there a /C: opt - PSW.Z for SETCBF
	CALL	SETCBF		;Report buffer size/loc
	JB	GOMERR		; & validate size
	MOV	WORD PTR CSWSIZ,DX	;COM buffer size

;Calculate NEWDS (New DS:)
; DX  - COM buffer size
; NEWDS = (D+15/16) + DS:
	ADD	DX,15D		;Round off to paragraph
	SHR	DX,1
	SHR	DX,1
	SHR	DX,1
	SHR	DX,1
	ADD	DX,CX		;Skip COM buffer
	JO	GOMERR
	MOV	WORD PTR NEWDS,DX

;Validate the /M option or calculate the maximum possible MAXMEM
;1. Calcualte maximum MAXMEM based on the NEWDS
;2. If there was no /M option then goto 4
;3. Compare /M to the maximum and declare an error if /M is larger
;4. Save the new memory size as MSWSIZ
	PUSH	BX		;Save text pointer
	MOV	BX,WORD PTR CPMMEM
	SUB	BX,DX		;Avail paragraphs
	JB	GOMERR
	MOV	DX,OFFSET 65535D/16D	;Max usable paragraphs
	CMP	BX,DX
	JB	MAXREQ		;More than enough
	MOV	BX,DX
MAXREQ:	MOV	CL,LOW 4D
	SHL	BX,CL		;DX has valid maximum bytes
	TEST	BYTE PTR MSWFLG,LOW 255D
	JZ	NOMOPT		;No memory option
	MOV	DX,WORD PTR MSWSIZ	;Get /M: size
	CMP	BX,DX
	JB	GOMERR		;Not enough for request
	MOV	BX,DX
NOMOPT:	MOV	WORD PTR MSWSIZ,BX	;New MAXMEM
;       ADDI    BX,^D256
;       JB      MAXRQ1                  ;BRIF very large MAXMEM, value OK
;       CMP     BX,TXTTAB               ;Is new MAXMEM big enough?
;       JBE     GOMERR                  ;BRIF new MAXMEM smaller than data area
	POP	BX
	RET	

;SEGOFF     Convert end of memory segment to offset from current DS
;
;   On entry:   BX=last segment in memory
;               DS=current data segment
;
;   On exit:    BX=offset from current segment to paragraph specified by BX
;               Other registers unchanged, flags modified
;
	PUBLIC	SEGOFF
	EXTRN	OMERR:NEAR

SEGOFF:	PUSH	CX
	MOV	CX,DS
	SUB	BX,CX		;[BX]=number of paragraphs free for DSEG
	JBE	SGOFER		;BRIF last segment is less than current
	MOV	CX,7777O	;[CX]=max num of paragraphs BASIC could use
	CMP	BX,CX
	JBE	LESS64		;Brif less than 64k bytes available
	MOV	BX,CX		;don't need more than 64k bytes
LESS64:
	MOV	CL,LOW 4
	SHL	BX,CL		;convert paragraphs to bytes
	POP	CX		;restore caller's CX
	RET	
SGOFER:	JMP	OMERR

CSEG	ENDS
	END
                                                      