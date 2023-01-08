CC=xcrun -sdk iphoneos clang
CFLAGS=-target arm64-apple-darwin -arch arm64 -O2 -Wall -Wextra

all: launchd jb.dylib jbloader

launchd: src/launchd_hook.m ents/launchd.entitlements
	$(CC) -o $@ src/launchd_hook.m -framework Foundation -framework UIKit $(CFLAGS)
	ldid -Sents/launchd.entitlements $@
	mkdir -p build
	mv -v ./$@ ./build/

jb.dylib: src/jb.c
	$(CC) -o $@ -shared src/jb.c $(CFLAGS)
	ldid -S $@
	mkdir -p build
	mv -v ./$@ ./build/

jbloader: src/jbinit.c ents/jbloader.entitlements
	$(CC) -o $@ src/jbinit.c $(CFLAGS)
	ldid -Sents/jbloader.entitlements $@
	mkdir -p build
	mv -v ./$@ ./build/

PHONY: clean
clean:
	rm -rvf ./build/