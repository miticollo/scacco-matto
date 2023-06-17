import {log} from "./logger.js";

// C functions
const sqlite3_exec = new NativeFunction(
    Module.getExportByName(null, "sqlite3_exec"),
    'int',
    ['pointer', 'pointer', 'pointer', 'pointer', 'pointer']
);

const openFunctions: { [key: string]: NativePointer } = {
    "sqlite3_open_v2": Module.getExportByName(null, "sqlite3_open_v2"),
    "sqlite3_open": Module.getExportByName(null, "sqlite3_open"),
    "sqlite3_open16": Module.getExportByName(null, "sqlite3_open16"),
};

const keyFunctions: { [key: string]: NativePointer } = {
    "sqlite3_key_v2": Module.getExportByName(null, "sqlite3_key_v2"),
    "sqlite3_key": Module.getExportByName(null, "sqlite3_key"),
    "sqlite3_rekey_v2": Module.getExportByName(null, "sqlite3_key_v2"),
    "sqlite3_rekey": Module.getExportByName(null, "sqlite3_key"),
};

const closeFunctions: { [key: string]: NativePointer } = {
    "sqlite3_close_v2": Module.getExportByName(null, "sqlite3_close_v2"),
    "sqlite3_close": Module.getExportByName(null, "sqlite3_close"),
}

const pragmaKeys: string[] = [
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
    handle: string;
    path: string;

    constructor(handle: string, path: string) {
        this.handle = handle;
        this.path = path;
    }
}

const nativeDBs: { [index: string]: NativeDb } = {};

/*
 * Inspired by: https://github.com/frida/frida-objc-bridge/blob/4cae28a3bc077c9/lib/api.js#L117-L137
 */
Object.keys(openFunctions).forEach(function (name: string): void {
    Interceptor.attach(openFunctions[name], {
        onEnter(args): void {
            this.filename = args[0].readUtf8String();
            this.ppDb = args[1];
            if (name === "sqlite3_open_v2") {
                this.flags = args[2];
                this.zVfs = args[3].readUtf8String();
            }
        },
        onLeave: function (retval): void {
            const dbHandle = this.ppDb.readPointer();
            const returnInt: number = retval.toInt32();
            log(`int ${name}(`);
            {
                log(`  Database filename (UTF-8) = "${this.filename}"`);
                log(`  OUT: SQLite db handle     = ${dbHandle.readPointer()}`);
                if (name === "sqlite3_open_v2") {
                    log(`  Flags                     = ${this.flags}`);
                    log("  Name of VFS module to use = " + (this.zVfs === null ? "NULL" : this.zVfs));
                    // This is always NULL as show
                    // https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L324
                }
            }
            log(") {");
            log("  return " + (returnInt == 0 ? "SQLITE_OK" : returnInt) + ";");
            // The only significant status code is SQLITE_OK. Otherwise
            // https://github.com/groue/GRDB.swift/blob/ba68e3b02d9ed953a0c9ff43183f856f20c9b7ce/GRDB/Core/Database.swift#L336
            log("}");
            nativeDBs[dbHandle.toString()] = new NativeDb(dbHandle.toString(), this.filename);
        }
    });
});

Object.keys(keyFunctions).forEach(function (name: string): void {
    Interceptor.attach(keyFunctions[name], {
        onEnter(args): void {
            log(`int ${name}(`);
            {
                let db: NativePointer = args[0].readPointer();
                log(`  Database to be keyed                             = ${db}`);
                let index: number = 1;
                if (name === "sqlite3_key_v2") {
                    const zDbName: string = args[index++].readUtf8String()!;
                    log(`  Name of the database                             = "${zDbName}"`);
                }
                let pKey: string = args[index++].readUtf8String()!;
                if (pKey != null)
                    log(`  The Raw Key Data (Without PBKDF2 key derivation) = 0x${pKey.slice(2, -1)}`);
                else log("  The Raw Key Data (Without PBKDF2 key derivation) = NULL");
                let nKey: number = args[index].toInt32();
                log(`  The length of the key in bytes                   = ${nKey}`);
                // Why 99 bytes?
                // 96 bytes from https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/SessionUtilitiesKit/Database/Storage.swift#L70-L71
                // Then they add a prefix "x'" and a suffix "'" as shown
                // https://github.com/oxen-io/session-ios/blob/8976ab5f5f0a63db232e3278b23ccfe808e800fc/SessionUtilitiesKit/Database/Storage.swift#L76-L77
            }
            log(")");
        }
    });
});

function getPragmaValue(nativeDb: NativeDb, name: string): string | string[] {
    const errorMsgPtr: NativePointer = Memory.alloc(Process.pointerSize);

    let val: string[] = [];
    const callback = new NativeCallback((_: NativePointer, nCol: number, azVals: NativePointer, azCols: NativePointer): number => {
        for (let i = 0; i < nCol; i++)
            val.push(azVals.add(Process.pointerSize * i).readPointer().readUtf8String()!);
        return 0;
    }, 'int', ['pointer', 'int', 'pointer', 'pointer']); //int (*callback)(void*,int,char**,char**)

    const retExec = sqlite3_exec(ptr(nativeDb.handle), Memory.allocUtf8String("PRAGMA " + name + ";"), callback, NULL, errorMsgPtr);
    if (retExec != 0)
        log("Error getting pragma " + name + " from " + nativeDb.path + " query return: " + retExec + " error message: " + errorMsgPtr.readPointer().readUtf8String());
    return val.length == 1 ? val[0] : val;
}

function listPragmaValues(nativeDb: NativeDb): { [pr: string]: string | string[]; } {
    let map: { [pr: string]: string | string[]; } = {};

    for (const pragmaKey of pragmaKeys)
        map[pragmaKey] = getPragmaValue(nativeDb, pragmaKey);
    return map;
}

function onClosure(handle: string): void {
    const nativeDB: NativeDb = nativeDBs[handle];
    let pragmas: { [pr: string]: string | string[]; } = listPragmaValues(nativeDB);
    log(`Dump PRAGMAs (used in ${ptr(nativeDB.handle).readPointer()}) ${JSON.stringify(pragmas, null, 2)}`);
}

Object.keys(closeFunctions).forEach(function (name: string): void {
    Interceptor.attach(closeFunctions[name], {
        onEnter: function (args): void {
            onClosure(args[0].toString());
            delete nativeDBs[args[0].toString()];
        }
    });
});

rpc.exports.dispose = (): void => {
    for (const handle in nativeDBs) onClosure(handle);
    Thread.sleep(3);
}