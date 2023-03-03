## uikittools-ng

uikittools è un pacchetto che contiene diversi CLI tool per eseguire screenshot, creare notifiche o alert e aprire applicazioni.

# `uiopen`

Qualora fosse necessario avviare un'applicazione, su un **device jailbroken**, senza usare frida è possibile farlo con [`uiopen`](https://github.com/ProcursusTeam/uikittools-ng/blob/main/uiopen.m)
```shell
# to open Session app with its name
uiopen -a Session
# to open Session app with bundleID
uiopen -b com.loki-project.loki-messenger
```
