CC		= xcrun -sdk iphoneos clang
OBJCOPY	= $$(brew --prefix)/opt/binutils/bin/gobjcopy
CFLAGS	= -target arm64-apple-darwin -Wall -O2 -Wextra -Wfloat-equal -pedantic

.PHONY: clean

EXECS=normal debug-changing-rootdev debug-normal

all: $(EXECS)

$(EXECS):
	$(CC) $(CFLAGS) $@.S -o $@.o
	$(OBJCOPY) -O binary -j .text $@.o $@.bin
	-$(RM) $@.o

clean:
	-$(RM) *.o
	-$(RM) *.bin

