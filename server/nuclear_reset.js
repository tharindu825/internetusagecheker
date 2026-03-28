const sqlite3 = require('sqlite3').verbose();
const dbPath = 'C:\\ProgramData\\InternetUsageTracker\\usage_tracker.db';
const db = new sqlite3.Database(dbPath);

console.log("--- NUCLEAR DATABASE RESET STARTING ---");

db.serialize(() => {
    // Drop records from both tables
    db.run("DELETE FROM usage_logs", (err) => {
        if (err) console.error("Error clearing logs:", err.message);
        else console.log("✅ All usage logs cleared.");
    });
    
    db.run("DELETE FROM clients", (err) => {
        if (err) console.error("Error clearing clients:", err.message);
        else console.log("✅ All client records cleared.");
    });

    // Reset auto-increment counters if any
    db.run("DELETE FROM sqlite_sequence WHERE name='usage_logs' OR name='clients'", (err) => {
        if (err) console.log("Info: sqlite_sequence cleaned.");
    });

    db.run("VACUUM", (err) => {
        if (err) console.error("Error vacuuming database:", err.message);
        else console.log("✅ Database reset and vacuumed successfully.");
    });
});

db.close((err) => {
    if (err) console.error("Error closing database:", err.message);
    else console.log("--- RESET COMPLETE ---");
});
