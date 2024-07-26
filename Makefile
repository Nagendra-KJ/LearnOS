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
	dd if=$(BUILD_DIR)/stage1.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc # Copy the bootloader binary to the first sector.
	# The above step erases the FAT12 metadata unless this data is present in the bootloader.
	mcopy -v -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/stage2.bin "::/stage2.bin" # Copy the kernel.bin file to the FAT12 file system on the floppy disk image
	mcopy -v -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::/kernel.bin" # Copy the kernel.bin file to the FAT12 file system on the floppy disk image
	mcopy -v -i $(BUILD_DIR)/main_floppy.img $(TOOLS_DIR)/fat/test.txt "::/test.txt"
	mdir -i $(BUILD_DIR)/main_floppy.img ::


#
# Bootloader Recipe
#
bootloader: stage1 stage2

stage1:	$(BUILD_DIR)/stage1.bin

$(BUILD_DIR)/stage1.bin: always
	$(MAKE) -C $(SRC_DIR)/bootloader/stage1 BUILD_DIR=$(abspath $(BUILD_DIR))

stage2:	$(BUILD_DIR)/stage2.bin

$(BUILD_DIR)/stage2.bin: always
	$(MAKE) -C $(SRC_DIR)/bootloader/stage2 BUILD_DIR=$(abspath $(BUILD_DIR))


#
# Kernel Recipe
#

kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: always
	$(MAKE) -C $(SRC_DIR)/kernel BUILD_DIR=$(abspath $(BUILD_DIR))

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
	$(MAKE) -C $(SRC_DIR)/kernel BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	$(MAKE) -C $(SRC_DIR)/bootloader/stage1 BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	$(MAKE) -C $(SRC_DIR)/bootloader/stage2 BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	rm -rf $(BUILD_DIR)/*
