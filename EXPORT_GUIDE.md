# Export guide: web build and GitHub Pages

This guide covers two things:

- **Part 1:** turning the Godot project into a web build (`index.html` plus a few files) and testing it on your PC.
- **Part 2:** putting that build on GitHub Pages so anyone can play it at an address like
  `https://kulurc.github.io/tether-game/`.

Two folders matter:

| Folder | What's in it |
|---|---|
| `C:\Users\kylea\Desktop\CraveFX_Assessment\platformer` | The Godot project (open this in Godot) |
| `C:\Users\kylea\Desktop\CraveFX_Assessment\Builds` | Exported builds, **outside** the project. `Builds\Web` is the web build; `run_web.bat` / `serve.py` test it |

Keeping builds outside the project means Godot never tries to import them, and they don't end up in the
project's git repository.

---

## Part 1: export the game as a web build

### What you get

Exporting writes these files into `CraveFX_Assessment\Builds\Web\`:

| File | What it is |
|---|---|
| `index.html` | The page you open. It loads everything below. |
| `index.wasm` | The Godot engine compiled for browsers (~38 MB). It only changes if you change Godot version. |
| `index.pck` | **Your game**: scenes, scripts, fonts, audio (~11 MB: includes the music, character sprite sheets and sound effects). This is what changes when you edit the game. |
| `index.js` | Starts the engine. |
| `index.audio.worklet.js`, `index.audio.position.worklet.js` | Audio playback. |
| `index.png`, `index.icon.png`, `index.apple-touch-icon.png` | Loading-screen logo and icons. |

All of these must stay together in the same folder.

### One-time setup

1. **Export templates.** Godot needs the web export templates for its exact version (4.5.1).
   In Godot: **Editor → Manage Export Templates…**. If it says *Installed* for 4.5.1, you're done.
   Otherwise click **Download and Install**. They're already installed on this PC.
2. **Export preset.** The project already has a **Web** preset (it's stored in `export_presets.cfg`).
   Open **Project → Export…** and check that **Web** is in the list on the left. If it's missing (for example,
   in a fresh copy of the project): **Add… → Web**, then use these settings:

   | Setting | Value | Why |
   |---|---|---|
   | Name | `Web` | The command-line export refers to it by this name |
   | Export Path | `../Builds/Web/index.html` | Relative to the project folder, so it lands in `CraveFX_Assessment\Builds\Web\index.html`. The file must be named `index.html` so web hosts open it automatically |
   | Variant → **Thread Support** | **Off** | Runs on any plain web host (GitHub Pages, itch.io) without special server settings. Turning it on breaks GitHub Pages |
   | Variant → Extensions Support | Off | Not used by this project |
   | VRAM Texture Compression → For Desktop | On | Default |
   | HTML → Canvas Resize Policy | Adaptive | Game fills the browser window |
   | HTML → Focus Canvas on Start | On | Keyboard works without clicking first (in most browsers) |
   | Resources → Exclude filter | `_archive_v1/*` | Keeps the old prototype out of the game file |

### Before every export: checklist

- [ ] **Main scene.** Project → Project Settings → Application → Run → **Main Scene** is the level the game should
      start in (currently `Scenes/MainMenu.tscn`, which starts `Level1_Visual`).
- [ ] **Debug ticks on DialogueTriggers.** Any trigger with `debug` ticked is switched **off** in the build
      (drawn red with "DEBUG: OFF" in the editor). The Level1_Visual **Intro** trigger is ticked right now, so the
      intro is skipped. Untick it to play the intro.
- [ ] **Debug keys.** TetherRig → Debug → `debug_tools` (F2-F5 cheats). Untick it for a build other people will play.
- [ ] **FPS counter.** TetherRig → Debug → `show_fps` decides whether it starts on (F1 still toggles it).
- [ ] **Save everything** (Ctrl+Shift+S). Unsaved scene changes are not exported.

### Export from the editor

1. **Project → Export…**
2. Select **Web** on the left.
3. Click **Export Project…** (bottom of the window).
4. The path should be `.../CraveFX_Assessment/Builds/Web/index.html` (the preset fills it in). Keep the file name `index.html`.
5. **Untick "Export With Debug"** for a normal build. Debug builds are bigger and slower.
6. Click **Save**. It takes 10-30 seconds. Existing files in `Builds\Web\` are overwritten.
   If Godot says the target folder doesn't exist, create `CraveFX_Assessment\Builds\Web` first.

### Export from the command line (optional)

From PowerShell. This uses the same preset and gives the same result:

```powershell
& "C:\Users\kylea\Downloads\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe" --headless --path C:\Users\kylea\Desktop\CraveFX_Assessment\platformer --export-release "Web" C:\Users\kylea\Desktop\CraveFX_Assessment\Builds\Web\index.html
```

It's finished when the output ends with `[ DONE ] savepack`. Use `--export-debug` instead of `--export-release` for a debug build.

### Test the build on your PC

A browser **won't** run the game if you double-click `index.html`. Pages opened from a file (`file://...`) aren't
allowed to load `index.wasm` and `index.pck`, so you'd see a blank page or an error. The files have to come from a web server, even a local one:

1. Double-click **`CraveFX_Assessment\Builds\run_web.bat`**. A console window opens and your browser opens
   **http://127.0.0.1:8060/**. (This needs Python, which is installed on this PC.)
   - From a terminal instead: `python C:\Users\kylea\Desktop\CraveFX_Assessment\Builds\serve.py`
     (add a number for another port, e.g. `... serve.py 9000`).
2. Click the game once so it gets keyboard focus. Browsers also only allow sound to start after a click or key press.
3. Check: F1 toggles the FPS counter, the intro plays (if you unticked its `debug`), there's sound, and the movement is smooth.
4. Close the console window to stop the server.

### Troubleshooting

| Problem | Fix |
|---|---|
| Blank page, or an error about `file://` / CORS | You opened `index.html` directly. Use `run_web.bat`. |
| `run_web.bat` window closes or says the address is in use | Another server is already on port 8060. Close the other console window, or run `serve.py` with another port (`python ...\Builds\serve.py 9000`) and open http://127.0.0.1:9000/. |
| Browser still shows the old version | Hard refresh with **Ctrl+F5** (or open the page in a private/incognito window). |
| Error mentioning **SharedArrayBuffer** or "cross-origin isolation" | Thread Support got turned on in the preset. Turn it **off** and export again. |
| "No export template found" | Editor → Manage Export Templates → Download and Install (it must match Godot 4.5.1 exactly). |
| Game is choppy | Check the FPS counter (F1). Art drawn with many `draw_circle` / `draw_colored_polygon` calls is very slow in browsers. Use the `FastDraw` helpers instead (`Scripts/Visual/fast_draw.gd`). |
| Looks slightly different from the editor | Browsers use the **Compatibility** renderer (WebGL 2) instead of Forward+. Shaders can look a little different. |

---

## Part 2: host the game on GitHub Pages

GitHub Pages hosts plain files for free, the same way your portfolio is hosted. The web build is just plain
files, so it works as long as **Thread Support stays off** (GitHub Pages can't send the special server headers a
threaded build needs).

The address is `https://<username>.github.io/<repository name>/`. A repository named `tether-game` on the
account `Kulurc` is served at **https://kulurc.github.io/tether-game/**. Pick the name you want in the address.

**Use a separate repository for the build, not the `Platformer` source repository.** That keeps the 38 MB
engine file out of your source history, and the game's address stays the same even if you reorganise the source.

### One-time setup

**Step 1: create the repository on GitHub**

1. On github.com, click **+** (top right) → **New repository**.
2. Repository name: e.g. `tether-game`. This becomes the end of the address.
3. Visibility: **Public** (GitHub Pages for private repositories needs a paid plan).
4. Leave **Add a README**, **.gitignore** and **license** all off. The repository must start empty.
5. Click **Create repository**. Keep the page open; it shows the repository's address
   (`https://github.com/Kulurc/tether-game.git`).

**Step 2: make a local folder with the build in it**

The build files must be at the **top level** of the repository (`index.html` at the top, not inside a `Web/` folder).

```powershell
New-Item -ItemType Directory -Force C:\Users\kylea\Desktop\tether-game
```
```powershell
Copy-Item C:\Users\kylea\Desktop\CraveFX_Assessment\Builds\Web\* C:\Users\kylea\Desktop\tether-game\ -Force
```

**Step 3: add a `.nojekyll` file**

This empty file tells GitHub Pages to serve the files exactly as they are. Without it, Pages first runs its
site builder (Jekyll), which makes each deploy slower and can skip some files.

```powershell
New-Item -ItemType File -Force C:\Users\kylea\Desktop\tether-game\.nojekyll
```

**Step 4: upload (push) the files**

```powershell
cd C:\Users\kylea\Desktop\tether-game; git init; git add .; git commit -m "Web build"; git branch -M main; git remote add origin https://github.com/Kulurc/tether-game.git; git push -u origin main
```

Change `tether-game` in the URL if you picked another name. The first push uploads ~40 MB and can take a minute.
If git asks you to sign in, a browser window opens for it.

*No-terminal alternative:* on the empty repository page, click **uploading an existing file** and drag in every file
from `C:\Users\kylea\Desktop\tether-game\`, then **Commit changes**. Windows Explorer hides `.nojekyll`
(View → Show → Hidden items). If it's missing after uploading, use **Add file → Create new file**,
name it `.nojekyll`, leave it empty, and commit.

**Step 5: turn on GitHub Pages**

1. In the repository: **Settings → Pages** (left sidebar).
2. Under **Build and deployment**:
   - Source: **Deploy from a branch**
   - Branch: **main**, folder: **/ (root)**
3. Click **Save**.

**Step 6: open the game**

Wait 1-2 minutes. You can watch progress in the repository's **Actions** tab (a green tick = live). The
address appears at the top of **Settings → Pages** ("Your site is live at ..."):

**https://kulurc.github.io/tether-game/**

### Updating the game later

1. Export again (Part 1). This updates `CraveFX_Assessment\Builds\Web\`.
2. Copy the new files over and push them:

```powershell
Copy-Item C:\Users\kylea\Desktop\CraveFX_Assessment\Builds\Web\* C:\Users\kylea\Desktop\tether-game\ -Force
```
```powershell
cd C:\Users\kylea\Desktop\tether-game; git add .; git commit -m "Update build"; git push
```

3. Wait a minute, then open the address with **Ctrl+F5**. Browsers can hold on to the old files for a while, so a normal refresh may still show the previous version.

Usually only `index.pck` (your game) changes, so updates are small. `index.wasm` only changes when you change Godot version.

### Sharing it

- **Link:** share `https://kulurc.github.io/tether-game/` or link to it from your portfolio.
- **Embed it in a page** (e.g. on your portfolio):

  ```html
  <iframe src="https://kulurc.github.io/tether-game/" width="1280" height="720"
          allow="autoplay; fullscreen" style="border:0; max-width:100%;"></iframe>
  ```

- **Phones and tablets:** the page loads on recent Android/iPhone browsers, but the game uses keyboard and mouse
  only, with no on-screen touch controls. Phone players can't play it yet.
- **First load** downloads about 40 MB (less over the network, since GitHub compresses it). That's fine on Wi-Fi,
  slower on mobile data. Later visits load from the browser's cache.

### Taking it down

Settings → Pages → set Source to **None** (keeps the repository), or delete the repository
(Settings → General → Danger Zone → Delete this repository).

### Other places to host (same build)

- **itch.io:** zip the *contents* of `CraveFX_Assessment\Builds\Web\` (with `index.html` at the top of the zip), create a project,
  set Kind to **HTML**, upload the zip, tick **This file will be played in the browser**, and set the viewport to 1280×720.
