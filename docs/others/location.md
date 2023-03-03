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
3. Installiamo il CLI tool [`ipsw`](https://github.com/blacktop/ipsw)
   ```shell
   brew install blacktop/tap/ipsw
   ```
4. Montiamo la Developer Disk Image
   ```shell
   ipsw idev img mount -V 16.3.1/DeveloperDiskImage.dmg 16.3.1/DeveloperDiskImage.dmg.signature
   ```
5. Se tutto è andato a buon fine dovrebbe comparire la voce "Sviluppatore" nell'app Impostazioni
   <p align="center">
     <img src="../images/sviluppatore.jpeg?raw=true" height=50% width=50% alt="The developer pane in Settings app">
   </p>
6. Ora proviamo a cambiare la posizione per esempio usando le coordinate di New York:
   ```shell
   ../tools/libimobiledevice/tools/idevicesetlocation -d -- 40.7638478 -73.9729785
   ```
7. Apriamo l'app Mappe e controlliamo la nostra posizione
   <p align="center">
     <img src="../images/apple-store.jpeg?raw=true" height=50% width=50% alt="Apple Store Fifth Avenue">
   </p>
8. Resettiamo la posizione
   ```shell
   ../tools/libimobiledevice/tools/idevicesetlocation -d -- reset
   ```
9. Per smontare la Developer Disk Image possiamo usare il seguente comando su **iOS in jailbroken state**: 
   ```shell
   sudo umount -v /Developer
   ```
   Quindi una Developer Disk Image non è nient'altro che un nuovo dispositivo a blocchi che viene montato (in read-only) sulla directory `/Developer`.<br/>
   Qualora il dispositivo non sia jailbroken possiamo smontare la Developer Disk Image
   ```shell
   ipsw idev img unmount -V
   ```
   oppure riavviare lo stesso.