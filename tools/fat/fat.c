#include "fat.h"

BootSector g_BootSector;
uint8_t *g_Fat =  NULL;
DirectoryEntry *g_RootDirectory = NULL;
uint32_t g_RootDirectoryEnd;

int main(int argc, char **argv)
{
    if (argc < 3) {
        printf("Syntax: %s <disk image> <file name>\n", argv[0]);
        return -1;
    }
    FILE *disk = fopen(argv[1], "rb");
    if (!disk) {
        fprintf(stderr, "Cannot open disk image %s !\n", argv[1]);
        return -1;
    }
    if (!readBootSector(disk)) {
        fprintf(stderr, "Could not read boot sector!\n");
        return -2;
    }

    if (!readFat(disk)) {
        fprintf(stderr, "Could not read FAT!\n");
        free(g_Fat);
        return -3;
    }

    if (!readRootDirectory(disk)) {
        fprintf(stderr, "Could not read Root Directory!\n");
        free(g_Fat);
        free(g_RootDirectory);
        return -4;
    }

    DirectoryEntry *fileEntry = findFile(argv[2]);

    if (!fileEntry) {
        fprintf(stderr, "Could not find file %s!\n", argv[2]);
        free(g_Fat);
        free(g_RootDirectory);
        return -5;
    }

    uint8_t *buffer = (uint8_t *) malloc(fileEntry->Size * g_BootSector.BytesPerSector);
    if (!readFile(fileEntry, disk, buffer)) {
        fprintf(stderr, "Could not read file %s\n", argv[2]);
        free(g_Fat);
        free(g_RootDirectory);
        free(buffer);
        return -6;
    }

    for (size_t i = 0; i < fileEntry->Size; ++i) {
        if (isprint(buffer[i]))
            fputc(buffer[i], stdout);
        else
            printf("<%02x>", buffer[i]);
    }
    free(g_Fat);
    free(g_RootDirectory);
    return 0;
}

bool readBootSector(FILE *disk)
{
    return fread(&g_BootSector, sizeof(g_BootSector), 1, disk);    
}

bool readSectors(FILE *disk, uint32_t lba, uint32_t count, void* bufferOut)
{
    bool ok = true;
    ok = ok & (fseek(disk, lba * g_BootSector.BytesPerSector, SEEK_SET) == 0); // Seek to the correct sector
    ok = ok & (fread(bufferOut, g_BootSector.BytesPerSector, count, disk) == count); // Read the entire sector into the buffer out pointer
    return ok;
}

bool readFat(FILE *disk)
{
    g_Fat = (uint8_t*) malloc(g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector);
    return readSectors(disk, g_BootSector.ReservedSectorsCount, g_BootSector.SectorsPerFat, g_Fat);

}

bool readRootDirectory(FILE *disk)
{
    uint32_t lba = g_BootSector.ReservedSectorsCount + g_BootSector.SectorsPerFat * g_BootSector.FatCount; // Get the beginning of the root directory.
    uint32_t size = sizeof(DirectoryEntry) * g_BootSector.DirEntriesCount;
    uint32_t sectors = (size / g_BootSector.BytesPerSector);
    if (size % g_BootSector.BytesPerSector > 0)
        ++sectors;
    g_RootDirectoryEnd = lba + sectors;
    g_RootDirectory = (DirectoryEntry*) malloc(sectors * g_BootSector.BytesPerSector); // We can only allocate sizes to directories in chunks of sectors.
    return readSectors(disk, lba, sectors, g_RootDirectory);
}

DirectoryEntry* findFile(const char *name)
{
    for (uint32_t i = 0; i < g_BootSector.DirEntriesCount; ++i) {
        if (memcmp(name, g_RootDirectory[i].Name, 11) == 0)
            return &g_RootDirectory[i];
    }
    return NULL;
}

bool readFile(DirectoryEntry *fileEntry, FILE *disk, uint8_t *outputBuffer)
{
   bool ok = true;
   uint16_t currentCluster = fileEntry->FirstClusterLow;

   do {
        uint32_t lba = g_RootDirectoryEnd + (currentCluster - 2) * g_BootSector.SectorsPerCluster;
        ok = ok && readSectors(disk, lba, g_BootSector.SectorsPerCluster, outputBuffer);
        outputBuffer += g_BootSector.SectorsPerCluster * g_BootSector.BytesPerSector;

        // Read the next cluster
        uint32_t fatIndex = currentCluster * 3 / 2;
        if (currentCluster % 2 == 0) // We need to read the upper 12 bits
            currentCluster = (*(uint16_t *)g_Fat + fatIndex) & 0xFFF;
        else                        // We need to read the lower 12 bits
            currentCluster = (*(uint16_t *)g_Fat + fatIndex) >> 4;
   } while(ok && currentCluster < 0x0FF8);
   return ok;
}
