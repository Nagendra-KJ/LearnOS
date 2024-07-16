ASM=nasm
CC=gcc

SRC_DIR=src
TOOLS_DIR=tools
BUILD_DIR=build

.PHONY: all floppy_image kernel bootloader clean always tools_fat

all: floppy_image tools_fat

#
# Floppy image generation
#
floppy_image:	$(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img	 bs=512 count=2880 # Copy 0s to floppy.img with sector size of 512 and number of sectors equal to 2880
	mkfs.fat -F 12 -n "LOSBOS" $(BUILD_DIR)/main_floppy.img # Format this image as a FAT12 file system
	mdir -i $(BUILD_DIR)/main_floppy.img ::
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc # Copy the bootloader binary to the first sector.
	# The above step erases the FAT12 metadata unless this data is present in the bootloader.
	mcopy -v -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::/kernel.bin" # Copy the kernel.bin file to the FAT12 file system on the floppy disk image
	mcopy -v -i $(BUILD_DIR)/main_floppy.img $(TOOLS_DIR)/fat/test.txt "::/test.txt"
	mdir -i $(BUILD_DIR)/main_floppy.img ::


#
# Bootloader Recipe
#
bootloader: $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin

#
# Kernel Recipe
#

kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: always
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin

#
# Always
#
always:
	mkdir -p $(BUILD_DIR)

#
# Tools
#
tools_fat: $(BUILD_DIR)/tools/fat

$(BUILD_DIR)/tools/fat: always $(TOOLS_DIR)/fat/fat.c
	mkdir -p $(BUILD_DIR)/tools
	$(CC) -g -o $(BUILD_DIR)/tools/fat $(TOOLS_DIR)/fat/fat.c

	$(BUILD_DIR)/tools/fat $(BUILD_DIR)/main_floppy.img "TEST    TXT"

clean:
	rm -rf $(BUILD_DIR)/*
