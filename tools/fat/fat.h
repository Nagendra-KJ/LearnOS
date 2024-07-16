#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define true 1
#define false 0

typedef uint8_t bool;

typedef struct {
    uint8_t DriveNumber;
    uint8_t _ReservedByte;
    uint8_t Signature;
    uint32_t VolumeID;
    uint8_t VolumeLabel[11];
    uint8_t SystemID[8];
} __attribute__((packed)) ExtendedBootRecord;


typedef struct {
    uint8_t BootJumpInstruction[3];
    uint8_t OEMIdentifer[8];
    uint16_t BytesPerSector;
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectorsCount;
    uint8_t FatCount;
    uint16_t DirEntriesCount;
    uint16_t TotalSectorsCount;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t HeadsCount;
    uint32_t HiidenSectorsCount;
    uint32_t LargeSectorsCount;
    ExtendedBootRecord EBR;
} __attribute__((packed)) BootSector;

typedef struct {
    uint8_t Name[11];
    uint8_t Attribute;
    uint8_t _Reserved;
    uint8_t CreatedTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
} __attribute__((packed)) DirectoryEntry;

bool readBootSector(FILE *disk);
bool readFat(FILE *disk);
bool readRootDirectory(FILE *disk);
DirectoryEntry* findFile(const char *name);
bool readFile(DirectoryEntry *fileEntry, FILE *disk, uint8_t *outputBuffer);
