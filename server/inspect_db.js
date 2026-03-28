const sqlite3 = require('sqlite3').verbose();
const dbPath = 'C:\\ProgramData\\InternetUsageTracker\\usage_tracker.db';
const db = new sqlite3.Database(dbPath);

console.log("Inspecting DB records at:", dbPath);

db.serialize(() => {
    db.all("SELECT id, hostname, type, last_seen, total_sent, total_received FROM clients", [], (err, rows) => {
        if (err) {
            console.error("Error reading clients:", err.message);
        } else {
            console.log("\n--- Client Records ---");
            rows.forEach(row => console.log(JSON.stringify(row)));
        }
    });

    db.get("SELECT name, sql FROM sqlite_master WHERE type='table' AND name='clients'", (err, row) => {
        if (err) console.error("Error reading schema:", err.message);
        else console.log("\n--- Table Schema ---\n", row.sql);
    });
});

db.close();
