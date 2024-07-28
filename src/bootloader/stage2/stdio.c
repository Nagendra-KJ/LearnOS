#include "stdio.h"
#include "x86_putchar.h"
#include "x86_divide_64_32.h"

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

int* printf_number(int* argp,  int length, bool sign, int radix)
{
    char buffer[32];
    unsigned long long number;
    int number_sign = 1;
    int pos = 0;


    // Process the length of the number
    switch (length) {
        case LENGTH_SHORT_SHORT:
        case LENGTH_SHORT:
        case LENGTH_DEFAULT:
            if (sign) {
                int n = *argp;
                if (n < 0) {
                    number_sign = -1;
                    n = -n;
                }
                else
                    number_sign = 1;
                number = (unsigned long long)n;
            }
            else {
                number = *(unsigned int *)argp;
            }
            argp++;
            break;
        case LENGTH_LONG:
            if (sign) {
                long int n = *argp;
                if (n < 0) {
                    number_sign = -1;
                    n = -n;
                }
                else
                    number_sign = 1;
                number = (unsigned long long)n;
            }
            else {
                number = *(unsigned long int *)argp;
            }
            argp+= 2;
            break;
        case LENGTH_LONG_LONG:
            if (sign) {
                long long int n = *argp;
                if (n < 0) {
                    number_sign = -1;
                    n = -n;
                }
                else
                    number_sign = 1;
                number = (unsigned long long)n;
            }
            else {
                number = *(unsigned long long int *)argp;
            }
            argp+= 4;
            break;
    }

    // Write the number into its ASCII representation
    
    do {
        uint32_t rem;
        x86_Divide64By32(number, radix, &number, &rem);
        buffer[pos++] = HexChars[rem];
    } while (number > 0);

    if (sign && number_sign == -1)
        buffer[pos++] = '-';

    // Print the number in reverse

    while (--pos >= 0)
        putc(buffer[pos]);

    return argp;

}

void _cdecl printf(const char* fmt, ...)
{
    enum printf_state state = STATE_NORMAL;
    int* argp = (int *) &fmt;
    enum printf_length length = LENGTH_DEFAULT;
    bool sign = false;
    int radix = 10;

    ++argp;

    while (*fmt)
    {
        if (state == STATE_NORMAL) {
            if (*fmt == '%') {
                state = STATE_LENGTH;
                ++fmt;
            }
            else
                putc(*fmt);
        }
        if (state == STATE_LENGTH) {
            if (*fmt == 'h') {
                length = LENGTH_SHORT;
                state = STATE_LENGTH_SHORT;
                ++fmt;
            }
            else if (*fmt == 'l') {
                length = LENGTH_LONG;
                state = STATE_LENGTH_LONG;
                ++fmt;
            }
            else
                state = STATE_SPECIFIER;
        }
        if (state == STATE_LENGTH_LONG) {
            if (*fmt == 'l') {
                length = LENGTH_LONG_LONG;
                ++fmt;
            }
            state = STATE_SPECIFIER;
        }
        if (state == STATE_LENGTH_SHORT) {
            if (*fmt == 'h') {
                length = LENGTH_SHORT_SHORT;
                ++fmt;
            }
            state = STATE_SPECIFIER;
        }
        if (state == STATE_SPECIFIER) {
            switch (*fmt) {
                case 'c':
                    putc((char)*argp);
                    ++argp;
                    break;
                case 's':
                    puts(*(char **)argp);
                    ++argp;
                case '%':
                    putc('%');
                    break;
                case 'd':
                case 'i':
                    radix = 10;
                    sign = true;
                    argp = printf_number(argp, length, sign, radix);
                    break;
                case 'u':
                    radix = 10;
                    sign = false;
                    argp = printf_number(argp, length, sign, radix);
                    break;
                case 'x':
                case 'X':
                case 'p':
                    radix = 16;
                    sign = false;
                    argp = printf_number(argp, length, sign, radix);
                    break;
                case 'o':
                    radix = 8;
                    sign = false;
                    argp = printf_number(argp, length, sign, radix);
                    break;
                default:
                    break;
            }
            state = STATE_NORMAL;
            radix = 10;
            sign = false;
            length = LENGTH_DEFAULT;
        }
        ++fmt;
    }
}
