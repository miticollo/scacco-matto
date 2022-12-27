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
   mkdir -p work/{restore,jb}
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

> :warning: Questa operazione non è in alcun modo automatizzabile

1. Spostiamoci nella directory `restore`
   ```shell
   cd work/restore
   ```
2. Attiviamo il Python Virtual Environment, che lo script `deps.sh` ha preparato 
   ```shell
   source ../../.venv/bin/active
   ```
3. Entriamo in pwnDFU mode, disabilitando il signcheck e riparando l'heap:
   ```shell
   ipwndfu -p && sleep 2 && ipwndfu --patch-sigchecks && sleep 2 && ipwndfu --repair-heap && sleep 2
   ```
   Qualora `ipwndfu -p` fallisca ripetere il comando perché l'exploitation non è stabile.

Il signcheck è necessario per permettere a `futurerestore` d'impostare nella NVRAM il corretto generatore:
```shell
setenv com.apple.System.boot-nonce <generator>
saveenv
```
che viene usato per calcolare l'APNonce.


#### Il tool `futurestore`



### Altri usi di futurerestore
- Aggiornare iOS a una versione jailbrekable permettendo di fatto il passaggio da una versione jailbroken a un'altra.
- Effettuare il tethering restore: ovvero retrocedere a una versione di iOS per cui non si possiedono i blob SHSH.
  Per maggiori dettagli si faccia riferimento a [sunst0rm](https://github.com/mineek/sunst0rm).

## Jailbreak

## Credits

