bits 16

section _TEXT class=CODE

global _x86_DiskReset

_x86_DiskReset:
    push bp             ; Save old bp and move sp to bp
    mov bp, sp          ; New call frame

    push bx             ; Save callee saved bx register

    ; [bp - 2] - Callee saved value of BX
    ; [bp + 0] - Old value of BP
    ; [bp + 2] - Return address (RIP)
    ; [bp + 4] - First argument the drive number

    mov dl, [bp + 4]    ; Drive number

    xor ah, ah          ; Set ah into 0
    stc                 ; Set carry flag so that we can check if it was cleared after interrupt or not
    int 0x13            ; Call INT 13H

    jc error            ; If carry flag is set, ah contains the error code and return
    mov al, 0x1         ; No error, save true (01) in al
    jmp exit            ; Jump to exit


global _x86_DiskRead

_x86_DiskRead:
    push bp             ; Save old bp and move sp to bp
    mov bp, sp          ; New call frame

    push bx             ; Save callee saved bx register
    push es             ; Save callee saved es register

    ; [bp - 2] - Callee saved value of BX
    ; [bp + 0] - Old value of BP
    ; [bp + 2] - Return address (RIP)
    ; [bp + 4] - First argument the disk id
    ; [bp + 6] - Second argument the cylinder (Args are word size padded)
    ; [bp + 8] - Third argument the head
    ; [bp + 10] - Fourth argument the sector
    ; [bp + 12] - Fifth argument the count
    ; [bp + 14] - Sixth argument the out pointer

    mov dl, [bp + 4]    ; Move drive into dl
    mov ch, [bp + 6]    ; Lower 8 bits of cylinder number
    mov cl, [bp + 7]    ; High bits of cylinder
    shl cl, 6           ; Only in upper 2 bits

    mov al, [bp + 10]   ; Sector number
    and al, 0x3f        ; Get only lower 6 bits
    or cl, al           ; Save lower 6 bits in cl

    mov dh, [bp + 8]    ; Head number in dh

    mov al, [bp + 12]   ; Number of sectors to read in al
    
    mov bx, [bp + 16]   ; Higher bits to be put in es
    mov es, bx
    mov bx, [bp + 14]   ; Lower bits to be put in bx
    
    mov ah, 0x2         ; ah to contain 0x2
    stc
    int 0x13

    jc error            ; Jump if carry is set (error)
    mov al, 0x1         ; If no error, save true
    pop es
    jmp exit

global _x86_DiskGetDriveParams

_x86_DiskGetDriveParams:
    push bp             ; Save old bp and move sp to bp
    mov bp, sp          ; New call frame

    push bx             ; Save callee saved bx register
    push es             ; Save callee saved es register
    push di             ; Save callee saved di register
    push si             ; Save callee saved si register

    ; [bp - 2] - Callee saved value of BX
    ; [bp + 0] - Old value of BP
    ; [bp + 2] - Return address (RIP)
    ; [bp + 4] - First argument the disk id
    ; [bp + 6] - Second argument pointer to drive type out
    ; [bp + 8] - Third argument pointer to cylinders out
    ; [bp + 10] - Fourth argument pointer to sectors out
    ; [bp + 12] - Fifth argument pointer to head out

    mov dl, [bp + 4]    ; Move drive into dl
    mov di, 0x0         ; DI to contain 0
    mov es, di          ; ES to contain 0

    mov ah, 0x8         ; ah to contain 0x8
    stc
    int 0x13

    jc error            ; Jump if carry is set (error)

    mov si, [bp + 6]    ; Save drive type out
    mov [si], bl

    mov al, cl
    and al, 0x3f
    mov si, [bp + 10]
    mov [si], al        ; Save number of sectors

    mov si, [bp + 8]
    mov [si], ch        ; Save cylinders out
    shr cl, 6           ; Higher 2 bits for number of cylinders
    mov si, [bp + 9]
    mov [si], cl

    mov si, [bp + 12]
    mov [si], dh        ; Save number of heads

    mov al, 0x1         ; Save true for success
    pop si
    pop di
    pop es
    jmp exit



error:
    mov al, ah          ; Save error code in lower byte
    xor ah, ah          ; Clear the higher byte

exit:
    pop bx              ; Restore callee saved register
    mov sp, bp          ; Restore old sp
    pop bp              ; Restore old bp
    ret
