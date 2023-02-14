#include <Foundation/Foundation.h>
#include "common.h"

#define PROT_READ       0x01            /* [MC2] pages can be read */
#define PROT_WRITE      0x02            /* [MC2] pages can be written */

#define MAP_ANON        0x1000          /* allocated from memory, swap space */
#define MAP_ANONYMOUS   MAP_ANON
#define MAP_PRIVATE     0x0002          /* [MF|SHM] changes are private */

int main() {
    if (getpid() == 1) {
        int fd_console = open("/dev/console", O_RDWR, 0);
        sys_dup2(fd_console, 0);
        sys_dup2(fd_console, 1);
        sys_dup2(fd_console, 2);
        char statbuf[0x400];

        puts("================ Hello from jbinit ================ \n");

        printf("Got opening jb.dylib\n");
        int fd_dylib = 0;
        fd_dylib = open("/jbin/jb.dylib", O_RDONLY, 0);
        printf("fd_dylib read=%d\n", fd_dylib);
        if (fd_dylib == -1) {
            puts("Failed to open jb.dylib for reading");
            spin();
        }
        size_t dylib_size = msyscall(199, fd_dylib, 0, SEEK_END);
        printf("dylib_size=%zu\n", dylib_size);
        msyscall(199, fd_dylib, 0, SEEK_SET);

        printf("reading jb.dylib\n");
        void *dylib_data = mmap(NULL, (dylib_size & ~0x3fff) + 0x4000, PROT_READ | PROT_WRITE,
                                MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        printf("dylib_data=0x%016llx\n", dylib_data);
        if (dylib_data == (void *) -1) {
            puts("Failed to mmap");
            spin();
        }
        int didread = read(fd_dylib, dylib_data, dylib_size);
        printf("didread=%d\n", didread);
        close(fd_dylib);

        {
            int err = 0;
            if ((err = stat("/sbin/launchd", statbuf)))
                printf("stat /sbin/launchd FAILED with err=%d!\n", err);
            else
                puts("stat /sbin/launchd OK\n");
        }

        puts("Closing console, goodbye!\n");

        /*
         Launchd doesn't like it when the console is open already!
         */
        for (size_t i = 0; i < 10; i++)
            close(i);

        char **argv = (char **) dylib_data;
        char **envp = argv + 2;
        char *strbuf = (char *) (envp + 2);
        printf("%s\n", strbuf);
        memcpy(strbuf, "/sbin/launchd", sizeof("/sbin/launchd"));
        argv[0] = strbuf;
        argv[1] = NULL;
        memcpy(strbuf, "/sbin/launchd", sizeof("/sbin/launchd"));
        strbuf += sizeof("/sbin/launchd");
        envp[0] = strbuf;
        envp[1] = NULL;

        char envvars[] = "DYLD_INSERT_LIBRARIES=/jbin/jb.dylib";
        memcpy(strbuf, envvars, sizeof(envvars));
        // We're the first process
        // Spawn launchd
        pid_t pid = fork();
        if (pid != 0) {
            // Parent
            execve("/sbin/launchd", argv, envp);
            return -1;
        }
        return -1;
    }
    return 0;
}
