bits 16

section _TEXT class=CODE

global _x86_Divide64By32

_x86_Divide64By32:
    push bp             ; Save old bp and move sp to bp
    mov bp, sp          ; New call frame

    push bx             ; Save callee saved bx register

    ; [bp - 2] - Callee saved value of BX
    ; [bp + 0] - Old value of BP
    ; [bp + 2] - Return address (RIP)
    ; [bp + 4] - First argument the dividend
    ; [bp + 12] - Second argument the divisor
    ; [bp + 16] - Third argument the quotient pointer (Pointers are still only 16 bits)
    ; [bp + 18] - Fourth argument the remainder pointer

    mov eax, [bp + 8]   ; Upper 32 bits of Dividend
    mov ecx, [bp + 12]  ; Divisor
    xor edx, edx        ; Reset the edx register to 0 it out
    div ecx             ; Quotient in EAX, Remainder in EDX
    mov bx, [bp + 16]
    mov [bx + 4], eax   ; Store upper part of quotient
    mov eax, [bp + 4]   ; Lower 32 bits of Dividend
    div ecx             ; Quotient in EAX, Remainder in EDX
    mov [bx], eax       ; Store lower part of quotient
    mov bx, [bp + 18]
    mov [bx], edx   ; Store remainder



    pop bx              ; Restore callee saved register
    mov sp, bp          ; Restore old sp
    pop bp              ; Restore old bp
    ret
