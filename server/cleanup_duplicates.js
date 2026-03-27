const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Target the stable database in C:\ProgramData
const dbPath = 'C:\\ProgramData\\InternetUsageTracker\\usage_tracker.db';
const db = new sqlite3.Database(dbPath);

console.log("--- CLEANING UP DUPLICATE AGENTS (0B) ---");

db.serialize(() => {
    // 1. Delete clients with zero usage (those are the duplicates)
    db.run(`DELETE FROM clients WHERE total_received = 0`, function(err) {
        if (err) return console.error("Error deleting duplicates:", err.message);
        console.log(`Successfully removed ${this.changes} duplicate agents.`);
    });

    // 2. Clean up historical logs for those IDs
    db.run(`DELETE FROM usage_logs WHERE received = 0 AND sent = 0`, (err) => {
        if (err) console.error("Error cleaning logs:", err.message);
        console.log("Cleanup complete.");
        db.close();
    });
});
