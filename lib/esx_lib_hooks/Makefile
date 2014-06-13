CC = gcc
CFLAGS = -Wall -O2 -fpic -shared -ldl

TARGET = miq_lib_hooks.so

$(TARGET): miq_lib_hooks.c
	$(CC) $(CFLAGS) -o $(TARGET) miq_lib_hooks.c
	