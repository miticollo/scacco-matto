# La gestione degli IPA

In questo breve README mostrerò come poter recuperare e installare un'IPA da macOS/Linux.
Parto quindi dal motivo per cui questo README è necessario: come abbiamo visto precedentemente perché frida funzioni si deve disporre di un iDevice jailbroken.
I jailbreak per device vulnerabili a un bootROM exploit ci consentono di operare anche con l'ultima versione **beta** di iOS (nel momento in cui si scrive la 16.4b2).
Tuttavia i device per cui non è **pubblicamente** rilasciato un bootROM possono contare solo sulle vulnerabilità, **patchabili in qualunque momento**, di iOS.
Allo stato attuale iPhone con AP A14+ non presentano un bootROM exploit, mentre gli A12 e A13 presentano, come abbiamo già visto, l'UaF, che non è sufficiente senza un memory leak che permetta l'heap feng shui.
Quindi per questi dispositivi l'unica soluzione è un JB semi-untethered come [unc0ver](https://unc0ver.dev/)+[fugu14](https://github.com/LinusHenze/Fugu14).

Quando gli iPhone A11 non riceveranno più aggiornamenti, gli unici dispositivi impiegabili saranno quelli con AP A12+.
Questo significa che un jailbreak **end-user**, per le versioni più recenti di iOS, non sarà disponibile in breve tempo e magari non coprirà tutti gli aggiornamenti di quella major release.
Un esempio è iOS 15, per cui esistono tre JB pubblici in Work In Progress (WIP):
- [XinaA15](https://twitter.com/xina520) che supporta solo iOS 15-15.1.1.
- [Fugu15 max](https://github.com/opa334/Fugu15/tree/max) che supporta iOS 15-15.4.1, ma con moltissime problematiche:
  - solo le versioni 15.4 e 15.4.1 possono usare il [Wi-Fi](https://github.com/opa334/Fugu15#known-issuesbugs), per le altre versioni _sembra_ che il device va in kernel panic e
  - <span><!-- https://discord.com/channels/779134930265309195/779151007488933889/1081588249472016515 --></span>
    probabilmente la versione rootless di frida non riuscirebbe a effettuare l'hook delle funzioni C.
- [ra1ncloud](https://github.com/iarchiveml/ra1ncloud) che supporta iOS 15-15.4.1, perché, come quello precedente, si basa su [Fugu15](https://github.com/pinauten/Fugu15) di Linus Henze.

A ogni modo tutti e tre risultano poco stabili e affidabili per un **end-user**.
Quindi qualora si cerchi un JB end-user è necessario usare versioni più vecchie di iOS come la 14.8, tenendo ben a mente che l'ultima (nel momento in cui si scrive) è la 16.3.1.

Va fatta una precisazione riguardo quanto detto finora: è vero che il JB può essere reso al pubblico in "ritardo" rispetto la versione supportata dalla Apple, ma spesso questo viene fatto perché i primi tentativi di JB sono fatti su misura.
Ad esempio l'utente twitter jmpews ha mostrato in [un post](https://twitter.com/jmpews/status/1623605844305924097) di essere riuscito a ottenere il JB di iOS 16.3 su **iPhone 14 Pro (A16)**, senza però divulgare dettagli o codice molto probabilmente perché ciò che ha realizzato è tarato sul suo dispositivo e dovrebbe essere riadattato (correzione offset) per funzionare su altri.

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
Tuttavia quest'ultimo richiede il bundleID dell'app, che non viene fornito sulla pagina dell'Apple Store.
Quindi useremo le [API di Apple](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/LookupExamples.html#//apple_ref/doc/uid/TP40017632-CH7-SW1) per recuperare quest'informazione:
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
Importante è l'opzione `--purchase` che permette di accettare la licenza, ma non necessario specificarla per download futuri della stessa app.

### Applicazione a pagamento

In questo esperimento considereremo l'applicazione []().

## Come installare un'IPA? 

Proviamo ad installare Microsoft Teams con 

> **Note**</br>
> AnForA dovrebbe includere un supporto **solo** per l'installazione dell'IPA, ma il recupero dello stesso è a carico dell'analista.
> Questo ricalca fedelmente il comportamento previsto dal team di Android.
> A ogni modo quanto detto prima potrebbe far parte di una FAQ consultabile dall'analista.

### Come disinstallare l'IPA?

Ora proviamo a disinstallare la precedente applicazione:
```shell

```
