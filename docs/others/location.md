# Cambio di location

Come facciamo a cambiare la posizione dell'iPhone **senza la necessità di un jailbreak**?
1. Posizioniamoci nella solita working directory `work`
2. Scarichiamo l'archivio ZIP contenente la Developer Disk Image appropriata, nel mio caso per iOS 16.3.1
   <span><!-- https://t.me/libimobiledevice/8285 --></span>
   ```shell
   curl -LO https://github.com/mspvirajpatel/Xcode_Developer_Disk_Images/releases/download/16.3.1/16.3.1.zip
   unzip 16.3.1.zip
   ```
   <span><!-- https://t.me/libimobiledevice/8297 --></span>
   Qualora si stia usando una versione beta o RC di iOS è possibile scaricare la Developer Disk Image che supporta la versione di iOS "più vicina".
3. Supponendo di essere all'interno del virtual environment creato dallo script `../tools/deps.sh`, montiamo la Developer Disk Image
   ```shell
   pymobiledevice3 mounter mount -v 16.3.1/DeveloperDiskImage.dmg 16.3.1/DeveloperDiskImage.dmg.signature
   ```
4. Se tutto è andato a buon fine dovrebbe comparire la voce "Sviluppatore" nell'app Impostazioni
   <p align="center">
     <img src="../images/sviluppatore.jpeg?raw=true" height=50% width=50% alt="The developer pane in Settings app">
   </p>
   
   Inoltre dall'interfaccia seriale dovremmo leggere il seguente messaggio: `hfs: mounted DeveloperDiskImage on device disk4`.
5. Ora proviamo a cambiare la posizione per esempio usando le coordinate di New York:
   ```shell
   pymobiledevice3 developer simulate-location set -v -- 40.7638478 -73.9729785
   ```
6. Apriamo l'app Mappe e controlliamo la nostra posizione
   <p align="center">
     <img src="../images/apple-store.jpeg?raw=true" height=50% width=50% alt="Apple Store Fifth Avenue">
   </p>
7. Resettiamo la posizione
   ```shell
   pymobiledevice3 developer simulate-location clear -v
   ```
8. Per smontare la Developer Disk Image possiamo usare il comando `umount` su **iOS in jailbroken state**, ma ci serve conoscere dove è montato.
   Di default viene montata sotto `/Developer` per esserne sicuri verifichiamo con `pymobiledevice3`:
   ```shell
   pymobiledevice3 mounter list -v
   ```
   Quindi procediamo allo smonto
   ```shell
   sudo umount -v /Developer
   ```
   che ci viene confermato dal seguente messaggio dell'interfaccia seriale: `hfs: unmount initiated on DeveloperDiskImage on device disk4`, ma anche dal fatto che il precedente comando di `pymobiledevice3` ora restituisce un array vuoto.
   Quindi una Developer Disk Image non è nient'altro che un nuovo dispositivo a blocchi che viene montato (in read-only) sulla directory `/Developer`.<br/>
   Qualora il dispositivo non sia jailbroken possiamo smontare la Developer Disk Image con
   ```shell
   pymobiledevice3 mounter umount -v
   ```
   oppure riavviare lo stesso.

`pymobiledevice3` non è l'unica scelta possibile: infatti esistono il CLI tool [`ipsw`](https://github.com/blacktop/ipsw) o la libreria C [libimobiledevice](https://github.com/libimobiledevice/libimobiledevice).
Tuttavia `pymobiledevice3` oltre a essere un CLI tool, come molti altri progetti Python che abbiamo già incontrato, può essere usato come [libreria che mette a disposizione delle API](https://github.com/doronz88/pymobiledevice3#usage), che lo rendono perfetto per AnForA.
> **Warning**</br>
> Una precisazione è doverosa.
> I CLI tool finora mostrati sono stati scelti, non solo per la loro completezza, ma anche per il fatto che, al momento in cui si scrive, sono mantenuti.
> Tuttavia questo non vale in generale.<br/>
> Spesso nel mondo del jailbreaking vi sono progetti, che vengono sviluppati solo per esperimento i cosiddetti Proof of concept (PoC) ne sono un esempio i [progetti di tihmstar](https://github.com/tihmstar?tab=repositories): uno fra tutti [`futurerestore`](https://github.com/tihmstar/futurerestore) che oggi è mantenuto da [Cryptic](https://github.com/cryptiiiic).
> Un progetto **non mantenuto** _non significa_ che **non funzioni**, ma piuttosto che potrebbe richiedere dei riadattamenti anche importanti per funzionare con le nuove versioni di iOS o AP.
> Per tanto, qualora non si è certi, meglio chiedere all'autore e dove quest'ultimo non risponde rivolgersi alla nutrita community del jailbreak diffusa su Discord (in cui potrebbe bazzicare anche l'autore).