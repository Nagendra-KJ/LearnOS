#include "disk.h"
#include "x86_disk.h"

bool Disk_Initialize(DISK *disk, uint8_t driveNumber)
{
    uint8_t driveType;
    uint16_t cylinders, sectors, heads;

    if (!x86_DiskGetDriveParams(disk->id, &driveType, &cylinders, &sectors, &heads)) {
        return false; 
    }
    
    disk->id = driveNumber;
    disk->cylinders = cylinders;
    disk->sectors = sectors;
    disk->heads = heads;

    return true;
}

void DISK_LBA2CHS(DISK *disk, uint32_t lba, uint16_t *cylindersOut, uint16_t *headsOut, uint16_t *sectorsOut)
{
    *sectorsOut = (lba % disk->sectors) + 1;
    *headsOut = (lba / disk->sectors) % disk->heads;
    *cylindersOut = (lba / disk->sectors) / disk->heads;
}

bool Disk_ReadSectors(DISK *disk, uint32_t lba, uint8_t sectors, uint8_t far* dataOut)
{
    uint16_t cylinder, sector, head;
    DISK_LBA2CHS(disk, lba, &cylinder, &head, &sector);

    for (int i = 0; i < 3; ++i)
    {
        if (x86_DiskRead(disk->id, cylinder, head, sector, sectors, dataOut))
            return true;
        x86_DiskReset(disk->id);
    }
    return false;

}

