; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   GWRAM - GW BASIC OEM Independent RAM Declarations

COMMENT	*
        --------- --- ---- -- ---------
        COPYRIGHT (C) 1981 BY MICROSOFT
        --------- --- ---- -- ---------
        *

	INCLUDE	GIO86U
	.SALL

	.RADIX	10

MUSIC=PLAYSW OR BEEPSW
GRPMCL=1
NMPAGE=1

	PUBLIC	HEDING,$DATE,CERMSG

	QUOTE=42O
	CR=15O
;

	PAGE	
	SUBTTL Sign on message and other data to be discarded after INIT

HEDING:	ACRLF	
	DB	"(C) Copyright Microsoft 1982"
$DATE:	DB	"         "	;$DATE
	ACRLF	
	DB	00O		;Terminate previous string.

CERMSG:	ACRLF			;Command line error message
	DB	"Error detected in command line"
	ACRLF	
	DB	00O

CSEG	ENDS			; End of code segment constants
	PAGE	
DSEG	SEGMENT PUBLIC 'DATASG'		; Start of data segment GW variables
	ASSUME DS:DSEG

;
; ASM86 version don't need to fool around with offsets into OEMBAS,
; as the linker can preload segments with data.  Thus, the R macros
; need only define the label and a size if the variable is not intitalized.
;
R1	MACRO	NAME,SIZE
	Q=Q+SIZE
	QDS=QDS+SIZE
	PUBLIC	NAME
	ORG	$-1
NAME	LABEL WORD
	ORG	$+1
IF	SIZE  
	DB	SIZE DUP(?)
ENDIF 
ENDM 

R	MACRO	NAME,SIZE
	Q=Q+SIZE
	QDS=QDS+SIZE
	PUBLIC	NAME
NAME	LABEL WORD
IF	SIZE  
	DB	SIZE DUP(?)
ENDIF 
ENDM 

RINIT	MACRO	NAME,SIZE
	PUBLIC	NAME
NAME	LABEL WORD
	QQ=NAME-MOVDAT-Q
IF	QQ  
	%OUT  *FATAL RINIT ERROR*
ENDIF 
	Q=Q+SIZE
	QDS=QDS+SIZE
ENDM 

ACRLF	MACRO	
	DB	13D
	DB	10D
ENDM 


	Q=0
	QDS=0
	RINIT	MOVDAT,0
	RINIT	FREFLG,1	;Flag to print BYTES FREE message
	DB	0D
	RINIT	INITFG,1	;Initialization complete flag
	DB	0D		;INITFG
	RINIT	ESCFLG,1	;Escape seq. in progress flag
	DB	0D
	RINIT	TWOBYT,1	;Save location for collecting two byte chars
	DB	0D

;
; Keyboard Support Variables
;
	RINIT	STRTAB,16D*NMKEYF	;SOFTKEY table
;
;** The following line is used by a source maint. tool - do not remove
;** (OEM FUNCTION KEY DEFINITIONS) **************
;
	DB	"LIST"		;FUNCTION 1
	DB	0D
	DB	11D DUP(?)
	DB	"RUN"		;FUNCTION 2
	DB	OFFSET CR,0
	DB	11D DUP(?)
	DB	"LOAD"		;FUNCTION 3
	DB	OFFSET QUOTE,0
	DB	10D DUP(?)
	DB	"SAVE"		;FUNCTION 4
	DB	OFFSET QUOTE,0
	DB	10D DUP(?)
	DB	"CONT"		;FUNCTION 5
	DB	OFFSET CR,0
	DB	10D DUP(?)
	DB	","		;FUNCTION 6
	DB	OFFSET QUOTE
	DB	"LPT1:"
	DB	OFFSET QUOTE,0
	DB	7D DUP(?)
	DB	"TRON"		;FUNCTION 7
	DB	OFFSET CR,0
	DB	10D DUP(?)
	DB	"TROFF"		;FUNCTION 8
	DB	OFFSET CR,0
	DB	9D DUP(?)
	DB	"KEY"		;FUNCTION 9
	DB	0D
	DB	12D DUP(?)
	DB	"SCREEN 0,0,0"	;FUNCTION :
	DB	OFFSET CR,0
	DB	2D DUP(?)
;**(END OF DEFINITIONS) *************************
;The preceding line is used by a source maint. tool - do not remove.
;
	RINIT	ENDTAB,0
	DIST=ENDTAB-STRTAB-(16D*NMKEYF)
IF	DIST  
	%OUT/++++BAD SOFTKEY PADDING+++++/
ENDIF 


	RINIT	CMDOFF,2	;Index into ESCBUFF or STRTAB
	DW	0D
	RINIT	FKCNUM,1	;Number of chars. per fun. key to display
	DB	6D		; on the last line
	RINIT	ACTPAG,1	;Active page
	DB	1 DUP(?)
	RINIT	F_EDPG,1	; Flag - =^O377 indicates program statement edit
	DB	0
	RINIT	SEMFLG,1	; Flag - non-zero indicates INPUT; statement(no
	DB	0		;        CRLF at end of input)
	RINIT	F_CRET,1	;Zero indicates last character output was CR
	DB	377O
	RINIT	F_INST,1	; Flag - =^O377 indicates insert mode
	DB	0
	RINIT	F_EDIT,1	; Flag - non-zero indicates INLIN active
	DB	0
;
;MACLNG variables for DRAW
;
	RINIT	DRWSCL,1	;DRAW: SCALE
	DB	00O		;DRAW POS,2 ling factor
	RINIT	DRWFLG,1	;OPTION FLAGS
	DB	00O		;DRAW flag
	RINIT	DRWANG,1	;DRAW "ANGLE" (0..3)
	DB	00O		;DRAW translation angle
	RINIT	MCLPTR,2	;MAC LANG PTR
	DB	2 DUP(?)	;Other DRAW vars. not initialized
	RINIT	MCLLEN,1	;STRING LENGTH
	DB	1 DUP(?)
	RINIT	MCLTAB,2	;PTR TO COMMAND TABLE
	DB	2 DUP(?)
;OEM Independent Music Locations
	RINIT	OCTAVE,1	;PLAY: OCTAVE
	DB	4D		;OCTAVE
	RINIT	BEATS,1		;BEATS
	DB	120D		;BEATS (default = 120 L4 notes per minute)
	RINIT	NOTELN,1	;NOTE LENGTH
	DB	4D		;NOTELN
	RINIT	NOTE1L,1	;One (current) Note Length
	DB	4D		;NOTE1L
	RINIT	MSCALE,1	;Note Length Scale Factor (ML,MN,MS)
	DB	3D		;MSCALE (default = 7/8 time)
	RINIT	MMODE,1		;Music Mode (Foreground/Background)
	DB	0D		;MMODE (default = forground)
	RINIT	SNDTIC,1	;Sound/Clock tick modulo counter
	DB	1 DUP(?)
	RINIT	SNDBAS,2	;Base addr of Sound Queue Cells
	DB	2 DUP(?)
	RINIT	SNDOUT,2	;Base addr of Sound Queue Buffer
	DB	2 DUP(?)
	PAGE	
	SUBTTL  Page Dependent OEM Independent Variables

; Page Dependent variables arranged as follows:
; Variables which are initialized by block move are declared using the RINIT
; macro.  These declarations are made within the definition of macro PDIRAM
; (page dependent initialized RAM).
; Variables which are not initialized by block move are declared using the R
; macro.  These declarations are made within the definition of macro PDURAM
; (page dependent uninitialized RAM).
; The memory map for multi page page dependent variables is as follows:
;--------------------------------------------------------------------------
;
; CS: resident initialization values are copied to DS: by the same copy
;     as usual.
;
;--------------------------------------------------------------------------
;
; DS:PDIDS1:              ;Beginning of ini value block copied from CS:
;                         ; This block is used to initialize pages at
;                         ; various times during execution.
;
;           (initialization values set by CS: to DS: block move)
;
; DS:FPDVAR:              ;First page dependent variable
;
;           (first come vars initializable by block move from PDIDS1.
;            Then come all other vars. which are page dependent.)
;
; DS:LPDVAR:              ;Address of end of variables for active page
;                         ; The variables between FPDVAR and LPDVAL are the
;                         ; ones that are labeled as per RINIT and R macros.
;
; (Lastly comes (LPDVAR-FPDVAR)*NMPAGE RAM locations used to store the state
;   of each page while it is not active.)
;
;In systems where only one page is available label FPDVAL is made to
; coincide with label PDIDS1 and there are no locations reserved to store
; the state of the page while it is not active.
;

	PUBLIC	PDIDS1		;Start of DS: init block.
	PUBLIC	FPDVAR,LPDVAR	;Addresses of first and last active page vars in DS:

PDIRAM	MACRO	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;       Start of declaration of page dependent variables
;       which are initialized by block move either by
;       GWINIT (for one page systems) or
;       PDVINI (Page Dependent Var INI for multi-page systems
;
;CAUTION!!!
;
; The PDIRAM module is invoked several times.  CS: space should be
; reserved only once.  To solve this problem pseudos which declare
; CS: values must be accessed through a macro which can either be
; defined as calls to the appropriate pseudo or as NOPs.
; Currently, DB, DW, and DT are the only macros supported in this manner.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
;Screen Editor Support Variables
;

	RINIT	KEYSW,1		;Flag for softkey display
	DB	0		;Flag: 0=do not display softkeys.
ENDM 

PDURAM	MACRO	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;       Start of declaration of page dependent variables
;
; The PDRAM module is invoked several times.  CS: space should
; not be reserved.  DS: lables must be declared only once.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;The following is page dependent data unique to the SCNDRV module
;
	R	LINLEN,1	; Number of characters in a line
	R	LINCNT,1	; Number of lines
	R	CRTWID,1	; Characters per line
	R	WDOTOP,1	; Top line in window(1-[LINCNT])
	R	WDOBOT,1	; Bottom line in window([WDOTOP]-[LINCNT])
	R	WDOLFT,1	; Leftmost column in window(1-[CRTWID])
	R	WDORGT,1	; Rightmost column plus one([WDOLFT]-[LINCNT])
	R	WDTFLG,1	; Default width of SCRN:
	R	LINTTB,2*(NMLINE+1)	; Line Terminator table
	R	TRMCUR,2	; Address of current terminator entry (2 bytes)
	R	FSTLIN,1	; Line number saved by SCNSTM call
	R	FSTCOL,1	; Column saved as above and decreases to WDOLFT
	R	LSTLIN,1	; Line number saved by SCNSTM and grows as the
	R	LSTCOL,1	; Column saved as above which grows as the
				;   col on LSTLIN).

;NOTE: Some Routines expect CSRX to immediately follow CSRY
	R	CSRY,1		; Current line(1-[LINCNT])
	R	CSRX,1		; Current column(1-[CRTWID])
ENDM 


RINIT	MACRO	NAME,SIZE
	QDS=QDS+SIZE
ENDM 

	QDS=Q

	R	PDIDS1,0	;Page Dependent DS: init. value block start
	PDIRAM			;Insert Ini values
	FPDVAR=PDIDS1		;INI area and First Page Dependent VARiable
				; are overlaid in this case
RINIT	MACRO	NAME,SIZE
	PUBLIC	NAME
NAME	LABEL WORD
	QQ=NAME-MOVDAT-QDS
IF	QQ  
	%OUT  *FATAL RINIT ERROR*
ENDIF 
	Q=Q+SIZE
	QDS=QDS+SIZE
ENDM 

;Although RINIT is used subsequently there are no more CS: RAM locations
; to declare.   The RINIT will be used for DS: declaration only
;
;
; Now declare the labeled DS: for 1 page systems.  This area is the
;       labeled active page for multi-page systmes
;
	PDIRAM			;Declare Active Page Inited RAM
;
	PDURAM			;Declare Active Page Uninit RAM
	R	LPDVAR,0	;End of active page vars in DS:

RINIT	MACRO	NAME,SIZE
IF	SIZE  
	DB	SIZE DUP(?)
	QDS=QDS+SIZE
ENDIF 
ENDM 
R	MACRO	NAME,SIZE
IF	SIZE  
	DB	SIZE DUP(?)
	QDS=QDS+SIZE
ENDIF 
ENDM 
;
;Now put back the R macro for use by Page Independent Uninitialized RAM
; declarations.
;
;P.I.U. RAM MUST be declared after all P.D.U. RAM, P.D.I. RAM,
; and P.I.I. RAM.
;

R	MACRO	NAME,SIZE
	PUBLIC	NAME
NAME	LABEL WORD
IF	SIZE  
	DB	SIZE DUP(?)
ENDIF 
	QQ=NAME-MOVDAT-QDS
IF	QQ  
	%OUT  *FATAL RINIT ERROR*
ENDIF 
	Q=Q+SIZE
	QDS=QDS+SIZE
ENDM 
	PAGE	
	SUBTTL  Page Independent Uninitialized RAM Location Definitions

;OEM Independent Graphics Locations
;
	R	GRPACX,2	; Previous X Coordinate
	R	GRPACY,2	; Previous Y Coordinate
	R	ATRBYT,1	;Attribute Byte to Store
	R	GXPOS,2		;X Position of Second Coordinate
	R	GYPOS,2		;Y Position of Second Coordinate
	R1	MAXUPD,2	;Address of Major Axis Move Update
	R1	MINUPD,2	;Address of Minor Axis Move Update
	R	MAXDEL,2	;Largest Delta for Line
	R	MINDEL,2	;Smaller of 2 Deltas for Line
	R	ASPECT,2	;ASPECT RATIO
	R	CENCNT,2	;END CIRCLE POINT COUNT
	R	CLINEF,1	;LINE-TO-CENTER FLAG
	R	CNPNTS,2	;1/8 NO. OF PTS IN CIRCLE
	R	CPLOTF,1	;PLOT FLAG
	R	CPCNT,2		;1/8 NO. OF PTS IN CIRCLE
	R	CPCNT8,2	;NO. OF PTS IN CIRCLE
	R	CRCSUM,2	;CIRCLE SUM
	R	CSTCNT,2	;START COUNT
	R	CSCLXY,1	;FLAG WHETHER ASPECT WAS .GT. 1
	R	CSAVEA,2	;ADVGRP C save area
	R	CSAVEM,1	;ADVGRP C save area
	R	CXOFF,2		;X OFFSET FROM CENTER SAVE LOC
	R	CYOFF,2		;Y OFFSET SAVE LOCATION
	R	LOHMSK,1	;RAM SAVE AREA FOR LEFT OVERHANG
	R	LOHDIR,1	;*** LOHMSK & LOHDIR MUST BE CONTIG !
	R	LOHADR,2
	R	LOHCNT,2
	R	LFPROG,1	;PAINT: SCAN LINE ALREADY PAINTED FLAGS
	R	RTPROG,1
	R	SKPCNT,2	;SKIP COUNT
	R	MOVCNT,2	;MOVE COUNT
	R	PDIREC,1	;PAINT DIRECTION
	R	PUTFLG,1	;WHETHER DOING PUT() OR GET()
	R	QUEINP,2
	R	QUEOUT,2
	R	PSNLEN,2	;Queue present length
	R	QUELEN,2	;Maximum queue length

	R	SAVLEN,2	;used by BLOAD, BSAVE

;
;Device Variables
;

	PUBLIC	FOPTSZ
	FOPTSZ=64D		;size of file open options buffer

	R	FILOPT,FOPTSZ	;buffer for Special-Device Open Options

;
;Line Printer variables
;
;       note: If size of LPT Device Control Block changes,
;             routine GLPDCB in GIOLPT must be changed.
;
	R	LP1DCB,4*NMLPT	;LPT1 device control block
				;2 bytes (width, position)
;
;Keyboard variables
;
	PUBLIC	KYBQSZ
	KYBQSZ=32D
	R	KYBQDS,8	;queue descriptor (for format see GIO86)
	R	KYBQUE,KYBQSZ	;buffer circular key queue

;
;RS232C variables
;
	R	MSWSIZ,2D	;/M: value
	R	MSWFLG,1D	;/M: exists flag
	R	CSWSIZ,2D	;/C: value
	R	CSWFLG,1D	;/C: exists flag
	R	NEWDS,2D	;New DS:
	R	COMDSC,18D	;buffer used to communicate RS232 requests to OS
	R	CM1DCB,24D*NMCOMT	;COM1 device control block (24 bytes per device)
	R	LSTIOB,1	;Contains Last RS232 unit accessed (0..15)
				;2 bytes (width, position)
				;2 bytes (width, position)
;
; RAM USED FOR EVENT TRAPPING
;
	R	TRPTBL,3*NUMTRP	;trap table - see GWSTS
	R	ONGSBF,1	;see NEWSTT
	R	SOFTKY,1	;used by key trapping in GWSTS
	R	F_SUPR,1	; Flag - non-zero =  super shift expansion

DSEG	ENDS
	END
                                                        