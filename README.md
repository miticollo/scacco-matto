# checkm8

### Setup
1. Iniziamo con il preparare l'ambiente di lavoro:
   ```shell
   git clone --recursive --depth 1 -j8 https://github.com/lorenzoferron98/scacco-matto.git
   cd scacco-matto
   ```
2. Compiliamo i tools che useremo negli step successivi:
   ```shell
   ./tools/deps.sh
   ```
3. Creiamo la working directory nel repository appena clonato:
   ```shell
   mkdir -v -p work/{restore,jb}
   ```
4. Salviamo una copia dell'IPSW del firmware che vogliamo usare nella directory `work`.

## Update + Restore

In questo passaggio utilizzeremo [futurerestore](https://github.com/futurerestore/futurerestore) per eseguire il restore dell'iPhone.
Questo strumento permette di passare a una versione di iOS non più firmata: ovvero per cui non è possibile recuperare i blob SHSH, che quindi saranno forniti dall'utente.
La versione che andremo a installare è la 15.7.1, che non è più firmata per iPhone X.

> :warning: Per effettuare questa operazione è necessario possedere i blob SHSH per la versione di iOS 15.7.1 (build 19H117).

L'utente che avesse già installato questa versione può ignorare questo passaggio.

### Put into practice

Nei seguenti paragrafi esamineremo i passaggi per il corretto ripristino.

#### pwnDFU mode

Innanzitutto è necessario mettere l'iPhone in DFU mode: nel caso del modello X basta seguire [questi passaggi](https://www.theiphonewiki.com/w/index.php?title=DFU_Mode&oldid=125882#A11_and_newer_devices_.28iPhone_8_and_above.2C_iPad_Pro_2018.2C_iPad_Air_2019.2C_iPad_Mini_2019.29).
L'utente alle prime armi potrebbe fallire questo passo perché non esegue correttamente le istruzioni per mettere l'iPhone in DFU.

> :warning: Questa operazione non è in alcun modo automatizzabile.

1. Spostiamoci nella directory `restore`
   ```shell
   cd work/restore
   ```
2. Attiviamo il Python Virtual Environment, che lo script `deps.sh` ha preparato 
   ```shell
   source ../../.venv/bin/activate
   ```
3. Entriamo in pwnDFU mode, disabilitando il signcheck e ripariamo l'heap:
   ```shell
   ipwndfu -p && sleep 2 && ipwndfu --patch-sigchecks && sleep 2 && ipwndfu --repair-heap && sleep 2
   ```
   Qualora `ipwndfu -p` fallisca ripetere il comando perché l'exploitation non è stabile.

##### Boot-none (o generator)

Per effettuare un corretto ripristino, Finder e iTunes devono fare richiesta del certificato SHSH ai [Tatsu Signing Server (TSS)](https://www.theiphonewiki.com/w/index.php?title=Tatsu_Signing_Server&oldid=101793).
Questa operazione non è nient'altro che una richiesta POST, effettuabile con cURL, e il cui body è codificato in XML.
La risposta alla richiesta è una semplice risposta HTTP POST contenente, se la richiesta ha avuto successo, un XML nel valore REQUEST_STRING.
Questo XML contiene la `<key>` `ApImg4Ticket`, che rappresenta il blob SHSH più altre informazioni di contorno usate da `futurerestore`, come il `generator`.
La struttura della richiesta e le possibili risposte sono descritte dall'[omonimo protocollo](https://www.theiphonewiki.com/w/index.php?title=SHSH_Protocol&oldid=121894).
Il salvataggio dei blob SHSH può essere fatto con strumenti come [blobsaver](https://github.com/airsquared/blobsaver).

Per poter usare il certificato SHSH recuperato, o nel caso di `futurerestore` passatogli in input con l'opzione `-t`, è necessario che l'[ApNonce](https://www.theiphonewiki.com/w/index.php?title=Nonce&oldid=119870) all'interno dell'iPhone corrisponda a quello usato per generare il medesimo certificato.
Dato che l'ApNonce è calcolato sulla base del boot-nonce (o generator) dobbiamo impostare tale valore all'interno della NVRAM.
Tuttavia quest'ultima non è accessibile né dalla versione RELEASE di iBoot (il bootloader) né dai bootarg del kernel.
Per tanto sfruttando checkm8 è possibile, dopo aver disabilitato il signcheck e riparato l'heap, caricare una versione patchata di iBSS, che permette di scrivere in NVRAM il generator:
```shell
setenv com.apple.System.boot-nonce <generator>
saveenv
```
Per poi inviare l'iBEC patchato in maniera tale da avviare "freshnonce" e generare l'ApNonce che soddisfi l'apticket (altro modo con cui è conosciuto il blob SHSH).

#### Il tool `futurestore`



### Altri usi di futurerestore
- Aggiornare iOS a una versione jailbrekable permettendo di fatto il passaggio da una versione jailbroken a un'altra.
- Effettuare il tethering restore: ovvero retrocedere a una versione di iOS per cui non si possiedono i blob SHSH.
  Per maggiori dettagli si faccia riferimento a [sunst0rm](https://github.com/mineek/sunst0rm).

## Jailbreak

## Credits

