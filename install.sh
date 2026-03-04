#!/bin/bash

# Konfigurasi Warna
GREEN='\033[0;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${CYAN}===================================================${NC}"
echo -e "${GREEN}   AUTO INSTALLER SCANNER PRO v2.7 VIP (TELEGRAM)  ${NC}"
echo -e "${CYAN}===================================================${NC}"
echo -e "${YELLOW}Silakan masukkan data Telegram Bot Anda:${NC}"

# PROMPT INTERAKTIF
read -p "Masukkan BOT TOKEN (dari @BotFather): " BOT_TOKEN
read -p "Masukkan ADMIN ID (Angka ID Telegram Anda): " ADMIN_ID

if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
    echo -e "\n\033[0;31m[ERROR] Token atau ID tidak boleh kosong! Instalasi dibatalkan.\033[0m"
    exit 1
fi

echo -e "\n${YELLOW}[1/5] Memperbarui sistem & menginstal dependensi...${NC}"
apt update -y && apt upgrade -y
apt install curl nano ufw -y

echo -e "\n${YELLOW}[2/5] Menginstal Node.js (v20) & PM2...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
npm install -g pm2

echo -e "\n${YELLOW}[3/5] Menyiapkan modul Backend & Telegram Bot...${NC}"
mkdir -p /root/scanner-backend
cd /root/scanner-backend
npm init -y
npm install express cors axios node-telegram-bot-api

echo -e "\n${YELLOW}[4/5] Merakit Mesin Server (server.js)...${NC}"

# Menulis server.js tanpa mengeksekusi variabel bash di dalamnya
cat << 'EOF' > server.js
const express = require('express');
const cors = require('cors');
const net = require('net');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const TelegramBot = require('node-telegram-bot-api');

// --- KONFIGURASI BOT ---
const BOT_TOKEN = 'INSERT_TOKEN_HERE'; 
const ADMIN_ID = 'INSERT_ID_HERE';

const app = express();
app.use(cors());

const DB_FILE = path.join(__dirname, 'database.json');
if (!fs.existsSync(DB_FILE)) fs.writeFileSync(DB_FILE, JSON.stringify({ "ANSOR-VIP": 100 }, null, 2));
const readDB = () => JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
const writeDB = (data) => fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2));

const CACHE_FILE = path.join(__dirname, 'cache.json');
if (!fs.existsSync(CACHE_FILE)) fs.writeFileSync(CACHE_FILE, JSON.stringify({}, null, 2));
const readCache = () => JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8'));
const writeCache = (data) => fs.writeFileSync(CACHE_FILE, JSON.stringify(data, null, 2));

// --- BOT TELEGRAM ---
const bot = new TelegramBot(BOT_TOKEN, { polling: true });
let botState = {}; 

const sendMainMenu = (chatId) => {
    const options = {
        reply_markup: JSON.stringify({
            inline_keyboard: [
                [{ text: '➕ Buat Lisensi Baru', callback_data: 'create' }],
                [{ text: '📋 Lihat Daftar Lisensi', callback_data: 'list' }],
                [{ text: '🗑️ Hapus Lisensi', callback_data: 'delete' }]
            ]
        })
    };
    bot.sendMessage(chatId, "🛠️ *Panel Admin Scanner Pro* 🛠️\n\nSilakan pilih menu di bawah ini:", { parse_mode: 'Markdown', ...options });
};

bot.onText(/\/start/, (msg) => {
    if (msg.chat.id.toString() !== ADMIN_ID) return; 
    botState[msg.chat.id] = null; 
    sendMainMenu(msg.chat.id);
});

bot.on('callback_query', (query) => {
    const chatId = query.message.chat.id;
    if (chatId.toString() !== ADMIN_ID) return;
    const action = query.data;

    if (action === 'create') {
        botState[chatId] = 'AWAITING_POINTS';
        bot.sendMessage(chatId, "Berapa jumlah poin untuk lisensi ini?\n\n*(Ketik angkanya saja, misal: 50)*", { parse_mode: 'Markdown' });
    } else if (action === 'list') {
        const db = readDB();
        let text = "📋 *Daftar Lisensi & Sisa Poin:*\n\n";
        let count = 0;
        for (let key in db) { text += `🔑 \`${key}\` : *${db[key]} Poin*\n`; count++; }
        if (count === 0) text += "_Belum ada lisensi terdaftar._\n";
        bot.sendMessage(chatId, text, { parse_mode: 'Markdown' });
        sendMainMenu(chatId); 
    } else if (action === 'delete') {
        botState[chatId] = 'AWAITING_DELETE';
        bot.sendMessage(chatId, "Ketik atau *Paste kode lisensi* yang ingin dihapus:", { parse_mode: 'Markdown' });
    }
    bot.answerCallbackQuery(query.id); 
});

bot.on('message', (msg) => {
    const chatId = msg.chat.id;
    if (chatId.toString() !== ADMIN_ID || msg.text.startsWith('/')) return;
    const state = botState[chatId];

    if (state === 'AWAITING_POINTS') {
        const points = parseInt(msg.text.trim());
        if (isNaN(points)) {
            bot.sendMessage(chatId, "⚠️ *Gagal!* Harap masukkan format angka.", { parse_mode: 'Markdown' });
        } else {
            const db = readDB();
            const uniqueCode = 'VIP-' + Math.random().toString(36).substring(2, 8).toUpperCase();
            db[uniqueCode] = points;
            writeDB(db);
            bot.sendMessage(chatId, `✅ *Lisensi Berhasil Dibuat!*\n\n🔑 Kode: \`${uniqueCode}\`\n💰 Poin: *${points}*`, { parse_mode: 'Markdown' });
        }
        botState[chatId] = null;
        setTimeout(() => sendMainMenu(chatId), 1000);
    } else if (state === 'AWAITING_DELETE') {
        const codeToDelete = msg.text.trim();
        const db = readDB();
        if (db[codeToDelete] !== undefined) {
            delete db[codeToDelete]; writeDB(db);
            bot.sendMessage(chatId, `🗑️ Lisensi \`${codeToDelete}\` berhasil dihapus.`, { parse_mode: 'Markdown' });
        } else {
            bot.sendMessage(chatId, `⚠️ Lisensi \`${codeToDelete}\` tidak ditemukan!`, { parse_mode: 'Markdown' });
        }
        botState[chatId] = null;
        setTimeout(() => sendMainMenu(chatId), 1000);
    }
});

// --- API BACKEND ---
let ipTracker = {};
let currentDate = new Date().toDateString();
const processedBatches = {};

const checkAndConsumeLimit = (req, type) => {
    const key = req.query.key || '';
    const batch = req.query.batch || '';
    let ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    if (ip.includes(':')) ip = ip.split(':').pop();

    const db = readDB();
    const now = Date.now();
    
    if (key && db[key] !== undefined) {
        if (db[key] <= 0) return { allowed: false, error: 'Poin lisensi habis! Silakan top-up.' };
        if (batch) {
            if (!processedBatches[key]) processedBatches[key] = [];
            if (!processedBatches[key].includes(batch)) {
                db[key] -= 1; writeDB(db);
                processedBatches[key].push(batch);
                if (processedBatches[key].length > 20) processedBatches[key].shift();
            }
        } else {
            db[key] -= 1; writeDB(db);
        }
        return { allowed: true, isPremium: true, points: db[key] };
    }

    const today = new Date().toDateString();
    if (currentDate !== today) { ipTracker = {}; currentDate = today; }
    if (!ipTracker[ip]) ipTracker[ip] = { grab: 0, scan: 0 };
    if (ipTracker[ip][type] >= 2) return { allowed: false, error: 'Batas gratis harian habis!' };

    if (batch) {
        const ipBatchKey = ip + '-' + type;
        if (!processedBatches[ipBatchKey]) processedBatches[ipBatchKey] = [];
        if (!processedBatches[ipBatchKey].includes(batch)) {
            ipTracker[ip][type] += 1;
            processedBatches[ipBatchKey].push(batch);
            if (processedBatches[ipBatchKey].length > 10) processedBatches[ipBatchKey].shift();
        }
    } else {
        ipTracker[ip][type] += 1;
    }
    return { allowed: true, isPremium: false, limit: 2 - ipTracker[ip][type] };
};

const runCurl = (url) => {
    return new Promise((resolve) => {
        exec(`curl -s "${url}"`, (error, stdout) => { if (error) resolve(""); else resolve(stdout); });
    });
};

app.get('/subdomain', async (req, res) => {
    const domain = req.query.domain;
    if (!domain) return res.status(400).json({ error: 'Domain wajib diisi' });

    const auth = checkAndConsumeLimit(req, 'grab');
    if (!auth.allowed) return res.status(403).json({ error: auth.error, needTopup: true });

    const cacheData = readCache();
    const now = Date.now();
    const CACHE_TTL = 24 * 60 * 60 * 1000; 

    if (cacheData[domain] && (now - cacheData[domain].timestamp < CACHE_TTL)) {
        return res.json({ subdomains: cacheData[domain].subdomains, auth, cached: true });
    }

    const subs = new Set();
    const reqConfig = { timeout: 15000 };

    const p1 = axios.get(`https://jldc.me/anubis/subdomains/${domain}`, reqConfig).then(r => { if(Array.isArray(r.data)) r.data.forEach(s => subs.add(s.trim().toLowerCase())); }).catch(() => {});
    const p2 = axios.get(`https://crt.sh/?q=%25.${domain}&output=json`, reqConfig).then(r => { if(Array.isArray(r.data)) r.data.forEach(e => e.name_value.split('\n').forEach(s => subs.add(s.trim().toLowerCase()))); }).catch(() => {});
    const p3 = axios.get(`https://otx.alienvault.com/api/v1/indicators/domain/${domain}/passive_dns`, reqConfig).then(r => { if(r.data && r.data.passive_dns) r.data.passive_dns.forEach(e => subs.add(e.hostname.trim().toLowerCase())); }).catch(() => {});
    const p4 = axios.get(`https://api.threatminer.org/v2/domain.php?q=${domain}&rt=5`, reqConfig).then(r => { if(r.data && Array.isArray(r.data.results)) r.data.results.forEach(s => subs.add(s.trim().toLowerCase())); }).catch(() => {});
    const p5 = runCurl(`https://api.hackertarget.com/hostsearch/?q=${domain}`).then(data => { if (data && !data.includes('error') && !data.includes('API count')) { data.split('\n').forEach(line => { const parts = line.split(','); if (parts.length > 0) subs.add(parts[0].trim().toLowerCase()); }); } }).catch(() => {});

    await Promise.allSettled([p1, p2, p3, p4, p5]);

    const finalSubs = Array.from(subs).filter(sub => sub.endsWith(domain) && sub !== domain && !sub.startsWith('*'));
    cacheData[domain] = { timestamp: now, subdomains: finalSubs };
    writeCache(cacheData);

    res.json({ subdomains: finalSubs, auth, cached: false });
});

const checkPort = (ip, port, timeout = 3000) => {
    return new Promise((resolve) => {
        const socket = new net.Socket();
        const startTime = Date.now();
        let isResolved = false;
        socket.setTimeout(timeout);
        socket.on('connect', () => { if (!isResolved) { isResolved = true; socket.destroy(); resolve({ port, ok: true, latency: Date.now() - startTime }); } });
        const handleError = () => { if (!isResolved) { isResolved = true; socket.destroy(); resolve({ port, ok: false, latency: -1 }); } };
        socket.on('timeout', handleError); socket.on('error', handleError);
        socket.connect(port, ip);
    });
};

app.get('/tcp', async (req, res) => {
    const { ip, ports } = req.query;
    if (!ip || !ports) return res.status(400).json({ error: 'IP dan Ports wajib diisi' });

    const auth = checkAndConsumeLimit(req, 'scan');
    if (!auth.allowed) return res.status(403).json({ error: auth.error, needTopup: true });

    const portArray = ports.split(',').map(Number).filter(Boolean);
    let country = 'UNK';
    try {
        const geoRes = await axios.get(`http://ip-api.com/json/${ip}?fields=countryCode`, { timeout: 3000 });
        if (geoRes.data && geoRes.data.countryCode) country = geoRes.data.countryCode;
    } catch (e) {}

    const results = await Promise.all(portArray.map(p => checkPort(ip, p)));
    res.json({ country, results, auth });
});

const PORT = 3001;
app.listen(PORT, '0.0.0.0', () => { console.log(`Backend Scanner berjalan di port ${PORT}`); });
EOF

# Menyuntikkan Token & ID yang dimasukkan user ke dalam file server.js
sed -i "s|INSERT_TOKEN_HERE|$BOT_TOKEN|g" server.js
sed -i "s|INSERT_ID_HERE|$ADMIN_ID|g" server.js

echo -e "\n${YELLOW}[5/5] Mengatur Firewall & Menjalankan Bot dengan PM2...${NC}"
ufw allow 3001/tcp > /dev/null 2>&1

pm2 stop scanner-api > /dev/null 2>&1
pm2 delete scanner-api > /dev/null 2>&1
pm2 start server.js --name "scanner-api"
pm2 save
env_path=$(pm2 startup | grep "sudo env PATH")
eval "$env_path" > /dev/null 2>&1

VPS_IP=$(curl -s ifconfig.me)

echo -e "\n${CYAN}===================================================${NC}"
echo -e "${GREEN}      INSTALASI SELESAI & SUKSES! 🚀               ${NC}"
echo -e "${CYAN}===================================================${NC}"
echo -e "1. VPS URL untuk Aplikasi Anda: ${YELLOW}http://$VPS_IP:3001${NC}"
echo -e "2. Silakan buka Bot Telegram Anda dan ketik: ${GREEN}/start${NC}"
echo -e "==================================================="
