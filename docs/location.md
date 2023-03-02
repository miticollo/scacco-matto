# Cambio di location

Come facciamo a cambiare la posizione dell'iPhone senza necessità di jailbreak?
1. Posizioniamoci nella solita working directory `work`
2. Scarichiamo l'archivio ZIP contenente la Developer Disk Image appropriata, nel mio caso per iOS 16.3.1
   <span><!-- https://t.me/libimobiledevice/8285 --></span>
   ```shell
   curl -LO https://github.com/mspvirajpatel/Xcode_Developer_Disk_Images/releases/download/16.3.1/16.3.1.zip
   unzip 16.3.1.zip
   ```
   <span><!-- https://t.me/libimobiledevice/8297 --></span>
   Qualora si stia usando una versione beta o RC di iOS è possibile scaricare la Developer Disk Image che supporta la versione di iOS "più vicina".
3. Montiamo la Developer Disk Image
   ```shell
   ../tools/libimobiledevice/tools/ideviceimagemounter -d 16.3.1/DeveloperDiskImage.dmg 16.3.1/DeveloperDiskImage.dmg.signature
   ```
4. Se tutto è andato a buon fine dovrebbe comparire la voce "Sviluppatore" nell'app Impostazioni
   <p align="center">
     <img src="./images/sviluppatore.jpeg?raw=true" height=50% width=50% alt="The developer pane in Settings app">
   </p>
5. 