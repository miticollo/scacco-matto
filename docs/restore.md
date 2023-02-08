# Update + Restore

In questo capitolo utilizzeremo [futurerestore](https://github.com/futurerestore/futurerestore) per eseguire il restore dell'iPhone.
Questo strumento permette di passare a una versione di iOS non più firmata: ovvero per cui non è più possibile recuperare i blob SHSH, che quindi saranno forniti dall'utente.
La versione che andremo a installare è la 15.7.1.

> :warning: Per effettuare questa operazione è necessario possedere i blob SHSH per la versione di iOS 15.7.1 (build 19H117).

L'utente che avesse già installato questa versione può tralasciare i comandi proposti concentrandosi solo sugli aspetti teorici trattati.

## L'hardware che conta

Per comprendere meglio i prossimi paragrafi è necessario acquisire un po' di terminologia sull'hardware che troviamo all'interno di un iPhone.
In [Figura](https://help.apple.com/pdf/security/it_IT/apple-platform-security-guide-t.pdf#page=11) viene presentato un generico system on a chip (SoC).<br/>
<p align="center">
  <img src="./images/soc.png?raw=true" height=50% width=50% alt="SoC internals">
</p>

A livello commerciale questo componente viene chiamato Axx, dove al posto di "xx" si specifica un numero.
In particolare per tutte le mie sperimentazioni ho sempre usato un iPhone X (aka 10,6) con [A11 (aka T8015)](https://www.theiphonewiki.com/w/index.php?title=T8015&oldid=76706).
Lo stesso SoC è presente sull'iPhone 8 messomi a disposizione dall'università.

Non tratteremo tutti i componenti presentati in figura, ma ci concentreremo soprattutto sull'Application Processor (AP), la NAND e l'AES engine.
L'AP è il processore del nostro iPhone, mentre l'unità di archiviazione è realizzata con [porte NAND](https://www.theiphonewiki.com/w/index.php?title=NAND&oldid=98679), la cui capacità cambia in base alle esigenze e disponibilità economiche dell'utente da 4 GiB a 1 TiB.
Tuttavia se l'utente avesse bisogno di maggiore spazio di archiviazione, può decidere di [sostituire in autonomia la sola NAND](https://twitter.com/lipilipsi/status/1610275491537375237).
Nei modelli di iPhone precedenti al 4 era presente una NOR su cui risiedeva iBoot (il bootloader), mentre oggi non è più presente questo componente.
Pertanto iBoot si trova in `/dev/disk1`, come vedremo in seguito.

Infine notiamo che l'AES engine è un componente separato dall'AP, questo per una questione di sicurezza che tratteremo più avanti.

## Trusted boot chain

Prima di passare alla pratica è necessario capire come avviene l'avvio di iOS: da quando premiamo il tasto di accensione fino alla schermata di blocco.
![ibootchain](./images/ibootchain.png?raw=true "The traditional boot chain of *OS")<br/>
Da un primo sguardo della [Figura](http://newosxbook.com/bonus/iboot.pdf#page=1) notiamo, che i passaggi tra i vari componenti di avvio formano una catena.
Inoltre, come discuteremo tra breve, ogni passo verifica che quello successivo sia firmato digitalmente da Apple.
Per questi motivi viene chiamata _trusted boot chain_.

Iniziamo con il considerare un avvio normale, che comincia con la pressione del side button.
Il primo codice che l'AP eseguirà è il [SecureROM](https://papers.put.as/papers/ios/2019/LucaPOC.pdf#page=7), esso non è nient'altro che una versione essenziale e semplificata di iBoot.
Ciò che accade successivamente dipende dall'AP (frecce verdi in figura):
- sui device con A10+ viene mandato in esecuzione iBoot;
- mentre sui device meno recenti (A9 o inferiore) viene eseguito [Low Level Bootloader (LLB)](https://www.theiphonewiki.com/w/index.php?title=LLB&oldid=67906).

Adesso proviamo a rintracciare queste immagini all'interno di una versione del firmware.
Innanzitutto dobbiamo procuraci l'IPSW compatibile con il device a nostra disposizione (nel mio caso iPhone X): per farlo colleghiamoci al sito [appledb.dev](https://appledb.dev/device-selection/), che non è l'unico sito da cui poter scaricare IPSW, ma è il più completo e affidabile.
Il sito mette a disposizione diverse versioni di iOS, tra cui quelle beta, per ciascuna indica se è oppure no firmata.
Visto che successivamente useremo [iOS 15.7.1](https://updates.cdn-apple.com/2022FallFCS/fullrestores/012-95442/E99DEEC6-9763-45EF-B2FF-0BA51A1E966B/iPhone10,3,iPhone10,6_15.7.1_19H117_Restore.ipsw) useremo questa versione, ma quanto segue vale per qualunque versione.<br/>
Al termine del download estraiamo l'IPSW con il comando `unzip`: infatti esso non è nient'altro che un archivio ZIP:


