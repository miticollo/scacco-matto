# Update + Restore

In questo capitolo utilizzeremo [futurerestore](https://github.com/futurerestore/futurerestore) per eseguire il restore dell'iPhone.
Questo strumento permette di passare a una versione di iOS non più firmata: ovvero per cui non è più possibile recuperare i blob SHSH, che quindi saranno forniti dall'utente.
La versione che andremo a installare è la 15.7.1.

> :warning: Per effettuare questa operazione è necessario possedere i blob SHSH per la versione di iOS 15.7.1 (build 19H117).

L'utente che avesse già installato questa versione può tralasciare i comandi proposti concentrandosi solo sugli aspetti teorici trattati.

## L'hardware che conta

Per comprendere meglio i prossimi paragrafi è necessario acquisire un po' di terminologia sull'hardware che troviamo all'interno di un iPhone.
In [Figura](https://help.apple.com/pdf/security/it_IT/apple-platform-security-guide-t.pdf#page=11) viene presentato un generico system on a chip (SoC).<br/>
![ibootchain](./images/soc.png?raw=true "The traditional boot chain of *OS")<br/>
A livello commerciale questo componente viene chiamato Axx, dove al posto di "xx" si specifica un numero.
In particolare per tutte le mie sperimentazioni ho sempre usato un iPhone X (aka 10,6) con [A11 (aka T8015)](https://www.theiphonewiki.com/w/index.php?title=T8015&oldid=76706).
Lo stesso SoC è presente sull'iPhone 8 messomi a disposizione dall'università.

Non tratteremo tutti i componenti presentati in Figura, ma ci concentreremo soprattutto sull'Application Processor (AP), la NAND e l'AES engine.
L'AP è il processore del nostro iPhone, mentre l'unità di archiviazione è realizzata con [porte NAND](https://www.theiphonewiki.com/w/index.php?title=NAND&oldid=98679), la cui capacità cambia in base alle esigenze e disponibilità economiche dell'utente da 4 GiB a 1 TiB.
Nei modelli di iPhone precedenti al 4 era presente una NOR su cui risiedeva iBoot (il bootloader), tuttavia oggi non più presente questo componente.
Pertanto iBoot si trova in `dev/disk1`, come vedremo in seguito.

Infine notiamo che l'AES engine è un componente separato dall'AP, questo per una questione di sicurezza che tratteremo più avanti.

## Trusted boot chain

Prima di passare alla pratica è necessario capire come avviene l'avvio di iOS: da quando premiamo il tasto di accensione fino alla schermata di blocco.
![ibootchain](./images/ibootchain.png?raw=true "The traditional boot chain of *OS")<br/>
Da un primo sguardo della [Figura](http://newosxbook.com/bonus/iboot.pdf#page=1) notiamo, che i passaggi tra i vari componenti di avvio formano una catena.
Inoltre, come discuteremo tra breve, ogni passo verifica che quello successivo sia firmato digitalmente da Apple.
Per questi motivi viene chiamata _trusted boot chain_.

## Put into practice

Nei seguenti paragrafi esamineremo i passaggi per il corretto ripristino.

### pwnDFU mode

Dopo aver collegato l'iPhone al PC mettiamolo in DFU mode: nel caso del modello X basta seguire [questi passaggi](https://www.theiphonewiki.com/w/index.php?title=DFU_Mode&oldid=125882#A11_and_newer_devices_.28iPhone_8_and_above.2C_iPad_Pro_2018.2C_iPad_Air_2019.2C_iPad_Mini_2019.29).
Può capire che l'utente inesperto non riesca a mettere l'iPhone in DFU al primo tentativo.
Se ciò dovesse accadere basta riprovare.

> :warning: Questa operazione non è in alcun modo automatizzabile.

1. Spostiamoci nella directory `restore`
   ```shell
   cd work/restore
   ```
2. Verifichiamo che il dispositivo sia effettivamente in DFU mode utilizzando il tool [`irecovery`](https://github.com/libimobiledevice/libirecovery/blob/master/tools/irecovery.c):
   ```shell
    ../../tools/libirecovery/tools/irecovery -m 
   ```
3. Entriamo in pwnDFU mode, disabilitando il sigcheck:
   ```shell
   ../../tools/gaster/gaster pwn
   ```
4. Verifichiamo nuovamente con `irecovery`
   ```shell
   ../../tools/libirecovery/tools/irecovery -q | grep -w 'PWND'
   ```
È importante notare che si è usato un fork di gaster piuttosto che l'[originale](https://github.com/0x7ff/gaster).
Questo perché il tool originale, seppur funzionante, ha un problema: infatti l'upload dell'iBSS fallisce.
Tuttavia se si ripete il comando precedente, `futurerestore` riesce a portare a termine con successo l'upload.
Una sua possibile alternativa è [ipwndfu](https://github.com/hack-different/ipwndfu), ma nonostante sia ancora mantenuto è sconsigliato.

#### Sigchecks

<!-- https://discord.com/channels/779134930265309195/779139039365169175/1057637924532924576 -->

Nel funzionamento previsto da Apple la modalità DFU permette di ripristinare l'iDevice qualora esso sia bloccato in Restore Mode (logo Apple con barra progresso) o sia in bootloop perché si è verificato un kernel panic.
Infatti in questa circostanza il dispositivo non entrerebbe in Recovery Mode per tanto il PC non sarebbe in grado di rilevarlo come dispositivo che richiede un ripristino.
Al contrario la DFU è sempre possibile perché essa è parte integrante del SecureROM (o AP BootROM).

Posto l'iPhone in DFU mode, esso viene riconosciuto automaticamente da Finder/iTunes, che avvertono l'utente che il dispositivo deve essere ripristinato all'ultima versione.
A questo punto viene avviato il download del firmware, che sarà successivamente decompresso (fattibile anche con `unzip`) per parsificare il `BuildManifest.plist` e individuare i file da usare nel ripristino.
In particolare il primo file che viene inviato al dispositivo è l'[iBSS (iBoot Single Stage)](https://www.theiphonewiki.com/wiki/IBSS) facendo si che l'iPhone passi dalla DFU mode alla Recovery mode.
Tuttavia questo può essere fatto solo se iBSS proviene da Apple, qualora iBoot fosse stato patchato allora il SecureROM si rifiuterebbe di caricarlo.
> :information_source: Questo non vale per l'iPhone originale (con application processor S5L8900) che invece non imponeva controlli sulle immagini che gli venivano inviate.

<!-- https://youtu.be/DxoL2azQ3Io -->
Per ovviare a questa problematica ci serviamo di checkm8, ovvero una vulnerabilità per cui non esiste una soluzione perché fusa con la SecureROM.
In particolare questo componente hardware non viene più aggiornato una volta che ha lasciato gli stabilimenti in cui l'iPhone è stato assemblato.
Per tanto `gaster` usa checkm8 per patchare il sigchecks e permettere alla SecureROM di accettare la versione di iBSS pachata.

Perché iBSS deve essere patchato? Il motivo è la necessità d'impostare un boot-nonce (o generator) prima di procedere con il ripristino.

#### Boot-none (o generator)

Per effettuare un corretto ripristino, Finder e iTunes devono fare richiesta del certificato SHSH ai [Tatsu Signing Server (TSS)](https://www.theiphonewiki.com/w/index.php?title=Tatsu_Signing_Server&oldid=101793).
Questa operazione non è nient'altro che una richiesta POST, effettuabile con cURL, e il cui body è codificato in XML.
La risposta alla richiesta è una semplice risposta HTTP contenente, se la richiesta ha avuto successo, un XML nel valore REQUEST_STRING.
Questo XML contiene la `<key>` `ApImg4Ticket`, che rappresenta il blob SHSH codificato in base64 più altre informazioni di contorno usate da `futurerestore`, come il `generator`.
La struttura della richiesta e le possibili risposte sono descritte dall'[omonimo protocollo](https://www.theiphonewiki.com/w/index.php?title=SHSH_Protocol&oldid=121894).
Il salvataggio dei blob SHSH può essere fatto con [blobsaver](https://github.com/airsquared/blobsaver).

Per poter usare il certificato SHSH recuperato è necessario che l'[ApNonce](https://www.theiphonewiki.com/w/index.php?title=Nonce&oldid=119870) all'interno dell'iPhone corrisponda a quello usato per generare il medesimo certificato.
Dato che l'ApNonce è calcolato sulla base del boot-nonce (o generator) dobbiamo impostare tale valore all'interno della NVRAM.
Quindi per prima cosa dobbiamo caricare l'iBSS (iBoot Single Stage) patchato.

##### iBSS

1. Recuperiamo il `BuildManifest.plist`
   ```shell
   unzip -p ../iPhone10,3,iPhone10,6_15.7.1_19H117_Restore.ipsw 'BuildManifest.plist' > 'BuildManifest.plist'
   ```
2. Determiniamo il percorso dell'iBSS all'interno del firmware parsificando il `BuildManifest.plist`
   

## Altri usi di futurerestore
- Aggiornare iOS a una versione jailbrekable permettendo di fatto il passaggio da una versione jailbroken a un'altra.
- Effettuare il tethering restore: ovvero retrocedere a una versione di iOS per cui non si possiedono i blob SHSH.
  Per maggiori dettagli si faccia riferimento a [sunst0rm](https://github.com/mineek/sunst0rm).
