const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('usage_tracker.db');

db.all("SELECT name FROM sqlite_master WHERE type='table'", (err, rows) => {
    if (err) console.error(err);
    else console.log('TABLES:', JSON.stringify(rows));
    db.close();
});
