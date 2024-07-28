#pragma once

void putc(char c);
void puts(const char *str);
void _cdecl printf(const char *fmt, ...);

enum printf_state {STATE_NORMAL, STATE_LENGTH, STATE_LENGTH_SHORT, STATE_LENGTH_LONG, STATE_SPECIFIER};
enum printf_length {LENGTH_DEFAULT, LENGTH_SHORT_SHORT, LENGTH_SHORT, LENGTH_LONG, LENGTH_LONG_LONG};

const char HexChars[] = "0123456789ABCDEF";
