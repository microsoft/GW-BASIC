;
;               Include file for BINTRP.ASM
;

INCLUDE OEM.H                   ; General definitions

MOVRI   MACRO   B,C,D,E
        DB      271O            ; "LXI  B"
        DB      C
        DB      B
        DB      272O            ; "LXI  D"
        DB      E
        DB      D
ENDM 

;
; Reserve word table generating Macros
;
un_def  MACRO   RESWRD
        %OUT +++ Undefined reserved word - &RESWRD
ENDM

T       MACRO   RESWRD
        QQ=QQ+1
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

DERMAK  MACRO   X
        PUBLIC  DER&X
DER&X:  MOV     DL,OFFSET ERR&X
        DB      271O                    ; LXI B over next error
ENDM
;
; Dispatch table generating Macros.  We have to play games with the
; external declarations as ASM86 won't allow something to be declared
; external during pass 2.  Instead we build a chain of dummy macros
; that could generate the declaration for all potentially external 
; reserve word dispatch addresses.
;

;
; play games with a possible external.  Create a new
; macro for the symbol and text, and string it together
; with a central invoker
;
IF1
    ?i=0
ENDIF

?z0 macro               ; Bottom of the chain
endm

;
; add an external declaration to S with type NEAR if it is not defined
;
add_ext macro   s
    IFNDEF   ?&s
        ?i = ?i + 1
        def_mac     ?z&%?i,?z&%(?i-1),s
    ENDIF
endm

;
; define a macro called that possibly externals S:NEAR and then calls macro n
;
def_mac macro   m,n,s
m   macro
    ifndef s
        extrn s:NEAR
    endif
    purge m
    n
endm
?&s macro
&endm
endm

;
; call the macro chain
;
do_ext  macro
    expand_mac  ?z%?i
endm

expand_mac macro m
    m
endm
;
R       MACRO   RESWRD
 IFNDEF RESWRD
        add_ext RESWRD
 ENDIF
        DW      RESWRD
        QQ=QQ+1
        $&RESWRD=QQ
ENDM

R2      MACRO   RESWRD,RESDSP
 IFNDEF RESDSP
        add_ext RESDSP
 ENDIF
        DW      RESDSP
        QQ=QQ+1
        $&RESWRD=QQ
ENDM
;
PAGE
