const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const { initDb, updateClient, getAllClients, getHistory, getDailyHistory, deleteClient } = require('./db');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

app.use(cors());
app.use(express.json());

// API Routes
app.get('/api/clients', async (req, res) => {
    try {
        const clients = await getAllClients();
        res.json(clients);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/history/:clientId', async (req, res) => {
    try {
        const history = await getHistory(req.params.clientId);
        res.json(history);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/history/daily/:clientId', async (req, res) => {
    try {
        const dailyHistory = await getDailyHistory(req.params.clientId);
        res.json(dailyHistory);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.delete('/api/clients/:id', async (req, res) => {
    try {
        await deleteClient(req.params.id);
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/report', async (req, res) => {
    const { id, hostname, sent, received, type } = req.body;
    
    // Server-side Log (Heartbeat)
    const timestamp = new Date().toLocaleTimeString();
    console.log(`[${timestamp}] Data Received: ${hostname} (${type || 'classic'}) - Sent: ${Math.round(sent / 1024)}KB Recv: ${Math.round(received / 1024)}KB`);

    if (!id || !hostname) {
        return res.status(400).json({ error: "Missing required fields" });
    }

    try {
        await updateClient(id, hostname, sent, received, type);
        
        // Broadcast in real-time
        io.emit('usage_update', { id, hostname, sent, received, type, timestamp: new Date().toISOString() });
        
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

const PORT = 3001;

initDb().then(() => {
    server.listen(PORT, '0.0.0.0', () => {
        console.log(`Server running on port ${PORT}`);
        console.log(`Open Dashboard: http://localhost:3001 or http://192.168.1.32:3001`);
    });
}).catch(err => {
    console.error("Failed to initialize database:", err);
});
