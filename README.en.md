# Slop+ 🍿

**Alpha version 0.1** · *"Roku wants you to subscribe to yet another streaming service? Relax, chief."*

🇺🇸 English · [🇧🇷 Português](README.md)

Slop+ is a Roku channel that looks like a legit Stremio (except it's free and has a worse name). It uses addons from the Stremio ecosystem, your PC does the heavy lifting, and the poor little Roku Express (or Roku TV) just has to display the video.

> I'M NOT A DEV (I used to be, these days I just edit videos, man), just a stubborn guy who got fed up trying to watch sketchy streams on a Roku. THIS IS 200% VIBE CODED!!! If it worked at my place, it should work at yours. If not, open an issue and pray. 🙏

---

## First things first, the serious stuff (or something like that)

- Slop+ **doesn't host, download content on its own, or distribute anything**. It only comes with the public catalog (Cinemeta) and subtitles (OpenSubtitles). Video sources come from the addons **you** choose to add. Only watch stuff you have the right to watch. If things go sideways, well, they go sideways.
- **Torrenting exposes your public IP** to other people sharing the same file. That's how any torrent client works, not my fault or Slop+'s. If that keeps you up at night, use a VPN.
- We're not affiliated with Stremio, Roku, or any of the sources. They don't even know this thing exists.
- It's **alpha**. There are bugs. A lot? Maybe. But hey, it has "Continue Watching."

What's inside:

- 🏠 **Home** with "Continue Watching," catalogs, and search
- 📺 **Details** with seasons and episodes (with thumbnails, fancy stuff)
- 🧲 **Source list** sorted by quality (4K > 1080p > 720p > SD > "recorded in a movie theater") and, within each quality, by peer count
- ▶️ **Player** with controls, audio switching, subtitles (language, size, color, background, and sync, for that movie where the subtitles show up 2 seconds late)
- ⏱️ **Remembers where you left off**, even if you switch torrents (yeah, we care)
- 🎮 Encodes video using your NVIDIA GPU (NVENC) if you've got one; otherwise, your CPU suffers a little
- 🧹 Clears the previous video's cache when you play the next one. Your hard drive says thanks.

## What you'll need

- A **Roku** (tested on the Roku Express, the humblest of them all) on the same network as your PC.
- A **Windows 10/11 PC** that stays on while you're watching.
- **Node.js 20 or newer** ([nodejs.org](https://nodejs.org), grab the LTS version and keep clicking "Next" until it's done)

## Installation

### 1. Put your Roku in developer mode ("hacker mode")

1. On your Roku remote, enter the KUnami Code: **Home 3x, Up 2x, Right, Left, Right, Left, Right**. Seriously. Looks like the Konami Code, but that's Roku for you.
2. Write down the **IP** shown on the screen (e.g., `192.168.x.xx`).
3. Accept the terms (nobody reads those, we know), enable the installer, and **create a password**. Write that down too.
4. The Roku restarts. Breathe.

> Your Roku's IP and password are **yours**. They stay **on your PC only**, in a file that Git ignores. **Never** paste them into an issue, a pull request, or a screenshot on Twitter (RIP).

### 2. Download Slop+

At the top of this page, click **Code > Download ZIP** and extract it anywhere (e.g., `Documents\slop-plus\`).

### 3. Run the magic installer

Open the extracted folder, right-click an empty spot, and select **Open in Terminal**. Then paste:

```powershell
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
```

The installer will:
1. Check whether Node.js is there.
2. Download the dependencies.
3. **Ask for your Roku's IP and password**.
4. Start the backend, which will then launch automatically with Windows.
5. Install the **Slop+** channel on your Roku.

If Windows asks about the **Firewall** for Node.js, click **Allow** (private network). Without that, your Roku will just be screaming into the void.

### 4. Get yourself some sources

Out of the box, Slop+ only has the catalog and subtitles. So you can see everything, but nothing plays. To get video sources, add whichever Stremio addons you want:

- **Import from your Stremio account** (grabs the same addons you already use there):

  ```powershell
  cd backend
  npm run import
  ```

  Your email and password are only used to log in to Stremio and **aren't saved**. We don't see them either.
- **The old-school way:** edit `backend\config.json` and put each addon's `manifest.json` URL in the `addons` list.

Then restart the backend: run `.\instalar-autostart.ps1` again, or go with the classic "turn your PC off and on again."

## Everyday use

- Open **Slop+** on your Roku. The backend should already be running on your PC, quietly doing its best.
- **Search:** press `*` on the Home screen.
- **In the player:**
  - **OK:** pause/resume.
  - **Left/right:** skip back or forward 10s. ⏪/⏩ skip 30s.
  - **Down:** show the buttons (subtitles, audio, style).
  - **`*`:** open the subtitle menu directly.
- **1080p with a green dot** (lots of peers) starts pretty quickly. A 60 GB 4K file with 3 peers will take you right back to the days of dial-up internet and Tibia...

## Privacy: what goes where

| Data | Where it's stored | Goes to GitHub? |
|---|---|---|
| Roku IP and password | `configuracao-local.json` | No (Git ignores it) |
| Your addons | `backend\config.json` | No (Git ignores it) |
| History / where you left off | `%LOCALAPPDATA%\SlopPlus\history.json` | No (outside the project folder) |
| PC IP | Only inside the package sent to the Roku | No |
| Downloaded videos | Windows temp folder, deleted when switching videos | No, not even possible |

The backend only accepts connections from your home network (private IPs). If someone accidentally opens port 8787 on their router, requests from the internet get a 403 right in the face. Still, **don't open that port on your router.**

## Something broke?

| Symptom | What to do |
|---|---|
| Stuck on "Connecting to Slop+ on your PC..." forever | Is the PC on? Is the backend running? Check the log at `%LOCALAPPDATA%\SlopPlus\backend.log`. Check your Firewall. |
| Deploy failed | Wrong Roku IP or password, or developer mode got turned off. Run `instalar.ps1` again. |
| Your PC's IP changed | Run `.\deploy.ps1 -PcIp NEW_IP`, or reserve your PC's IP in your router (DHCP reservation). |
| Takes forever to start | Pick a source with more peers or lower quality. Your Roku Express isn't NASA. |
| Want to disable auto-start | `.\instalar-autostart.ps1 -Remover` |

## For actual devs

```text
backend/          Node.js: aggregates addons, WebTorrent, ffmpeg (HLS), history
  server.js       API used by Roku (/api/home, /api/streams, /api/play, ...)
  supervisor.js   brings the backend back to life if it crashes
  *.test.js       tests (npm test); e2e-*.js use public-domain torrents
roku/             BrightScript + SceneGraph channel
  components/     screens (Home, Details, Sources, Player) and components
tools/            channel image generator
deploy.ps1        packages and uploads the channel to Roku (-SoEmpacotar only generates the zip)
```

- Backend tests: `cd backend; npm test`
- BrightScript validation: `cd roku; npx brighterscript --createPackage false`
- **Contributions are very welcome!** Open an issue or send a pull request. Right now the installer only works on Windows; Linux/macOS support would be awesome. Player improvements, new languages, and better jokes for this README are welcome too.

## Credits and licenses

- Slop+ code: [MIT](LICENSE). Do whatever you want, just don't say it's my fault.
- [Poppins](https://fonts.google.com/specimen/Poppins) font: SIL Open Font License (`roku/fonts/OFL.txt`)
- [WebTorrent](https://webtorrent.io) (MIT) and [FFmpeg](https://ffmpeg.org) (downloaded during installation via `ffmpeg-static`; LGPL/GPL)
- Compatible with the [Stremio addon protocol](https://github.com/Stremio/stremio-addon-sdk), thanks for keeping it open ❤️
