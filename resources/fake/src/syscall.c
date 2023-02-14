#include "common.h"

__attribute__((naked)) kern_return_t thread_switch(mach_port_t new_thread, int option, mach_msg_timeout_t time) {
    asm(
            "movn x16, #0x3c\n"
            "svc 0x80\n"
            "ret\n");
}

__attribute__((naked)) uint64_t msyscall(uint64_t syscall, ...) {
    asm(
            "mov x16, x0\n"
            "ldp x0, x1, [sp]\n"
            "ldp x2, x3, [sp, 0x10]\n"
            "ldp x4, x5, [sp, 0x20]\n"
            "ldp x6, x7, [sp, 0x30]\n"
            "svc 0x80\n"
            "ret\n");
}

void _sleep(int secs) {
    thread_switch(0, 2, secs * 1000);
}

int sys_dup2(int from, int to) {
    return msyscall(90, from, to);
}

int stat(void *path, void *ub) {
    return msyscall(188, path, ub);
}

int sys_sysctlbyname(const char *name, size_t namelen, void *old, size_t *oldlenp, void *new, size_t newlen) {
    return msyscall(274, name, namelen, old, oldlenp, new, newlen);
}

void *mmap(void *addr, size_t length, int prot, int flags, int fd, uint64_t offset) {
    return (void *)msyscall(197, addr, length, prot, flags, fd, offset);
}