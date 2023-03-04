#include "common.h"

#define PATH_MAX 1000
#define RSA "/binpack/dropbear_rsa_host_key"

static bool userspace_reboot = false;

int run(char *const argv[], bool async) {
    pid_t pid = 0;
    int status = 0;
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

    if (!async) {
        printf("Waiting for child process to finish...\n");
        if (waitpid(pid, &status, WCONTINUED) != pid) {
            printf("Error while waiting for child process\n");
            return -1;
        }
        printf("Child process finished with status %d\n", status);
    } else
        printf("Child (async) process finished with status %d\n", status);

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
                run(daemons, true);
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
            run(rcd, true);
        }
        // Close the directory
        closedir(dir);
    } else
        // the folder does not exist or access is denied
        printf("Error: unable to access folder /etc/rc.d/\n");
}

void makeRSA(void) {
    FILE *fd = fopen(RSA, "r");
    if (!fd) {
        puts("generating rsa key\n");
        char *args[] = {"/binpack/usr/bin/dropbearkey", "-t", "rsa", "-f", RSA, NULL};
        run(args, false);
    } else
        fclose(fd);
}

int main (int argc, char *argv[]) {
    int fd_console = open("/dev/console", O_RDWR, 0);
    sys_dup2(fd_console, 0);
    sys_dup2(fd_console, 1);
    sys_dup2(fd_console, 2);
    char bootargs[0x270];

    puts("======== Hello from jbloader! ======== \n");
    {
        unsigned long bootargs_len = sizeof(bootargs);
        int err = sys_sysctlbyname("kern.bootargs", sizeof("kern.bootargs"), &bootargs, &bootargs_len, NULL, 0);
        if (err) {
            printf("cannot get bootargs: %d\n", err);
            spin();
        }
        printf("boot-args = %s\n", bootargs);
    }
    printf("jb.dylib says that my name is \"%s\"\n", argv[0]);
    if (argc == 2)
        if (!strcmp(argv[1], "-i"))
            userspace_reboot = true;
    if (userspace_reboot)
        puts("already mounted\n");
    else {
        char *const mount_rootfs[] = {"/sbin/mount", "-uw", "/", NULL};
        run(mount_rootfs, false);
        char *const mount_preboot[] = {"/sbin/mount", "-uw", "/private/preboot", NULL};
        run(mount_preboot, false);
    }

    if (access("/.installed_anfora_jb", F_OK) != 0) {
        puts("======== start SSH ======== \n");
        makeRSA();
        char *const dropbear[] = { "/binpack/bin/launchctl", "load", "-w", "/binpack/Library/LaunchDaemons/dropbear.plist", NULL };
        int status = run(dropbear, true);
        printf("Command execution finished with status %d\n", status);
    } else {
        puts("======== start Jailbreak ======== \n");
        load_etc_rc_d();
        loadDaemons();
        char *const uicache[] = {"/usr/bin/uicache", "-a", NULL};
        run(uicache, true);
        char *const sbreload[] = {"/usr/bin/sbreload", NULL};
        run(sbreload, false);
        char *const sbdidlaunch[] = {"/usr/bin/sbdidlaunch", NULL};
        run(sbdidlaunch, false);
        _sleep(5);
        char *const uialert[] = { "/usr/bin/uialert", "-b", "\"DONE! All daemons are loaded!\"", "\"AnForA\"", NULL };
        run(uialert, true);
    }
    puts("======== Bye from jbloader! ======== \n");
    close(fd_console);
}