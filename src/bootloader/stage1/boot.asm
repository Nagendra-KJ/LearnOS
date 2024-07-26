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
                ; Code segment has been setup for us to be 0 by the BIOS. Set up the data segments to be 0 now.
        mov ax, 0
        mov ds, ax
        mov es, ax

                ; Setup the stack
        mov ss, ax
        mov sp, 0x7c00 ; Full descending stack, so we point it to the end of our program so our code is not overwritten.
        
        ; Some BIOS don't set up the code segment to be 0, so we just push es and after and do a far jump.
        push es,
        push word .after
        retf
.after:
        ; Read something from disk
        ; BIOS should set the DL to the drive number
        mov [ebr_drive_number], dl
       
        ; Show loading message
        mov si, msg_boot_loading
        call puts

        ; Read drive parameters directly using x86 interrupt 0x13

        ; The disk to read from should be set in DL (Set to 0 meaning floppy drive A)
        ; The operation to be performed on the disk should be stored in AH (0x8 to read)
        ; AL contains sectors to read count, CH contains cylinder, CL contains sector, DH the head, and DL the drive. ES:BX contains the buffer address.

        push es
        mov ah, 0x8
        int 0x13
        jc boot_error
        pop es

        ; CH contains the first 8 bits of the cylinder number
        ; First 2 bits of CL contains the last 2 bits of the cylinder number and last 6 bits contain the sector information

        and cl, 0x3f ; Mask upper 2 bits of CL
        xor ch, ch  ; Make sector number as 0
        mov [bpb_sectors_per_track], cx ; Save sector count

	    inc dh
	    mov [bpb_heads], dh		; Get the head count

        ; Reading the FAT root directory

        mov ax, [bpb_sectors_per_fat]   ; Root sector begins at reserved_sector + fat_count * sectors_per_fat
        mov bl, [bpb_fat_count]
        xor bh, bh
        mul bx                          ; dx:ax = [fat_count * sectors_per_fat]
        add ax, [bpb_reserved_sectors]  ; ax = LBA of root directory
        push ax

        ; Compute the size of the root directory
        mov ax, [bpb_dir_entries_count]
        shl ax, 5                       ; ax = dir_entries_count * 32 which is the size of each sector
        xor dx, dx
        div word [bpb_bytes_per_sector] ; Size of FAT / bytes per sector to give us number of sectors we need to read in ax and remainder in dx

        test dx, dx                     ; Check if dx == 0
        jz root_dir_after               ; If 0, no remainder
        inc ax                          ; Otherwise, there is a remiainder, i.e partial sector, so increment the number of sectors we have to read

root_dir_after:
        ; Read root directory
        mov cl, al                      ; Number of sectors to read = Number of sectors spanned by root directory
        pop ax                          ; LBA of root directory
        mov dl, [ebr_drive_number]
        mov bx, buffer                  ; es:bx is our buffer
        call disk_read

        ; Search for the stage2.bin file in the directory entries

        xor bx, bx                      ; Number of directory entries checked is stored in bx
        mov di, buffer
        
.search_stage2:
        mov si, file_stage2_bin
        mov cx, 11
        push di
        repe cmpsb
        pop di
        je .found_stage2
       

        ; Current directory was not stage2 entry, move on to next one.
        add di, 32
        inc bx
        cmp bx, [bpb_dir_entries_count]
        jl .search_stage2

        ; Kernel not found
        jmp stage2_not_found_error

.found_stage2:
        ; DI should point to the address of the entry
        ; The lower bits of the cluster are in DI + 26
        mov ax, [di + 26]
        mov [stage2_cluster], ax
        

       ; Read the FAT

        mov ax, [bpb_reserved_sectors]      ; LBA is 1 meaning we just read from block 1
        mov bx, buffer                      ; Save to buffer
        mov cl, [bpb_sectors_per_fat]      ; Read sectors per fat number of sectors
        mov dl, [ebr_drive_number]          ; From the ebr drive
        call disk_read                      ; Go ahead and read it

        ; Read the stage2 and process the FAT chain
        ; Save the stage2 in the area 0x7E00 to 0x7FFF (400 KB worth of space)

        mov bx, STAGE2_LOAD_SEGMENT
        mov es, bx
        mov bx, STAGE2_LOAD_OFFSET


.load_stage2_loop:
        ; Read next cluster
        mov ax, [stage2_cluster]
        add ax, 31                          ; First cluster is [stag2_cluster - 2] * sectors_per_cluster + start_sector
                                            ; Start sector = reserved + FATs + Root Directory Size = 1 + 18 + 14 = 33
                                            ; First cluster is -2 * 1 + 33 = 31 which we have hardcoded here
        mov cl, 1
        mov dl, [ebr_drive_number]
        call disk_read


        add bx, [bpb_bytes_per_sector]      ; Possible overflow here, may need to fix in future

        ; Compute the location of the next cluster
        mov ax, [stage2_cluster]
        mov cx, 3
        mul cx
        mov cx, 2
        div cx                              ; AX contains the index and DX contains the remainder

        mov si, buffer
        add si, ax
        mov ax, [ds:si]                     ; Read Index from FAT
        or dx, dx                           ; Set FLAGS
        jz .even                            

.odd:                                       ; Read upper 12 bits
        shr ax, 4
        jmp .next_cluster_after
.even:                                      ; Read lower 12 bits
        and ax, 0x0fff


.next_cluster_after:
        cmp ax, 0x0ff0                      ; Check if end of cluster
        jae .read_finish

        mov [stage2_cluster], ax
        jmp .load_stage2_loop

.read_finish:
        mov dl, [ebr_drive_number]
        mov ax, STAGE2_LOAD_SEGMENT
        mov ds, ax
        mov es, ax

        jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET




        ; We should be in stage2 land at this point
        jmp wait_key_and_reboot
        
        
        
        


        cli
        hlt

boot_error:
        mov si, msg_boot_fail
        call puts
        jmp wait_key_and_reboot

stage2_not_found_error:
        mov si, msg_stage2_not_found
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

        pop di         ; Restore Callee Saved Registers
        pop dx
        pop cx
        pop bx
        pop ax
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




msg_boot_loading:   db 'Loading...', ENDL, 0
msg_boot_fail:      db 'Fatal: Boot Failed!', ENDL, 0
msg_stage2_not_found:      db 'Fatal: Stage 2 Not Found!', ENDL, 0
file_stage2_bin:    db 'STAGE2  BIN'

stage2_cluster:     dw 0

STAGE2_LOAD_SEGMENT     equ 0x2000
STAGE2_LOAD_OFFSET      equ 0

times 510-($-$$) db 0   ; Times is a directive that repeats another directive (in this case db) n number of times.
                        ; $ gives the memory offset of the current line. $$ gives the memory offset of the current sector (in our case the beginning of the program).
                        ; $ - $$ just gives us the length of the program in bytes. So, every byte out of 510 except the program bytes should be set to 0.
                        ; We use 510 because we are emulating a standard 1.4 MB floppy disk that has sector sizes of 512 bytes.
dw 0aa55h

buffer:
