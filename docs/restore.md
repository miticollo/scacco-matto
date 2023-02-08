# Update + Restore

In questo capitolo utilizzeremo [futurerestore](https://github.com/futurerestore/futurerestore) per eseguire il restore dell'iPhone.
Questo strumento permette di passare a una versione di iOS non più firmata: ovvero per cui non è più possibile recuperare i blob SHSH, che quindi saranno forniti dall'utente.
La versione che andremo a installare è la 15.7.1.

> :warning: Per effettuare questa operazione è necessario possedere i blob SHSH per la versione di iOS 15.7.1 (build 19H117).

L'utente che avesse già installato questa versione può tralasciare i comandi proposti concentrandosi solo sugli aspetti teorici trattati.

## L'hardware che conta

Per comprendere meglio i prossimi paragrafi è necessario acquisire un po' di terminologia sull'hardware che troviamo all'interno di un iPhone.
In [Figura](https://help.apple.com/pdf/security/it_IT/apple-platform-security-guide-t.pdf#page=11) viene presentato un generico system on a chip (SoC).<br/>
<p align="center">
  <img src="./images/soc.png?raw=true" height=50% width=50% alt="SoC internals">
</p>

A livello commerciale questo componente viene chiamato Axx, dove al posto di "xx" si specifica un numero.
In particolare per tutte le mie sperimentazioni ho sempre usato un iPhone X (aka 10,6) con [A11 (aka T8015)](https://www.theiphonewiki.com/w/index.php?title=T8015&oldid=76706).
Lo stesso SoC è presente sull'iPhone 8 messomi a disposizione dall'università.

Non tratteremo tutti i componenti presentati in figura, ma ci concentreremo soprattutto sull'Application Processor (AP), la NAND e l'AES engine.
L'AP è il processore del nostro iPhone, mentre l'unità di archiviazione è realizzata con [porte NAND](https://www.theiphonewiki.com/w/index.php?title=NAND&oldid=98679), la cui capacità cambia in base alle esigenze e disponibilità economiche dell'utente da 4 GiB a 1 TiB.
Tuttavia se l'utente avesse bisogno di maggiore spazio di archiviazione, può decidere di [sostituire in autonomia la sola NAND](https://twitter.com/lipilipsi/status/1610275491537375237).
Nei modelli di iPhone precedenti al 4 era presente una NOR su cui risiedeva iBoot (il bootloader), mentre oggi non è più presente questo componente.
Pertanto iBoot si trova in `/dev/disk1`, come vedremo in seguito.

Infine notiamo che l'AES engine è un componente separato dall'AP, questo per una questione di sicurezza che tratteremo più avanti.

## Trusted boot chain

Prima di passare alla pratica è necessario capire come avviene l'avvio di iOS: da quando premiamo il tasto di accensione fino alla schermata di blocco.
![ibootchain](./images/ibootchain.png?raw=true "The traditional boot chain of *OS")<br/>
Da un primo sguardo della [Figura](http://newosxbook.com/bonus/iboot.pdf#page=1) notiamo, che i passaggi tra i vari componenti di avvio formano una catena.
Inoltre, come discuteremo tra breve, ogni passo verifica che quello successivo sia firmato digitalmente da Apple.
Per questi motivi viene chiamata _trusted boot chain_.

Iniziamo con il considerare un avvio normale, che comincia con la pressione del side button.
Il primo codice che l'AP eseguirà è il [SecureROM](https://papers.put.as/papers/ios/2019/LucaPOC.pdf#page=7), esso non è nient'altro che una versione essenziale e semplificata di iBoot.
Ciò che accade successivamente dipende dall'AP (frecce verdi in figura):
- sui device con A10+ viene mandato in esecuzione iBoot;
- mentre sui device meno recenti (A9 o inferiore) viene eseguito [Low Level Bootloader (LLB)](https://www.theiphonewiki.com/w/index.php?title=LLB&oldid=67906).

Adesso proviamo a rintracciare queste immagini all'interno del firmware.
Estraiamo l'IPSW, contenuto nella nostra working directory, con il comando `unzip`: infatti esso non è nient'altro che un archivio ZIP
```shell
unzip ./iPhone10,3,iPhone10,6_15.7.1_19H117_Restore.ipsw -d ipsw/
```
Al termine dell'estrazione, nella directory `ipsw` troviamo il file `BuildManifest.plist`, che contiene nel nodo `BuildIdentities` le configurazioni per i vari device supportati dall'IPSW.
Ad esempio, l'iPhone X ha due identificatori diversi [iPhone10,3](https://ipsw.me/iPhone10,3/info) e [iPhone10,6](https://ipsw.me/iPhone10,6/info), quindi abbiamo due configurazioni che raddoppiano perché dobbiamo considerare la stringa `Variant` all'interno del nodo `Info`, che assume i valori `Customer Erase Install (IPSW)` e `Customer Upgrade Install (IPSW)`. <br/>
Non procederemo oltre con l'analisi di questo file, useremo lo script Python in `tools/parser.py` per ottenere i percorsi dei file che ci interessano.
Lo script fa uso di una built-in library di Python chiamata [plistlib](https://docs.python.org/3/library/plistlib.html) risultando semplice, ma grezzo per questo in un progetto sarebbe meglio usare la libreria [pybmtool](https://github.com/Cryptiiiic/BMTool), che a sua volta usa la libreria di Python.
Per prendere confidenza con gli argomenti richiesti dallo script, eseguiamolo una volta senza di essi
```shell
python ../tools/parser.py
```
scopriamo che richiede in input 3 argomenti:
- `<manifest>` il percorso del file `BuildManifest.plist`,
- `<BDID>` il [Board ID](https://www.theiphonewiki.com/w/index.php?title=BORD&oldid=125531) del device e
- `<CPID>` il [Chip ID](https://www.theiphonewiki.com/w/index.php?title=CHIP&oldid=125390) del device.

Per ricavare questi ultimi due argomenti possiamo utilizzare il tool [`irecovery`](https://github.com/libimobiledevice/libirecovery/blob/master/tools/irecovery.c), che useremo con l'iPhone in DFU mode.
Per poter entrare correttamente in questa modalità dovremo **collegare l'iPhone al PC** e premere una combinazione di tasti: nel caso del modello X basta seguire [questi passaggi](https://www.theiphonewiki.com/w/index.php?title=DFU_Mode&oldid=125882#A11_and_newer_devices_.28iPhone_8_and_above.2C_iPad_Pro_2018.2C_iPad_Air_2019.2C_iPad_Mini_2019.29).
Può capire che l'utente inesperto non riesca a mettere l'iPhone in DFU al primo tentativo.
Se ciò dovesse accadere basta riprovare.

<!-- https://discord.com/channels/779134930265309195/779151007488933889/1069257586018369546 -->
> :information_source: Con AP A14+ o superiore il cavo non è più necessario.