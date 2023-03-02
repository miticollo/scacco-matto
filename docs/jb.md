# Jailbreak

Il seguente capitolo affronterà una procedura semplice, ma non efficiente per effettuare il jailbreak di iOS 16.3.1.
Potremmo definire tale procedura checkra1n-like.
Tuttavia le soluzione adottate da [bakera1n](https://github.com/dora2-iOS/bakera1n/tree/bakera1n1620) (by dora) e [palera1n-c](https://github.com/palera1n/palera1n-c) sono molto più efficaci, ma molto più complicate.

> **Note**</br>
> Qualora sia necessario aggiornare la copia locale della repo è possibile farlo con il seguente comando
> ```shell
> git pull --recurse-submodules && ./tools/deps.sh
> ```

La scelta di effettuare il jailbreak di iOS 16.3.1 nasce dal fatto che il 10 febbraio 2023 il team di frida [ha corretto i problemi con la early instrumentation](https://github.com/frida/frida-core/commit/dccb612f655b0338a23da4ab8ff223e38e7357ad) che si verificano su iOS 16.