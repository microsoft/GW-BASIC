; [ This translation created 12-Jan-83 by Version 4.3 ]

	SUBTTL    MSDOSU - MS-DOS Constants and Data-Structure Definitions

COMMENT	*

--------- --- ---- -- ---------
COPYRIGHT (C) 1982 BY MICROSOFT
--------- --- ---- -- ---------

	Programmer: Tom Corbett,  Microsoft Inc.

	*

CALLOS	MACRO	FUNC
IFNB	<FUNC>  
	MOV	AH,LOW OFFSET FUNC
ENDIF 
	INT	33D		;MSDOS system call
ENDM 

ROFFST	MACRO	NAME,SIZE	;define record macro
	NAME=_OFFST
	_OFFST=_OFFST+SIZE
ENDM 


; MSDOS System Call codes
;
	C_PRTO=5D		;Printer output
	C_DCIO=6D		;Direct console I/O
	C_REST=13D		;INITIALIZE BDOS
	C_SDRV=14D		;SET CURRENTLY SELECTED DRIVE
	C_OPEN=15D
	C_CLOS=16D
	C_SEAR=17D		;SEARCH FOR FILE
	C_DELE=19D
	C_READ=20D
	C_MAKE=22D
	C_RENA=23D
	C_GDRV=25D		;GET CURRENTLY SELECTED DRIVE
	C_BUFF=26D		;SET DMA ADDRESS
	C_RNDR=33D		;Random read
	C_RNDW=34D		;Random write
	C_RBR=39D		;Random Block Read
	C_PARS=41D		;Parse Filename

	FNAML=11D		;number of bytes in Filename with extension
	DATPSC=128D		;bytes per sector
	FCBSIZ=38D		;File Control Block size

;MS-DOS FILE-DATA-BLOCK Record Definition
;
	_OFFST=0		;initialize count
	ROFFST	F_NUL1,1	;not used by basic interpreter
	ROFFST	F_NUM,1		;file number 0..255
	ROFFST	F_NUL2,2	;not used by basic interpreter
	ROFFST	F_NEXT,2	;thread for linked list, [MEMSIZ]=end
	ROFFST	F_MODE,1	;file mode:
	MD_SQI=1D		;sequential input
	MD_SQO=2D		;sequential output
	MD_RND=4D		;random
	MD_APP=8D		;append
	ROFFST	F_FCB,FCBSIZ	;File Control Block: used to communicate with OS
	ROFFST	F_CLOC,2	;for seq files: num sectors read/written   (LOCOFS)
				;for rnd files: last record number + 1
	ROFFST	F_ORCT,1	;"Original Byte Count"                     (ORNOFS)
				;for seq input: #bytes in sector when read
				;for seq output: #bytes in output sector
				;for random files: bytes per sector
	ROFFST	F_BREM,1	;number of bytes till end-of-buffer        (NMLOFS)
	ROFFST	F_CODE,1	;file encoding:
	FC_ASC=0		;Ascii SAVE, Data files
	FC_BIN=1		;binary file (BSAVE, binary SAVE)
	ROFFST	F_BAKC,1	;holds next sequential input when F.FLBS.FL.BKC is true
	ROFFST	F_NUL3,1	;not used by basic interpreter
	ROFFST	F_DEV,1		;Device number                             (FL.DSK)
	ROFFST	F_WID,1		;File width
	ROFFST	F_NUL4,1	;not used by basic interpreter
	ROFFST	F_FLGS,1	;flags
	FL_BKC=200O		;when true, F.BAKC contains next sequential input
	ROFFST	F_POS,1		;Current column position                   (FL.OPS)
	ROFFST	FDBSIZ,0	;size of device independent part of FDB
				;device dependant FDB entries start here

	ROFFST	DATOFS,DATPSC	;Operating System interface buffer
	ROFFST	FD_SIZ,2	;variable record length for random files
	ROFFST	FD_PHY,2	;current physical record number
	ROFFST	FD_LOG,2	;current logical record number
	ROFFST	F_NUL5,1	;Future use
	ROFFST	FD_OPS,2	;current output position for sequential I/O
	ROFFST	FD_DAT,0	;field buffer of random file

; OFFSETS INTO MSDOS FCB
;
	FCB_DV=F_FCB+0D		;DRIVE (0=default, 1=A:, 2=B:, ...)
	FCB_FN=F_FCB+1D		;FILE NAME
	FCB_FT=F_FCB+9D		;EXTENSION
	FCB_EX=F_FCB+12D	;FILE EXTENT (identifies block of 128 logical records)
	FCB_RC=F_FCB+14D	;RECORD SIZE
	FCB_FS=F_FCB+16D	;FILE SIZE IN BYTES
	FCB_DT=F_FCB+20D	;Date of last write to file
	FCB_DT=F_FCB+22D	;Time of last write to file
	FCB_NR=F_FCB+32D	;NEXT RECORD NUMBER
	FCB_RN=F_FCB+33D	;CP/M 2.x Random Record Number

        PAGE
