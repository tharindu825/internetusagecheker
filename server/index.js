const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const { initDb, updateClient, getAllClients, getHistory } = require('./db');

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

app.post('/api/report', async (req, res) => {
    const { id, hostname, sent, received } = req.body;
    if (!id || !hostname) {
        return res.status(400).json({ error: "Missing required fields" });
    }

    try {
        await updateClient(id, hostname, sent, received);
        
        // Broadcast in real-time
        io.emit('usage_update', { id, hostname, sent, received, timestamp: new Date().toISOString() });
        
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

const PORT = process.env.PORT || 3001;

initDb().then(() => {
    server.listen(PORT, () => {
        console.log(`Server running on port ${PORT}`);
    });
}).catch(err => {
    console.error("Failed to initialize database:", err);
});
