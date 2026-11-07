# Slop+ 🍿

**Alpha 0.1** · *"Another streaming subscription? Not on my watch."*

[🇧🇷 Português](README.md) · 🇺🇸 English

Slop+ is a Netflix-looking channel for Roku (except it's free and has a worse name). It plays content from Stremio-compatible addons. Your PC does all the heavy lifting, and the poor Roku Express just has to look pretty and show the video.

> Built by someone who "isn't a dev", powered by pure stubbornness and an AI assistant. If it works in my living room, it should work in yours. If it doesn't, open an issue and pray. 🙏

> ℹ️ The app UI and the install scripts speak Portuguese for now. Translations are a great first contribution!

---

## ⚠️ First things first (the serious part, I promise it's short)

- Slop+ **does not host, fetch on its own, or distribute any content**. Out of the box it only ships the public catalog (Cinemeta) and subtitles (OpenSubtitles). Video sources come from the addons **you** choose to add. Only watch what you have the right to watch. If things go sideways, that's on you, not on the code. 👀
- **Torrents expose your public IP** to everyone sharing the same file. That's how every BitTorrent client works, not a Slop+ thing. If that keeps you up at night, run a VPN on your PC.
- Not affiliated with Stremio or Roku. They don't even know we exist.
- This is **alpha**. Translation: there are bugs. Possibly many. But hey, it has "Continue watching"!

## 🧠 How it works

```
 Roku (Slop+ channel)  ──home Wi-Fi──▶  Windows PC (the "backend")  ──▶  addons / torrents
   just looks pretty                     sweats, downloads, transcodes
```

What's inside:

- 🏠 **Home** with "Continue watching", catalogs and search
- 📺 **Details** with seasons and episodes (with thumbnails, fancy)
- 🧲 **Source list** sorted by quality (4K > 1080p > 720p > SD > "filmed in a theater with a potato") and, within each, by peer count
- ▶️ **Player** with controls, audio track switching and subtitles (language, size, color, background and sync, for that one movie where subs are always 2 seconds late)
- ⏱️ **Remembers where you stopped**, even if you switch torrents (yes, we care)
- 🎮 Transcodes on your NVIDIA GPU (NVENC) if you have one; otherwise your CPU suffers a little
- 🧹 Wipes the previous video's cache when you play the next one. Your hard drive says thanks.

## 🛒 You'll need

- A **Roku** (tested on the Roku Express, the humblest of them all) on the same network as your PC
- A **Windows 10/11 PC** that stays on while you watch (it's the engine; the Roku is the steering wheel)
- **Node.js 20 or newer** ([nodejs.org](https://nodejs.org), grab the LTS and keep clicking "Next")

## 🛠️ Installation (easier than assembling IKEA furniture, I swear)

### 1. Put your Roku in developer mode ("hacker mode")

1. On the Roku remote, enter the secret code: **Home 3x, Up 2x, Right, Left, Right, Left, Right**. Yes, really. It's basically the Konami Code, Roku edition.
2. Write down the **IP** shown on screen (e.g. `192.168.0.50`).
3. Accept the terms (nobody reads them, we know), enable the installer and **create a password**. Write that down too.
4. The Roku reboots. Breathe.

> 🔒 Your Roku IP and password are **yours**. They stay **only on your PC**, in a file git ignores. **Never** paste them into an issue, a pull request or a screenshot on Twitter. Seriously.

### 2. Download Slop+

At the top of this page, click **Code > Download ZIP** and extract it anywhere (e.g. `Documents\slop-plus`).

### 3. Run the magic installer 🪄

Open the extracted folder, right-click an empty spot and choose **Open in Terminal**. Then paste:

```powershell
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
```

The installer will:
1. check that Node.js is there;
2. download the dependencies (go grab a coffee ☕);
3. **ask for your Roku IP and password**;
4. start the backend, which from now on starts by itself with Windows;
5. install the **Slop+** channel on your Roku.

If Windows asks about the **Firewall** for Node.js, click **Allow** (private network). Without it, your Roku just yells into the void.

### 4. Get some sources

Out of the box, Slop+ only has the catalog and subtitles. It's like a Netflix display model: you can browse everything, but nothing plays. To get video sources, add Stremio addons of your choice:

- **Import from your Stremio account** (grabs the same addons you already use there):
  ```powershell
  cd backend
  npm run import
  ```
  Your email and password are only used to log in to Stremio and are **never saved**. Not even we see them.
- **The old-school way:** edit `backend\config.json` and add each addon's `manifest.json` URL to the `addons` list.

Then restart the backend: run `.\instalar-autostart.ps1` again, or do the classic "turn it off and on again" on your PC.

## 🛋️ Everyday use

- Open **Slop+** on your Roku. The backend is already running on the PC, quietly doing its best.
- **Search:** the `*` key on Home.
- **In the player:**
  - **OK:** pause and resume.
  - **Left/right:** back or forward 10s. ⏪/⏩ skip 30s.
  - **Down:** shows the buttons (subtitles, audio, style).
  - **`*`:** jumps straight to the subtitles menu.
- 💡 Pro tip: **1080p sources with a green dot** (lots of peers) start fast. A 60 GB 4K file with 3 peers will teach you the true meaning of patience.

## 🔐 Privacy: what lives where

| Data | Where it lives | Goes to GitHub? |
|---|---|---|
| Roku IP and password | `configuracao-local.json` | No (git ignores it) |
| Your addons | `backend\config.json` | No (git ignores it) |
| History / where you stopped | `%LOCALAPPDATA%\SlopPlus\history.json` | No (outside the folder) |
| PC IP | only inside the package sent to the Roku | No |
| Downloaded videos | Windows temp folder, wiped when you switch videos | No, and it couldn't anyway |

The backend only accepts connections from your home network (private IPs). If someone opens port 8787 on the router by mistake, requests from the internet get a 403 to the face. Still, **don't open that port on your router.**

## 🆘 Something broke?

| Symptom | What to do |
|---|---|
| "Conectando ao Slop+ no seu PC..." forever | Is the PC on? Is the backend running? Check the log at `%LOCALAPPDATA%\SlopPlus\backend.log`. Check the Firewall. |
| Deploy failed | Wrong Roku IP or password, or developer mode got turned off. Run `instalar.ps1` again. |
| Your PC's IP changed | Run `.\deploy.ps1 -PcIp NEW_IP`, or reserve the PC's IP on your router (DHCP reservation). |
| Slow to start | Pick a source with more peers or lower quality. Your Roku Express is not NASA. |
| I want to stop the auto-start | `.\instalar-autostart.ps1 -Remover` |

## 🤓 For developers (the real ones)

```
backend/          Node.js: addon aggregation, WebTorrent, ffmpeg (HLS), history
  server.js       API used by the Roku (/api/home, /api/streams, /api/play, ...)
  supervisor.js   resurrects the backend if it crashes
  *.test.js       tests (npm test); e2e-*.js use public-domain torrents
roku/             BrightScript + SceneGraph channel
  components/     screens (Home, Details, Sources, Player) and components
tools/            channel image generator
deploy.ps1        packages and sends the channel to the Roku (-SoEmpacotar only builds the zip)
```

- Backend tests: `cd backend; npm test`
- BrightScript validation: `cd roku; npx brighterscript --createPackage false`
- **Contributions are very welcome!** Open an issue or send a pull request. The installer is Windows-only for now; Linux/macOS support would be lovely. Player improvements, English UI and better jokes for this README also count.

## 🙌 Credits and licenses

- Slop+ code: [MIT](LICENSE). Do whatever you want, just don't blame us.
- [Poppins](https://fonts.google.com/specimen/Poppins) font: SIL Open Font License (`roku/fonts/OFL.txt`)
- [WebTorrent](https://webtorrent.io) (MIT) and [FFmpeg](https://ffmpeg.org) (downloaded at install time via `ffmpeg-static`; LGPL/GPL)
- Compatible with the [Stremio addon protocol](https://github.com/Stremio/stremio-addon-sdk), thanks for keeping it open ❤️
