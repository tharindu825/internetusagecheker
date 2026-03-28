# 🌐 Internet Usage Tracker (v3.1)

A high-precision, real-time monitoring system for tracking internet consumption across 25+ Windows systems. It automatically shields local SMB, NAS, and Backup traffic with **99.9% accuracy**.

## ✨ Key Features (v3.1)

- 🛡️ **High-Precision Global Shield**: Automatically excludes local file transfers (SMB) from internet totals, even over VPNs like Tailscale/Radmin.
- 🚀 **5% Framing Compensation**: Accounts for TCP/IP overhead that standard protocol counters miss.
- 🔒 **Identity Lock (v3.0)**: Prevents duplicate PC entries by locking usage to a normalized hostname.
- ⚛️ **Real-Time Dashboard**: Beautiful, live monitoring via React + socket.io with historical daily trends.
- ☢️ **Nuclear Reset**: One-click "Fresh Start" capability to wipe all metadata and history.

## 🛠️ Quick Start

### 1. Server Setup (Main PC)
1. Ensure [Node.js](https://nodejs.org/) is installed.
2. Run `npm install` in both `/server` and `/dashboard` folders.
3. Use **`run_all.bat`** to start the infrastructure.

### 2. Client Deployment (Target PCs)
1. Copy the `agent` folder to the target machine.
2. Right-click **`InstallAgent.bat`** and select **"Run as Administrator"**.

### 🔧 Maintenance Tools
- **`FIX-ALL-NOW.bat` (Admin)**: The ultimate "Reset Button". It kills all processes, clears database duplicates, and performs a full data purge.
- **`stop_all.bat`**: Gracefully stops all local monitoring processes.

---

## 📖 Complete Documentation
For detailed setup instructions, architecture breakdown, and advanced configuration, see the [**Comprehensive GUIDE.md**](file:///f:/Onedrive/Tharindu/Researches/InternetUsage_Checker/internetusagecheker/GUIDE.md).
