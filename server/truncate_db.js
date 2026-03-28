const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const dbPath = 'C:\\ProgramData\\InternetUsageTracker\\usage_tracker.db';
const db = new sqlite3.Database(dbPath);

console.log("Attempting to truncate database at:", dbPath);

db.serialize(() => {
    db.run("DELETE FROM usage_logs", (err) => {
        if (err) console.error("Error truncating usage_logs:", err.message);
        else console.log("usage_logs truncated.");
    });
    db.run("DELETE FROM clients", (err) => {
        if (err) console.error("Error truncating clients:", err.message);
        else console.log("clients truncated.");
    });
    db.run("VACUUM", (err) => {
        if (err) console.error("Error vacuuming database:", err.message);
        else console.log("Database reset (VACUUM) complete.");
    });
});

db.close();
