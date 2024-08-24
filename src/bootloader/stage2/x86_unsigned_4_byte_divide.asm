bits 16

section _TEXT class=CODE

global __U4D

__U4D:
    shl edx, 16     ; Move lower 16 bits of edx to higher 16 bits
    mov dx, ax      ; Move 16 bits in ax into lower 16 bits of edx
    mov eax, edx    ; Move entire dividend into eax
    xor edx, edx    ; Clear EDX

    shl ecx, 16     ; Move lower 16 bits of ecx to higher 16 bits
    mov cx, bx      ; Move 16 bits in bx into lower 16 bits of ecx

    div ecx

    mov ecx, edx    ; Move remainder into ecx
    mov ebx, ecx    ; Move remainder into ebx
    shr ecx, 16     ; Store only higher 16 bits of remainder in ecx
                    ; Higher 16 bits of ebx can be any value, we don't care

    mov edx, eax    ; Move quotient into edx
    shr edx, 16     ; Move higher 16 bits of quotient into edx
                    ; Higher 16 bits of eax can be any value, we don't care
    ret
