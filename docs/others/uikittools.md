# uikittools-ng

uikittools è un pacchetto che contiene diversi CLI tool per eseguire screenshot, creare notifiche o alert e aprire applicazioni.
Insomma permette di fare quello che si fa con [Zenity](https://en.wikipedia.org/w/index.php?title=Zenity&oldid=1140898488) negli shell e batch script.

## `uiopen`

Qualora fosse necessario avviare un'applicazione, su un **device jailbroken**, senza usare frida è possibile farlo con [`uiopen`](https://github.com/ProcursusTeam/uikittools-ng/blob/main/uiopen.m)
```shell
# to open Session app with its name
uiopen -a Session
# to open Session app with its bundleID
uiopen -b com.loki-project.loki-messenger
```

### Lanciare un'app con iOS stock da macOS/Linux

1. Dopo aver montato la Developer Disk Image
   ```shell
   pymobiledevice3 mounter mount -v 16.3.1/DeveloperDiskImage.dmg 16.3.1/DeveloperDiskImage.dmg.signature
   ```
2. Lanciamo l'app Session (specificandone il bundleID)
   ```shell
   pymobiledevice3 developer dvt launch -v com.loki-project.loki-messenger
   ```
3. Terminiamola usando il suo nome
   ```shell
   pymobiledevice3 developer dvt pkill -v 'Session'
   ```
   Quest'ultimo comando può essere usato anche per terminare l'applicazione anche se questa è stata avviata da frida: `frida -U -f com.loki-project.loki-messenger`.

### frida in jailed mode

Lo spawning di un'app può essere fatto da frida anche in [jailed mode](https://frida.re/docs/ios/#without-jailbreak), ovvero senza la necessità di un dispositivo jailbroken.
Tuttavia l'app target deve essere debuggable ovvero deve presentare tra gli [entitlement](https://developer.apple.com/documentation/bundleresources/entitlements) [`get-task-allow`](https://stackoverflow.com/a/1026472).
Quest'ultimo permette agli altri processi di eseguire l'attach sull'app. 
In particolare all'interno della Developer Disk Image è contenuto il debugger (`/Developer/usr/bin/debugserver`) usato anche da Xcode per effettuare il debugging remoto dell'app.
<span><!-- https://t.me/fridadotre/85357 --></span>
<span><!-- https://t.me/fridadotre/42430 --></span>
Frida sfrutta `debugserver` per poter avviare l'app e [mappare `frida-gadget.dylib` nella memoria](https://github.com/frida/frida-core/blob/master/src/fruity/injector.vala) utilizzando il [protocollo LLDB](https://github.com/frida/frida-core/blob/master/src/fruity/lldb.vala) (che non è nient'altro che il protocollo GDB con estensioni).

Proviamo a lanciare l'app Session, scaricata dall'App Store, utilizzando [`idevicedebug`](https://github.com/libimobiledevice/libimobiledevice/blob/master/tools/idevicedebug.c), proprio come farebbe frida su un iOS unjailbroken
```shell
../tools/libimobiledevice/tools/idevicedebug -d --detach run com.loki-project.loki-messenger
```
ci accorgiamo subito che l'applicazione non si avvia e sul terminale è comparso un messaggio di errore: `ERROR: failed to get the task for process <ID>`.
Questo perché l'applicazione non presenta tra gli entitlement `get-task-allow` e lo possiamo verificare nel seguente modo
```shell
# on jailbroken iPhone
ldid -e /private/var/containers/Bundle/Application/106B02D0-186E-47D3-8F9F-824467B5C0C7/Session.app/Session | grep 'get-task-allow'
```
Tuttavia se eseguiamo lo stesso test per l'applicazione [blank app](https://github.com/miticollo/blank-app), otteniamo un risultato diverso dal precedente comando.
Ovviamente l'app in questione è stata compilata per eseguirne il debugging, mentre un'app proveniente dall'App Store è in produzione, quindi essa non deve essere lanciata da un debugger per tanto l'entitlement non può essere presente.

Quindi come possiamo aggiungerlo? Beh, abbiamo due soluzioni:
- usando `ldid -M -S[file.xml]`, oppure
- includendo `frida-gadget.dylib` durante il sideloadling dell'app con [Sideloadly](https://sideloadly.io/).

Entrambe le soluzioni richiedono di decriptare l'app e firmare nuovamente (con `codesign`) il bundle con il proprio certificato da sviluppatore.
La prima operazione richiede di rimuovere il Digital Rights Management (DRM) aggiunto alle app dello Store che la Apple ha battezzato [FairPlay](https://segmentfault.com/a/1190000041023774/en).
Cercando online si trovano molte soluzioni a questo problema, ma tutte potrebbero portare alla stessa conseguenza: l'impossibilità di eseguire correttamente l'applicazione (vedi [Telegram VS Spotify](https://drive.google.com/file/d/1iBnWAuelz0y0Il3mihyFDoyd_7D9-p7x/view)).
Alcune app, le più famose, sono state corrette caricando un'apposita `.dylib`: un esempio è [IGSideloadFix](https://github.com/opa334/IGSideloadFix) realizzata da [opa334](https://twitter.com/opa334dev), ovviamente per Instagram.
A ogni modo non esiste una soluzione universale e questo porta ad abbandonare ogni speranza riguardo l'uso di un device unjailbroken per AnForA.<br/>
Mentre `codesign` è necessario perché il Mach-O file dell'applicazione è stato alterato da `ldid` per inserirci `get-task-allow`.

## [`uinotify`](https://github.com/ProcursusTeam/uikittools-ng/blob/main/uinotify.m)

Questo comando, come suggerisce il nome, permette di creare una notifica per una data app
```shell
uinotify -b 'And the crocodile?' -i com.loki-project.loki-messenger -s '...moo' 'The cow says...'
```
![session](../images/uinotify/session.jpeg?raw=true "A notice from Session")<br/>
Possiamo decidere di non aver nessun icona
```shell
uinotify -b 'And the crocodile?' -i com.apple.donotdisturb -s '...moo' 'The cow says...'
```
![empty](../images/uinotify/empty.jpg?raw=true "An empty notice")<br/>
Oppure avere la classica icona di warning
```shell
uinotify -b 'And the crocodile?' -i com.apple.cmas -s '...moo' 'The cow says...'
```
![warning](../images/uinotify/warning.jpg?raw=true "A warning notice")

## [`uialert`](https://github.com/ProcursusTeam/uikittools-ng/blob/main/uialert.m)

Permette di creare un alert box. Vediamone due esempi.
```shell
uialert -b 'The cow says...' -p 'moo' -s 'woof' -t 'meoh' 'AnForA'
```
![buttons](../images/uialert/3-buttons.jpg?raw=true "An box with 3 buttons")
```shell
uialert  --secure 'Your password' 'AnForA'
```
![password](../images/uialert/password.jpg?raw=true "An alert to enter a secret like a password")<br/>
Altre opzioni sono disponibili come ad esempio `--timeout`, che permette di chiudere l'alert dopo il numero di secondi impostato.