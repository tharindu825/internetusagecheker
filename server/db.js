const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

// Move Database to C:\ProgramData for System Access
const dbDir = 'C:\\ProgramData\\InternetUsageTracker';
if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
}
const dbPath = path.join(dbDir, 'usage_tracker.db');
const db = new sqlite3.Database(dbPath);

const initDb = () => {
    return new Promise((resolve, reject) => {
        db.serialize(() => {
            // Clients table (Identity Lock: Hostname is now the deduplication key)
            db.run(`CREATE TABLE IF NOT EXISTS clients (
                id TEXT PRIMARY KEY,
                hostname TEXT UNIQUE,
                type TEXT,
                last_seen DATETIMEOFFSET,
                total_sent INTEGER DEFAULT 0,
                total_received INTEGER DEFAULT 0
            )`, (err) => { if (err) reject(err); });

            // Usage logs table
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

// Update Client with ID Unification
const updateClient = (id, hostname, sent, received, type = 'classic') => {
    return new Promise((resolve, reject) => {
        const now = new Date().toISOString();
        const cleanHostname = hostname.trim().toLowerCase();
        
        // Identity Lock Logic:
        // Instead of just Conflict(id), we check for Conflict(cleanHostname)
        // This merges any "Duplicate" IDs that share the same Computer Name!
        db.run(`INSERT INTO clients (id, hostname, type, last_seen, total_sent, total_received)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(hostname) DO UPDATE SET
                type = excluded.type,
                last_seen = excluded.last_seen,
                total_sent = total_sent + excluded.total_sent,
                total_received = total_received + excluded.total_received`,
        [id, cleanHostname, type, now, sent, received],
        function(err) {
            if (err) return reject(err);
            
            // Get the actual stored ID (after internal merge) for the log
            db.get(`SELECT id FROM clients WHERE hostname = ?`, [cleanHostname], (err, row) => {
                if (err || !row) return reject(err || new Error("ID not found"));
                
                // Insert log
                db.run(`INSERT INTO usage_logs (client_id, sent, received, timestamp)
                        VALUES (?, ?, ?, ?)`,
                [row.id, sent, received, now],
                (err) => {
                    if (err) reject(err);
                    else resolve();
                });
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

const getHistory = (clientId, limit = 48) => {
    return new Promise((resolve, reject) => {
        db.all(`SELECT * FROM usage_logs WHERE client_id = ? ORDER BY timestamp DESC LIMIT ?`,
        [clientId, limit],
        (err, rows) => {
            if (err) reject(err);
            else resolve(rows);
        });
    });
};

const getDailyHistory = (clientId) => {
    return new Promise((resolve, reject) => {
        db.all(`SELECT 
                    SUBSTR(timestamp, 1, 10) as date, 
                    SUM(sent) as sent, 
                    SUM(received) as received 
                FROM usage_logs 
                WHERE client_id = ? 
                GROUP BY date 
                ORDER BY date DESC`,
        [clientId],
        (err, rows) => {
            if (err) reject(err);
            else resolve(rows);
        });
    });
};

const deleteClient = (id) => {
    return new Promise((resolve, reject) => {
        db.serialize(() => {
            db.run(`DELETE FROM usage_logs WHERE client_id = ?`, [id], (err) => {
                if (err) return reject(err);
                db.run(`DELETE FROM clients WHERE id = ?`, [id], (err) => {
                    if (err) reject(err);
                    else resolve();
                });
            });
        });
    });
};

module.exports = { initDb, updateClient, getAllClients, getHistory, getDailyHistory, deleteClient };
