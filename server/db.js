const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'usage_tracker.db');
const db = new sqlite3.Database(dbPath);

const initDb = () => {
    return new Promise((resolve, reject) => {
        db.serialize(() => {
            // Clients table
            db.run(`CREATE TABLE IF NOT EXISTS clients (
                id TEXT PRIMARY KEY,
                hostname TEXT,
                last_seen DATETIMEOFFSET,
                total_sent INTEGER DEFAULT 0,
                total_received INTEGER DEFAULT 0
            )`, (err) => { if (err) reject(err); });

            // Usage logs table (Hourly aggregation or per-report)
            db.run(`CREATE TABLE IF NOT EXISTS usage_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                client_id TEXT,
                sent INTEGER,
                received INTEGER,
                timestamp DATETIMEOFFSET,
                FOREIGN KEY(client_id) REFERENCES clients(id)
            )`, (err) => {
                if (err) reject(err);
                else resolve();
            });
        });
    });
};

const updateClient = (id, hostname, sent, received) => {
    return new Promise((resolve, reject) => {
        const now = new Date().toISOString();
        db.run(`INSERT INTO clients (id, hostname, last_seen, total_sent, total_received)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                hostname = excluded.hostname,
                last_seen = excluded.last_seen,
                total_sent = total_sent + excluded.total_sent,
                total_received = total_received + excluded.total_received`,
        [id, hostname, now, sent, received],
        function(err) {
            if (err) return reject(err);
            
            // Insert log
            db.run(`INSERT INTO usage_logs (client_id, sent, received, timestamp)
                    VALUES (?, ?, ?, ?)`,
            [id, sent, received, now],
            (err) => {
                if (err) reject(err);
                else resolve();
            });
        });
    });
};

const getAllClients = () => {
    return new Promise((resolve, reject) => {
        db.all(`SELECT * FROM clients`, [], (err, rows) => {
            if (err) reject(err);
            else resolve(rows);
        });
    });
};

const getHistory = (clientId, limit = 24) => {
    return new Promise((resolve, reject) => {
        db.all(`SELECT * FROM usage_logs WHERE client_id = ? ORDER BY timestamp DESC LIMIT ?`,
        [clientId, limit],
        (err, rows) => {
            if (err) reject(err);
            else resolve(rows);
        });
    });
};

module.exports = { initDb, updateClient, getAllClients, getHistory };
