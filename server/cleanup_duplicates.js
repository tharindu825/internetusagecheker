const sqlite3 = require('sqlite3').verbose();
const dbPath = 'C:\\ProgramData\\InternetUsageTracker\\usage_tracker.db';
const db = new sqlite3.Database(dbPath);

console.log("\n--- [NUCLEAR RESET] STARTING FULL DATABASE WIPE ---");

db.serialize(() => {
    // 1. Wipe all usage history
    db.run(`DELETE FROM usage_logs`, function(err) {
        if (err) return console.error("Error clearing logs:", err.message);
        console.log(`✅ Cleared all usage history records.`);
    });

    // 2. Wipe all clients
    db.run(`DELETE FROM clients`, function(err) {
        if (err) return console.error("Error clearing clients:", err.message);
        console.log(`✅ Cleared all client records (Fresh Start).`);
    });

    // 3. Clear sequences
    db.run(`DELETE FROM sqlite_sequence WHERE name='usage_logs' OR name='clients'`, (err) => {
        if (!err) console.log("✅ Auto-increment sequences reset.");
    });

    // 4. Vacuum the database to clean the file
    db.run(`VACUUM`, (err) => {
        if (err) console.error("Error vacuuming database:", err.message);
        else console.log("✅ Database vacuumed and optimized.");
        console.log("--- [NUCLEAR RESET] COMPLETE ---\n");
        db.close();
    });
});
