const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('usage_tracker.db');

db.all('SELECT id, hostname FROM clients WHERE hostname LIKE "%CTP2503%"', (err, rows) => {
    if (err) {
        console.error(err);
        process.exit(1);
    }
    console.log('CLIENTS_FOUND:', JSON.stringify(rows));
    db.close();
});
