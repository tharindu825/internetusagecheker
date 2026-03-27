# 🚀 Internet Usage Tracker - Comprehensive Guide

A centralized system designed to monitor real-time internet usage across multiple Windows systems while automatically excluding local (LAN) and backup traffic.

---

## 🏗️ System Architecture

The system consists of three main components:
1.  **Backend Server (`/server`)**: A Node.js Express server with SQLite storage. It acts as the central "brain" that collects reports from all client PCs via a REST API.
2.  **Frontend Dashboard (`/dashboard`)**: A modern React-based monitoring interface with real-time charts and historical tables.
3.  **Client Agent (`/agent`)**: A lightweight PowerShell script that runs as a background task on every monitored PC, calculating and reporting internet consumption every 30 seconds.

---

## 🛠️ Server Setup (Main PC)

### 1. Requirements
Ensure you have [Node.js](https://nodejs.org/) installed on your main PC.

### 2. Installations
Run these commands in the root directory:
```powershell
# Install server dependencies
cd server
npm install

# Install dashboard dependencies
cd ../dashboard
npm install
```

### 3. Launching the System
You have three options for starting the tracker on your main PC:
*   **Visible (Manual)**: Double-click **`run_all.bat`**. This opens two terminal windows showing logs.
*   **Silent (Background)**: Double-click **`Run-Tracker-Hidden.bat`**. This launches everything in the background with zero windows.
*   **Stop Everything**: Double-click **`stop_all.bat`** to kill all background server processes.

> [!TIP]
> Your dashboard will be available at: **http://localhost:5173**

---

## 📡 Client Deployment (Target PCs)

To start tracking internet usage on a new PC, follow these steps:

1.  **Copy the `agent` folder** to the target PC (via USB or Network Share).
2.  **Right-click `InstallAgent.bat`** and select **"Run as Administrator"**.
    - This automatically bypasses execution policies and registers the agent as a hidden Windows Scheduled Task.
3.  **Verify**: Open **`check_status.bat`** to confirm the agent is running and has a valid PID.

### 🛑 Managing the Agent
*   **Stop Agent**: Right-click `stop_agent.bat` (Run as Admin).
*   **Uninstall**: Run `Unregister-ScheduledTask -TaskName WindowsInternetUsageTracker` in Administrator PowerShell.

---

## 📊 Dashboard Features

### Real-Time Monitoring
*   **Online/Offline Status**: PCs are automatically marked as "Offline" if they stop reporting for more than 90 seconds.
*   **Live Bandwidth Indication**: Small blue/green indicators show real-time Upload/Download activity as it happens.

### Historical Tracking
*   **Usage Charts**: Click any PC to see its consumption trends over the last 24 reports.
*   **Daily Breakdown**: See exactly how much data each PC used per day in the "Internet Usage by Date" table.

### Data Cleanup
If you have old or duplicate PC entries (e.g., from a re-installation):
1.  Wait for the old entry to show as **"Offline"**.
2.  Hover over the card in the list and click the **Red Trash Icon**.

---

## 🛡️ How It Excludes Local Traffic

The agent uses **low-level Windows Network Statistics (IP Helper API)** to ensure **Backup and Local** traffic is perfectly excluded:

1.  **Per-Connection Tracking**: The agent monitors every active TCP connection on the system.
2.  **Private IP Filtering**: It identifies the **Remote IP** of every connection and ignores it if it belongs to any RFC1918 private range:
    - `10.0.0.0/8`
    - `172.16.0.0/12`
    - `192.168.0.0/16`
    - `169.254.0.0/16` (APIPA)
3.  **True Byte Measurement**: Unlike basic counters, it queries the **exact bytes** transferred for each non-local connection, ensuring 100% accuracy for SMB, HTTP/S, and most backups.

---

## ⚙️ Configuration
The server IP is currently hardcoded to **`192.168.1.32`**. If your server PC's IP address changes, you must update the `$ServerUrl` variable in `agent/InternetUsageAgent.ps1` and re-run the `InstallAgent.bat` on your clients.
