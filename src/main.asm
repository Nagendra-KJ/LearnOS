org 0x7c00      ; This is a directive that tells the assembler that all addresses are to be calculated relative to this starting address.
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
                ; Code segment has been setup for us to be 0 by the BIOS. Set up the data segments to be 0 now.
        mov ax, 0
        mov ds, ax
        mov es, ax

                ; Setup the stack
        mov ss, ax
        mov sp, 0x7c00 ; Full descending stack, so we point it to the end of our program so our code is not overwritten.

        ; print hello world to the screen
        mov si, msg_hello
        call puts

        hlt
.halt:          ; A halt section to trap the execution of our program if it reaches this point by mistake.
        jmp .halt

msg_hello: db 'Hello World!', ENDL, 0

times 510-($-$$) db 0   ; Times is a directive that repeats another directive (in this case db) n number of times.
                        ; $ gives the memory offset of the current line. $$ gives the memory offset of the current sector (in our case the beginning of the program).
                        ; $ - $$ just gives us the length of the program in bytes. So, every byte out of 510 except the program bytes should be set to 0.
                        ; We use 510 because we are emulating a standard 1.4 MB floppy disk that has sector sizes of 512 bytes.
dw 0aa55h
