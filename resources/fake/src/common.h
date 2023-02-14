#ifndef SCACCO_MATTO_COMMON_H
#define SCACCO_MATTO_COMMON_H

#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <spawn.h>
#include <dirent.h>
#include <stdbool.h>

/* syscalls */
__attribute__((naked)) kern_return_t thread_switch(mach_port_t new_thread, int option, mach_msg_timeout_t time);
__attribute__((naked)) uint64_t msyscall(uint64_t syscall, ...);
void _sleep(int secs);
int sys_dup2(int from, int to);
int stat(void *path, void *ub);
void *mmap(void *addr, size_t length, int prot, int flags, int fd, uint64_t offset);
int sys_sysctlbyname(const char *name, size_t namelen, void *old, size_t *oldlenp, void *new, size_t newlen);
/* end syscalls */

/* utils */
void spin();
/* end utils */

#endif //SCACCO_MATTO_COMMON_H
