# checkm8

### Setup
1. Iniziamo con il preparare l'ambiente di lavoro
   ```shell
   git clone --recursive --depth 1 -j8 https://github.com/miticollo/scacco-matto.git
   cd scacco-matto
   ```
2. Compiliamo i tools che useremo negli step successivi
   ```shell
   ./tools/deps.sh
   ```
3. Accediamo al virtual environment creato dallo script precedente
   ```shell
   source ./.venv/bin/activate
   ```
4. Creiamo la working directory nel repository appena clonato
   ```shell
   mkdir -v -p work/{restore,jb,ipsw/{orig,decrypted}}
   ```
5. Salviamo una copia dell'IPSW del firmware che vogliamo usare nella directory `work`. <br/>
   IPSW, compatibili con il proprio device, possono essere scaricati dal sito [appledb.dev](https://appledb.dev/device-selection/): non è l'unico sito che offre questo servizio, ma all'interno della comunità del JB è quello **attualmente** più accreditato per la sua completezza e affidabilità.
   Inoltre il sito, oltre a mettere a disposizione le versioni stabili di iOS, permette il download anche di quelle beta e per entrambe indica se è oppure no firmata.
6. Infine aggiungiamo una copia del blob SHSH, se necessario, nella directory `work/restore`.

## La vulnerabilità

_See_ [dedicated chapter](docs/checkm8.md)

## Update + Restore

_See_ [dedicated chapter](docs/restore.md)

## Jailbreak

_See_ [dedicated chapter](docs/jb.md)

## frida

_See_ [dedicated folder](frida/)

## Location

_See_ [dedicated chapter](docs/location.md)

## Credits

