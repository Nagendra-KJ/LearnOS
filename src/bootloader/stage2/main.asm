bits 16

section _ENTRY class=CODE ; Defining the entry point for our linker and telling it that this belongs in the code section

extern _cstart_ ; This will be the extern symbol where C will enter into.

global entry

entry:
    cli
    mov ax, ds  ; Since we are using a small memory model the stack segment and data segment are in the same space.
    mov ss, ax  ; Since stage1 has already set up the data segment for us, we copy that into the stack segment.
    mov sp, 0   ; Resetting the base and stack pointer. This will cause overwriting if our file is larger than 60KB as sp and bp will wrap around
    mov bp, sp
    sti         ; Re-enable interrupts once stack is set up.

    ; Stage 1 has set the boot drive which was loaded into dl, we will send this to the cstart function
    xor dh, dh  ; Resetting high bytes since we don't need it
    push dx     ; Saving dx onto the stack
    call _cstart_   ; Should never return from this

    cli
    hlt

