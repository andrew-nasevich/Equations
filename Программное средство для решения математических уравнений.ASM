        format PE GUI 4.0      ; todo добавить обработку y
include 'win32a.inc'

entry Main

section '.data' data writeable readable

include 'Equations.txt'

include 'Variables.txt'

section '.code' code writeable readable
Main:

        invoke GetModuleHandle, 0
        mov [wc.hInstance], eax
        invoke LoadCursor, 0, IDC_ARROW
        mov [wc.hCursor], eax
        invoke LoadIcon, 0, IDI_APPLICATION
        mov [wc.hIcon], eax

        invoke RegisterClass, wc
        cmp eax, 0
        je .error

        invoke CreateWindowEx, 0, classWnd, nameWnd, WS_VISIBLE + WS_OVERLAPPEDWINDOW, 100, 100, 800, 500, 0, 0, [wc.hInstance], 0
        cmp eax, 0
        je .error

        mov [hwnd], eax
        mov [msg.hwnd], eax

.loopMsg:
        invoke GetMessage, msg, 0, 0, 0
        cmp eax, 0
        je .finishProcess
        invoke TranslateMessage, msg
        invoke DispatchMessage, msg
        jmp .loopMsg

.error:
        invoke MessageBox, 0, 0, errorCaption, MB_ICONERROR + MB_OK
.finishProcess:
        invoke ExitProcess, 0

include 'WndProc.txt'

proc CountX uses edi esi ebx, a, b, c

locals
        locBuff rb 101
        reserved dd -1
        float_num dd 0
endl

        cmp [a], 0
        jz .oneX
        fild [b]
        fimul [b]
        fild [a]
        fimul [c]
        mov [reserved], 4
        fimul [reserved]
        fsubp st1, st0
        fldz
        fcomp st1
        fstsw ax; регистр rs в Ax
        sahf ; ah в флаги
        jbe @f
        fstp st0
        invoke MessageBox, [hwnd], ErrorD, 0, MB_OK
        jmp .finish
@@:
        fsqrt
        fild [b]
        fchs
        fadd st0, st1 ;[-b+d]; [d]

        fild [a]
        mov [reserved], 2

        fimul [reserved]

        fdivp st1, st0
        ftst
        fstsw ax; регистр rs в Ax
        sahf
        jne @f
        fabs
@@:
        fstp [tFloat]
        stdcall FloatToString,tFloat, szFloat
        invoke SendMessage, [hedit2], WM_SETTEXT, 100, szFloat

        fild [b]
        fchs
        fsub st0, st1

        fild [a]
        fimul [reserved]
        fdivp st1, st0

        ftst
        fstsw ax; регистр rs в Ax
        sahf
        jne @f
        fabs
@@:
        fstp [tFloat]
        stdcall FloatToString,tFloat, szFloat
        invoke SendMessage, [hedit3], WM_SETTEXT, 100, szFloat

        fstp st0
        jmp .finish
.oneX:
        fild [c]
        fchs
        fidiv [b]
        ftst
        fstsw ax; регистр rs в Ax
        sahf
        jne @f
        fabs
@@:
        fstp [tFloat]
        stdcall FloatToString,tFloat, szFloat
        invoke SendMessage, [hedit2], WM_SETTEXT, 100, szFloat
        invoke SendMessage, [hedit3], WM_SETTEXT, 100, 0

.finish:
        ret
endp

include 'CheckingEquationStr.txt'

; процедура удаления пробелов
proc DelSpaces uses edi esi ebx, strSrc
        xor edi, edi
        xor esi, esi
        mov ebx, [strSrc]
.Cycle:
        cmp byte[ebx + edi], 0
        je .end
        cmp byte [ebx + edi], ' '
        jne @f
        inc edi
        jmp .Cycle
@@:
        mov al, [ebx + edi]
        mov [ebx + esi], al
        inc esi
        inc edi
        jmp .Cycle
.end:
        mov byte[ebx + esi], 0
        ret
endp

proc InitializeScreen, hwnd
        invoke CreatePen, PS_SOLID, 1, $909090
        mov [hLinePen], eax
        invoke SelectObject, [hdc], [hLinePen]
        mov [hOldPen], eax

        mov edi, MINCOORDY
        mov esi, MINCOORDX + 10
.Cycle1:
        invoke MoveToEx, [hdc], esi, MINCOORDY, 0
        invoke LineTo, [hdc], esi, MAXCOORDY

        add esi, 20
        dec edi
        jne .Cycle1

        mov edi, 21
        mov esi, MINCOORDY + 15
.Cycle2:
        invoke MoveToEx, [hdc], MINCOORDX, esi, 0
        invoke LineTo, [hdc], MAXCOORDX, esi

        add esi, 20
        dec edi
        jne .Cycle2

        invoke DeleteObject,[hLinePen]

        invoke CreatePen, PS_SOLID, 1, $0
        mov [hLinePen], eax
        invoke SelectObject, [hdc], [hLinePen]

        invoke MoveToEx, [hdc], MINCOORDX, CENTRALY, 0
        invoke LineTo, [hdc], MAXCOORDX, CENTRALY
        invoke LineTo, [hdc], MAXCOORDX - 10, CENTRALY - 10
        invoke MoveToEx, [hdc], MAXCOORDX, CENTRALY, 0
        invoke LineTo, [hdc], MAXCOORDX -10, CENTRALY + 10
        invoke MoveToEx, [hdc], CENTRALX, MAXCOORDY, 0
        invoke LineTo, [hdc], CENTRALX, MINCOORDY
        invoke LineTo, [hdc], CENTRALX + 10, MINCOORDY + 10
        invoke MoveToEx, [hdc], CENTRALX, MINCOORDY, 0
        invoke LineTo, [hdc], CENTRALX - 10, MINCOORDY + 10

        invoke DeleteObject,[hLinePen]
        invoke SelectObject, hdc, hOldPen
        ret
endp

proc TransformText uses esi ebx, buffSrc, XpriceSrc

locals
        Result dd 0
endl
        mov ebx, [buffSrc]
        xor esi, esi

.Cycle:
        cmp byte[ebx + esi], 0
        je .end
        cmp byte[ebx + esi], '0'
        jb .error
        cmp byte[ebx + esi], '9'
        ja .error
        xor edx, edx
        mov dl, [ebx + esi]
        sub dl, '0'
        mov eax, [Result]
        imul eax, 10
        add eax, edx
        mov [Result], eax
        inc esi
        jmp .Cycle

.error:
        mov eax, 1
        jmp @F

.end:
        mov edx, [Result]
        mov ebx, [XpriceSrc]
        mov [ebx], edx
        xor eax, eax
        cmp [Result], 0
        jne @f
        inc eax
@@:
        ret
endp

; в стеке fpu должен хранить доп параметр - x/20*i
; возвращается в eax y в точках
proc    CountY uses ebx esi ecx, xSrc, Yprice
locals
        reserved dd ?
endl
        xor ecx, ecx
        mov ebx, [xSrc]
        mov cl, byte[ebx]
        mov esi, ecx
        dec esi
        fldz
        cmp cl, 0
        je .functions
; st1 - x/20*i, st0 - текущий y
.cycle:
        fld1
        xor edx, edx
@@:
        cmp edx, esi
        je @F
        fmul st0, st2
        inc edx
        jmp @b

@@:
        mov eax, dword[ebx + 1 + 4 * esi]
        test eax, eax
        jns @F
        neg eax
        fchs


@@:
        mov [reserved], eax
        fimul [reserved]
        faddp st1, st0
        dec esi
        loop .cycle
        ;fld st1
       ; fimul dword[ebx + 1 + 4 * 1]
       ; faddp st1, st0
       ; cmp dword[ebx + 1 + 4 * 0], 0
       ; jns @F
       ; mov eax, dword[ebx + 1 + 4 * 0]
       ; neg eax
       ; mov [reserved], eax
       ; fisub [reserved]
       ; jmp .negC

       ; fiadd dword[ebx + 1 + 4 * 0]
;.negC:

.functions:
        cmp byte[sctct], 0
        je @F
        fld st1
        fsin
        faddp st1, st0
@@:
        cmp byte[sctct + 1], 0
        je @F
        fld st1
        fcos
        faddp st1, st0
@@:
        cmp byte[sctct + 2], 0
        je @F
        fld st1
        fptan
        fstp st0
        faddp st1, st0
@@:
        cmp byte[sctct + 3], 0
        je @F
        fld st1
        fptan
        fdivrp st1, st0
        faddp st1, st0
@@:

        cmp byte[mod_x], 0
        je .finish

        xor ecx, ecx
        mov ebx, mod_x
        mov cl, byte[mod_x]
        mov esi, ecx
        dec esi

.Cycle.mod_x:
        fld1
        xor edx, edx
@@:
        cmp edx, esi
        je @F
        fmul st0, st2
        inc edx
        jmp @b

@@:
        mov eax, dword[ebx + 1 + 4 * esi]
        fabs

@@:
        mov [reserved], eax
        fimul [reserved]
        faddp st1, st0
        dec esi
        loop .Cycle.mod_x


.finish:
        mov [reserved], 20
        fimul [reserved]
        fidiv [Yprice]
        fistp [reserved]
        fstp st0
        mov eax, [reserved]
        ret
endp

include 'FloatToStr.txt'
section '.idata' import data readable writeable
library kernel32, 'KERNEL32.DLL',\
        user32, 'USER32.DLL',\
        gdi32,    'gdi32.dll'

include 'api\kernel32.inc'
include 'api\gdi32.inc'
include 'api\user32.inc'