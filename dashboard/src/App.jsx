import React, { useState, useEffect } from 'react';
import { io } from 'socket.io-client';
import axios from 'axios';
import { 
  Activity, 
  Monitor, 
  ArrowUpCircle, 
  ArrowDownCircle, 
  Globe, 
  CheckCircle2, 
  AlertCircle,
  Clock
} from 'lucide-react';
import { 
  LineChart, 
  Line, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer 
} from 'recharts';

const API_BASE = "http://localhost:3001"; // Update with actual server IP if needed
const socket = io(API_BASE);

function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

const App = () => {
  const [clients, setClients] = useState([]);
  const [totalStats, setTotalStats] = useState({ sent: 0, received: 0 });
  const [selectedClient, setSelectedClient] = useState(null);
  const [history, setHistory] = useState([]);

  useEffect(() => {
    // Initial fetch
    fetchClients();

    // Socket listeners
    socket.on('usage_update', (data) => {
      setClients(prev => {
        const index = prev.findIndex(c => c.id === data.id);
        if (index === -1) {
          return [...prev, { ...data, total_sent: data.sent, total_received: data.received, last_seen: data.timestamp }];
        }
        const updated = [...prev];
        updated[index] = {
          ...updated[index],
          total_sent: (updated[index].total_sent || 0) + data.sent,
          total_received: (updated[index].total_received || 0) + data.received,
          last_seen: data.timestamp,
          current_sent: data.sent, // For live indicator
          current_received: data.received
        };
        return updated;
      });

      // Update total stats
      setTotalStats(prev => ({
        sent: prev.sent + data.sent,
        received: prev.received + data.received
      }));

      // If viewing this client, update history (simulate)
      if (selectedClient && selectedClient.id === data.id) {
        setHistory(prev => [...prev.slice(-19), { timestamp: data.timestamp, sent: data.sent, received: data.received }]);
      }
    });

    return () => socket.off('usage_update');
  }, [selectedClient]);

  const fetchClients = async () => {
    try {
      const res = await axios.get(`${API_BASE}/api/clients`);
      setClients(res.data);
      
      const total = res.data.reduce((acc, c) => ({
        sent: acc.sent + (c.total_sent || 0),
        received: acc.received + (c.total_received || 0)
      }), { sent: 0, received: 0 });
      setTotalStats(total);
    } catch (err) {
      console.error("Error fetching clients:", err);
    }
  };

  const fetchHistory = async (client) => {
    setSelectedClient(client);
    try {
      const res = await axios.get(`${API_BASE}/api/history/${client.id}`);
      setHistory(res.data.reverse());
    } catch (err) {
      console.error("Error fetching history:", err);
    }
  };

  return (
    <div className="min-h-screen w-full p-4 md:p-8 space-y-8 max-w-7xl mx-auto">
      {/* Header */}
      <header className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold flex items-center gap-3">
            <Globe className="text-primary animate-pulse" />
            Internet Usage Tracker
          </h1>
          <p className="text-slate-400 mt-1">Centralized monitoring for 25+ Windows systems</p>
        </div>
        <div className="flex gap-4">
          <div className="glass px-6 py-3 flex items-center gap-4">
            <div className="bg-primary/20 p-2 rounded-lg">
              <ArrowUpCircle className="text-primary" />
            </div>
            <div>
              <p className="text-xs text-slate-400 uppercase tracking-wider">Total Sent</p>
              <p className="text-xl font-bold">{formatBytes(totalStats.sent)}</p>
            </div>
          </div>
          <div className="glass px-6 py-3 flex items-center gap-4">
            <div className="bg-secondary/20 p-2 rounded-lg">
              <ArrowDownCircle className="text-secondary" />
            </div>
            <div>
              <p className="text-xs text-slate-400 uppercase tracking-wider">Total Received</p>
              <p className="text-xl font-bold">{formatBytes(totalStats.received)}</p>
            </div>
          </div>
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* PC List */}
        <section className="lg:col-span-1 space-y-4">
          <h2 className="text-xl font-semibold flex items-center gap-2">
            <Monitor size={20} />
            Connected Devices
          </h2>
          <div className="space-y-3 overflow-y-auto max-h-[70vh] pr-2 scrollbar-thin scrollbar-thumb-white/10">
            {clients.length === 0 && (
              <div className="text-center py-12 glass border-dashed">
                <AlertCircle className="mx-auto text-slate-500 mb-2" />
                <p className="text-slate-500">No active reports yet</p>
              </div>
            )}
            {clients.map(client => (
              <div 
                key={client.id}
                onClick={() => fetchHistory(client)}
                className={`glass p-4 cursor-pointer transition-all hover:scale-[1.02] border-l-4 ${selectedClient?.id === client.id ? 'border-primary' : 'border-transparent'}`}
              >
                <div className="flex justify-between items-start mb-2">
                  <div>
                    <h3 className="font-bold text-lg">{client.hostname}</h3>
                    <p className="text-xs text-slate-500 font-mono">{client.id.substring(0, 8)}...</p>
                  </div>
                  <div className="flex items-center gap-1 text-xs text-secondary">
                    <div className="w-2 h-2 rounded-full bg-secondary animate-pulse" />
                    Online
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2 text-sm">
                  <div className="flex items-center gap-2 text-slate-300">
                    <ArrowUpCircle size={14} className="text-primary" />
                    {formatBytes(client.total_sent)}
                  </div>
                  <div className="flex items-center gap-2 text-slate-300">
                    <ArrowDownCircle size={14} className="text-secondary" />
                    {formatBytes(client.total_received)}
                  </div>
                </div>
                <div className="mt-3 flex justify-between items-center text-[10px] text-slate-500">
                  <span className="flex items-center gap-1">
                    <Clock size={10} />
                    {new Date(client.last_seen).toLocaleTimeString()}
                  </span>
                  {client.current_sent > 0 && (
                    <span className="text-primary font-bold">
                      +{formatBytes(client.current_sent)}
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* Details & Charts */}
        <section className="lg:col-span-2 space-y-6">
          {selectedClient ? (
            <div className="space-y-6">
              <div className="glass p-6">
                <div className="flex justify-between items-center mb-6">
                  <div>
                    <h2 className="text-2xl font-bold flex items-center gap-3">
                      <Activity className="text-primary" />
                      Usage History: {selectedClient.hostname}
                    </h2>
                    <p className="text-slate-400 text-sm">Real-time internet consumption trends</p>
                  </div>
                  <button 
                    onClick={() => setSelectedClient(null)}
                    className="text-slate-400 hover:text-white transition-colors"
                  >
                    Close
                  </button>
                </div>

                <div className="h-[300px] w-full mt-8">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={history}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#ffffff10" />
                      <XAxis 
                        dataKey="timestamp" 
                        tick={{fontSize: 10, fill: '#64748b'}} 
                        tickFormatter={(t) => new Date(t).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      />
                      <YAxis tick={{fontSize: 10, fill: '#64748b'}} />
                      <Tooltip 
                        contentStyle={{backgroundColor: '#1e293b', border: 'none', borderRadius: '8px', color: '#f8fafc'}}
                        formatter={(value) => formatBytes(value)}
                      />
                      <Line type="monotone" dataKey="sent" stroke="#3b82f6" strokeWidth={2} dot={false} animationDuration={300} />
                      <Line type="monotone" dataKey="received" stroke="#10b981" strokeWidth={2} dot={false} animationDuration={300} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="glass p-6">
                  <h4 className="text-sm font-medium text-slate-400 uppercase tracking-widest mb-4">Cumulative Upload</h4>
                  <div className="flex items-end gap-3">
                    <span className="text-4xl font-bold text-primary">{formatBytes(selectedClient.total_sent).split(' ')[0]}</span>
                    <span className="text-lg text-slate-500 mb-1">{formatBytes(selectedClient.total_sent).split(' ')[1]}</span>
                  </div>
                </div>
                <div className="glass p-6">
                  <h4 className="text-sm font-medium text-slate-400 uppercase tracking-widest mb-4">Cumulative Download</h4>
                  <div className="flex items-end gap-3">
                    <span className="text-4xl font-bold text-secondary">{formatBytes(selectedClient.total_received).split(' ')[0]}</span>
                    <span className="text-lg text-slate-500 mb-1">{formatBytes(selectedClient.total_received).split(' ')[1]}</span>
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div className="h-full glass flex flex-col items-center justify-center p-12 text-center space-y-4">
              <div className="bg-primary/10 p-6 rounded-full">
                <Activity size={48} className="text-primary/50" />
              </div>
              <div>
                <h3 className="text-2xl font-bold">Select a device to view history</h3>
                <p className="text-slate-500 mt-2 max-w-sm">
                  Click on any active PC from the list to see their specific internet usage trends and cumulative data.
                </p>
              </div>
            </div>
          )}
        </section>
      </div>
    </div>
  );
};

export default App;
