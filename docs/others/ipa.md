# La gestione degli IPA

In questo breve README mostrerò come poter recuperare e installare un'IPA da macOS/Linux.
Parto quindi dal motivo per cui questo README è necessario: come abbiamo visto precedentemente perché frida funzioni si deve disporre di un iDevice jailbroken.
I jailbreak per device vulnerabili a un bootROM exploit ci consentono di operare anche con l'ultima versione **beta** di iOS (nel momento in cui si scrive la 16.4b3).
Tuttavia i device per cui non è **pubblicamente** rilasciato un bootROM exploit possono contare solo sulle vulnerabilità, **patchabili in qualunque momento**, di iOS.
Allo stato attuale iPhone con AP A14+ non presentano un tale exploit, mentre gli A12 e A13 presentano, come abbiamo già visto, l'UaF, che non è sufficiente senza un memory leak che permetta l'heap feng shui.
Quindi per questi dispositivi l'unica soluzione è un JB semi-untethered come [unc0ver](https://unc0ver.dev/) + [fugu14](https://github.com/LinusHenze/Fugu14).

Quando gli iPhone con AP A11 non riceveranno più aggiornamenti, gli unici dispositivi impiegabili saranno quelli con AP A12+.
Questo significa che un jailbreak **end-user**, per le versioni più recenti di iOS, non sarà disponibile in breve tempo e magari non coprirà tutti gli aggiornamenti di quella major release.
Un esempio è iOS 15, per cui esistono tre JB pubblici in Work In Progress (WIP):
- [XinaA15](https://twitter.com/xina520) che supporta solo iOS 15-15.1.1.
- Fugu15 Max che supporta iOS 15-15.4.1, ma con [problematiche](https://github.com/opa334/Fugu15/tree/max#fugu15-max).
- [ra1ncloud](https://github.com/iarchiveml/ra1ncloud) che supporta iOS 15-15.4.1, perché, come quello precedente, si basa su [Fugu15](https://github.com/pinauten/Fugu15) di Linus Henze.

A ogni modo tutti e tre risultano poco stabili e affidabili per un **end-user**.
Quindi qualora si cerchi un JB end-user è necessario usare versioni più vecchie di iOS come la 14.8, tenendo ben a mente che l'ultima (nel momento in cui si scrive) è la 16.3.1.

Va fatta una precisazione riguardo quanto detto finora: è vero che il JB può essere reso al pubblico in "ritardo" rispetto la versione supportata dalla Apple, ma spesso questo viene fatto perché i primi tentativi di JB sono fatti su misura.
Ad esempio l'utente twitter jmpews ha mostrato in [un post](https://twitter.com/jmpews/status/1623605844305924097) di essere riuscito a ottenere il JB di iOS 16.3 su **iPhone 14 Pro (A16)**, senza però divulgare dettagli o codice.
Molto probabilmente perché ciò che ha realizzato è tarato sul suo dispositivo e dovrebbe essere riadattato (correzione offset) per funzionare su altri.

Ora supponiamo di voler installare un'applicazione che **richiede almeno iOS 15** su un iPhone SE (2020) con iOS 14.4.2 (jailbreakable con unc0ver + fugu14).
Inoltre l'applicazione in questione **non è mai stata acquistata dall'utente**, quindi non comparirà tra gli "Acquisti" del proprio Apple ID all'interno dell'App Store.

## Come scaricare un'IPA?

Considerò due casi separati: applicazione a pagamento e non.

### Applicazione gratuita

In questo esperimento considereremo l'applicazione [Microsoft Teams](https://apps.apple.com/it/app/microsoft-teams/id1113153706). 
Per scaricarla utilizzeremo il CLI tool [`ipatool`](https://github.com/majd/ipatool).
Per prima cosa eseguiamo il login con il nostro Apple ID:
```shell
ipatool auth login -e '20024182@studenti.uniupo.it' --verbose
```
ora possiamo procedere con il download dell'app con il sotto-comando: `download`.
Tuttavia quest'ultimo richiede il bundleID dell'app, che non viene fornito sulla pagina dell'App Store.
Quindi useremo le [API di Apple](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/LookupExamples.html#//apple_ref/doc/uid/TP40017632-CH7-SW1) per recuperare questo dato:
```shell
curl -sL 'https://itunes.apple.com/lookup?id=1113153706&country=it' | jq '.results[0].bundleId'
```
In particolare estraiamo il campo `bundleId` del primo (e unico) risultato contenuto nella risposta JSON alla richiesta cURL.
Per parsificare la risposta è stata utilizza la utility a linea di comando [`jq`](https://stedolan.github.io/jq/), che può essere installata con:
```shell
brew install jq
```
Ora possiamo scaricare l'applicazione:
```shell
ipatool download -b 'com.microsoft.skype.teams' --verbose --purchase
```
Importante è l'opzione `--purchase` che permette di accettare la licenza, ma non è necessario specificarla per download futuri della stessa app.

### Applicazione a pagamento

In questo esperimento considereremo l'applicazione [Threema](https://apps.apple.com/app/threema/id578665578).
Non possiamo utilizzare `ipatool` per acquistarla **la prima volta**.
L'unica soluzione fattibile è utilizzare una vecchia versione di iTunes per Windows.
In particolare ci servirà la [12.6.5.3](https://secure-appldnld.apple.com/itunes12/091-87819-20180912-69177170-B085-11E8-B6AB-C1D03409AD2A6/iTunes64Setup.exe): infatti tale versione è l'ultima che supporta l'acquisto di app direttamente dall'App Store.
Al termine del download potremmo trovare l'IPA in `%UserProfile%\Music\iTunes\iTunes Media\Mobile Applications`.
> **Note**</br>
> Questa soluzione ha il difetto di far affidamento su [una vecchia versione](https://appledb.dev/firmware/iTunes/1265A4.html) di iTunes, le cui API prima o poi smetteranno di funzionare.
> Si spera che qualora ciò dovesse accadere si possa far già affidamento su qualche progetto open source.

## Come installare un'IPA? 

Proviamo ad installare Microsoft Teams con `pymobiledevice3`:
```shell
pymobiledevice3 apps install -v ./com.microsoft.skype.teams_1113153706_v5.3.1_561.ipa
```
Ma questo fallirà perché `DeviceOSVersionTooLow: The system version is lower than the minimum OS version specified`. Quindi come procedere?
Abbiamo due alternative:
- installare l'ultima versione supportata dalla nostra versione di iOS, visto che essa ora compare nella sezione "Acquisti".
  Se non avessimo usato `ipatool` **non avremmo potuto** effettuare il download di una versione più datata.
  <span><!-- https://stackoverflow.com/a/24320279 --></span>
  Try to install PowerPoint (never purchased)             |  Install Microsoft Teams (it has just purchased)
  :------------------------------------------------------:|:----------------------------------------------------:
  ![before](../images/ipa/before.jpg?raw=true "Before")   |  ![before](../images/ipa/after.jpg?raw=true "After")
- Oppure possiamo installare una versione ancora più vecchia, ma per far ciò abbiamo due soluzioni:
  - usare un iPhone jailbroken o
  - usare Windows.

Nel primo caso ci basta installare il tweak [AppStore++](https://cokepokes.github.io/depiction/appstoreplus.html), mentre nel secondo caso possiamo usare [`ipatool-py-scrape`](https://github.com/minif/ipatool-py-scrape#download-old-version), che permette attraverso frida di instrumentare la versione di iTunes 12.6.5.3 ed effettuare il download di una specifica versione oppure di tutte.

### I framework

<span><!-- https://discord.com/channels/349243932447604736/688122301975363591/1074726760316411904 --></span>
Il motivo per cui un'app richiede una versione superiore di iOS è **di solito** dovuta al fatto che usa dei framework non presenti in una versione inferiore.
Tuttavia è possibile che gli sviluppatori decidano di richiede una versione superiore di iOS senza impiegare nessun nuovo framework.
Quindi in linea di principio sarebbe possibile forzare l'installazione agendo sul file `Info.plist`, ma poi ricadremmo sempre nello stesso problema: ovvero un'app proveniente dall'App Store è criptata e firmarla nuovamente (con `codesign`) porta a un'app che **non funziona**.

Per verificare quanto ho detto è possibile usare una [blank app](https://github.com/miticollo/blank-app), che ho realizzato anche per provare Swift + SwiftUI.

> **Note**</br>
> AnForA dovrebbe includere un supporto **solo** per l'installazione dell'IPA, ma il recupero dello stesso è a carico dell'analista.
> Questo ricalca fedelmente il comportamento previsto dal team di Android.
> A ogni modo quanto detto prima potrebbe far parte di una FAQ consultabile dall'analista.

### Come disinstallare l'IPA?

Ora proviamo a disinstallare la precedente applicazione:
```shell
pymobiledevice3 apps uninstall -v 'com.microsoft.skype.teams'
```

### App non disponibili

E se l'app in questione non fosse disponibile sullo Store italiano di Apple?
Beh, una soluzione semplice sarebbe quella di cambiare Store, passando da quello italiano a quello statunitense.
Poi scaricare l'app o usare AppStore++ per effettuarne il downgrade.
Al termine di ciò possiamo tornare allo Store italiano notando che l'app non compare tra i nostri acquisti.
Quindi l'iPhone non l'aggiornerà automaticamente, perché non presente sullo Store del paese scelto.

Se invece vogliamo scaricarla con `ipatool` dovremo usare una versione meno recente la [1.1.4](https://github.com/majd/ipatool/releases/tag/v1.1.4) perché include l'opzione `--country`:
1. effettuiamo (nuovamente) il login con il nostro AppleID:
   ```shell
   ipatool auth login
   ```
2. cerchiamo il bundleID dell'app che ci interessa (ad esempio quella [ABC](https://apps.apple.com/us/app/abc-live-tv-full-episodes/id364191819)):
   ```shell
   curl -sL 'https://itunes.apple.com/lookup?id=364191819&country=us' | jq '.results[0].bundleId'
   ```
   > **Warning**</br>
   > È importante osservare che abbiamo indicato `country=us` perché altrimenti non ci sarebbero stati risultati con `country=it`.
3. procediamo con il download
   ```shell
   ipatool download -b com.abcdigital.abc.videoplayer --country us --device-family iPhone --log-level debug --purchase
   ```
   Al termine potremo tornare allo Store italiano e **per quest'app non sarà più necessario** cambiare Store quando vogliamo scaricarla nuovamente con **questa** versione di `ipatool`, ma sarà comunque necessario specificare `--country us`.

Infine rimane in sospesa una questione: dove procurarsi un'app (anche già scaricata) che è stata ritirata da tutti gli Store?
Ad esempio [WPA Tester](https://www.iphoneitalia.com/309585/wpa-tester-3-0-disponibile-su-app-store), che fu ritirata probabilmente perché permetteva di calcolare attraverso l'SSID di default le password dei modem Alice.
In pratica permetteva di scroccare la rete Wi-Fi del vicino.
Anche se il suo autore l'aveva progetta per verificare se la propria rete Wi-Fi era sicura: ovvero se avevi cambiato la password di default.
Oggi non sarebbe più possibile utilizzarla, ma fino a iOS 11 era possibile installarla purché si avesse una copia dell'IPA.<br/>
Quindi in questo caso come procedere? La soluzione migliore è cercare la versione dell'IPA **non criptata** e poi installarla con Sideloadly.
Teniamo conto che un'applicazione ritirata **non significa** che essa non funzioni, ma semplicemente che potrebbe aver violato i termini della Apple.
