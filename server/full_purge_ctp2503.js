const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('usage_tracker.db');

const ids = [
    '0f343579-3435-7934-3579-343579343579', 
    'test-id-2503',
    'test-connection' // This is the ID from the screenshot!
];

db.serialize(() => {
    ids.forEach(id => {
        console.log(`Deleting all data for ID: ${id}`);
        db.run('DELETE FROM usage_logs WHERE client_id = ?', [id]);
        db.run('DELETE FROM clients WHERE id = ?', [id], (err) => {
            if (err) console.error(`Error deleting client ${id}:`, err);
            else console.log(`Client ${id} and all related logs are now PURGED.`);
        });
    });
});

db.close();
