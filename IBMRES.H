; Include file for IBMRES.ASM
;
INCLUDE OEM.H                        ; General definitions

;
; Reserve word table generating Macros
;
un_def  MACRO   RESWRD
        %OUT +++ Undefined reserved word - &RESWRD
ENDM

T       MACRO   RESWRD
        QQ=QQ+1
        PUBLIC  $&RESWRD
        $&RESWRD=QQ
ENDM

Q       MACRO   RESWRD
 IFDEF  $&RESWRD
        $F=0
  IRPC  XX,<RESWRD>
   IF   $F
        $Q="&XX&"
        DB      "&XX&"
   ENDIF        
   IFE  $F-1
        .XLIST
   ENDIF
        $F=$F+1
  ENDM
        .LIST
        ORG     $-1
        DB      $Q+128D
        DB      $&RESWRD
 ELSE
        un_def  RESWRD
 ENDIF
ENDM

QF      MACRO   RESWRD
 IFDEF  $&RESWRD
        $F=0
  IRPC  XX,<RESWRD>
   IF   $F
        $Q="&XX&"
        DB      "&XX&"
   ENDIF        
   IFE  $F-1
        .XLIST
   ENDIF
        $F=$F+1
  ENDM
        .LIST
        ORG     $-1
        DB      $Q+128D
        DB      $&RESWRD-128D
 ELSE
        un_def  RESWRD
 ENDIF
ENDM

;
R       MACRO   RESWRD
        extrn   RESWRD:NEAR
        DW      RESWRD
        QQ=QQ+1
        PUBLIC  $&RESWRD
        $&RESWRD=QQ
ENDM

R2      MACRO   RESWRD,RESDSP
        extrn   RESDSP:NEAR
        DW      RESDSP
        QQ=QQ+1
        PUBLIC  $&RESWRD
        $&RESWRD=QQ
ENDM
;
PAGE
