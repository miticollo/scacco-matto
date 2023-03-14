# Update + Restore

In questo README utilizzeremo [futurerestore](https://github.com/futurerestore/futurerestore) per eseguire il restore dell'iPhone.
Questo strumento permette di passare a una versione di iOS non più firmata: ovvero per cui non è più possibile recuperare i blob SHSH, che quindi saranno forniti dall'utente.
La versione che andremo a installare è la 15.7.1.

<span><!-- https://twitter.com/diegohaz/status/1527642881384759297 --></span>
<span><!-- https://github.com/community/community/discussions/16925#discussioncomment-3459263 --></span>
<span><!-- https://github.com/Mqxx/GitHub-Markdown --></span>
> **Warning**</br>
> Per effettuare questa operazione è necessario possedere i blob SHSH per la versione di iOS 15.7.1 (build 19H117).

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

Non tratterò tutti i componenti presentati in figura, ma mi concentrerò soprattutto sull'Application Processor (AP), la NAND e l'AES engine.
L'AP è il processore del nostro iPhone, mentre l'unità di archiviazione è realizzata con [porte NAND](https://www.theiphonewiki.com/w/index.php?title=NAND&oldid=98679), la cui capacità cambia in base alle esigenze e disponibilità economiche dell'utente da 4 GiB a 1 TiB.
Tuttavia se l'utente avesse bisogno di maggiore spazio di archiviazione, può decidere di [sostituire in autonomia la sola NAND](https://twitter.com/lipilipsi/status/1610275491537375237).
Nei modelli di iPhone precedenti al 4 era presente una NOR su cui risiedeva iBoot (il bootloader), mentre oggi non è più presente questo componente.
Pertanto iBoot si trova in `/dev/disk1` (o `/dev/disk2`), come vedremo in seguito.

Infine notiamo che l'AES engine è un componente separato dall'AP, questo per una questione di sicurezza che tratterò più avanti.

## Trusted boot chain

Prima di passare alla pratica è necessario capire come avviene l'avvio di iOS: da quando premiamo il tasto di accensione fino alla schermata di blocco.
![ibootchain](./images/ibootchain.png?raw=true "The traditional boot chain of *OS")<br/>
Da un primo sguardo della [Figura](http://newosxbook.com/bonus/iboot.pdf#page=1) notiamo, che i passaggi tra i vari componenti di avvio formano una catena.
Inoltre, come discuterò tra breve, ogni passo verifica che quello successivo sia firmato digitalmente da Apple.
Per questi motivi viene chiamata _trusted boot chain_.

Iniziamo con il considerare un avvio normale, che comincia con la pressione del side button.
<span><!-- https://discord.com/channels/779134930265309195/791490631804518451/1076006380487594144 --></span>
Il primo codice che l'AP eseguirà è il [SecureROM](https://papers.put.as/papers/ios/2019/LucaPOC.pdf#page=7), esso non è nient'altro che una versione essenziale e semplificata di iBoot (circa il 15%).
Ciò che accade successivamente dipende dall'AP (frecce verdi in figura):
- sui device con A10+ viene mandato in esecuzione iBoot;
- mentre sui device meno recenti (A9 o inferiore) viene eseguito [Low Level Bootloader (LLB)](https://www.theiphonewiki.com/w/index.php?title=LLB&oldid=67906).

In entrambi i percorsi troviamo che iBoot si occupa di saltare (boot trampoline) al kernel, che a volte viene chiamato kernelcache o [XNU](https://github.com/apple-oss-distributions/xnu).

### IPSW

Adesso proviamo a rintracciare iBoot e LLB all'interno del firmware.
Estraiamo l'IPSW, contenuto nella nostra working directory, con il comando `unzip`: infatti esso non è nient'altro che un archivio ZIP
```shell
unzip ./iPhone10,3,iPhone10,6_15.7.1_19H117_Restore.ipsw -d ipsw/orig
```
Al termine dell'estrazione, nella directory `ipsw/orig` troviamo il file `BuildManifest.plist`, che contiene nel nodo `BuildIdentities` le configurazioni per i vari device supportati dall'IPSW.
Ad esempio, l'iPhone X ha due identificatori diversi [iPhone10,3](https://ipsw.me/iPhone10,3/info) e [iPhone10,6](https://ipsw.me/iPhone10,6/info), quindi abbiamo due configurazioni che raddoppiano perché dobbiamo considerare la stringa `Variant` all'interno del nodo `Info`, che assume i valori `Customer Erase Install (IPSW)` e `Customer Upgrade Install (IPSW)`. <br/>
Non procederemo oltre con l'analisi di questo file, useremo lo script Python in `tools/parser.py` per ottenere i percorsi dei file che ci interessano.
Lo script fa uso di una built-in library di Python chiamata [plistlib](https://docs.python.org/3/library/plistlib.html) risultando semplice, ma grezzo per questo in un progetto sarebbe meglio usare la libreria [pybmtool](https://github.com/Cryptiiiic/BMTool), che a sua volta usa la libreria nativa di Python.
Per prendere confidenza con gli argomenti richiesti dallo script, eseguiamolo una volta senza di essi
```shell
python ../tools/parser.py
```
scopriamo che richiede in input 3 argomenti:
- `<manifest>` il percorso del file `BuildManifest.plist`,
- `<BDID>` il [Board ID](https://www.theiphonewiki.com/w/index.php?title=BORD&oldid=125531) del device e
- `<CPID>` il [Chip ID](https://www.theiphonewiki.com/w/index.php?title=CHIP&oldid=125390) del device.

Per ricavare questi ultimi due argomenti possiamo utilizzare il tool [`irecovery`](https://github.com/libimobiledevice/libirecovery/blob/master/tools/irecovery.c), che eseguiremo con l'iPhone in DFU mode.
Per poter entrare correttamente in questa modalità dovremo **collegare l'iPhone al PC** e premere una combinazione di tasti: nel caso del modello X basta seguire [questi passaggi](https://www.theiphonewiki.com/w/index.php?title=DFU_Mode&oldid=125882#A11_and_newer_devices_.28iPhone_8_and_above.2C_iPad_Pro_2018.2C_iPad_Air_2019.2C_iPad_Mini_2019.29).
Può capire che l'utente inesperto non riesca a mettere l'iPhone in DFU al primo tentativo.
Se ciò dovesse accadere basta riprovare.

<span><!-- https://discord.com/channels/779134930265309195/779151007488933889/1069257586018369546 --></span>
> **Note**</br>
> Con AP A14+ o superiore il cavo non è più necessario.
<span><!-- TODO: la DFU può essere automatizzata, ma non ho capito come: https://discord.com/channels/779134930265309195/791490631804518451/1070241399984902225 --></span>

1. Verifichiamo che il dispositivo sia effettivamente in DFU mode
   ```shell
    ../tools/libirecovery/tools/irecovery -m 
   ```
2. Ricaviamo il `<BDID>` e il `<CPID>`
   ```shell
    ../tools/libirecovery/tools/irecovery -q | grep -E 'BDID|CPID'
   ```
3. Ora possiamo eseguire `parser.py`
   ```shell
    python ../tools/parser.py ./ipsw/orig/BuildManifest.plist '0x0e' '0x8015'
   ```
   otteniamo il seguente output
   ```text
   iBSS:                  Firmware/dfu/iBSS.d22.RELEASE.im4p
   iBEC:                  Firmware/dfu/iBEC.d22.RELEASE.im4p
   iBoot:                 Firmware/all_flash/iBoot.d22.RELEASE.im4p
   KernelCache:           kernelcache.release.iphone10b
   LLB:                   Firmware/all_flash/LLB.d22.RELEASE.im4p
   RestoreRamDisk:        098-03675-020.dmg
   Root Filesystem (OS):  098-04055-020.dmg
   Touch firmware:        Firmware/D221_Multitouch.im4p
   SEP firmware:          Firmware/all_flash/sep-firmware.d221.RELEASE.im4p
   Device tree:           Firmware/all_flash/DeviceTree.d221ap.im4p
   Apple logo:            Firmware/all_flash/applelogo@3x~iphone.im4p
   Static trust cache:    Firmware/098-04055-020.dmg.trustcache
   ```
   <span><!-- https://discord.com/channels/842189018523631658/917198974555942942/1071059805327859792 --></span>
   > **Note**</br>
   > In quest'ultimo passaggio avremmo potuto anche scaricare direttamente da Internet il `BuildManifest.plist`.
   > Per far ciò basta sostituire `iPhone10,3,iPhone10,6_15.7.1_19H117_Restore.ipsw` con `BuildManifest.plist` nell'URL che permette di scaricare il firmware:
   > ```shell
   > curl -o '/tmp/BuildManifest.plist' -L https://updates.cdn-apple.com/2022FallFCS/fullrestores/012-95442/E99DEEC6-9763-45EF-B2FF-0BA51A1E966B/BuildManifest.plist
   > python ../tools/parser.py /tmp/BuildManifest.plist '0x0e' '0x8015'
   > ```
   > Se volessimo potremmo **selezionare** e scaricare anche i componenti del firmware direttamente da Internet senza aver bisogno di effettuare il download dell'intero IPSW, risparmiando banda, tempo e spazio.
   > Vedremo come fare ciò in un prossimo paragrafo, per ora mi limiterò a dire che utilizzeremo un interessante utility: [`pzb`](https://github.com/tihmstar/partialZipBrowser).

Dall'output del comando precedente notiamo che i file hanno estensione [`.im4p`](https://www.theiphonewiki.com/w/index.php?title=IMG4_File_Format&oldid=122062#IMG4_Payload) e [`.dmg`](https://en.wikipedia.org/w/index.php?title=Apple_Disk_Image&oldid=1098452713).

#### IMG4 file = Payload (IM4P) + Manifest (IM4M)

Per ora concentriamoci solo sui payload degli IMG4.
Per semplicità considereremo solo l'iBSS, ma nulla vieta di usare l'iBEC o un altro componente che possiamo trovare all'interno del firmware.
Per prima cosa [decodifichiamolo con OpenSSL](https://twitter.com/nyan_satan/status/1404839407874682887)
```shell
openssl asn1parse -in ipsw/orig/Firmware/dfu/iBSS.d22.RELEASE.im4p -i -inform DER
```
e otterremmo (omettendo il **vero e proprio** binario)
<pre>
    0:d=0  hl=5 l=1094868 cons: SEQUENCE          
    5:d=1  hl=2 l=   4 prim:  IA5STRING         :IM4P
   11:d=1  hl=2 l=   4 prim:  IA5STRING         :ibss
   17:d=1  hl=2 l=  17 prim:  IA5STRING         :iBoot-7459.140.15
   36:d=1  hl=5 l=1094704 prim:  OCTET STRING      [HEX DUMP]: <i>omesso</i>
1094745:d=1  hl=2 l= 116 prim:  OCTET STRING      [HEX DUMP]:30723037020101041062A3C90D8B8A62837D48E8E68B35138C0420BDA4B5C481822D18AF9DA996DA1699497C5FE7E717D6FD030003B88464846D4230370201020410E74241869155243951E6308B15B19F4B0420BA3F6062D0F7D48F953D6CAD56F9D8D133080E848F5D539EA3F4F37839D7C2F5
1094863:d=1  hl=2 l=   8 cons:  SEQUENCE          
1094865:d=2  hl=2 l=   1 prim:   INTEGER           :01
1094868:d=2  hl=2 l=   3 prim:   INTEGER           :161620
</pre>

Per capire l'output mostrato conviene esaminare il comando che lo ha prodotto: `asn1parse` della utility `openssl`.
Tralasciamo l'opzione `-in` che banalmente permette di specificare il file di input e concentriamoci sulle restanti.
`-inform DER` indica che il file `iBSS.d22.RELEASE.im4p` usa la codifica Distinguished Encoding Rules (DER) mentre `-i` permette di indentare l'output prodotto.
Quest'ultimo non è nient'altro che il risultato del parsing delle strutture [Abstract Syntax Notation One (ASN.1)](https://letsencrypt.org/docs/a-warm-welcome-to-asn1-and-der/). <br/>
Il linguaggio ASN.1 permette di descrivere strutture dati in maniera indipendente dal linguaggio di programmazione usato per trattarli.
Possiamo paragonare l'[ASN.1 a un JSON schema](https://stackoverflow.com/a/14407935): la differenza principale con quest'ultimo sta nel fatto che il JSON è **sempre codificato in human-readable plain text** con una sintassi ben definita che ne permette di individuare gli oggetti rappresentati, mentre l'ANS.1 può anche essere codificato in un formato binario.
In particolare DER è una codifica type-length-value (TLV) che garantisce una codifica univoca per i valori ASN.1 utilizzando la minor quantità di byte necessari.
Una possibile definizione ASN.1 usata per il formato IMG4 può essere trovata [qui](https://raw.githubusercontent.com/galli-leo/emmutaler/master/docs/thesis.pdf#page=62). <br/>
Non si conoscono le ragioni per cui Apple ha scelto questo formato rispetto al classico `.plist`.
Ad ogni modo l'ASN.1 fu adottato per la rappresentazione dei certificati (1988), prima dell'avvento del [JSON](https://www.rfc-editor.org/rfc/rfc4627), e visto che i certificati vengo usati per garantire l'autenticità anche la Apple avrà deciso di adottare la stessa notazione e codifica per garantire l'affidabilità della boot chain.

Tornando all'output di prima, notiamo che abbiamo due valori di tipo `OCTET STRING`, che un è built-in type in ASN.1.
Il primo, che è stato omesso perché troppo lungo, come abbiamo già detto contiene un payload: il binario di iBSS.
Per verificarlo possiamo provare a estrarlo con [PyIMG4](https://github.com/m1stadev/PyIMG4), che è un tool in Python, ma che può anche essere importato nel proprio progetto per usarlo come libreria
```shell
pyimg4 im4p extract -i ipsw/orig/Firmware/dfu/iBSS.d22.RELEASE.im4p -o ipsw/decrypted/ibss.enc --no-decompress
```
Ora usando il tool `xxd` produciamo un one line hexdump dell'output di PyIMG4
<span><!-- https://unix.stackexchange.com/a/706374 --></span>
<span><!-- https://stackoverflow.com/a/31553497 --></span>
```shell
xxd -u -p -c0 ./ipsw/decrypted/ibss.enc
```
Se confrontiamo l'output di questo comando con il valore dell'`OCTET STRING` precedente ci rendiamo conto che sono uguali.
Tuttavia `./ipsw/decrypted/ibss.enc` non è il vero e proprio binario: infatti PyIMG4 riporta `payload data is LZFSE_ENCRYPTED compressed`.
In particolare ci sta dicendo che il payload estratto prima è criptato e compresso con [LZFSE](https://en.wikipedia.org/w/index.php?title=LZFSE&oldid=1132724077).
Avremo potuto scoprire la stessa cosa usando il sotto-comando `info` di `pyimg4 im4p`
```shell
pyimg4 im4p info -vvv -i ipsw/orig/Firmware/dfu/iBSS.d22.RELEASE.im4p
```
oppure osservando che [dopo il primo `OCTET STRING` ne è presente un secondo](https://github.com/m1stadev/PyIMG4/blob/02a770e0e46842ffbeecea44b521ddeb9af93726/pyimg4/_parser.py#L826-L827), che di seguito è stato suddiviso per mettere in evidenza le chiavi e gli IV.
```text
307230370201010410
                  62A3C90D8B8A62837D48E8E68B35138C (IV for PRODUCTION)
                                                  0420
                                                      BDA4B5C481822D18AF9DA996DA1699497C5FE7E717D6FD030003B88464846D42 (key for PRODUCTION)
                                                                                                                      30370201020410
                                                                                                                                    E74241869155243951E6308B15B19F4B (IV for DEV)
                                                                                                                                                                    0420
                                                                                                                                                                         BA3F6062D0F7D48F953D6CAD56F9D8D133080E848F5D539EA3F4F37839D7C2F5 (key for DEV)
```
Quindi non ci rimane che decriptare e decomprimere `ibss.enc`, per far ciò dobbiamo sapere [quale algoritmo di cifratura è usato](https://github.com/m1stadev/PyIMG4/blob/02a770e0e46842ffbeecea44b521ddeb9af93726/pyimg4/_parser.py#L1287): [Advanced Encryption Standard (AES)](https://en.wikipedia.org/w/index.php?title=Advanced_Encryption_Standard&oldid=1138366480) con modalità [Cipher block chaining (CBC)](https://en.wikipedia.org/w/index.php?title=Block_cipher_mode_of_operation&oldid=1132330761#CBC) e chiave da 256 bit.
Ora che sappiamo quale algoritmo viene usato dobbiamo trovare i suoi parametri, che nel caso di AES sono due: l'[Initialization Vector (IV)](https://en.wikipedia.org/w/index.php?title=Initialization_vector&oldid=1136156102) e la chiave.
> **Warning**</br>
> Non facciamoci ingannare dall'output di `pyimg4 im4p info`.
> È vero che esso ci stampa un keybag di produzione ([ricavato dal secondo `OCTET STRING`](https://github.com/m1stadev/PyIMG4/blob/02a770e0e46842ffbeecea44b521ddeb9af93726/pyimg4/_parser.py#L829-L841)) contenente l'IV e la chiave, ma questi non possono essere usati perché **cifrati** con la [GID0 key](#gid0-key), che discuteremo nel prossimo paragrafo.

Per trovare l'IV e la chiave per **decifrare l'iBSS di questo IPSW** possiamo usare la [pagina di the iPhone Wiki](https://www.theiphonewiki.com/w/index.php?title=Firmware_Keys#Firmware_Versions) e più precisamente [quella che interessa a noi](https://www.theiphonewiki.com/wiki/SkySecuritySydneyB_19H117_(iPhone10,6)#iBSS).
> **Note**</br>
> Qualora si volesse automatizzare questa operazione è possibile usare questo [script Python](https://github.com/Cryptiiiic/ios-tools/blob/master/wiki-proxy.py).

Una volta recuperato l'IV e la chiave possiamo usare OpenSSL
```shell
openssl enc -aes-256-cbc -nopad -d -in ipsw/decrypted/ibss.enc -K '814134782438f75f9ccced43fff5fb0e51a8baf38f591accb88e92fb2c1be7c0' -iv 'd31e54acb4badb8af5cc327b28cb9276' -out ipsw/decrypted/ibss.lzfse -p -v
```
Verifichiamo che l'output di OpenSSL sia compresso in LZFSE
```shell
file ipsw/decrypted/ibss.lzfse
```
Per tanto non ci resta che decomprimere `ibss.lzfse`
```shell
lzfse -decode -i ipsw/decrypted/ibss.lzfse -o ipsw/decrypted/ibss.raw -v
```
> **Note**<br>
> Qualora non si avesse installato il comando `lzfse` basta eseguire `brew install lzfse`, che richiede [Homebrew](https://brew.sh/).

Si noti che avremmo potuto semplicemente decifrare e decomprimere `iBSS.d22.RELEASE.im4p` in un solo passaggio con PyIMG4
```shell
pyimg4 im4p extract -i ipsw/orig/Firmware/dfu/iBSS.d22.RELEASE.im4p -o ipsw/decrypted/ibss.raw --iv d31e54acb4badb8af5cc327b28cb9276 --key 814134782438f75f9ccced43fff5fb0e51a8baf38f591accb88e92fb2c1be7c0
```

Ora decriptiamo e decomprimiamo anche iBEC, iBoot e LLB
```shell
pyimg4 im4p extract -i ipsw/orig/Firmware/dfu/iBEC.d22.RELEASE.im4p -o ipsw/decrypted/ibec.raw --iv 2288b60aba82f1139384b6fc1a1f7ce4 --key dde8a6d5b5b4332d5839da7d94d8f0547cdc3e14fc080e5e8f8823791d0f40e8
pyimg4 im4p extract -i ipsw/orig/Firmware/all_flash/iBoot.d22.RELEASE.im4p -o ipsw/decrypted/iboot.raw --iv fcd7a26f0b0527fd588c0ff34d869842 --key 8dc6735a5efbc0447522c18c1948528250cb15390936c57cbb1adcddf09fec2f
pyimg4 im4p extract -i ipsw/orig/Firmware/all_flash/LLB.d22.RELEASE.im4p -o ipsw/decrypted/llb.raw --iv ed29461163fe6ad946182779e0ae12f1 --key 7612dff248c4fa5015cb08a787ef5c5ad5ab6fc70b35027429daf670bd6e0688
```
E confrontiamo iBSS, iBEC, iBoot e LLB
<span><!-- https://unix.stackexchange.com/a/33687 --></span>
```shell
diff -q --from-file ipsw/decrypted/*.raw
```
Sorprendente, tutti i file sono uguali!
<span><!-- https://discord.com/channels/779134930265309195/779134930265309198/875676924721119233 --></span>
La Apple con gli AP A10+ ha deciso di usare un single-stage iBoot, ovvero il SecureROM, iBoot, iBEC, LLB e iBSS condivido un codice sorgente comune.
<span><!-- https://discord.com/channels/779134930265309195/779151007488933889/1078421177430720692 --></span>
Nei modelli precedenti non si poteva fare per [limiti della SRAM](http://newosxbook.com/bonus/iboot.pdf#page=2) oppure la porzione che gli veniva riservata dalla SecureROM nella SRAM non era sufficiente, quindi era necessario che LLB caricasse iBoot nella DRAM.
Quindi di fatto non sono più necessari 4 file distinti, ma tuttavia sono ancora presenti nell'IPSW, perché?
<span><!-- https://discord.com/channels/779134930265309195/779134930265309198/875678703672246332 --></span>
Probabilmente per mantenere una compatibilità con i software di restore.<br>
<span><!-- https://discord.com/channels/779134930265309195/779151007488933889/986400776861671424 --></span>
Quindi come fa il device a comportarsi correttamente?
Beh, basandosi sull'[IM4P tag (o TYPE)](https://www.theiphonewiki.com/w/index.php?title=TYPE&oldid=123816): ve ne sono molti, ma ne citerò solo alcuni.
Per determinare quale tag viene usato da un dato payload possiamo usare sia `pyimg4 im4p info` sia `openssl asn1parse`, ad esempio il tag di iBoot è `ibot` mentre quello di iBSS è `ibss`.
È importante ricordare che il tag è composto di soli 4 caratteri perché è rappresentato da un 32-bit unsigned integer (`uint32_t`).<br/>
In aggiunta a quanto detto prima per i modelli A9 o inferiori: se avessimo eseguito gli stessi passaggi avremmo osservato che LLB e iBSS sono uguali, come iBoot e iBEC; ancora una volta la distinzione ricade sugli IMG4 tag.

In ultimo vorrei tornare sul titolo con cui ho aperto questo paragrafo "IMG4 file = Payload (IM4P) + Manifest (IM4M)".
Esso ci dice che un IM4P fa parte di un file con estensione IMG4, che per ora non abbiamo incontrato, ma lo faremo più avanti.
Successivamente sarà presentato che cos'è un manifest, ovvero un file IM4M, per l'esattezza ne tratteremo quando parleremo del local boot.

Quello che abbiamo spiegato finora è una parte del local boot, ma non abbiamo ancora detto come la SecureROM trova iBoot, che come ho già accennato si trovato su `/dev/disk1` (o `/dev/disk2`).
Inoltre mostrerò anche come è fatto questo block device.

#### GID0 key

Ora supponiamo di voler decriptare l'iBSS di iOS 16.0.3.
Come prima cosa dobbiamo decrittare l'IV e la chiave del keybag di produzione restituitoci da `pyimg4 im4p info`.
Quindi colleghiamoci a the iPhone Wiki e cerchiamo la pagina per iOS 16.0.3 per iPhone10,6, ma [non la troviamo](https://www.theiphonewiki.com/w/index.php?title=Firmware_Keys/16.x&oldid=125807).
Cosa fare? Potremmo usare `gaster`.

Esso è un CLI tool che permette di sfruttare checkm8. 
Per ora ci basti sapere questo, ma lo approfondiremo più avanti.
Purtroppo questo tool non ha un manuale, perciò come primo approccio eseguiamolo senza argomenti
```shell
../tools/gaster/gaster
```
otterremo il seguente output
```text
usb_timeout: 5
usb_abort_timeout_min: 0
Usage: env ../tools/gaster/gaster options
env:
USB_TIMEOUT - USB timeout in ms
USB_ABORT_TIMEOUT_MIN - USB abort timeout minimum in ms
options:
reset - Reset DFU state
pwn - Put the device in pwned DFU mode
decrypt src dst - Decrypt file using GID0 AES key
decrypt_kbag kbag - Decrypt KBAG using GID0 AES key
```
Le opzioni che ci interessano sono due `decrypt` e `decrypt_kbag` entrambe richiedono che l'iPhone sia in DFU mode.
> **Note**<br>
> Testeremo entrambe le opzioni con iBSS proveniente da iOS 15.7.1, questo perché così il lettore potrà confrontare il keybag con quello usato precedentemente, che sappiamo essere corretto.

Iniziamo dall'opzione `decrypt`
```shell
../tools/gaster/gaster decrypt ipsw/orig/Firmware/dfu/iBSS.d22.RELEASE.im4p ipsw/decrypted/ibss.gaster
```
e confrontiamo il risultato con `ibss.raw`
```shell
cmp -l ipsw/decrypted/ibss.{raw,gaster}
```
Essi sono uguali! Quindi cosa [fa](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1601) `gaster decrypt`? 
Beh, in sostanza quello che abbiamo già fatto **manualmente** noi prima:
1. prima esegue l'[exploit per checkm8](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1231-L1276);
2. poi avviene la [fase di decrypt](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1562):
   1. crea [in memoria una rappresentazione dell'IM4P del file sorgente](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1407-L1411);
   2. estrae [IV e key dall'IM4P e li concatena in un keybag](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1391-L1405): `IV + key` (**l'ordine è importante!**);
   3. usa l'[AES engine per decriptare il keybag](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1495-L1555);
   4. usa il [keybag decriptato per decriptare il payload dell'IM4P](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1444) e
   5. infine [decomprime l'archivio LZFSE](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1449).

> **Note**<br>
> Quanto descritto vale anche per gli IMG4 e non solo per gli IM4P.

Tuttavia, come vedremo in seguito, `futurerestore` **può usare le pagine di the iPhone wiki** per ottenere l'IV e le chiavi, quindi esse devono essere presenti sulla wiki.
Perciò, come decriptare l'IV e la chiave con `gaster`?
1. Costruiamo il keybag concatenando semplicemente l'IV e la chiave (di produzione) restituiti dal comando `pyimg4 im4p info`
   ```shell
   pyimg4 im4p info -vvv -i ipsw/orig/Firmware/dfu/iBSS.d22.RELEASE.im4p | grep -A4 "Type: PRODUCTION" | awk '/IV:/{iv=$2}/Key:/{key=$2} END{print iv key}'
   ```
<!-- https://discord.com/channels/842189018523631658/842194992537141298/1028164327116652647 -->
<!-- https://discord.com/channels/842189018523631658/842194992537141298/1028165221405179945 -->
2. Decriptiamolo con `gaster decrypt_kbag`
   ```shell
   ../tools/gaster/gaster decrypt_kbag 62a3c90d8b8a62837d48e8e68b35138cbda4b5c481822d18af9da996da1699497c5fe7e717d6fd030003b88464846d42 | tail -1
   ```
3. Voilà!
   ```text
   IV: D31E54ACB4BADB8AF5CC327B28CB9276, key: 814134782438F75F9CCCED43FFF5FB0E51A8BAF38F591ACCB88E92FB2C1BE7C0 
   ```

Come ulteriore verifica possiamo usare [`pongoterm`](https://github.com/checkra1n/PongoOS/blob/master/scripts/pongoterm.c) per inviare comandi a [PongoOS](https://github.com/checkra1n/PongoOS/):
1. Decriptiamo l'IV sfruttando una variante dell'here doc: la [here-string](https://www.gnu.org/software/bash/manual/html_node/Redirections.html#Here-Strings)
   ```shell
   # repeat if output is blank
   ../tools/PongoOS/scripts/pongoterm <<< 'aes cbc dec 256 gid0 62a3c90d8b8a62837d48e8e68b35138c' 2> /dev/null | awk -F "> " '{print $2}' | head -1
   ```
2. Poi decriptiamo la chiave. Tuttavia per farlo correttamente dovremmo usare la keybag (IV + key) e poi rimuovere l'IV all'inizio
   ```shell
   ../tools/PongoOS/scripts/pongoterm <<< 'aes cbc dec 256 gid0 62a3c90d8b8a62837d48e8e68b35138cbda4b5c481822d18af9da996da1699497c5fe7e717d6fd030003b88464846d42' 2> /dev/null | awk -F "> " '{print $2}' | head -1 | cut -c 33-
   ```
3. Riavviamo il device
   ```shell
   ../tools/PongoOS/scripts/pongoterm <<< 'reset'
   ```
<span><!-- https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1567 usa un uint8_t per rappresentare 2 nibble: ognuno rappresenta una cifra HEX --></span>
Ora vogliamo fare la stessa cosa, ma usando `openssl` come abbiamo già fatto precedentemente.
Quindi ci aspettiamo di usare un comando del genere
```shell
echo -n '62a3c90d8b8a62837d48e8e68b35138cbda4b5c481822d18af9da996da1699497c5fe7e717d6fd030003b88464846d42' | openssl enc -aes-256-cbc -d -p -v -K # <?>
```
Tuttavia ci manca un ingrediente fondamentale: la chiave.
Osservando il comando `aes` usato in precedenza scopriamo che la chiave necessaria è chiamata AP [GID](https://www.theiphonewiki.com/w/index.php?title=GID_Key&oldid=117065)0, dove la possiamo trovare?
Nell'AES engine, la possiamo leggere?
In pratica si, ma è molto complicato.

Innanzitutto dobbiamo chiarire che noi chiediamo un "servizio" all'AES engine ovvero di decriptare qualcosa.
Esso, infatti, non ci fornisce **mai** la chiave, ma si fa carico lui di decifrare i dati che gli passiamo in input.
Quindi, avendo a disposizione un device vulnerabile a checkm8, possiamo inviare i comandi per richiedere di decriptare un dato payload.
Sottolineo che un device con AP A12+, non avendo un bootROM exploit pubblico conosciuto, non ha una procedura simile.
<span><!-- https://discord.com/channels/779134930265309195/791490631804518451/1073573995322028042 --></span>
Questo perché, anche con iOS in jailbroken state, non è possibile inviare comandi all'AES engine per usare la GID**0**: infatti essa viene disabilita al boot trampoline.
Quanto detto può essere verificato osservando la tabella per iPhone riportata nella pagina [Firmware Keys/15.x](https://www.theiphonewiki.com/w/index.php?title=Firmware_Keys/15.x&oldid=125705#iPhone) della wiki, in cui per tutte, o quasi, le versioni di iOS 15 per iPhone, vulnerabili a checkm8, sono disponibili le chiavi, mentre non lo sono per gli iPhone XR e successivi.
Tuttavia quanto detto non sembra corrispondere esattamente al vero: infatti in tabella sono presenti, in ben 2 occasioni, delle chiavi per iPhone con AP A12+, come è possibile?
<span><!-- https://discord.com/channels/779134930265309195/791490631804518451/1075876541940121680 --></span>
Beh, **una possibile spiegazione** potrebbe essere quello di aver usato [`astris`](https://www.theiphonewiki.com/w/index.php?title=Astris&oldid=119709) con un [cavo di debug](https://www.theiphonewiki.com/w/index.php?title=Serial_Wire_Debug&oldid=118686) su un iPhone prototipo, ovvero che ha ChiP Fuse Mode (CPFM) impostato a `0x00`.

Prima di concludere ci sono ancora 2 aspetti che vanno trattati: quali altre chiavi GID utilizza l'iPhone e quali attacchi possiamo sferrare per ottenere GID0.
<span><!-- https://discord.com/channels/779134930265309195/791490631804518451/940650824017780746 --></span>
Oltre a GID0 ci sono **almeno** altre 2 GID key: AP GID1 e SEP GID.
Per la prima non si conosce il suo scopo, ma è accessibile a XNU, dopo il boot trampoline; mentre la seconda è contenuta nel co-processore SEP ed è usata per [decriptare il SEP firmware](https://raw.githubusercontent.com/windknown/presentations/master/Attack_Secure_Boot_of_SEP.pdf#page=5).
<span><!-- https://discord.com/channels/779134930265309195/779139039365169175/1076539594910212166 --></span>
Tuttavia con il device a mia disposizione non è possibile effettuare questa operazione: infatti osservando l'help del comando `sep` (in PongoOS) si può notare che il sotto-comando [`decrypt`, come il suo analogo `encrypt`, richiede `pwned SEPROM`](https://github.com/checkra1n/PongoOS/blob/dab28e87566f6830faacb1323c0387a983a7131d/src/drivers/sep/sep.c#L1142-L1143).
<span><!-- https://github.com/futurerestore/futurerestore/issues/93#issuecomment-1235802769 --></span>
Questo significa che il dispositivo deve essere vulnerabile a [blackbird](https://www.theiphonewiki.com/w/index.php?title=Blackbird_Exploit&oldid=124810) ([la presentazione](https://raw.githubusercontent.com/windknown/presentations/master/Attack_Secure_Boot_of_SEP.pdf) mostra solo la vulnerabilità non l'exploit né la exploitation): un SEPROM exploit che sfrutta un bug della SEPROM degli AP A8, A9, A10 e A11.
<span><!-- https://discord.com/channels/779134930265309195/779151007488933889/1063891883207708774 --></span>
Attualmente comunque l'exploit (implementato **solo** in PongoOS) [non funziona correttamente sugli A11](https://raw.githubusercontent.com/windknown/presentations/master/Attack_Secure_Boot_of_SEP.pdf#page=37): infatti la ROM va in crash.<br/>
<span><!-- Perché avviene il crash? https://discord.com/channels/779134930265309195/779151007488933889/1063893379185901568, ma cos'è un integrity tree? --></span>
<span><!-- https://www.reddit.com/r/jailbreak/comments/76kdgb/comment/dof3b76/?utm_source=share&utm_medium=web2x&context=3 --></span>
Quindi, come il lettore avrà capito, il fatto che disponiamo di un bootROM exploit non significa che possiamo manipolare la SEPROM.
Più avanti incontreremo di nuovo blackbird e spiegherò a cosa serve SEP e cosa significa un JB senza la possibilità di sfruttare un SEPROM exploit.

Non rimane che accennare a un attacco per ottenere la GID0 key.
L'attacco in questione è argomento della [tesi magistrale](https://web.archive.org/web/20210514073023/https://www.seceng.ruhr-uni-bochum.de/media/attachments/files/2021/04/Master_thesis_Oleksiy_Lisovets.pdf) di [tihmstar](https://twitter.com/tihmstar/), ma è anche stato [presentato dallo stesso al Hardwear.io Netherlands 2022](https://youtu.be/s_cnjOCegs0) ([slides](https://raw.githubusercontent.com/tihmstar/gido_public/master/Using%20a%20magic%20wand%20to%20break%20the%20iPhone's%20last%20security%20barrier.pdf)).
tihmstar propone un attacco fisico chiamato Electro Magnetic (EM) side-channel attack: perché AES, per le proprietà matematiche di cui gode, è crittograficamente sicuro.
L'idea alla base è che l'AP eseguendo del codice consuma energia ed emette emissioni elettromagnetiche, entrambe queste grandezze fisiche dipendono da ciò che l'AP esegue nel momento della misura.
Per tanto è possibile sfruttare questa correlazione per ottenere informazioni utili come la GID0 key.
Anche se va tenuto in considerazione che un tale attacco si basa su misure provenienti dal mondo reale affette da errore e rumore, quindi serviranno metodi statistici per portarlo a termine.
Per poter misurare le emissioni elettromagnetiche è stato necessario smontare l'iPhone per esporre l'AP su cui è stata posizionata una sonda EM collegata a un amplificatore, che ha sua volta è stato collegato a un ([costoso](https://twitter.com/tihmstar/status/1586684619621122051)) oscilloscopio.<br/>
Per il progetto è stato usato un iPhone 4 anche se un dispositivo più moderno, come iPhone 8 o X, poteva essere impiegato l'importante è che sia vulnerabile a un bootROM exploit, che nel caso di iPhone 4 è [limera1n](https://www.theiphonewiki.com/w/index.php?title=Limera1n_Exploit&oldid=122780).
Questo perché l'attacco richiede di eseguire più e più volte `aes cbc dec 256 gid0` al fine di misurare le emissioni elettromagnetiche.
Inoltre essendo nel contesto del SecureROM solo un singolo core è in esecuzione, mentre gli altri sono inattivi.
Tale core esegue solo il codice del comando `aes` e non essendoci concorrenza e time-sharing è l'unico codice in esecuzione fino al completamento dell'operazione garantendo di fatto una riduzione del rumore, che impatta sulle misure.

Concludo facendo un'osservazione sulle pagine della wiki: abbiamo visto che tutti, sia noi utenti sia `futurerestore`, le consultano per ricercare l'IV e la chiave decriptate (se disponibili), il che significa che, fissata la versione di iOS, entrambi sono uguali per i dispositivi di una stessa famiglia.
Infatti la **Group** ID (GID) key è una chiave che tutti i dispositivi di una stessa famiglia (es. iPhone 10,6) condividono, al contrario della [**Unique** ID (UID) key](https://www.theiphonewiki.com/w/index.php?title=UID_key&oldid=121990), che invece è diversa per ogni dispositivo e non è nemmeno conosciuta da Apple.
Quest'ultima verrà ripresa quando parlerò del ripristino degli iPhone A12+: perché essa viene usata come mitigazione contro il downgrade di iOS.

### Debug cable

Nel paragrafo precedente ho lasciato un rimando alla wiki per un approfondimento su questo argomento, ma ci tengo fare alcune precisazioni.
Non tutti, ma la maggior parte di cavi di debug, sono illegali.
Possono essere acquistati all'interno del mercato nero e non come nuovi, ma usati.
Nel momento in cui si scrive gli unici cavi ritenuti legali sono 2:
<span><!-- https://discord.com/channels/349243932447604736/688124600269144162/792865141275492364 --></span>
- il [Bonobo](https://docs.bonoboswd.com/index.html), che è molto [costoso ed esaurito](https://shop.lambdaconcept.com/home/37-bonobo-debug-cable.html) dal 2021, e
- il [Tamarin](https://www.youtube.com/watch?v=7p_njRMqzrY), che è considerato, almeno da chi scrive, un valido candidato come debugging cable perché non è né molto costoso né difficile da procurarselo: infatti è un progetto [DIY](https://en.wikipedia.org/w/index.php?title=Do_it_yourself&oldid=1138671731).
  Attualmente la versione (quasi) funzionante del firmware è disponibile nel [fork](https://github.com/pinauten/tamarin-firmware) di [Linus Henze](https://twitter.com/LinusHenze) (creatore di Fugu`*`).
  Per essere realizzato si necessita di un [Raspberry Pico](https://www.raspberrypi.com/products/raspberry-pi-pico/) e un [connettore Apple Lightning maschio](https://elabbay.myshopify.com/products/apple-lm-bo-v1a-apple-lightning-male-connector-breakout-board?variant=30177591875).

Questi cavi permetto di sfruttare un interfaccia chiamata Serial Wire Debug (SWD), che combinata con il leaked tool `astris`, consente di eseguire un debug molto approfondito dell'iDevice.
Addirittura è possibile eseguire l'`halt` di una delle CPU presenti nell'AP e osservare il contenuto dei suoi registri fisici.
Visto che il sottoscritto non ha potuto mettere le mani su nessun dei cavi citati, si rimanda il lettore a [questo thread di Twitter](https://twitter.com/nyan_satan/status/1090989650280398849) per maggiori dettagli sull'argomento.
Inoltre qualora avessi disposto sia dei cavi sia del software mi sarei dovuto procurare anche un iPhone con CPFM `0x01` o `0x00`.
> **Note**</br>
> <span><!-- https://discord.com/channels/779134930265309195/779134930265309198/930283891623854081 --></span>
> Le fasi di produzione di un prodotto Apple sono 4:
> - Prototype
> <span><!-- https://discord.com/channels/779134930265309195/779134930265309198/930285128691880026 --></span>
> - Engineering Validation Test (EVT) con CPFM `0x00`
> <span><!-- https://discord.com/channels/779134930265309195/779134930265309198/930285165064888350 --></span>
> - Development Validation Test (DVT) con CPFM `0x01`
> <span><!-- https://discord.com/channels/779134930265309195/779134930265309198/930285185436626955 --></span>
> - Production Validation Test (PVT) con CPFM `0x03`
> <span><!-- https://discord.com/channels/779134930265309195/791490631804518451/1077364925804052551 --></span>
> <span><!-- https://discord.com/channels/779134930265309195/779134930265309198/930285185436626955 --></span>
> - Mainline Production (MP) con CPFM `0x03` e in cui il SWD engine è disabilitato
> 
> in cui CPFM significa
> - `0x00`: AP insecure SEP insecure,
> - `0x01`: Secure mode,
> - `0x02`: Production mode e
> - `0x03 = 0x02 + 0x01`.

Non è strettamente necessario procurarsi un iPhone con un CPFM inferiore al `0x01`: se si dispone di un device vulnerabile a checkm8.
Questi device possono essere posti in [demotion](http://newosxbook.com/bonus/iboot.pdf#page=5): ovvero è possibile cambiare il CPFM, ma solo fino al prossimo riavvio.
Il motivo è legato al fatto che il CPFM è impostato quando il device è prodotto, quindi è immutabile.
Tuttavia esso viene mappato in un registro di memoria, che può essere alterato qualora si possieda un bootROM exploit.
Così facendo abilitiamo l'interfaccia SWD, che prende anche il nome di Joint Test Access Group (JTAG) nel mondo ARM, che è la [stessa architettura adottata dagli AP](https://raw.githubusercontent.com/galli-leo/emmutaler/master/docs/thesis.pdf#page=10).

Il SWD non è l'unica interfaccia che viene esposta: infatti sulla porta (femmina) Lightning, presente sul device, troviamo un circuito integrato chiamato [Tristar](https://nyansatan.github.io/lightning/) (sugli iPhone 8/X si chiama Hydra), che non è nient'altro che un MUX.
In particolare permette di instradare anche la comunicazione USB e UART.
La prima è usata dall'utente medio per aggiornare e ripristinare l'iPhone, ma anche trasferire file su di esso.
La seconda torna utile quando l'iPhone va in kernel panic perché è possibile conoscerne la ragione.
Per poter usare quest'ultima interfaccia è necessario dotarsi di un cavo chiamato [DCSD](https://www.theiphonewiki.com/w/index.php?title=DCSD_Cable&oldid=110048#.27DCSD_Alex.27_PCB).<br/>
Googlando si trovano molti siti che vendono questo cavo a prezzi modici.
A ogni modo per essere sicuri meglio farsi consigliare da chi l'ha già comprato: nel mio caso ho [scelto questo](https://a.aliexpress.com/_mrLEF1s).
Più precisamente quello mostrato in Figura.
<p align="center">
  <img src="https://ae01.alicdn.com/kf/H2cc1cec8533a4767b82422a405e5aa9bS/Cavo-DCSD-Alex-originale-cavo-porta-seriale-di-ingegneria-per-leggere-scrivere-dati-Nand-SysCfg-per.jpg_640x640.jpg" alt="Second DCSD Cable">
</p>

> **Note**</br>
> Prestare attenzione a come si connette il cavo: infatti il connettore maschio Lightning in questo caso **non è reversibile**.
> Quindi controllare la scritta in Figura.
> ![ibootchain](./images/dcsd.jpeg?raw=true "The traditional boot chain of *OS")

Non indugiamo oltre e facciamo subito una prova.
Nella solita finestra di terminale aperta sulla directory `work`, lanciamo [`termz`](https://github.com/kpwn/termz), che non è nient'altro che una console seriale
```shell
../tools/termz/termz /dev/cu.usbserial-AU01TON3
```
Dopodiché colleghiamo l'iPhone al PC con il cavo DCSD e [forziamone il riavvio](https://support.apple.com/it-it/guide/iphone/iph8903c3ee6/15.0/ios/15.0).
Sulla console dovrebbero comparire delle "strane" stringhe esadecimali
<pre>
af0b11a98ee1c1b:437
af0b11a98ee1c1b:93
af0b11a98ee1c1b:94
af0b11a98ee1c1b:95
af0b11a98ee1c1b:98
af0b11a98ee1c1b:98
4fbf8fe65e3b7c6:346
4fbf8fe65e3b7c6:348
4fbf8fe65e3b7c6:348
4fbf8fe65e3b7c6:348
4fbf8fe65e3b7c6:348
4fbf8fe65e3b7c6:348
4fbf8fe65e3b7c6:348
4fbf8fe65e3b7c6:348
4fbf8fe65e3b7c6:348
<i>omesso</i>
</pre>

Questa è una forma di offuscamento deciso dalla Apple.
<span><!-- https://discord.com/channels/779134930265309195/791490631804518451/1070506084529356851 --></span>
<span><!-- https://discord.com/channels/779134930265309195/791490631804518451/1070504398813413456 --></span>
In particolare se dividiamo la stringa in `:` abbiamo due sotto-stringhe:
- la prima rappresenta il risultato di un HMAC del nome di un file contenente il codice sorgente di iBoot,
- mentre la seconda è la linea all'interno di quel file.

Per avere un'idea dei messaggi prodotti da iBoot durante il suo avvio dovremmo usare una versione di iBoot in sviluppo.
Tale versione non è rilasciata agli sviluppatori da Apple, tuttavia a volte qualche leak, commesso proprio dalla stessa Apple, capita.
Mi sto riferendo all'aggiornamento OTA di [iOS 15.1b3](https://updates.cdn-apple.com/2021FallSeed/patches/002-10420/36B2828C-B8CA-40DE-88F2-A4031B6A9BAC/com_apple_MobileAsset_SoftwareUpdate/7fefd31a7473d632237481eecbf39920364797cd.zip), che oltre a contenere le immagine in produzione, contiene anche quelle di sviluppo.
Per trovare quali firmware, anche OTA, potrebbero contenere tali immagini ho creato [uno script](../tools/finder/finder.sh) che usa le API di appledb.dev.

Qualora non volessimo utilizzare `termz` possiamo utilizzare l'app [CoolTerm](https://freeware.the-meiers.org/) ricordandoci di impostare il baud rate a [115200](https://github.com/kpwn/termz/blob/9cd1089b125ab60b40a11b2ec8844e2a12818457/main.m#L82-L83) baud (simboli al secondo).

### La SecureROM e la ricerca di iBoot

Iniziamo con il chiederci: dove si trova iBoot sull'iPhone?
<span><!-- https://discord.com/channels/779134930265309195/779134930265309198/798263003388051457 --></span>
Beh, la risposta è che risiede su un proprio block device, che condivide con altri componenti.
In particolare tale device è `/dev/disk1` (o `/dev/disk2` su iOS 16): proviamo a esaminarlo.
Come primo tentativo possiamo eseguire, **attraverso una sessione SSH su iPhone in jailbroken state**, il `cat` di questo device:
```shell
# over SSH on jailbroken iPhone
cat /dev/disk1 | head -1
```
Così facendo notiamo nell'output qualcosa di famigliare: la presenza della stringa "IM4P".
Pertanto perché non provare a usare il sotto-comando `asn1parse` della utility `openssl`?
```shell
# over SSH on jailbroken iPhone
openssl asn1parse -in /dev/disk1 -i -inform DER
```
Incredibile! L'interno device, che può essere scaricato [qui](https://raw.githubusercontent.com/miticollo/scacco-matto/main/docs/dumps/dev-disk1.txt) (circa 10 MB), è la concatenazione di diverse strutture ASN.1 codificate in DER.
Andiamo a esaminarne qualcuna.<br/>
Innanzitutto all'inizio di questo device troviamo iBoot: più precisamente troviamo LLB, ma come abbiamo visto prima i device con AP A10+ hanno iBoot e LLB uguali.
Ad ogni modo per convincerci di questo eseguiamo
```shell
openssl asn1parse -in ipsw/orig/Firmware/all_flash/LLB.d22.RELEASE.im4p -i -inform DER
```
e confrontiamo gli `OCTET STRING`.
Il lettore attento avrà notato che l'IM4P è contenuto all'interno di un IMG4, perciò dal titolo precedente sappiamo che ci deve essere un IM4M: infatti subito dopo, ovvero in coda, all'IM4P lo troviamo.
Lo affronteremo meglio nel prossimo paragrafo, ma in questo voglio sottolineare il fatto che tutti gli IMG4, contenuti nel device, hanno **lo stesso IM4M**.

Gli altri componenti che troviamo sono:
- il logo (con tag `logo`) della male morsicata, che appare all'avvio del device
- il BatteryLow1 (con tag `bat1`) che [possiamo vedere](./images/batterylow1.png) estraendo il payload da `ipsw/orig/Firmware/all_flash/batterylow1@3x~iphone.im4p` e convertendolo in PNG con il tool [`ibootim`](https://github.com/realnp/ibootim)
  ```shell
  pyimg4 im4p extract -i ipsw/orig/Firmware/all_flash/batterylow1@3x\~iphone.im4p -o ipsw/decrypted/batterylow1.raw
  ../tools/ibootim/ibootim ipsw/decrypted/batterylow1.raw ipsw/decrypted/batterylow1.png
  ```
- il LiquidDetect (con tag `liqd`) [estratto](./images/liqd.png) da `ipsw/orig/Firmware/all_flash/liquiddetect@2436\~iphone-lightning.im4p`
- il [device tree](https://www.theiphonewiki.com/w/index.php?title=DeviceTree&oldid=71501) (con tag `dtre`), che rappresenta l'hardware del device
- il GlyphPlugin (con tag `glyP`) che [possiamo vedere](./images/glyphplugin.png) estraendo, come fatto prima, il payload da `glyphplugin@2436~iphone-lightning.im4p`
- il BatteryLow0 (con tag `bat0`) estraendolo dal file `ipsw/orig/Firmware/all_flash/batterylow0@3x~iphone.im4p`<br/>
  <p align="center">
    <img src="./images/batterylow0.png?raw=true" alt="BatteryLow0 on iOS 15">
  </p>
- il BatteryCharging0 (con tag `chg0`) [estratto](./images/batterycharging0.png) da `ipsw/orig/Firmware/all_flash/batterycharging0@3x~iphone.im4p`
- il BatteryCharging1 (con tag `chg1`) [estratto](./images/batterycharging1.png) da `ipsw/orig/Firmware/all_flash/batterycharging1@3x~iphone.im4p`
- il logo della RecoveryMode (con tag `recm`) [estratto](./images/recm.png) da `ipsw/orig/Firmware/all_flash/recoverymode@2436~iphone-lightning.im4p`
- il SEP (con tag `sepi`)

Si fa presente che alcune dei loghi che compaiono sullo schermo vengono composti come sovrapposizione ne è un esempio: BatteryLow1 + BatteryLow0.

In ultimo si precisa che quanto finora descritto viene chiamato Local Boot e non richiede "nessun aiuto esterno".
Inoltre l'iPhone stesso ci informa sul tipo di boot.
Infatti se proviamo a forzare il riavvio collegando l'iPhone con il cavo DCSD e aprendo una console seriale con `termz` osserveremo il seguente banner
```text
=======================================
::
:: Supervisor iBoot for d22, Copyright 2007-2022, Apple Inc.
::
::	Local boot, Board 0xe (d221ap)/Rev 0xf
::
::	BUILD_TAG: iBoot-7459.140.15
::
::	BUILD_STYLE: RELEASE
::
::	USB_SERIAL_NUMBER: SDOM:01 CPID:8015 CPRV:11 CPFM:03 SCEP:01 BDID:0E ECID:000E421A01C0002E IBFL:3D SRNM:[GHKZ2116JCLJ]
::
=======================================
```
in cui viene mostrata la versione di iBoot usata, se è in produzione o release e alcune informazioni, che dovrebbero essere famigliari, tra cui il Chip ID (`CPID:8015`), il ChiP Fuse Mode (`CPFM:03`), il numero di serie (`SRNM:[GHKZ2116JCLJ]`), il Board ID (`BDID:0E`) e l'[Exclusive Chip Identification](https://www.theiphonewiki.com/w/index.php?title=ECID&oldid=125862) (`ECID:000E421A01C0002E`).
Tuttavia ciò che più conta è il fatto che è un `Local boot`.

Per riassumere il local boot è essenzialmente composto di tre passaggi fondamentali:
- il codice della SecureROM viene mandato in esecuzione;
- esso si occupa di leggere dal primo namespace un numero sufficiente di byte per recuperare l'IMG4 di iBoot;
- quest'ultimo viene passato alla funzione `image_load`, che controlla l'integrità di iBoot e la sua origine usando i certificati e i digest contenuti nell'IM4M, che accompagnano l'IMG4;
- successivamente il payload criptato di iBoot viene inviato all'AES engine dove viene decriptato usando la GID0 key e
- finalmente può essere mandato in esecuzione. Tra gli altri suoi compiti esso si occuperà di individuare il volume di Preboot in cui è contenuto il kernel per avviarlo.

#### IM4M

Apro questo paragrafo con un po' di sinonimi.
Infatti spesso nelle chat di [Discord](https://discord.com/) o su [Reddit](https://www.reddit.com/r/jailbreak/) si fa riferimento a questo componente con diversi nomi: manifest o [ApImg4Ticket](https://www.theiphonewiki.com/w/index.php?title=APTicket&oldid=117077#IM4M_APTicket.2FApImg4Ticket_format).

Innanzitutto estraiamolo da una di queste due sorgenti:
- [`/dev/rdisk1`](https://github.com/MatthewPierson/deverser/blob/b74000c5104c86c84f8a8121384b08ec6909507c/deverser.sh#L45)
  ```shell
  # over SSH on jailbroken iPhone
  cat /dev/rdisk1 | dd of=/tmp/onboard.der bs=256 count=$((0x4000))
  ```
- `/dev/disk1`
  ```shell
  # over SSH on jailbroken iPhone
  dd if=/dev/disk1 of=/tmp/onboard.der bs=256 count=$((0x4000))
  ```
Perché abbiamo due device? `/dev/rdisk1` è un device a blocchi o a caratteri?
Quest'ultima domanda potrebbe trovare risposta nel come abbiamo scritto il primo comando: infatti nel caso di `/dev/rdisk1` usiamo `cat` per leggerlo e non l'operando `if` di `dd`.
Ciò ci potrebbe portare a pensare che `/dev/rdisk1` sia un dispositivo a caratteri: per verificarlo usiamo `ls`
```shell
# over SSH on jailbroken iPhone
file /dev/{r,}disk1
```
e scopriamo che `/dev/rdisk1` è un dispositivo a caratteri **speciali**.<br/>
La presenza di questi due device non è una prerogativa di iOS e macOS, ma è presente anche su alcuni sistemi UNIX-like.
<span><!-- https://www.reddit.com/r/linux4noobs/comments/147sn0/comment/c7aqtxs/?utm_source=share&utm_medium=web2x&context=3 --></span>
<span><!-- https://serverfault.com/a/214548 --></span>
<span><!-- https://serverfault.com/a/206830 --></span>
Qual è la loro differenza? Basta consultare: [`man -P 'less -p "^DEVICE SPECIAL FILES"' hdiutil`](https://superuser.com/a/631601):
> Since any `/dev` entry can be treated as a raw disk image, it is worth noting which devices can be accessed when and how.  
> `/dev/rdisk` nodes are character-special devices, but are "raw" in the BSD sense and force block-aligned I/O.  
> They are closer to the physical disk than the buffer cache.
> `/dev/disk` nodes, on the other hand, are buffered block-special devices and are used primarily by the kernel's filesystem code.

<span><!-- https://superuser.com/a/892768 --></span>
Ovvero `/dev/rdisk` permette un accesso diretto al device di I/O purché le richieste siano allineate al settore, mentre l'uso `/dev/disk` richiede due buffer uno per lo userspace e l'altro per il device.
Si nota subito come nel primo caso abbiamo un'operazione bloccante, che non avviene nel secondo caso.

Quanto abbiamo visto poteva essere fatto in maniera più semplice recuperando il ticket dal volume di Preboot: `/private/preboot/<ticket_hash>/System/Library/Caches/apticket.der`.
Entrambi contengono l'ApImg4Ticket con una leggera differenza: usando `dd` abbiamo specificato di recuperare `0x4000` (16384) blocchi da 256 byte ovvero 4,194,304 byte (4,0MB), quindi più del necessario.
Per renderlo effettivamente utilizzabile lo dobbiamo convertire in un formato human-readable plain text: un `.shsh`, che non è nient'altro che un file plist.
Per far ciò possiamo utilizzare il CLI tool [`img4tool`](https://github.com/tihmstar/img4tool#convert-shsh-to-im4m) perché questa funzionalità non è disponibile in PyIMG4
```shell
# on macOS (our working directory)
../tools/img4tool --convert -s onboard.shsh ./onboard.der
```
All'interno della community del JB i file con estensione `.shsh` prendono il nome di blob SHSH, in particolare quelli finora recuperati vengono chiamati **on-board** blob.
Questo per distinguerli dai blob recuperati da [`blobsaver`](https://github.com/airsquared/blobsaver), che è un GUI tool basato su JavaFX.
Il tool, presentando una veste grafica semplice, permette all'utente di recuperare i blob SHSH per i propri dispositivi senza dover ricorrere necessariamente al CLI tool [`tsschecker`](https://github.com/airsquared/tsschecker), che quindi è usato indirettamente dall'utente attraverso `blobsaver`.
Proviamo a recuperare i blob SHSH per iOS 15.7.1 usando lo strumento da riga di comando, prima però dobbiamo ottenere alcuni dati usando `irecovery`, ma questa volta metteremo l'iPhone in [recovery mode](https://www.theiphonewiki.com/w/index.php?title=Recovery_Mode&oldid=125090) e non in DFU mode, come prima.
<span><!-- usiamo il termine computer perché vogliamo essere il più flessibile possibile comprendendo anche Linux e Hackintosh --></span>
1. Dopo aver collegato l'iPhone al computer eseguiamo, all'interno del virtual environment creato dallo script `../tools/deps.sh`
   ```shell
   pymobiledevice3 restore enter -v
   ```
   > **Note**</br>
   > Quando parlerò del JB mostrerò un modo alternativo per mettere l'iPhone in recovery mode.
2. Attendiamo che appaia sul display dell'iPhone il logo della RecoveryMode, che abbiamo incontrato prima.
3. Eseguiamo `irecovery` e filtriamone l'output
   ```shell
   ../tools/libirecovery/tools/irecovery -q | grep -E 'PRODUCT|MODEL|ECID|NONC|SNON'
   ```
4. Eseguiamo il `tsschecker` incluso all'interno del bundle di `blobsaver`
   ```shell
   /Applications/blobsaver.app/Contents/MacOS/tsschecker -d iPhone10,6 -m ./ipsw/orig/BuildManifest.plist -B d221ap -s -e 0x000e421a01c0002e -g 0x1111111111111111 --sepnonce ce197fb15494960c5a2f92cc5cc1e64be4c3a527 --apnonce 2cf7d08a03388589db214c405cca576025ab8578df965886911e21ec8529b7a7 --save-path ./ --nocache --debug
   ```
   > **Note**</br>
   > È stato necessario specificare il BuildManifest (opzione `-m`) perché il tool usa le API di ipsw.me per scaricarlo.
   > Tuttavia la versione 15.7.1 non è presente sul sito, quindi il programma fallisce nel recuperarlo.<br/>
   > Inoltre l'opzione `-B` richiede di specificare l'HEX riportato da `irecovery` come `MODEL`.
5. Torniamo in normal mode
   ```shell
   pymobiledevice3 restore exit
   ```

`tsschecker` per ottenere i blob SHSH deve contattare i [Tatsu Signing Server (TSS)](https://www.theiphonewiki.com/w/index.php?title=Tatsu_Signing_Server&oldid=101793), con l'opzione `--debug` stampiamo la richiesta e la conseguente risposta.

#### Remote



## `futurerestore`

> **Warning**</br>
> Il 24 febbraio 2023 la Apple ha chiuso le firme per iOS 15.6 RC (build 19G69) perciò non è possibile effettuare il downgrade ad iOS 15.7.1.


### Come effettuare il frezee dell'ApNonce

Qualora si pianifichi di effettuare in futuro il downgrade o l'upgrade a versioni di iOS non più firmate da Apple è importante salvare i blob SHSH.
Per gli iPhone con AP A12+, come abbiamo visto, non conta tanto il boot nonce piuttosto l'ApNonce.
Quindi `blobsaver` oltre a salvare il boot nonce e l'ApNonce, [forza il freezing di quest'ultimo](https://github.com/airsquared/blobsaver/blob/431f111e7e308ba4c5ddecec5b17f99e6bb5d0b9/src/main/java/airsquared/blobsaver/app/LibimobiledeviceUtil.java#L102-L129).
Vediamo manualmente come potremmo procedere.

Colleghiamo l'iPhone al computer e **rimanendo in normal mode** [richiediamo](https://github.com/libimobiledevice/libimobiledevice/blob/cc540a20e64b469f7d9d4754610c0692436880d6/tools/ideviceinfo.c#L235) al demone [lockdownd](https://iphonedev.wiki/index.php?title=Lockdownd&oldid=2982) (sull'iPhone) la chiave `ApNonce`
```shell
../tools/libimobiledevice/tools/ideviceinfo -k ApNonce | base64 -d -i - | xxd -p -c0
```
Questo forza l'iPhone ha generare un nuovo ApNonce, che noi andiamo a leggere.
Esso si conserverà, anche quando l'iPhone si riavvia, purché noi evitiamo di:
- <span><!-- https://discord.com/channels/779134930265309195/779151007488933889/1084988801316835499 --></span>
  rieseguire il comando precedente,
<span><!-- https://discord.com/channels/842189018523631658/917198974555942942/1077303242926587955 --></span>
- aggiornare (via OTA o iTunes/Finder) il device,
- effettuarne il restore o
- cercare semplicemente gli aggiornamenti.
Verifichiamo che effettivamente abbiamo congelato l'ApNonce.
- Per far ciò non possiamo usare `ideviceinfo -k ApNonce` per ovvi motivi, quindi dovremmo utilizzare `irecovery -q`.
1. Lasciamo l'iPhone collegato al computer e mandiamolo in recovery mode
   ```shell
   pymobiledevice3 restore enter -v
   ```
2. Una volta che il logo della RecoveryMode è apparso, eseguiamo
   ```shell
   while true; do ../tools/libirecovery/tools/irecovery -q | grep -E 'NONC|SNON' && pymobiledevice3 restore restart -v; done
   ```
   <span><!-- https://discord.com/channels/779134930265309195/779151007488933889/1084930408988291194 --></span>
   <span><!-- https://discord.com/channels/779134930265309195/779151007488933889/1084930216708808795 --></span>
   Noteremo che solo `NONC` (ApNonce) non cambia. Il `SNON` (SEPNonce) cambia perché questo è un nonce vero e proprio: infatti è generato sempre in modo casuale, come il boot nonce.
   <span><!-- https://discord.com/channels/779134930265309195/779134930265309198/838228003137781812 --></span>
   In effetti l'ApNonce si basa su un seed, ma non il SEPNonce.
3. Torniamo alla normal mode e riavviamo l'iPhone
   ```shell
   pymobiledevice3 restore restart -v
   ```
4. Quando l'iPhone si sarà riavviato possiamo tornare al punto 1 per verificare che l'ApNonce si sia conservato.

Abbiamo visto che per se l'iPhone a nostra disposizione è jailbreakable noi possiamo usare il tool dimentio.
Quindi il freezing è ancora utile? Assolutamente sì, per tutti quei device che si trovano su usa versione di iOS **non jailbreable**.
Diciamo che se si è molto fortunati si può eseguire il downgrade o l'upgrade a una versione di iOS non più firmata, **senza avere** a disposizione un JB.

#### SEP Nonce

E il freezing del SEP Nonce?
<span><!-- https://discord.com/channels/779134930265309195/779151007488933889/1084912385799753778 --></span>
Attualmente non si conosce una procedura per potere eseguire il freezing.

Anche in questo caso possiamo chiedere a lockdownd qual è il valore della chiave `SEPNonce`
```shell
../tools/libimobiledevice/tools/ideviceinfo -k SEPNonce | base64 -d -i - | xxd -p -c0
```
ottenendo lo stesso comportamento che abbiamo osservato precedentemente: ovvero genera un nuovo SEPNonce.
Avremmo potuto ottenere lo stesso risultato eseguendo:
```shell
# over SSH on jailbroken iPhone
/usr/libexec/seputil --new-nonce && /usr/libexec/seputil --get-nonce
```
dove [`seputil`](https://www.theiphonewiki.com/w/index.php?title=Seputil&oldid=117985) è un comando presente sul rootFS stock di iOS e permette una comunicazione con il SEPOS.
Ad ogni modo che si usi `ideviceinfo` o `seputil` possiamo leggere i loro output direttamente dalla console seriale utilizzando il DCSD cable:
```text
SEP EP 16 enabled
SEP EP 16 disabled
AppleSEP: New SEP Nonce (20 bytes): 0x2747a760119899bcc151bfc730ee4ef6aa88ff71
SEP EP 16 enabled
SEP EP 16 disabled
AppleSEP: Current SEP Nonce (20 bytes): 0x2747a760119899bcc151bfc730ee4ef6aa88ff71
```
cosa che non accade per l'ApNonce.