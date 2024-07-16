org 0x0         ; This is a directive that tells the assembler that all addresses are to be calculated relative to this starting address.
                ; Directives are only hints to the assembler not an instruction that will perform a computation.
bits 16         ; 8086 machines always start in 16 bit mode to ensure backward compatibility. So, we need to set a directive saying emit 16 bit code only.

%define ENDL 0x0d, 0x0a ; The endline macro is just line feed + carriage return characters.

start:
    jmp main

                ; Print a string to the screen.
                ; Params DS:SI points to the string.
puts:
        push si ; Saving callee saved registers
        push ax
	push bx
.loop:
        lodsb       ; Load the value in DS:SI into AL.
        or al, al   ; Check if al is 0 (Modify only ZF not value of register itself).
        jz .done    ; If byte is null exit loop.
        mov ah, 0xe ; Set AL to ASCII value and AH to interrupt id.
        mov bh, 0x0 ; Set page to 0.
        int 0x10    ; Call BIOS interrupt to print character to the screen.

        jmp .loop

.done:
	    pop bx	; Restoring callee saved registers
        pop ax
        pop si
        ret

main:
        ; print hello world to the screen
        mov si, msg_hello
        call puts

        cli
        hlt
.halt:          ; A halt section to trap the execution of our program if it reaches this point by mistake.
        jmp .halt

msg_hello: db 'Hello World, from Kernel Land!', ENDL, 0
