# Notes for Nagendras Reference
## Bios
Bios is the mechanism by which the computer finds the OS. There are two types of BIOS
1. Legacy
2. EFI

### Legacy BIOS
Search each boot partition's first sector (0x7c00)  for a sequence (0xaa55). If found, boot the OS at this partition.

### EFI
Search special EFI partitions for the OS. For this to work, the OS should be compiled as an EFI program.

## x86 Architecture
The 8086 CPU has a 16 bit data bus and a 20 bit address bus. 20 bits gives us 4GB worth of address space.
We use a segment and offset style of addressing to access different areas in memory.
Since each register is 16 bits wide, we have an offset register of 16 bits which gives us 64KB sized segments.

Real address = 16 * Segment Reigster Value + Offset Register Value.

RIP or the instruction pointer only holds the offset value not the real address.

Following are the different segment registers available

1. CS - Current Code Segment
2. DS - Data Segment
3. SS - Stack Segment

### Referencing a memory location
`segment:[base + index * scale + displacement]`

All fields are optional.

1. segment - The segment whose memory we are trying to access (by default it is the data segment)
2. base - The base address from where we calculate our displacement. For 16 bit mode this base address has to be stored in BP/BX
3. index - The index we try to add to the base. For 16 bit mode this base address has to be stored in SI/DI
4. scale - Only for 32 and 64 bit processors, 1, 2, 4 or 8
5. displacement - A signed constant value

#### Example
`array: dw 100, 200, 300, 400`
`mov bx, array`
`mov si, 2 * 2 ; Each element is 2 bytes (word) so second element is 2 * 2 bytes in`
`mov ax, [bx + si] ; Copy 2nd element to ax. Base + Index style of addressing`
