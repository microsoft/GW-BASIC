; [ This translation created 12-Jan-83 by Version 4.3 ]

	SUBTTL GIO86U - Device Independent I/O Constants and Macros

COMMENT	*

--------- --- ---- -- ---------
COPYRIGHT (C) 1982 BY MICROSOFT
--------- --- ---- -- ---------

        Programmer: Tom Corbett,  Microsoft Inc.

        *

ROFFST	MACRO	NAME,SIZE	;define record macro
	NAME=_OFFST
	_OFFST=_OFFST+SIZE
ENDM 


;ASCII character definitions
;
	ASCCTC=3D		;CTL-C
	ASCBS=8D		;backspace
	ASCTAB=9D		;Tab
	ASCLF=10D		;Line Feed
	ASCCR=13D		;Carriage Return
	ASCCTS=19D		;CTL-S
	ASCCTZ=26D		;Control Z (End-of-file for some devices)
	ASCESC=27D		;Escape
	ASCSPC=32D		;Space

;Special File ID's (identified by 1st byte of file)
;
	BINFID=255D		;files created by SAVE "fn"
	PROFID=254D		;files created by SAVE "fn",P
	BSVFID=253D		;files created by BSAVE "fn"

;Generalized I/O Function Codes:
;
	_OFFST=0		;initialize count
	ROFFST	G_EOF,2		;test EOF for file opened to this device
	ROFFST	G_LOC,2		;LOC
	ROFFST	G_LOF,2		;LOF
	ROFFST	G_CLS,2		;perform special CLOSE functions for this device
	ROFFST	G_SWD,2		;set device width
	ROFFST	G_RND,2		;GET/PUT random record from/to this device
	ROFFST	G_OPN,2		;perform special OPEN functions for this device
	ROFFST	G_SIN,2		;input 1 byte from file opened on this device
	ROFFST	G_SOT,2		;output 1 byte to file opened on this device
	ROFFST	G_GPS,2		;POS
	ROFFST	G_GWD,2		;get device width
	ROFFST	G_SCW,2		;set device column width
	ROFFST	G_GCW,2		;get device column width
	ROFFST	G_BIN,2		;block input from file opened on this device
	ROFFST	G_BOT,2		;block output to file opened on this device


        PAGE
