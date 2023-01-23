import { log } from "./logger.js";

// C functions
let sqlite3_open_v2 = Module.getExportByName("SQLCipher", "sqlite3_open_v2");
let sqlite3_key_v2 = Module.getExportByName("SQLCipher", "sqlite3_key_v2");

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