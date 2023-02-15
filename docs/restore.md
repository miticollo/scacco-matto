# Update + Restore

In questo capitolo utilizzeremo [futurerestore](https://github.com/futurerestore/futurerestore) per eseguire il restore dell'iPhone.
Questo strumento permette di passare a una versione di iOS non più firmata: ovvero per cui non è più possibile recuperare i blob SHSH, che quindi saranno forniti dall'utente.
La versione che andremo a installare è la 15.7.1.

[](https://twitter.com/diegohaz/status/1527642881384759297)
[](https://github.com/community/community/discussions/16925#discussioncomment-3459263)
[](https://github.com/Mqxx/GitHub-Markdown)
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

Non tratteremo tutti i componenti presentati in figura, ma ci concentreremo soprattutto sull'Application Processor (AP), la NAND e l'AES engine.
L'AP è il processore del nostro iPhone, mentre l'unità di archiviazione è realizzata con [porte NAND](https://www.theiphonewiki.com/w/index.php?title=NAND&oldid=98679), la cui capacità cambia in base alle esigenze e disponibilità economiche dell'utente da 4 GiB a 1 TiB.
Tuttavia se l'utente avesse bisogno di maggiore spazio di archiviazione, può decidere di [sostituire in autonomia la sola NAND](https://twitter.com/lipilipsi/status/1610275491537375237).
Nei modelli di iPhone precedenti al 4 era presente una NOR su cui risiedeva iBoot (il bootloader), mentre oggi non è più presente questo componente.
Pertanto iBoot si trova in `/dev/disk1`, come vedremo in seguito.

Infine notiamo che l'AES engine è un componente separato dall'AP, questo per una questione di sicurezza che tratteremo più avanti.

## Trusted boot chain

Prima di passare alla pratica è necessario capire come avviene l'avvio di iOS: da quando premiamo il tasto di accensione fino alla schermata di blocco.
![ibootchain](./images/ibootchain.png?raw=true "The traditional boot chain of *OS")<span id="fig-bootchain"></span><br/>
Da un primo sguardo della [Figura](http://newosxbook.com/bonus/iboot.pdf#page=1) notiamo, che i passaggi tra i vari componenti di avvio formano una catena.
Inoltre, come discuteremo tra breve, ogni passo verifica che quello successivo sia firmato digitalmente da Apple.
Per questi motivi viene chiamata _trusted boot chain_.

Iniziamo con il considerare un avvio normale, che comincia con la pressione del side button.
Il primo codice che l'AP eseguirà è il [SecureROM](https://papers.put.as/papers/ios/2019/LucaPOC.pdf#page=7), esso non è nient'altro che una versione essenziale e semplificata di iBoot.
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
Al termine dell'estrazione, nella directory `ipsw` troviamo il file `BuildManifest.plist`, che contiene nel nodo `BuildIdentities` le configurazioni per i vari device supportati dall'IPSW.
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

[](https://discord.com/channels/779134930265309195/779151007488933889/1069257586018369546)
> **Note**</br>
> Con AP A14+ o superiore il cavo non è più necessario.
<!-- TODO: la DFU può essere automatizzata, ma non ho capito come: https://discord.com/channels/779134930265309195/791490631804518451/1070241399984902225 -->

1. Verifichiamo che il dispositivo sia effettivamente in DFU mode
   ```shell
    ../tools/libirecovery/tools/irecovery -m 
   ```
2. Ricaviamo il `<BDID>`
   ```shell
    ../tools/libirecovery/tools/irecovery -q | grep 'BDID'
   ```
3. Ricaviamo il `<CPID>`
   ```shell
    ../tools/libirecovery/tools/irecovery -q | grep 'CPID'
   ```
4. Ora possiamo eseguire `parser.py`
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
   ```
Dall'output del comando precedente notiamo che i file hanno estensione [`.im4p`](https://www.theiphonewiki.com/w/index.php?title=IMG4_File_Format&oldid=122062#IMG4_Payload) e [`.dmg`](https://en.wikipedia.org/w/index.php?title=Apple_Disk_Image&oldid=1098452713).

#### IMG4 file = Payload (IM4P) + Manifest (IM4M)

Per ora concentriamoci solo sui payload degli IMG4.
Per semplicità considereremo solo l'iBSS, ma nulla vieta di usare l'iBEC o un altro payload che possiamo trovare all'interno del firmware.
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

Tornando all'output di prima notiamo che abbiamo due valori di tipo `OCTET STRING`, che un è built-in type in ASN.1.
Il primo, che è stato omesso perché troppo lungo, come abbiamo già detto contiene un payload: il binario di iBSS.
Per verificarlo possiamo provare a estrarlo con [PyIMG4](https://github.com/m1stadev/PyIMG4), che è un tool in Python, ma che può anche essere importato nel proprio progetto per usarlo come libreria
```shell
pyimg4 im4p extract -i ipsw/orig/Firmware/dfu/iBSS.d22.RELEASE.im4p -o ipsw/decrypted/ibss.enc --no-decompress
```
Ora usando il tool `xxd` produciamo un one line hexdump dell'output di PyIMG4
[](https://stackoverflow.com/a/31553497)
[](https://unix.stackexchange.com/a/706374)
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
> È vero che esso ci stampa un keybag di produzione ([ricavato dal secondo `OCTET STRING`](https://github.com/m1stadev/PyIMG4/blob/02a770e0e46842ffbeecea44b521ddeb9af93726/pyimg4/_parser.py#L829-L841)) contenente l'IV e la chiave, ma questi non possono essere usati perché cifrati con la GID0 key, che discuteremo nel prossimo paragrafo.

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
> Qualora non si avesse installato il comando `lzfse` basta eseguire `brew install lzfse`, che per essere eseguito richiede [Homebrew](https://brew.sh/).

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
[](https://unix.stackexchange.com/a/33687)
```shell
diff -q --from-file ipsw/decrypted/*.raw
```
Sorprendente, tutti i file sono uguali!
[](https://discord.com/channels/779134930265309195/779134930265309198/875676924721119233)
La Apple con gli AP A10+ ha deciso di usare un single-stage iBoot, ovvero il SecureROM, iBoot, iBEC, LLB e iBSS condivido un codice sorgente comune.
Nei modelli precedenti non si poteva fare per [limiti della SRAM](http://newosxbook.com/bonus/iboot.pdf#page=2), quindi era necessario che LLB caricasse iBoot.
Dalla [Figura](#fig-bootchain) ci accorgiamo che di fatto LLB non è più necessario, ma tuttavia è ancora presente nell'IPSW, perché?
[](https://discord.com/channels/779134930265309195/779134930265309198/875678703672246332)
Probabilmente per mantenere una compatibilità con i software di restore.<br>
[](https://discord.com/channels/779134930265309195/779151007488933889/986400776861671424)
Quindi come fa il device a comportarsi correttamente?
Beh, basandosi sull'[IM4P tag (o TYPE)](https://www.theiphonewiki.com/w/index.php?title=TYPE&oldid=123816): ve ne sono molti, ma ne citerò solo alcuni.
Per determinare quale tag viene usato da un dato payload possiamo usare sia `pyimg4 im4p extract` sia `openssl asn1parse`, ad esempio il tag di iBoot è `ibot` mentre quello di iBSS è `ibss`.
È importante ricordare che il tag è composto di soli 4 caratteri perché è rappresentato da un 32-bit unsigned integer (`uint32_t`).

In ultimo vorrei tornare sul titolo con cui ho aperto questo paragrafo "IMG4 file = Payload (IM4P) + Manifest (IM4M)".
Esso ci dice che un IM4P fa parte di un file con estensione IMG4, che per ora non abbiamo incontrato, ma lo faremo più avanti.
Prima, però, sarà presentato che cos'è un manifest, ovvero un file IM4M, per l'esattezza ne tratteremo quando parleremo del local boot.
Quello che abbiamo spiegato finora è una parte del local boot, ma non abbiamo ancora detto come la SecureROM trova iBoot, che come abbiamo già accennato si trovato su `/dev/disk1`.
Inoltre mostreremo anche come è fatto questo _NVMe namespace_.

#### GID0 key

Ora supponiamo di voler decriptare l'iBSS di iOS 16.0.3.
Come prima cosa dobbiamo decrittare l'IV e la chiave del keybag di produzione restituitoci da `pyimg4 im4p info`.
Quindi colleghiamoci a the iPhone Wiki e cerchiamo la pagina per iOS 16.0.3 per iPhone10,6, ma [non la troviamo](https://www.theiphonewiki.com/w/index.php?title=Firmware_Keys/16.x&oldid=125807).
Cosa fare? Dovremmo usare `gaster`.

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
> Testeremo entrambe le opzioni con iBSS proveniente da iOS 15.7.1, questo perché così il lettore potrà confrontare il keybag con quello usato precedentemente, che sappiamo essere funzionante.

Iniziamo dall'opzione `decrypt`
```shell
../tools/gaster/gaster decrypt ipsw/orig/Firmware/dfu/iBSS.d22.RELEASE.im4p ipsw/decrypted/ibss.gaster
```
e confrontiamo il risultato con `ibss.raw`
```shell
cmp -l ipsw/decrypted/ibss.{raw,gaster}
```
Essi sono uguali! Quindi cosa [fa](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1601) `gaster decrypt`?
1. Prima esegue l'[exploit per checkm8](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1231-L1276);
2. poi avviene la [fase di decrypt](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1562):
   1. crea [in memoria una rappresentazione dell'IM4P del file sorgente](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1407-L1411);
   2. estrae [IV e key dall'IM4P e li concatena in un keybag](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1391-L1405): `IV + key` (**l'ordine è importante!**);
   3. usa l'[AES engine per decriptare il keybag](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1495-L1555);
   4. usa il [keybag decriptato per decriptare il payload dell'IM4P](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1444) e
   5. infine [decomprime l'archivio LZFSE](https://github.com/0x7ff/gaster/blob/7fffffff38a1bed1cdc1c5bae0df70f14395129b/gaster.c#L1449).

> **Note**<br>
> Quanto descritto vale anche per gli IMG4 e non solo per gli IM4P.

Tuttavia, come vedremo in seguito, `futurerestore` usa le pagine di the iPhone wiki per ottenere l'IV e le chiavi, quindi esse devono essere presenti sulla wiki.
Perciò, come decriptare l'IV e la chiave con `gaster`?
1. Costruiamo il keybag concatenando semplicemente l'IV e la chiave (di produzione) restituiti dal comando `pyimg4 im4p info`
   ```shell
   pyimg4 im4p info -vvv -i ipsw/orig/Firmware/dfu/iBSS.d22.RELEASE.im4p | grep -A4 "Type: PRODUCTION" | awk '/IV:/{iv=$2}/Key:/{key=$2} END{print iv key}'
   ```
2. Decriptiamolo con `gaster decrypt_kbag`
   ```shell
   ../tools/gaster/gaster decrypt_kbag 62a3c90d8b8a62837d48e8e68b35138cbda4b5c481822d18af9da996da1699497c5fe7e717d6fd030003b88464846d42 | tail -1
   ```
3. Voilà!
   ```text
   IV: D31E54ACB4BADB8AF5CC327B28CB9276, key: 814134782438F75F9CCCED43FFF5FB0E51A8BAF38F591ACCB88E92FB2C1BE7C0 
   ```



### La SecureROM e la ricerca di iBoot



#### IM4M



#### Remote



## `futurerestore`



