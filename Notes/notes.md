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

1. segment - The segment whose memory we are trying to access (by default it is the data segment, and if base register is BP, stack segment is used)
2. base - The base address from where we calculate our displacement. For 16 bit mode this base address has to be stored in BP/BX
3. index - The index we try to add to the base. For 16 bit mode this base address has to be stored in SI/DI
4. scale - Only for 32 and 64 bit processors, 1, 2, 4 or 8
5. displacement - A signed constant value

#### Example
`array: dw 100, 200, 300, 400`
`mov bx, array`
`mov si, 2 * 2 ; Each element is 2 bytes (word) so second element is 2 * 2 bytes in`
`mov ax, [bx + si] ; Copy 2nd element to ax. Base + Index style of addressing`

## Components of an Operating System

The operating system generally has 2 components, the bootloader and the kernel.

### Bootloader

The bootloader is a tiny segment of code (usually 512 bytes) that loads the basic components of the OS into memory.
It puts the computer in an expected state and collects some information about the system. 
The bootloader switches from 16 bit mode into 32 bit protected mode and hands it off to the kernel.
32 bit protected mode has some limitations as to the kind of instructions we can execute, so the bootloader has to track all these things before we jump into the kernel.

## Disk Layout

To access the data on a disk we need to come up with an accessing scheme. Each side of the platter is called the head of the disk. Each ring on the head is called the cylinder. And the data is located in the sectors in these cylinders.

### CHS Scheme

In CHS scheme we access the data in the disk by specifying the cylinder, head and sector number. Cylinders and heads are 0 indexed and sectors are 1 indexed.
BIOS only supports CHS scheme.

### LBA Scheme

This stands for logical block addressing scheme, tells us which block of the disk the memory we want to access is present in. We must manually convert from LBA to CHS.

### Conversion from LBA to CHS

In a disk we have 2 constant values,

1. The number of sectors per track
2. The number of heads per cylinder

`sector = (LBA % sectors per track) + 1`
`heads = (LBA / sectors per track) % heads`
`cylinder = (LBA / sectors per track) / heads`

## File Systems

A file system is an organized way to store data on a disk. Following are some common file systems.

1. FAT - Simplest file system, very few features. Supported by Windows 9x and Windows 3.1
2. ext - Supported on Linux
3. APFS - Supported on newer Macs
3. HFS+ - Supported on older Macs
4. NTFS - Supported on newer Windows machines and supports many newer features

### FAT File System

Stands for File Attribute Table System. A FAT disk is broken into 4 region.

1. Reserved Region - Contains the size of a sector, size and locations of each of the regions and some metadata like volume ID and serial number. FAT32 has an additional sector called File System Information Sector. This is not present in FAT12 and FAT16.
2. File Allocation Table Region - Contains two copies of the file allocation table that gives us the location of the next block of data for a file.
3. Root Directory Region - Table of contents for a disk, contains entry for each file and folder present in the root directory of the disk. Contains information about file name, size, attributes and meta data of the file.
4. Data Region - Contains the actual contents of the file.

#### Reading a file from the FAT file system

1. First determine where the Root Directory region is. We know that the root directory is the third region after Reserved and FAT Regions.
    * Read the number of reserved sectors present in the reserved region. In our boot img this is 1.
    * To get the size of the FAT Region multiply the number of FAT counts (2) with the size of each FAT (9 sectors) = 18 sectors.
    * So the root directory starts at the 19th sector.
    * We now need to calculate the size of the root directory to determine where it ends.
    * We see the directory entry count (224) and the size of each directory (32 bytes) which gives us a total size of 7168 bytes.
    * Therefore we can now get the total number of sectors by dividing by 512 the size of each sector in FAT12 and end up with a total of 14 sectors.
    * To ensure ceil operation during division, we can do (num + divisor - 1)/divisor.
2. Once we reach the root directory, we search for the file we need.
    * File names can only be 11 characters long, which was extended with the help of the attribute field and other fields to store the parts of long file names.
    * Compare the file name field to the file name of our desired file. Once matched read the first cluster number.
    * FAT 32 uses cluster high and cluster low fields, FAT 12 only needs cluster low field.
    * In FAT a block of data is called a cluster. 
3. Since we know where the first cluster of a file is located, we can now start reading the file into memory.
    * The cluster number gives us the location to start reading from in the data region and the first data cluster starts from 2.
    * `LBA = data_region_begin  + (cluster - 2) * sectors_per_cluster`
    * `LBA = 1+18+14 + (3 - 2) * 2`
    * Once we know the first cluster, we look at the file allocation table to determine the next clusters for a file.
    * For FAT12 each entry in the FAT is 12 bits wide.
    * In our example, the first cluster is 3, so start reading from the 4th entry. This gives us the location of the next cluster.
    * Keep reading each subsequent cluster until you reach the end marker (value above 0xFF8). This is the end of a file.
4. If the file we want is in a folder,
    * Split the path into its component folders and end file.
    * Read each folder and file similar to before.
    * Parse the data of a folder similar to that of the root direcotry.

### [CDECL Calling Convention](https://learn.microsoft.com/en-us/cpp/cpp/cdecl?view=msvc-170)

In order to move from Assembly to a high level programming language (C) we need to setup our compilation toolchain. Since we are still in 16 bit real mode for our bootloader, we use the open watcom 16 bit compiler. We also do not have access to the standard library, so we must define our own library functions. For this, we need to setup basic interrupt calls from assembly as we cannot make interrupt calls from C. To pass the parameters from the C functions into assembly land, we need to follow a proper calling convention, for 16 bit systems we use the CDECL calling convention. The rules for this calling convention are given below.

1. Default calling convention for C and C++ programs.
2. Caller function is responsible for cleaning up the stack.
3. This allows for varargs during compilation.
4. Larger sized executables since each function needs to include cleanup code.
5. Arguments are passed from right to left.
6. Calling function pops the arguments from the stack.
7. _ is prefixed to names, except when _cdecl modifier is specified during linking for C programs.
8. AX, CX, and DX are caller saved and rest are callee saved registers.
9. The value is returned through AX, either an integer or a pointer.
10. The value can also be returned through ST0 if it is a floating point register.

### Pointer Comparison

This was a solution that was deviced when memory was a precious resource way back when. Every address in a program in x86 is 20 bits wide, however, the registers in x86 are only 16 bits wide.

So, the real address is calculated by doing `segment_register << 4 + offset_register`. This calculation means a given address is can be addressed using different ways (4096). This makes it difficult to compare two pointers as they may be pointing to the same real address with different register values. This leads to the following different types of pointers.

#### Near Pointers

Near pointers are 16 bit offsets within a segment (CS for code segment and DS for data segment). This allows for a range of 64KB worth of memory. They are really fast but limited in size.

`final 16 bit pointer address = 16 bit offset coming from offset register`

#### Far Pointers

Far pointers are 32 bit pointers, containing a segment and an offset. The segment is specified using the extra segment and the offset is specified using another register. This method of addressing allows a range of 1MB of memory. Far pointers allow for multiple segments to be accessed simply by changing the ES register value. Segments roll over post 64K and do not extend.

`final 32 bit pointer address = first 16 bits from ES register + last 16 bits coming from offset register`

#### Huge Pointers

Huge pointers are 32 bit pointers and are similar to far pointers, except that each time the address is normalized (re-organized) such that the segment register takes the maximum possible value to correctly calculate that address. This means when using huge pointers, 2 pointers which point to the same location, always have the same segment and offset registers.

`final 32 bit pointer address = first 16 bits from ES register (with the additional constraint that this the maxed out) + last 16 bits coming from offset register`


### Memory models

The above pointer types allows for the following memory models.

| MODEL | DATA | CODE | DEFINITION |
| Tiny  | near | near | CS = DS = SS |
| Small | near | near | DS = SS |
| Medium | near | far | DS = SS and multiple CS |
| Compact | far | near | single CS, multiple DS |
| Large | far | far | multiple CS, multiple DS |
| Huge | huge | far | multiple CS, and multiple DS, single array may be over 64KB |
