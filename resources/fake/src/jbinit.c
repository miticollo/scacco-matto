#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <spawn.h>
#include <dirent.h>
#include <stdbool.h>

#define PATH_MAX 1000

static bool userspace_reboot = false;

__attribute__((naked)) uint64_t msyscall(uint64_t syscall, ...){
    asm(
            "mov x16, x0\n"
            "ldp x0, x1, [sp]\n"
            "ldp x2, x3, [sp, 0x10]\n"
            "ldp x4, x5, [sp, 0x20]\n"
            "ldp x6, x7, [sp, 0x30]\n"
            "svc 0x80\n"
            "ret\n"
            );
}

int stat(void *path, void *ub){
    return msyscall(188,path,ub);
}

int sys_dup2(int from, int to) {
    return msyscall(90, from, to);
}

int run_shell_command(char *const argv[]) {
    pid_t pid = 0;
    int status;
    posix_spawnattr_t attr;

    printf("Initializing spawn attribute...\n");
    posix_spawnattr_init(&attr);

    printf("Running posix_spawn with the following arguments:\n");
    for (int i = 0; argv[i] != NULL; i++)
        printf("  argv[%d]: %s\n", i, argv[i]);
    int ret = posix_spawn(&pid, argv[0], NULL, &attr, argv, NULL);
    if (ret != 0) {
        printf("Error while running posix_spawn: %d\n", ret);
        return -1;
    }

    printf("Destroying spawn attribute...\n");
    posix_spawnattr_destroy(&attr);

    printf("Waiting for child process to finish...\n");
    if (waitpid(pid, &status, WCONTINUED) != pid) {
        printf("Error while waiting for child process\n");
        return -1;
    }

    printf("Child process finished with status %d\n", status);
    return status;
}

void loadDaemons(void) {
    DIR *dir;
    struct dirent *entry;
    char path[PATH_MAX];

    if ((dir = opendir("/Library/LaunchDaemons/")) != NULL) {
        while ((entry = readdir(dir)) != NULL)
            if (strstr(entry->d_name, ".plist") != NULL) {
                snprintf(path, PATH_MAX, "/Library/LaunchDaemons/%s", entry->d_name);
                char *const daemons[] = {"/bin/launchctl", "load", path, NULL};
                run_shell_command(daemons);
            }
        closedir(dir);
    } else
        printf("Error: unable to access folder /Library/LaunchDaemons/\n");
}

void load_etc_rc_d(void) {
    DIR *dir;
    struct dirent *entry;
    char path[PATH_MAX];

    // Open the directory specified by "/etc/rc.d"
    if ((dir = opendir("/etc/rc.d/")) != NULL) {
        // Read each entry in the directory
        while ((entry = readdir(dir)) != NULL) {
            // Skip the current directory and the parent directory
            if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
                continue;
            snprintf(path, PATH_MAX, "/etc/rc.d/%s", entry->d_name);
            char *const rcd[] = {path, NULL};
            run_shell_command(rcd);
        }
        // Close the directory
        closedir(dir);
    } else
        // the folder does not exist or access is denied
        printf("Error: unable to access folder /etc/rc.d/\n");
}

int main (int argc, char *argv[]) {
    int fd_console = open("/dev/console", O_RDWR, 0);
    sys_dup2(fd_console, 0);
    sys_dup2(fd_console, 1);
    sys_dup2(fd_console, 2);
    puts("======== Hello from jbloader! ======== \n");
    printf("jb.dylib says that my name is \"%s\"\n", argv[0]);
    if (argc == 2)
        if (!strcmp(argv[1], "-i"))
            userspace_reboot = true;
    if (userspace_reboot)
        puts("already loaded\n");
    else {
        char *const mount_rootfs[] = {"/sbin/mount", "-uw", "/", NULL};
        run_shell_command(mount_rootfs);
        char *const mount_preboot[] = {"/sbin/mount", "-uw", "/private/preboot", NULL};
        run_shell_command(mount_preboot);
    }

    if (access("/.installed_anfora_jb", F_OK) != 0) {
        puts("======== start SSH ======== \n");
        char *const dropbear[] = { "/binpack/bin/launchctl", "load", "-w", "/binpack/Library/LaunchDaemons/dropbear.plist", NULL };
        int status = run_shell_command(dropbear);
        printf("Command execution finished with status %d\n", status);
    } else {
        puts("======== start Jailbreak ======== \n");
        load_etc_rc_d();
        loadDaemons();
        char *const uicache[] = {"/usr/bin/uicache", "-a", NULL};
        run_shell_command(uicache);
        // To be sure
        char *const sileo[] = {"/usr/bin/uicache", "-p", "/Applications/Sileo.app", NULL};
        run_shell_command(sileo);
        char *const sbreload[] = {"/usr/bin/sbreload", NULL};
        run_shell_command(sbreload);
    }
    puts("======== Bye from jbloader! ======== \n");
    close(fd_console);
}