#include "stdio.h"
#include "x86_putchar.h"

void putc(char c)
{
    x86_PutCharToScreen(c, 0);
}

void puts(const char *str)
{
    while (*str)
    {
        putc(*str);
        ++str;
    }
}
