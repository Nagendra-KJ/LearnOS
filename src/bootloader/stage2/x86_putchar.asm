bits 16

section _TEXT class=CODE

global _x86_PutCharToScreen

_x86_PutCharToScreen:
    push bp             ; Save old bp and move sp to bp
    mov bp, sp          ; New call frame

    push bx             ; Save callee saved bx register

    ; [bp - 2] - Callee saved value of BX
    ; [bp + 0] - Old value of BP
    ; [bp + 2] - Return address (RIP)
    ; [bp + 4] - First argument the character to be printed as a 16 bit word.
    ; [bp + 6] - Second argument the page

    mov ah, 0xe
    mov al, [bp + 4]
    mov bh, [bp + 6]

    int 0x10

    pop bx              ; Restore callee saved register
    mov sp, bp          ; Restore old sp
    pop bp              ; Restore old bp
    ret
