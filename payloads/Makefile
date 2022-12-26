CC		= xcrun -sdk iphoneos clang
OBJCOPY	= $$(brew --prefix)/opt/binutils/bin/gobjcopy
CFLAGS	= -target arm64-apple-darwin -Wall -O2 -Wextra -Wfloat-equal -pedantic

.PHONY: clean

all: normal debug-changing-rootdev debug-normal

normal:
	$(CC) $(CFLAGS) normal.s -o normal.o
	$(OBJCOPY) -O binary -j .text normal.o normal.bin
	-$(RM) normal.o

debug-changing-rootdev:
	$(CC) $(CFLAGS) debug-changing-rootdev.s -o debug-changing-rootdev.o
	$(OBJCOPY) -O binary -j .text debug-changing-rootdev.o debug-changing-rootdev.bin
	-$(RM) debug-changing-rootdev.o

debug-normal:
	$(CC) $(CFLAGS) debug-normal.s -o debug-normal.o
	$(OBJCOPY) -O binary -j .text debug-normal.o debug-normal.bin
	-$(RM) debug-normal.o

clean:
	-$(RM) *.o
	-$(RM) *.bin

