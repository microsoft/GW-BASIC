; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE FIVEO 5.0 Features -WHILE/WEND, CALL, CHAIN, WRITE /P. Allen

	.SALL
	.RADIX	10

TSHIBA=0
PC8A=0
	LABEL=PC8A
OKI=0
	INCLUDE	GIO86U
	INCLUDE	MSDOSU
IF	CPM86  
	INCLUDE	CPM86U
ENDIF 

	EXTRN	RESTORE:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	ASSUME DS:DSEG
	EXTRN	SUBFLG:WORD,TEMP:WORD
DSEG	ENDS

				; Code Segment ( terminated by END at bottom of file )

	EXTRN	CHRGTR:NEAR,SYNCHR:NEAR,DCOMPR:NEAR
	EXTRN	GETYPR:NEAR
	EXTRN	SNERR:NEAR,GETSTK:NEAR,PTRGET:NEAR,CRDO:NEAR
	EXTRN	VMOVFM:NEAR
	EXTRN	FRQINT:NEAR

	SUBTTL  WHILE , WEND
	PUBLIC	WHILE,WEND
	EXTRN	ERROR:NEAR,FRMCHK:NEAR,$FOR:NEAR,$WHILE:NEAR,WNDSCN:NEAR
	EXTRN	FRMEVL:NEAR
	EXTRN	NEWSTT:NEAR,FORSZC:NEAR,ERRWE:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	SAVSTK:WORD,NXTLIN:WORD,CURLIN:WORD,ENDFOR:WORD
DSEG	ENDS
;
; THIS CODE HANDLES THE STATEMENTS WHILE/WEND
; THE 8080 STACK IS USED TO PUT AN ENTRY ON FOR EACH ACTIVE WHILE
; THE SAME WAY ACTIVE GOSUB AND FOR ENTRIES ARE MADE.
; THE FORMAT IS AS FOLLOWS:
;       $WHILE - THE TOKEN IDENTIFYING THE ENTRY (1 BYTE)
;       A TEXT POINTER AT THE CHARACTER AFTER THE WEND OF THE WHILE BODY (2 BYTES)
;       A TEXT POINTER AT THE CHARACTER AFTER THE WHILE OF THE WHILE BODY (2 BYTES)
;       THE LINE NUMBER OF THE LINE THAT THE WHILE IS ON (2 BYTES)
;
;       TOTAL   7 BYTES
;
WHILE:				;KEEP THE WHILE TEXT POINTER HERE
	MOV	ENDFOR,BX	;SAVE TEXT ADDRESS
	CALL	WNDSCN		;SCAN FOR THE MATCHING WEND
				;CAUSE AN ERRWH IF NO WEND TO MATCH
	CALL	CHRGTR		;POINT AT CHARACTWER AFTER WEND
	XCHG	BX,DX		;POSITION OF MATCHING WEND
	CALL	FNDWND		;SEE IF THERE IS A STACK ENTRY FOR THIS WHILE
	LAHF
	INC	SP		;GET RID OF THE NEWSTT ADDRESS ON THE STACK
	SAHF
	LAHF
	INC	SP
	SAHF
	JNZ	SHORT WNOTOL	;IF NO MATCH NO NEED TO TRUNCATE THE STACK
	ADD	BX,CX		;ELIMINATE EVERYTHING UP TO AND INCLUDING
				;THE MATCHING WHILE ENTRY
	MOV	SP,BX
	MOV	SAVSTK,BX
WNOTOL:	MOV	BX,CURLIN	;MAKE THE STACK ENTRY
	PUSH	BX
	MOV	BX,ENDFOR	;GET TEXT POINTER FOR WHILE BACK
	PUSH	BX
	PUSH	DX		;SAVE THE WEND TEXT POINTER
	JMP	SHORT FNWEND	;FINISH USING WEND CODE

WEND:	JZ	SHORT ??L000
	JMP	SNERR		;STATEMENT HAS NO ARGUMENTS
??L000:
	XCHG	BX,DX		;FIND MATCHING WHILE ENTRY ON STACK
	CALL	FNDWND
	JNZ	SHORT WEERR	;MUST MATCH OR ELSE ERROR
	MOV	SP,BX		;TRUNCATE STACK AT MATCH POINT
	MOV	SAVSTK,BX	;[H,L] POINTING INTO STACK ENTRY
	MOV	DX,CURLIN	;REMEMBER WEND LINE #
	MOV	NXTLIN,DX	;IN NXTLIN
	INC	BX		;INDEX INTO STACK ENTRY TO GET VALUES
	INC	BX		;SKIP OVER TEXT POINTER OF WEND
	MOV	DX,[BX]		;SET [D,E]=TEXT POINTER OF WHILE
	INC	BX
	INC	BX
	MOV	BX,[BX]		;[H,L]=LINE NUMBER OF WHILE
	MOV	CURLIN,BX	;IN CASE OF ERROR OR CONTINUATION FIX CURLIN
	XCHG	BX,DX		;GET TEXT POINTER OF WHILE FORMULA INTO [H,L]
FNWEND:	CALL	FRMEVL		;EVALUATE FORMULA
	EXTRN	VSIGN:NEAR
	PUSH	BX		;SAVE TEXT POINTER
	CALL	VSIGN		;GET IF TRUE OR FALSE
	POP	BX		;GET BACK WHILE TEXT POINTER
	JZ	SHORT FLSWHL	;GO BACK AT WEND IF FALSE
	MOV	CX,OFFSET $WHILE	;COMPLETE WHILE ENTRY
	MOV	CH,CL		;NEED IT IN THE HIGH BYTE
	PUSH	CX
	JMP	NEWSTT

FLSWHL:	MOV	BX,NXTLIN	;SETUP CURLIN FOR WEND
	MOV	CURLIN,BX
	POP	BX		;TAKE OFF TEXT OF WEND AS NEW TEXT POINTER
	POP	CX		;GET RID OF TEXT POINTER OF WHILE
	POP	CX		;TAKE OFF LINE NUMBER OF WHILE
	JMP	NEWSTT
;
; THIS SUBROUTINE SEARCHES THE STACK FOR AN WHILE ENTRY
; WHOSE WEND TEXT POINTER MATCHES [D,E]. IT RETURNS WITH ZERO TRUE
; IF A MATCH IS FOUND AND ZERO FALSE OTHERWISE. FOR ENTRIES
; ARE SKIPPED OVER, BUT GOSUB ENTRIES ARE NOT.
;
	WHLSIZ=7


;
; Note - 8086 versions force stack entries to be an even length
; so stack accesses won't cross word boundaries.  This is done
; for speed.  To accomplish this, an extra byte is pushed on
; top of the WHILE token.  This extra byte is NOT reflected in
; the value of WHLSIZ but is taken care of by the code.
;

FNDWND:	MOV	BX,4		;SKIP OVER RETURN ADDRESS AND NEWSTT
	ADD	BX,SP
FNDWN2:
	INC	BX
	MOV	AL,BYTE PTR [BX]	;GET THE ENTRY TYPE
	INC	BX
	MOV	CX,OFFSET $FOR
	CMP	AL,CL		;SEE IF ITS $FOR
	JNZ	SHORT FNDWN3
	MOV	CX,OFFSET FORSZC-1	;Yes, so skip over it.  Note that
	ADD	BX,CX		;the pointer has already been
	JMP	SHORT FNDWN2	;incremented once.

FNDWN3:	MOV	CX,OFFSET $WHILE
	CMP	AL,CL
	JZ	SHORT $+3
	RET
	INS86	71,27		;CMP [BX],DX-SAME WEND?
	MOV	CX,OFFSET WHLSIZ-1	;Note that the pointer has
				;already been incremented once.
	JNZ	SHORT $+3
	RET			;RETURN IF ENTRY MATCHES
	ADD	BX,CX
	JMP	SHORT FNDWN2

WEERR:	MOV	DX,OFFSET ERRWE
	JMP	ERROR


	SUBTTL  CHAIN
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	TXTTAB:WORD,VALTYP:WORD
DSEG	ENDS
	EXTRN	$COMMON:NEAR,$MERGE:NEAR,FRMEVL:NEAR,OMERR:NEAR,SCRTCH:NEAR
	EXTRN	LINGET:NEAR
	EXTRN	$DELETE:NEAR
	PUBLIC	CHAIN,COMMON
	EXTRN	PTRGTN:NEAR,PTRGTR:NEAR
	EXTRN	MOVE1:NEAR,NEWSTT:NEAR,PTRGET:NEAR,STRCPY:NEAR
	EXTRN	GARBA2:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FRETOP:WORD
DSEG	ENDS
;
;
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	SAVFRE:WORD
DSEG	ENDS
	EXTRN	IADAHL:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'		
	EXTRN	TEMP3:WORD,TEMP9:WORD,VARTAB:WORD,ARYTAB:WORD,CHNFLG:WORD
	EXTRN	STREND:WORD
	EXTRN	CURLIN:WORD,SAVSTK:WORD,ENDBUF:WORD,MRGFLG:WORD,MDLFLG:WORD
	EXTRN	CHNLIN:WORD,CMEPTR:WORD,CMSPTR:WORD
DSEG	ENDS
	EXTRN	BLTUC:NEAR,DATA:NEAR
	EXTRN	FNDLIN:NEAR,USERR:NEAR,ERSFIN:NEAR,FCERR:NEAR,NOARYS:NEAR
	EXTRN	DEL:NEAR,LINKER:NEAR,SCNLIN:NEAR,FRQINT:NEAR
; This is the code for the CHAIN statement
; The syntax is:
; CHAIN [MERGE]<file name>[,[<line number>][,ALL][,DELETE <range>]]
; The steps required to execute a CHAIN are:
;
; 1.) Scan arguments
;
; 2.) Scan program for all COMMON statements and
;       mark specified variables.
;
; 3.) Squeeze unmarked entries from symbol table.
;
; 4.) Copy string literals to string space
;
; 5.) Move all simple variables and arrays into the
;       bottom of string space.
;
; 6.) Load new program
;
; 7.) Move variables back down positioned after program.
;
; 8.) Run program
CHAIN:
	XOR	AL,AL		;Assume no MERGE
	MOV	BYTE PTR MRGFLG,AL
	MOV	BYTE PTR MDLFLG,AL	;Also no MERGE w/ DELETE option
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	OPTFLG:WORD,TOPTFG:WORD,OPTVAL:WORD,TOPTVL:WORD
DSEG	ENDS
	MOV	AL,BYTE PTR OPTFLG
	MOV	BYTE PTR TOPTFG,AL	;SAVE OPTION BASE VALUE
	MOV	AL,BYTE PTR OPTVAL	;SAVE OPTION VALUE FOR ARRAY BASE
	MOV	BYTE PTR TOPTVL,AL
	MOV	AL,BYTE PTR [BX]	;Get current char
	MOV	DX,OFFSET $MERGE	;Is it MERGE?
	CMP	AL,DL		;Test
	JNZ	SHORT NTCHNM	;NO
	MOV	BYTE PTR MRGFLG,AL	;Set MERGE flag
	INC	BX
NTCHNM:	DEC	BX		;Rescan file name
	CALL	CHRGTR
	EXTRN	PRGFLI:NEAR
	CALL	PRGFLI		;Evaluate file name and OPEN it
	PUSH	BX		;Save text pointer
	MOV	BX,0		;Get zero
	MOV	CHNLIN,BX	;Assume no CHAIN line #
	POP	BX		;Restore text pointer
	DEC	BX		;Back up pointer
	CALL	CHRGTR		;Scan char
	JNZ	SHORT ??L001
	JMP	NTCHAL		;No line number etc.
??L001:
	CALL	SYNCHR
	DB	OFFSET 54O	;Must be comma
	CMP	AL,LOW 54O	;Ommit line # (Use ALL for instance)
	JZ	SHORT NTLINF	;YES
	CALL	FRMEVL		;Evaluate line # formula
	PUSH	BX		;Save text poiner
	CALL	FRQINT		;Force to int in [H,L]
	MOV	CHNLIN,BX	;Save it for later
	POP	BX		;Restore text poiner
	DEC	BX		;Rescan last char
	CALL	CHRGTR
	JZ	SHORT NTCHAL	;No ALL i.e. preserve all vars across CHAIN
NTLINF:	CALL	SYNCHR
	DB	OFFSET 54O	;Should be comma here
	MOV	DX,OFFSET $DELETE	;Test for DELETE option
	CMP	AL,DL		;Is it?
	JZ	SHORT CHMWDL	;Yes
	CALL	SYNCHR
	DB	OFFSET "A"	;Check for "ALL"
	CALL	SYNCHR
	DB	OFFSET "L"
	CALL	SYNCHR
	DB	OFFSET "L"
	JNZ	SHORT ??L002
	JMP	DNCMDA		;Goto step 3
??L002:
	CALL	SYNCHR
	DB	OFFSET 54O	;Force comma to appear
	CMP	AL,DL		;Must be DELETE
	JZ	SHORT ??L003
	JMP	SNERR		;No, give error
??L003:
	OR	AL,AL		;Flag to goto DNCMDA
CHMWDL:	PUSHF			;Save ALL flag
	MOV	BYTE PTR MDLFLG,AL	;Set MERGE w/ DELETE
	CALL	CHRGTR		;Get char after comma
	CALL	SCNLIN		;Scan line range
	EXTRN	DEPTR:NEAR
	PUSH	CX
	CALL	DEPTR		;Change pointers back to numbers
	POP	CX
	POP	DX		;Pop max line off stack
	PUSH	CX		;Save pointer to start of 1st line
	MOV	BX,CX		;Save pointer to start line
	MOV	CMSPTR,BX
	CALL	FNDLIN		;Find the last line
	JAE	SHORT FCERRG	;Must have exact match on end of range
	MOV	DH,BH		;[D,E] =  pointer at the start of the line
	MOV	DL,BL		;beyond the last line in the range
	MOV	CMEPTR,BX	;Save pointer to end line
	POP	BX		;Get back pointer to start of range
	CMP	BX,DX		;Make sure the start comes before the end
FCERRG:	JNAE	SHORT ??L004
	JMP	FCERR		;If not, "Illegal function call"
??L004:
	POPF			;Flag that says whether to go to DNCMDA
	JZ	SHORT ??L005
	JMP	DNCMDA		;"ALL" option was present
??L005:
NTCHAL:	MOV	BX,CURLIN	;Save current line number on stack
	PUSH	BX
	MOV	BX,TXTTAB	;Start searching for COMMONs at program start
	DEC	BX		;Compensate for next instr
CLPSC1:	INC	BX		;Look at first char of next line
CLPSCN:	MOV	AL,BYTE PTR [BX]	;Get char from program
	INC	BX
	OR	AL,BYTE PTR [BX]	;Are we pointing to program end?
	JNZ	SHORT ??L006
	JMP	CLPFIN		;Yes
??L006:
	INC	BX
	MOV	DX,[BX]		;Get line # in [D,E]
	INC	BX
	MOV	CURLIN,DX	;Save current line # in CURLIN for errors
CSTSCN:	CALL	CHRGTR		;Get statment type
AFTCOM:	OR	AL,AL
	JZ	SHORT CLPSC1	;EOL Scan next one
	CMP	AL,LOW ":"	;Are we looking at colon
	JZ	SHORT CSTSCN	;Yes, get next statement
	CMP	AL,LOW 254D	;COMMONs prceeded by 254
	JNZ	SHORT NOCOMM	;not one
	INC	BX		;move ahead
	MOV	AL,BYTE PTR [BX]
	MOV	DX,OFFSET $COMMON	;Test for COMMON, avoid byte externals
	CMP	AL,DL		;Is it a COMMON?
	JZ	SHORT DOCOMM	;Yes, handle it
	DEC	BX		;Back up the pointer.
NOCOMM:	CALL	CHRGTR		;Get first char of statement
	CALL	DATA		;Skip over statement
	DEC	BX		;Back up to rescan terminator
	JMP	SHORT CSTSCN	;Scan next one
DOCOMM:	CALL	CHRGTR		;Get thing after COMMON
	JZ	SHORT AFTCOM	;Get next thing
NXTCOM:	PUSH	BX		;Save text pointer
	MOV	AL,LOW 1	;Call PTRGET to search for array
	MOV	BYTE PTR SUBFLG,AL
	CALL	PTRGTN		;This subroutine in F3 scans variables
	JZ	SHORT FNDAAY	;Found array
	MOV	AL,CH		;Try finding array with COMMON bit set
	OR	AL,LOW 128D
	MOV	CH,AL
	XOR	AL,AL		;Set zero CC
	CALL	ERSFIN		;Search array table
	MOV	AL,LOW 0	;Clear SUBFLG in all cases
	MOV	BYTE PTR SUBFLG,AL
	JNZ	SHORT NTFN2T	;Not found, try simple
	MOV	AL,BYTE PTR [BX]	;Get terminator, should be "("
	CMP	AL,LOW "("	;Test
	JNZ	SHORT SCNSMP	;Must be simple then
	POPF			;Get rid of saved text pointer
	JMP	SHORT COMADY	;Already was COMMON, ignore it
NTFN2T:	MOV	AL,BYTE PTR [BX]	;Get terminator
	CMP	AL,LOW "("	;Array specifier?
	POP	DX		;(DE:=saved text pointer.)
	JZ	SHORT SKPCOM	;Yes, undefined array - just skip it.
	PUSH	DX		;No, resave pointer to start of variable
SCNSMP:	POP	BX		;Rescan variable name for start
	CALL	PTRGTN		;Evaluate as simple
	OR	DX,DX		;If var not found, [D,E]=0
	JNZ	SHORT COMFNS	;Found it
	MOV	AL,CH		;Try to find in COMMON
	OR	AL,LOW 128D	;Set COMMON bit
	MOV	CH,AL
	MOV	DX,OFFSET COMPT2	;push on return address
	PUSH	DX
	MOV	DX,OFFSET PTRGTR	;address to common return point
	PUSH	DX
	MOV	AL,BYTE PTR VALTYP	;Must have VALTYP in [D]
	MOV	DH,AL
	JMP	NOARYS		;Search symbol table
COMPT2:	OR	DX,DX		;Found?
	JZ	SHORT SKPCOM	;No, just skip over this variable.
COMFNS:	PUSH	BX		;Save text pointer
	MOV	CH,DH		;Get pointer to var in [B,C]
	MOV	CL,DL
	MOV	BX,OFFSET BCKUCM	;Loop back here
	PUSH	BX
CBAKBL:	DEC	CX		;Point at first char of rest
LPBKNC:	MOV	SI,CX
	MOV	AL,[SI]		;Back up until plus byte
	DEC	CX
	OR	AL,AL
	JNS	SHORT ??L007
	JMP	LPBKNC
??L007:
				;Now point to 2nd char of var name
	MOV	SI,CX
	MOV	AL,[SI]		;set COMMON bit
	OR	AL,LOW 128D
	MOV	DI,CX
	STOSB
	RET			;done
FNDAAY:	MOV	BYTE PTR SUBFLG,AL	;Array found, clear SUBFLG
	MOV	AL,BYTE PTR [BX]	;Make sure really array spec
	CMP	AL,LOW "("	;Really an array?
	JNZ	SHORT SCNSMP	;No, scan as simp
	POP	SI		;XTHL
	XCHG	SI,BX
	PUSH	SI		;Save text pointer, get rid of saved text pointer
BAKCOM:	DEC	CX		;Point at last char of name extension
	DEC	CX
	CALL	CBAKBL		;Back up before variable and mark as COMMON
BCKUCM:	POP	BX		;Restore text pointer
SKPCOM:	DEC	BX		;Rescan terminator
	CALL	CHRGTR
	JNZ	SHORT ??L008
	JMP	AFTCOM		;End of COMMON statement
??L008:
	CMP	AL,LOW "("	;End of COMMON array spec?
	JNZ	SHORT CHKCST	;No, should be comma
COMADY:	PUSH	BX
	CALL	CHRGTR		;Fetch char after paren
	CMP	AL,LOW ")"
	JZ	SHORT COMRPN	;Only right paren follows
	POP	BX
	EXTRN	EVAL:NEAR
	CALL	EVAL		;Possible number of dimensions(compiler compatible)
	CALL	GETYPR
	JNZ	SHORT ??L009
	JMP	FCERR		;Dimensions argument cannot be string
??L009:
	JMP	SHORT COMRP1
COMRPN:	POP	DX
COMRP1:	CALL	SYNCHR
	DB	OFFSET ")"	;Right paren should follow
	JNZ	SHORT ??L010
	JMP	AFTCOM		;End of COMMON
??L010:
CHKCST:	CALL	SYNCHR
	DB	OFFSET 54O	;Force comma to appear here
	JMP	NXTCOM		;Get next COMMON variable
; Step 3 - Squeeze..
CLPFIN:	POP	BX		;Restore previous CURLIN
	MOV	CURLIN,BX
	MOV	DX,ARYTAB	;End of simple var squeeze to [D,E]
	MOV	BX,VARTAB	;Start of simps
CLPSLP:	CMP	BX,DX		;Are we done?
	JZ	SHORT DNCMDS	;Yes done, with simps
	PUSH	BX		;Save where this simp is
	MOV	CL,BYTE PTR [BX]	;Get VALTYP
	INC	BX
	INC	BX
	MOV	AL,BYTE PTR [BX]	;Get COMMON bit
	OR	AL,AL		;Set minus if COMMON
	PUSHF			;Save indicator
	AND	AL,LOW 177O	;Clear COMMON bit
	MOV	BYTE PTR [BX],AL	;Save back
	INC	BX
	CALL	IADAHL		;Skip over rest of var name
	MOV	CH,LOW 0	;Skip VALTYP bytes
	ADD	BX,CX
	POPF			;Get indicator whether to delete
	POP	CX		;Pointer to where var started
	JNS	SHORT ??L011
	JMP	CLPSLP
??L011:
	PUSH	CX		;This is where we will resume scanning vars later
	CALL	VARDLS		;Delete variable
	MOV	BX,ARYTAB	;Now correct ARYTAB by # of bytes deleted
	ADD	BX,DX		;Add negative difference between old and new
	MOV	ARYTAB,BX	;Save new ARYTAB
	XCHG	BX,DX		;To [D,E]
	POP	BX		;Get current place back in [H,L]
	JMP	SHORT CLPSLP
VARDLS:	XCHG	BX,DX		;Point to where var ends
VARDL1:	MOV	BX,STREND	;One beyond last byte to move
DLSVLP:	CMP	BX,DX		;Done?
	MOV	SI,DX
	MOV	AL,[SI]		;Grab byte
	MOV	DI,CX
	STOSB			;Move down
	LAHF
	INC	DX		;Increment pointers
	SAHF
	LAHF
	INC	CX
	SAHF
	JNZ	SHORT DLSVLP
	MOV	AL,CL		;Get difference between old and new
	SUB	AL,BL		;Into [D,E] ([D,E]=[B,C]-[H,L])
	MOV	DL,AL
	MOV	AL,CH
	SBB	AL,BH
	MOV	DH,AL
	DEC	DX		;Correct # of bytes
	DEC	CX		;Moved one too far
	MOV	BX,CX		;Get new STREND [H,L]
	MOV	STREND,BX	;Store it
	RET	
DNCMDS:	MOV	DX,STREND	;Limit of array search
CLPAKP:	CMP	BX,DX		;Done?
	JZ	SHORT DNCMDA	;Yes
	PUSH	BX		;Save pointer to VALTYP
	INC	BX		;Move down to COMMON bit
	INC	BX
	MOV	AL,BYTE PTR [BX]	;Get it
	OR	AL,AL		;Set CC's
	PUSHF			;Save COMMON indicator
	AND	AL,LOW 177O	;Clear COMMON bit
	MOV	BYTE PTR [BX],AL	;Save back
	INC	BX		;Point to length of array
	CALL	IADAHL		;Add length of var name
	MOV	CL,BYTE PTR [BX]	;Get length of array in [B,C]
	INC	BX
	MOV	CH,BYTE PTR [BX]
	INC	BX
	ADD	BX,CX		;[H,L] now points after array
	POPF			;Get back COMMON indicator
	POP	CX		;Get pointer to start of array
	JNS	SHORT ??L012
	JMP	CLPAKP		;COMMON, dont delete!
??L012:
	PUSH	CX		;Save so we can resume
	CALL	VARDLS		;Delete the array
	XCHG	BX,DX		;Returns with STREND in HL, so put in DE
	POP	BX		;Get back pointer to the next array
	JMP	SHORT CLPAKP	;Check next array
; Step 4 - Copy literals into string space
; This code is very similar to the string garbage collect code
; If BIGSTR is on, we also have to fix up the string back pointers.
DNCMDA:
	MOV	BX,VARTAB	;Look at simple strings
CSVAR:	MOV	DX,ARYTAB	;Limit of search to [D,E]
	CMP	BX,DX		;Done?
	JZ	SHORT CAYVAR	;Yes
	CALL	SKPNAM		;Skip name, returns Z if was a string
	JNZ	SHORT CSKPVA	;Skip this var, not string
	CALL	CDVARS		;Copy this guy into string space if nesc
	XOR	AL,AL		;CDVARS has already incremented [H,L]
CSKPVA:
	MOV	DL,AL
	MOV	DH,LOW 0	;Add length of VALTYP
	ADD	BX,DX
	JMP	SHORT CSVAR
CAYVA2:	POP	CX		;Adjust stack
CAYVAR:	MOV	DX,STREND	;New limit of search
	CMP	BX,DX		;Done?
	JZ	SHORT DNCCLS	;Yes
	CALL	SKPNAM		;Skip over name
	PUSH	AX		;Save VALTYP
	MOV	CL,BYTE PTR [BX]	;Get length of array
	INC	BX
	MOV	CH,BYTE PTR [BX]	;Into [B,C]
	INC	BX
	POP	AX		;Get back VALTYP
	PUSH	BX		;Save pointer to array element
	ADD	BX,CX		;Point after array
	CMP	AL,LOW 3	;String array?
	JNZ	SHORT CAYVA2	;No, look at next one
	MOV	TEMP3,BX	;Save pointer to end of array
	POP	BX		;Get back pointer to array start
	MOV	CL,BYTE PTR [BX]	;Pick up number of DIMs
	MOV	CH,LOW 0	;Make double with high zero
	ADD	BX,CX		;Go past DIMS
	ADD	BX,CX
	INC	BX		;One more to account for # of DIMs
CAYSTR:	MOV	DX,TEMP3	;Get end of array
	CMP	BX,DX		;See if at end of array
	JZ	SHORT CAYVAR	;Get next array
	MOV	CX,OFFSET CAYSTR	;Do next str in array
	PUSH	CX		;Save branch address on stack
CDVARS:
	MOV	AL,BYTE PTR [BX]	;Get length of array entry
	INC	BX		;Also pick up pointer into [D,E]
	MOV	DX,[BX]		;Get data pointer
	INC	BX
	INC	BX
	OR	AL,AL		;Set CC's on length
	JNZ	SHORT $+3
	RET			;Ignore null strings
	PUSH	BX		;Save where we are
	MOV	BX,VARTAB	;Is string in program text or disk buffers?
	CMP	BX,DX		;Compare
	POP	BX		;Restore where we are
	JNB	SHORT $+3
	RET			;No, must be in string space
	PUSH	BX		;save where we are again.
	MOV	BX,TXTTAB	;is it in buffers?
	CMP	BX,DX		;test
	POP	BX		;Restore where we are
	JNAE	SHORT $+3
	RET			;in buffers, do nothing
	PUSH	BX		;Save where we are for nth time
	DEC	BX		;Point to start of descriptor
	DEC	BX
	DEC	BX
	PUSH	BX		;Save pointer to start
	CALL	STRCPY		;Copy string into DSCTMP
	POP	BX		;Destination in [H,L], source in [D,E]
	MOV	CH,LOW 3	;# of bytes to move
	CALL	MOVE1		;Move em
	POP	BX		;Where we are
	RET	
; Step 5 - Move stuff up into string space!
DNCCLS:
	CALL	GARBA2		;Get rid of unused strings
	MOV	BX,STREND	;Load end of vars
	MOV	CX,BX		;Into [B,C]
	MOV	DX,VARTAB	;Start of simps into [D,E]
	MOV	BX,ARYTAB
	SUB	BX,DX		;Get length of simps in [H,L]
	MOV	TEMP9,BX	;Save here
	MOV	BX,FRETOP	;Destination of high byte
	MOV	SAVFRE,BX	;Save FRETOP to restore later
	CALL	BLTUC		;Move stuff up
	MOV	BX,CX		;Now adjust top of memory below saved vars
	DEC	BX		;One lower to be sure
	MOV	FRETOP,BX	;Update FRETOP to reflect new value
	MOV	AL,BYTE PTR MDLFLG	;MERGE w/ DELETE?
	OR	AL,AL		;Test
	JZ	SHORT NTMDLT	;No
	MOV	BX,CMSPTR	;Start of lines to delete
	MOV	CX,BX		;Into [B,C]
	MOV	BX,CMEPTR	;End of lines to delete
	CALL	DEL		;Delete the lines
	MOV	ARYTAB,BX	;***also set up ARYTAB and STREND
	MOV	STREND,BX	;in case we get error in CHAIN
				;because of file lookup and then have to
				;look at variables later (shouldnt be any)
				;***PGA 7/7/81
	CALL	LINKER		;Re-link lines just in case
; Step 6 - load new program
NTMDLT:	MOV	AL,LOW 1	;Set CHAIN flag
	MOV	BYTE PTR CHNFLG,AL
	EXTRN	CHNENT:NEAR,OKGETM:NEAR
	MOV	AL,BYTE PTR MRGFLG	;MERGEing?
	OR	AL,AL		;Set cc'S
	JZ	SHORT ??L013
	JMP	OKGETM		;Do MERGE
??L013:
	JMP	CHNENT		;Jump to LOAD code
; Step 7 - Move stuff back down
	PUBLIC	CHNRET
CHNRET:
	MOV	AL,BYTE PTR TOPTVL
	MOV	BYTE PTR OPTVAL,AL	;RESTORE IOTION BASE VALUE
	MOV	AL,BYTE PTR TOPTFG
	MOV	BYTE PTR OPTFLG,AL	;LRESTORE OPTION FLG
	XOR	AL,AL		;Clear CHAIN, MERGE flags
	MOV	BYTE PTR CHNFLG,AL
	MOV	BYTE PTR MRGFLG,AL
	MOV	BX,VARTAB	;Get current VARTAB
	MOV	CX,BX		;Into [B,C]
	MOV	BX,TEMP9	;Get length of simps
	ADD	BX,CX		;Add to present VARTAB to get new ARYTAB
	MOV	ARYTAB,BX
	MOV	BX,FRETOP	;Where to start moving
	INC	BX		;One higher
	XCHG	BX,DX		;Into [D,E]
	MOV	BX,SAVFRE	;Last byte to move
	MOV	FRETOP,BX	;Restore FRETOP from this
MVBKVR:	CMP	BX,DX		;Done?
	MOV	SI,DX
	MOV	AL,[SI]		;Move byte down
	MOV	DI,CX
	STOSB
	LAHF
	INC	DX		;Increment pointers
	SAHF
	LAHF
	INC	CX
	SAHF
	JNZ	SHORT MVBKVR
	DEC	CX		;Point to last var byte
	MOV	BX,CX		;[H,L]=last var byte
	MOV	STREND,BX	;This is new end
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	NLONLY:WORD
DSEG	ENDS
	XOR	AL,AL		;
	MOV	BYTE PTR NLONLY,AL	;allow all files to be closed
EXTRN	FINPRT:NEAR
	CALL	FINPRT		;close file zero and reset PTRFIL to 0
	XOR	AL,AL
	CALL	RESTORE		;Make sure DATA is valid by doing RESTORE
	MOV	DX,CHNLIN	;Get CHAIN line # in [D,E]
	MOV	BX,TXTTAB	;Get prog start in [H,L]
	DEC	BX		;Point at zero before program

	OR	DX,DX		;line number zero?
	JNZ	SHORT ??L014
	JMP	NEWSTT		;line #=0, go...
??L014:
	CALL	FNDLIN		;Try to find destination line
	JNAE	SHORT ??L015
	JMP	USERR		;Not there...
??L015:
	DEC	CX		;Point to zero on previous line
	MOV	BX,CX		;Make text pointer for NEWSTT
	JMP	NEWSTT		;Bye...
;
; Convenience routine to skip a variable's name pointed to by HL.
; Returns VALTYP in A with the zero flag set if it is a string.
;
	PUBLIC	SKPNAM
SKPNAM:
	MOV	AL,BYTE PTR [BX]	;Get VALTYP
	INC	BX		;Point to length of long var name
	INC	BX
	INC	BX
	PUSH	AX		;Save VALTYP
	CALL	IADAHL		;Move past long variable name
	POP	AX		;Get back VALTYP
	CMP	AL,LOW 3	;String?
	RET	
;
;
COMMON:
	JMP	DATA

	SUBTTL  WRITE
	EXTRN	FINPRT:NEAR
	EXTRN	FOUT:NEAR,STRLIT:NEAR,STRPRT:NEAR,OUTDO:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	FACLO:WORD
DSEG	ENDS
	PUBLIC	WRITE
WRITE:
	EXTRN	FILGET:NEAR
	MOV	CL,LOW OFFSET MD_SQO	;Setup output file
	CALL	FILGET
WRTCHR:	DEC	BX
	CALL	CHRGTR		;Get another character
	JZ	SHORT WRTFIN	;Done with WRITE
WRTMLP:	CALL	FRMEVL		;Evaluate formula
	PUSH	BX		;Save the text pointer
	CALL	GETYPR		;See if we have a string
	JZ	SHORT WRTSTR	;We do
	CALL	FOUT		;Convert to a string
	CALL	STRLIT		;Literalize string
	MOV	BX,FACLO	;Get pointer to string
	INC	BX		;Point to address field
	MOV	DX,[BX]
	INC	BX
	MOV	SI,DX
	MOV	AL,[SI]		;Is number positive?
	CMP	AL,LOW " "	;Test
	JNZ	SHORT WRTNEG	;No, must be negative
	INC	DX
	MOV	BYTE PTR [BX],DH
	DEC	BX
	MOV	BYTE PTR [BX],DL
	DEC	BX
	DEC	BYTE PTR [BX]	;Adjust length of string (length.LT.255 so OK)
WRTNEG:	CALL	STRPRT		;Print the number
NXTWRV:	POP	BX		;Get back text pointer
	DEC	BX		;Back up pointer
	CALL	CHRGTR		;Get next char
	JZ	SHORT WRTFIN	;end
	CMP	AL,LOW 59	;Semicolon?
	JZ	SHORT WASEMI	;Was one
	CALL	SYNCHR
	DB	OFFSET 54O	;Only possib left is comma
	DEC	BX		;to compensate for later CHRGET
WASEMI:	CALL	CHRGTR		;Fetch next char
	MOV	AL,LOW 54O	;put out comma
	CALL	OUTDO
	JMP	SHORT WRTMLP	;Back for more
WRTSTR:	MOV	AL,LOW 34	;put out double quote
	CALL	OUTDO		;Send it
	CALL	STRPRT		;print the string
	MOV	AL,LOW 34	;Put out another double quote
	CALL	OUTDO		;Send it
	JMP	SHORT NXTWRV	;Get next value
WRTFIN:
	EXTRN	CMPFBC:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	PTRFIL:WORD
DSEG	ENDS
	PUSH	BX		;Save text pointer
	MOV	BX,PTRFIL	;See if disk file
	MOV	AL,BH
	OR	AL,BL
	JZ	SHORT NTRNDW	;No
	PUSH	BX		;Save FDB pointer
	MOV	CX,OFFSET F_DEV
	ADD	BX,CX		;HL points to Device Entry in FDB
	MOV	AL,BYTE PTR [BX]	;[A]=device id
	OR	AL,AL		;if disk [A] will be 0..n
	POP	BX
	JNS	SHORT ??L016
	JMP	NTRNDW		;branch if special device ([A] is negative)
??L016:
	PUSH	BX
	MOV	CX,OFFSET F_MODE
	ADD	BX,CX		;HL points to File Mode Byte in FDB
	MOV	AL,BYTE PTR [BX]	;[A]=file mode
	POP	BX		;Restore FDB pointer
	CMP	AL,LOW OFFSET MD_RND	;Random?
	JNZ	SHORT NTRNDW	;NO
	CALL	CMPFBC		;See how many bytes left
	MOV	AL,BL		;do subtract
	SUB	AL,DL
	MOV	BL,AL
	MOV	AL,BH
	SBB	AL,DH
	MOV	BH,AL
	CRLFSQ=2		;Number of bytes in CR/LF sequence
	MOV	DX,OFFSET 0-CRLFSQ	;Subtract bytes in <cr>
	LAHF
	ADD	BX,DX
	RCR	SI,1
	SAHF
	RCL	SI,1
	JAE	SHORT NTRNDW	;Not enough, give error eventually
NXTWSP:	MOV	AL,LOW " "	;Put out spaces
	CALL	OUTDO		;Send space
	DEC	BX		;Count down
	MOV	AL,BH		;Count down
	OR	AL,BL
	JNZ	SHORT NXTWSP
NTRNDW:	POP	BX		;Restore [H,L]
	CALL	CRDO		;Do crlf
	JMP	FINPRT
CSEG	ENDS
	END
                   