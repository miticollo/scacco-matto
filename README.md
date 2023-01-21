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
3. Creiamo la working directory nel repository appena clonato
   ```shell
   mkdir -v -p work/{restore,jb}
   ```
4. Salviamo una copia dell'IPSW del firmware che vogliamo usare nella directory `work`.
5. Inoltre aggiungiamo una copia del blob SHSH, se necessario, nella directory `work/restore`.

## Update + Restore

_See_ [dedicated chapter](docs/restore.md)

## Jailbreak

_See_ [dedicated chapter](docs/jb.md)

## Credits

