# SQLCipher

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

## Session

[Session for iOS](https://github.com/oxen-io/session-ios) (version 2.2.4) depends on [GRDB.swift](https://github.com/groue/GRDB.swift).

### Call stack for `sqlite3_open_v2`

1. [Storage.swift](https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/SessionUtilitiesKit/Database/Storage.swift#L89-L91)
2. [DatabasePool.swift](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/DatabasePool.swift#L29-L44)
3. [SerializedDatabase.swift](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/SerializedDatabase.swift#L46-L49)
4. [Database.swift](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L303)
5. [Database.openConnection](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L321-L342)
6. [sqlite3_open_v2](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L324)

### Call stack for `sqlite3_key_v2`

1. [Storage.swift](https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/SessionUtilitiesKit/Database/Storage.swift#L62-L87).
   More info can be found on GitHub page of [GRDB.swift](https://github.com/groue/GRDB.swift/blob/master/README.md#creating-or-opening-an-encrypted-database).
   The version of SQLCipher used by Session is [4.5.0](https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/Podfile#L13-L14).
   So to implement these experimental hooks **I used new API not the old one**.
   Therefore, they are not compatible with old versions of SQLCipher (&lt;3.0.0).
2. [Database.swift](https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L1587-L1603).
3. [sqlite3_key](https://github.com/sqlcipher/sqlcipher/blob/8763afaf13231cb1fc835b52c94ada23f8e47b3d/src/crypto.c#L914-L917).
4. [sqlite3_key_v2](https://github.com/sqlcipher/sqlcipher/blob/8763afaf13231cb1fc835b52c94ada23f8e47b3d/src/crypto.c#L919-L928)

## Signal

Tested on Signal (version 6.8.0).

## Credit

- AnForA Android team: for useful code to dump PRAGMAs