org 0x7c00      ; This is a directive that tells the assembler that all addresses are to be calculated relative to this starting address.
                ; Directives are only hints to the assembler not an instruction that will perform a computation.
bits 16         ; 8086 machines always start in 16 bit mode to ensure backward compatibility. So, we need to set a directive saying emit 16 bit code only.

%define ENDL 0x0d, 0x0a ; The endline macro is just line feed + carriage return characters.

; We need to add the FAT12 metadata since we are trying to write this as the first sector of our disk.

; FAT 12 needs the first 3 bytes to be a short jmp instruction followed by a NOP.

jmp short start
nop

bpb_oem:                    db "MSWIN4.1"  ; 8 byte string of oem which made the disk.
bpb_bytes_per_sector:       dw 512    ; Number of bytes per sector
bpb_sectors_per_clusters:   db 1
bpb_reserved_sectors:       dw 1
bpb_fat_count:              db 2
bpb_dir_entries_count:      dw 0xe0
bpb_total_sectors:          dw 2880
bpb_media_descriptior:      db 0xf0 ; 3.5' floppy disk.
bpb_sectors_per_fat:        dw 9
bpb_sectors_per_track:      dw 18
bpb_heads:                  dw 2
bpb_hidden_sectors:         dd 0
bpb_large_sectors:          dd 0

; Extended Boot Record

ebr_drive_number:           db 0  ; 0x0 for floppy 0x80 for hdd but this should always be a floppy so....redundant
                            db 0    ; reserved byte
ebr_signature:              db 0x28
ebr_volume_id:              db 0x69  ; Serial number of volume
ebr_volume_label:           db "LEARNOSBOOT" ; 11 byte volume label that has to be padded with strings
ebr_system_id:              db "FAT12   " ; 8 byte string which should be FAT12 padded with spaces

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

        ; Read something from disk
        ; BIOS should set the DL to the drive number
        mov [ebr_drive_number], dl
        mov ax, 1       ; Read second sector (LBA = 1)
        mov cl, 1       ; 1 sector to be read
        mov bx, 0x7e00  ; Store the read data after the  bootloader
        call disk_read

        ; Print hello world to the screen
        mov si, msg_hello
        call puts

        hlt

boot_error:
        mov si, msg_boot_fail
        call puts
        jmp wait_key_and_reboot

wait_key_and_reboot:
        ; Wait for a keypress and retry BIOS
        mov ah, 0
        int 0x16        ; Wait for a keypress
        jmp 0xFFFF:0     ; Jump to beginning of BIOS

.halt:                  ; A halt section to trap the execution of our program if it reaches this point by mistake.
        cli             ; Clear all interrupts
        jmp .halt

; Convert the LBA address into CHS.
; AX contains the LBA address to be converted.
; CX[0-5] : Sector Number
; CX[6-15] : Cylinder Number
; DH : Head

lba_to_chs:
        push ax                                 ; Save callee saved registers
        push dx

        xor dx, dx  ; Clear dx
        div word [bpb_sectors_per_track]        ; AX = AX / Sectors Per Track.
                                                ; DX = AX % Sectors Per Track.
        inc dx                                  ; LBA % Sectors + 1 i.e Sectors.
        mov cx, dx
        xor dx, dx
        div word [bpb_heads]                    ; AX  = AX / Num Heads = Cylinders.
                                                ; DX = AX % Num Heads = Head.
        mov dh, dl                              ; Head value in DH.
        mov ch, al                              ; Cylinders into CH.
        shl ah, 0x6                             ; Shift out last 6 bits because cylinder should only start from 7th bit onwards.
        or cl, ah                               ; Put upper 2 bits of cylinder in its correct place.

        pop ax                                  ; Restore callee saved registers
        mov dl, al
        pop ax
        ret

; Reads sectors from a disk.
; Parameters:
;   - AX: The LBA address
;   - CL: The number of sectors
;   - DL: The drive number
;   - ES:BX: The memory location to store the read data

disk_read:
        push ax         ; Save Callee Saved Registers
        push bx
        push cx
        push dx
        push di

        push cx         ; Saving caller saved register
        call lba_to_chs ; Compute the CHS
        pop ax          ; AL = number of sectors to read which was previously pushed
        mov ah, 0x2     ; Saving the parameters according to what the disk read interrupt expects
        mov di, 3       ; Retry count

.retry:
        pusha           ; Save all registers
        stc             ; Set the carry flag. Needed by some BIOS programs
        int 0x13        ; Call the disk read interrupt. If carry flag is cleared operation succeeded. Otherwise retry.
        jnc .done
        ; Read failed
        popa
        call disk_reset
        dec di
        test di, di     ; Check if retry count is 0
        jnz .retry
.fail:
        ; Print boot failed and exit
        jmp boot_error
.done:
        popa

        push di         ; Restore Callee Saved Registers
        push dx
        push cx
        push bx
        push ax
        ret


; Reset the disk controller for the disk number contained in DL
disk_reset:
        pusha
        mov ah, 0x0
        stc
        int 0x13
        jc boot_error
        popa
        ret




msg_hello:      db 'Hello World!', ENDL, 0
msg_boot_fail:  db 'Fatal: Boot Failed!', ENDL, 0

times 510-($-$$) db 0   ; Times is a directive that repeats another directive (in this case db) n number of times.
                        ; $ gives the memory offset of the current line. $$ gives the memory offset of the current sector (in our case the beginning of the program).
                        ; $ - $$ just gives us the length of the program in bytes. So, every byte out of 510 except the program bytes should be set to 0.
                        ; We use 510 because we are emulating a standard 1.4 MB floppy disk that has sector sizes of 512 bytes.
dw 0aa55h
