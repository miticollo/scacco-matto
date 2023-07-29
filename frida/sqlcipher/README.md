# SQLCipher

Apps and approaches used.

## Apps

Here the analyzed apps.

### Session

[Session for iOS](https://github.com/oxen-io/session-ios) (version 2.2.4) depends on [GRDB.swift](https://github.com/groue/GRDB.swift).

#### Call stack for `sqlite3_open_v2`

1. [Storage.swift](https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/SessionUtilitiesKit/Database/Storage.swift#L89-L91)
2. [DatabasePool.swift](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/DatabasePool.swift#L29-L44)
3. [SerializedDatabase.swift](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/SerializedDatabase.swift#L46-L49)
4. [Database.swift](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L303)
5. [Database.openConnection](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L321-L342)
6. [sqlite3_open_v2](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L324)

#### Call stack for `sqlite3_key_v2`

1. [Storage.swift](https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/SessionUtilitiesKit/Database/Storage.swift#L62-L87).
   More info can be found on GitHub page of [GRDB.swift](https://github.com/groue/GRDB.swift/blob/master/README.md#creating-or-opening-an-encrypted-database).
   The version of SQLCipher used by Session is [4.5.0](https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/Podfile#L13-L14).
   So to implement these experimental hooks **I used new API not the old one**.
   Therefore, they are not compatible with old versions of SQLCipher (&lt;3.0.0).
2. [Database.swift](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L1587-L1603).
3. [sqlite3_key](https://github.com/sqlcipher/sqlcipher/blob/8763afaf13231cb1fc835b52c94ada23f8e47b3d/src/crypto.c#L914-L917).
4. [sqlite3_key_v2](https://github.com/sqlcipher/sqlcipher/blob/8763afaf13231cb1fc835b52c94ada23f8e47b3d/src/crypto.c#L919-L928)

### Signal

[Signal for iOS](https://apps.apple.com/us/app/signal-private-messenger/id874139669) (version 6.8.0).

### Wickr Me

This app doesn't require a key to decrypt the database. 
In fact, the database is in plaintext, but some data are encrypted (e.g., the messages). 
In the table `ZWICKR_MESSAGE`, we can find the `ZBODY` column that contains the ciphered message body. 
The structure of this encrypted data can be found in [this report](https://oops.math.spbu.ru/SE/diploma/2021/pi/Cherniavskii-report.pdf#page=14), which is as follows:
- The first byte: `0x00`
- From byte 2 to 13: GCM nonce (or IV)
- From byte 14 to 29: GCM tag
- From byte 30 to EOF: ciphertext

To decrypt this structure, we must use a 32-byte content data key (CDK) and AES256-GCM. 
To be more precise, CDK is retrieved by decrypting the `ZPT` column in `ZSECEX_ACCOUNT`, which contains the key derivation function (KDF) algorithm ID (`0x01`) ([Scrypt by Tarsnap](https://github.com/Tarsnap/scrypt)) and the KDF salt. 
They are necessary to use the [`scrypt_kdf`](https://github.com/Tarsnap/scrypt#using-scrypt-as-a-kdf) function. 
Furthermore, the `ZPT` column contains a GCM IV and tag, which are used to decrypt the ciphertext (always in `ZPT`) with AES256-GCM. 
The key of this step is the output of `scrypt_kdf`. 
After this decryption, we have a key to decrypt the content of other columns (like `ZBODY`).

Since Wickr Me is a closed-source app, I used [this article](https://www.sciencedirect.com/science/article/pii/S2666281721000366) (which [you know](https://people.unipmn.it/sguazt/publication/anglano-2021-useraction/Anglano-2021-UserAction.pdf#page=13)) to study it. 
**Unfortunately, I couldn't decrypt messages.**

## `sqlite3_open_v2`
```c
int sqlite3_open_v2(
  const char *filename,   /* Database filename (UTF-8) */
  sqlite3 **ppDb,         /* OUT: SQLite db handle */
  int flags,              /* Flags */
  const char *zVfs        /* Name of VFS module to use */
);
```
See [official documentation](https://www.sqlite.org/c3ref/open.html).

## `sqlite3_key_v2`
```c
int sqlite3_key_v2(
  sqlite3 *db,                   /* Database to be keyed */
  const char *zDbName,           /* Name of the database */
  const void *pKey, int nKey     /* The key */
);
```
See [official documentation](https://www.zetetic.net/sqlcipher/sqlcipher-api/#sqlite3_key).

### Use `pKey` to decrypt DB

Tested on [Session](#session) and [Signal](#signal).
I reported it only for Session but changing the paths and filenames these steps can be used also with Signal.

1. Install DB Browser for SQLite with SQLCipher support. I preferred using the [Nightly Build](https://nightlies.sqlitebrowser.org/latest/).
2. Now we can transfer the folder that contains DB and WAL file on PC to read them.
   To find its path it is sufficient to look the string stored in `filename` argument of `sqlite3_open_v2` function.
3. Open [`Session.sqlite`](https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/SessionUtilitiesKit/Database/Storage.swift#L10) with DB Browser for SQLite.
   > :warning: This is a WAL mode database so when you open it libsqlite3 (a library used by DB Browser for SQLite) [checkpoints the WAL file](https://sqliteforensictoolkit.com/forensic-examination-of-sqlite-write-ahead-log-wal-files/) and adds the changes to the main database.
4. As soon as we open the DB file, DB Browser for SQLite requires the password:</br>
   ![SQLCipher settings](../../docs/images/db4s.png?raw=true "SQLCipher settings")</br>
   The password is an HEX string that is contained in `pKey` argument of `sqlite3_key_v2`function.
   Furthermore, it is necessary to customize some settings to properly open DB.
   In particular, we use all settings for [SQLCipher 4](https://www.zetetic.net/sqlcipher/design/) (see below) but **it is necessary to set** ["Plaintext Header Size" to 32 byte](https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/SessionUtilitiesKit/Database/Storage.swift#L81-L86).
5. Finally, we can read the messages looking in the `interactions` table.

> **Note**<br/>
> I enabled a passcode to protect my Session app, and then I tried to retrieve `pkey`. 
> However, I discovered that Session opens the database before the passcode is entered, so I was able to successfully dump the key again. 
> Just out of curiosity, I found out that Session uses the iOS passcode, while Telegram implements its own passcode. 
> To use Session with a passcode, I had to use an iPhone SE 2020 because, as you know, the passcode requires SEP. 
> However, if you boot the iPhone from DFU on iOS 14+, SEP panics. 
> To solve this issue, you can use the SEPROM exploit, such as blackbird, but unfortunately, it doesn't work on A11.

### Alternative approach: `keychain_dumper`

Tested on [Session](#session) and [Signal](#signal).
Again changing bundleID (`org.whispersystems.signal`) these steps can be adapted for Signal.

Here I show an alternative method to retrieve the Session key using keychain.
1. Install cURL (or `wget`) and `sqlite3` with your preferred package manager (e.g. [Sileo](https://getsileo.app/), [Zebra](https://getzbra.com/), Cydia or [Installer5](https://apptapp.me/repo/)).
2. Open SSH session with root privileges and run the following commands:
   ```shell
   curl -LO https://github.com/ptoomey3/Keychain-Dumper/releases/download/1.1.0/keychain_dumper-1.1.0.zip
   unzip keychain_dumper-1.1.0.zip && rm -v keychain_dumper-1.1.0.zip
   curl -LO https://github.com/ptoomey3/Keychain-Dumper/archive/refs/heads/master.zip
   unzip master.zip && rm -v master.zip
   cd Keychain-Dumper-master/
   mv -v ../keychain_dumper ./
   chmod +x setup_on_iOS.sh && ./setup_on_iOS.sh
   chmod +x updateEntitlements.sh && ./updateEntitlements.sh
   cd ..
   ```
3. Use the `ldid` utility to check entitlements were properly set:
   ```shell
   ldid -e /usr/bin/keychain_dumper
   ```
4. Run `keychain_dumper` and cross your fingers:
   ```shell
   keychain_dumper -a
   ```
Looking into source code of Session I discovered that the key name used in keychain is [GRDBDatabaseCipherKeySpec](https://github.com/oxen-io/session-ios/blob/9a4988f2126135950a2a8d7c43873433aec6b751/SessionUtilitiesKit/Database/Storage.swift#L12).
The [password is randomly generated](https://github.com/oxen-io/session-ios/blob/9a4988f2126135950a2a8d7c43873433aec6b751/SessionUtilitiesKit/Database/Storage.swift#L252-L263) when initialising the Database for the first time. 
The Key and password are then stored in the keychain.
So a quick search on `keychain_dumper` output &mdash; using the keyword "GRDBDatabaseCipherKeySpec" or "com.loki-project.loki-messanger" (the bundleID of Session) &mdash; produces:
<pre>
Generic Password
----------------
Service: TSKeyChainService
Account: GRDBDatabaseCipherKeySpec
Entitlement Group: SUQ8J2PCT7.com.loki-project.loki-messenger
Label: (null)
Accessible Attribute: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, protection level 4
Description: (null)
Comment: (null)
Synchronizable: 0
Generic Field: (null)
<b>Keychain Data (Hex): 0xc9350d14d6f18b1197849f66c52d8c15331e814b439af4bb5179e745dcfe744c838235f3f339061ef547609f20972196</b>
</pre>

#### Notes

During investigations, I discovered that into Keychain are stored some items about removed apps.
This is normal because an app can save or delete item into Keychain using the appropriate API (e.g., `SecItemAdd` and `SecItemDelete`).
<span><!-- https://gist.github.com/dhoerl/1170641#file-keychainitemwrapper-m-L118-L119 --></span>
Anyway only that app can manage the items inside Keychain for security reasons.
The column `cdat` and `mdat`are encoded with [Apple Cocoa Core Data timestamp](https://www.epochconverter.com/coredata).

#### Wickr Me

I found this interesting key inside keychain:
<pre>
Generic Password
----------------
Service: wickr
Account: activeAccount
Entitlement Group: W8RC3R952A.com.mywickr.wickr
Label: (null)
Accessible Attribute: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, protection level 4
Description: (null)
Comment: (null)
Synchronizable: 0
Generic Field: (null)
Keychain Data (Hex): 0x00682cc29edc897e6fe49073f1790878ce1dea50b01a5e547c68a3173368e84de1
</pre>
But I don't know what is its purpose.

## Hooking on Swift

How to hook [`usePassphrase`](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L1587-L1603) from `GRDB.framework`?

1. Attach frida to Session or Signal
2. Find the path of the framework into target app
   ```javascript
   Process.enumerateModules().find(x => x.name.toUpperCase() === "GRDB").path
   ```
3. Enumerate all exports inside the framework
   ```javascript
   Module.enumerateExports(Process.enumerateModules().find(x => x.name.toUpperCase() === "GRDB").path);
   ```
4. Now we can search the functions
   ```javascript
   Module.enumerateExports(Process.enumerateModules().find(x => x.name.toUpperCase() === "GRDB").path).filter(x => x.name.includes("assphrase") && x.name.includes("use"));
   ```
5. At the moment, [`frida-swift-bridge`](https://github.com/frida/frida-swift-bridge/) works partially. Therefore, you will need to handle all the work, and this requires a good understanding of the Swift Memory Layout.

## Credits

- AnForA Android team: for useful code to dump PRAGMAs.
- [seb2point0](https://github.com/seb2point0): for [his post](https://cight.co/backup-signal-ios-jailbreak/) that shows me `keychain_dumper`.
