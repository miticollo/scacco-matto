import { log } from "./logger.js";

const pragmaKeys = [
    "cipher_version",
    //cipher_settings
    "kdf_iter",
    "cipher_page_size",
    "cipher_use_hmac",
    "cipher_plaintext_header_size",
    "cipher_hmac_algorithm",
    "cipher_kdf_algorithm",

    //cipher_default_settings
    "cipher_default_kdf_iter",
    "cipher_default_page_size",
    "cipher_default_use_hmac",
    // "cipher_default_plaintext_header_size",
    "cipher_default_hmac_algorithm",
    "cipher_default_kdf_algorithm",

    //others
    "cipher_settings",
    // "cipher_default_settings",
    "cipher_default_compatibility",
    "cipher_salt",
    "cache_size",
    "cipher_hmac_pgno",
    "cipher_hmac_salt_mask",
    "cipher_compatibility",
    "cipher_memory_security",
]
class NativeDb {
    handle: string
    path: string | null

    constructor(handle: string) {
        this.handle = handle;
        this.path = null;
    }
}

const sqlcipher = Process.getModuleByName("SQLCipher");     // SQLCipher or libsqlite3.dylib or other?
// C functions
const sqlite3_exec = sqlcipher.getExportByName("sqlite3_exec");
const sqlite3_open_v2 = sqlcipher.getExportByName("sqlite3_open_v2");
const sqlite3_key_v2 = sqlcipher.getExportByName("sqlite3_key_v2");
const sqlite3_close_v2 = sqlcipher.getExportByName("sqlite3_close_v2");

const callable_sqlite3_exec = new NativeFunction(sqlite3_exec, 'int', ['pointer', 'pointer', 'pointer', 'pointer', 'pointer']);
function getPragmaValue(nativeDb: NativeDb, name: string) {
    const errorMsgPtr = Memory.alloc(Process.pointerSize);

    let val: string[] = [];
    const callback = new NativeCallback((_arg1, count, data, columns) => {
        for (let i = 0; i < count; i++) {
            const arrayElementPointer = data.add(Process.pointerSize * i).readPointer();
            const value: string | null = arrayElementPointer.readUtf8String();
            if (value !== null)
                val.push(value);
        }
        return 0;
    }, 'int', ['pointer', 'int', 'pointer', 'pointer']); //int (*callback)(void*,int,char**,char**)

    const retExec = callable_sqlite3_exec(ptr(nativeDb.handle), Memory.allocUtf8String("PRAGMA " + name + ";"), callback, NULL, errorMsgPtr);
    if (retExec != 0)
        log("Error getting pragma " + name + " from " + nativeDb.path + " query return: " + retExec + " error message: " + errorMsgPtr.readPointer().readUtf8String());
    return val;
}
function listPragmaValues(nativeDb: NativeDb) {
    let map: { [pr: string]: string[]; } = {};

    for (const pragmaKey of pragmaKeys)
        map[pragmaKey] = getPragmaValue(nativeDb, pragmaKey);
    return map;
}

Interceptor.attach(sqlite3_key_v2, {
    onEnter(args) {
        log("int sqlite3_key_v2(");
        {
            let db = args[0].readPointer();
            log(`  Database to be keyed                             = ${db}`);
            const zDbName = args[1].readUtf8String();
            log(`  Name of the database                             = "${zDbName}"`);
            // @ts-ignore
            let pKey:string = args[2].readUtf8String().slice(2,-1);
            log("  The Raw Key Data (Without PBKDF2 key derivation) = " + "0x" + pKey);
            let nKey = args[3].toInt32();
            log(`  The length of the key in bytes                   = ${nKey}`);
            // Why 99 bytes?
            // 96 bytes from https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/SessionUtilitiesKit/Database/Storage.swift#L70-L71
            // Then they add a prefix "x'" and a suffix "'" as shown
            // https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/SessionUtilitiesKit/Database/Storage.swift#L76-L77
        }
        log(")");
    }
});

Interceptor.attach(sqlite3_close_v2, {
    onEnter: function (args) {
        let pragmas = listPragmaValues(new NativeDb(args[0].toString()));
        log(`Dump PRAGMAs (used in ${args[0].readPointer()}) {`);
        {
            for(const property in pragmas) log(`  PRAGMA ${property} = ${pragmas[property]};`);
        }
        log("}");
    }
});

Interceptor.attach(sqlite3_open_v2, {
    onEnter(args) {
        this.filename = args[0].readUtf8String();
        this.ppDb = args[1];
        this.flags = args[2];
        this.zVfs = args[3].readUtf8String();
    },
    onLeave: function (retval) {
        const dbHandle = this.ppDb.readPointer().readPointer();
        const returnInt = retval.toInt32();
        log("int sqlite3_open_v2(");
        {
            log(`  Database filename (UTF-8) = "${this.filename}"`);
            log(`  OUT: SQLite db handle     = ${dbHandle}`);
            log(`  Flags                     = ${this.flags}`);
            log("  Name of VFS module to use = " + (this.zVfs === null ? "NULL" : this.zVfs));
            // This is always NULL as show
            // https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L324
        }
        log(") {");
        log("  return " + (returnInt == 0 ? "SQLITE_OK" : returnInt) + ";");
        // The only significant status code is SQLITE_OK. Otherwise
        // https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L336
        log("}");
    }
});