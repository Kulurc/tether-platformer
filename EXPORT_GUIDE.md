# Export guide: web build and GitHub Pages

This guide covers two things:

- **Part 1:** turning the Godot project into a web build (`index.html` plus a few files) and testing it on your PC.
- **Part 2:** hosting that build on GitHub Pages, straight from this repository (`Kulurc/Platformer`), so anyone
  can play it at **https://kulurc.github.io/Platformer/**.

| Folder | What's in it |
|---|---|
| `CraveFX_Assessment\platformer` | The Godot project and git repository (open this in Godot) |
| `CraveFX_Assessment\platformer\docs` | **The web build.** GitHub Pages serves this folder. It has a `.gdignore` (Godot never imports it) and a `.nojekyll` (Pages serves the files exactly as they are) |
| `CraveFX_Assessment\Builds` | `run_web.bat` / `serve.py`: test the build in `docs\` on your PC |

---

## Part 1: export the game as a web build

### What you get

Exporting writes these files into `platformer\docs\`:

| File | What it is |
|---|---|
| `index.html` | The page you open. It loads everything below. |
| `index.wasm` | The Godot engine compiled for browsers (~38 MB). It only changes if you change Godot version. |
| `index.pck` | **Your game**: scenes, scripts, fonts, audio (~12 MB: includes the music, character sprite sheets and sound effects). This is what changes when you edit the game. |
| `index.js` | Starts the engine. |
| `index.audio.worklet.js`, `index.audio.position.worklet.js` | Audio playback. |
| `index.png`, `index.icon.png`, `index.apple-touch-icon.png` | Loading-screen logo and icons. |

All of these must stay together in `docs\`. Don't delete `docs\.gdignore` or `docs\.nojekyll`.

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
   | Export Path | `docs/index.html` | Inside the repository, in the folder GitHub Pages serves. The file must be named `index.html` so the site opens it automatically |
   | Variant → **Thread Support** | **Off** | Runs on any plain web host (GitHub Pages, itch.io) without special server settings. Turning it on breaks GitHub Pages |
   | Variant → Extensions Support | Off | Not used by this project |
   | VRAM Texture Compression → For Desktop | On | Default |
   | HTML → Canvas Resize Policy | Adaptive | Game fills the browser window |
   | HTML → Focus Canvas on Start | On | Keyboard works without clicking first (in most browsers) |

### Before every export: checklist

- [ ] **Main scene.** Project → Project Settings → Application → Run → **Main Scene** is the scene the game should
      start in (currently `Scenes/MainMenu.tscn`, which starts `Level1_Visual`).
- [ ] **Debug ticks on DialogueTriggers.** Any trigger with `debug` ticked is switched **off** in the build
      (drawn red with "DEBUG: OFF" in the editor). Untick them so intros play.
- [ ] **Debug keys.** TetherRig → Debug → `debug_tools` (F2-F5 cheats). Untick it for a build other people will play.
- [ ] **FPS counter.** TetherRig → Debug → `show_fps` decides whether it starts on (F1 still toggles it).
- [ ] **Save everything** (Ctrl+Shift+S). Unsaved scene changes are not exported.

### Export from the editor

1. **Project → Export…**
2. Select **Web** on the left.
3. Click **Export Project…** (bottom of the window).
4. The path should end in `platformer/docs/index.html` (the preset fills it in). Keep the file name `index.html`.
5. **Untick "Export With Debug"** for a normal build. Debug builds are bigger and slower.
6. Click **Save**. It takes 10-30 seconds. Existing files in `docs\` are overwritten.

### Export from the command line (optional)

From PowerShell. This uses the same preset and gives the same result:

```powershell
& "C:\Users\kylea\Downloads\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe" --headless --path C:\Users\kylea\Desktop\CraveFX_Assessment\platformer --export-release "Web" docs/index.html
```

It's finished when the output ends with `[ DONE ] savepack`. Use `--export-debug` instead of `--export-release` for a debug build.

### Test the build on your PC

A browser **won't** run the game if you double-click `index.html`. Pages opened from a file (`file://...`) aren't
allowed to load `index.wasm` and `index.pck`, so you'd see a blank page or an error. The files have to come from a web server, even a local one:

1. Double-click **`CraveFX_Assessment\Builds\run_web.bat`**. A console window opens and your browser opens
   **http://127.0.0.1:8060/** (it serves `platformer\docs`). This needs Python, which is installed on this PC.
   - From a terminal instead: `python C:\Users\kylea\Desktop\CraveFX_Assessment\Builds\serve.py`
     (add a number for another port, e.g. `... serve.py 9000`).
2. Click the game once so it gets keyboard focus. Browsers also only allow sound to start after a click or key press.
3. Check: F1 toggles the FPS counter, the intro plays, there's sound, and the movement is smooth.
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
| A short freeze when music starts | Web builds decode each track the first time it plays. Scenes do this during their black screens (`SoundManager.prepare`). A new track played mid-scene should be prepared the same way first. |
| Looks slightly different from the editor | Browsers use the **Compatibility** renderer (WebGL 2) instead of Forward+. Shaders can look a little different. |
| Progress (the after-the-ending menu) won't reset | It's saved in the browser's site data. Clear the site data for the page, or use a private window. |

---

## Part 2: host the game on GitHub Pages (from this repository)

GitHub Pages hosts plain files for free. The repository already holds the build in `docs\`, so hosting is just a
setting. It works as long as **Thread Support stays off** (GitHub Pages can't send the special server headers a
threaded build needs). The repository must be **Public** (Pages for private repositories needs a paid plan).

### One-time setup

**Step 1: push the build**

Export (Part 1), then commit and push as usual. The `docs\` folder must be in the commit:

```powershell
cd C:\Users\kylea\Desktop\CraveFX_Assessment\platformer; git add -A; git commit -m "Web build"; git push
```

The first push with the build uploads about 50 MB and can take a minute.

**Step 2: turn on GitHub Pages**

1. On github.com, open the repository **Kulurc/Platformer** → **Settings → Pages** (left sidebar).
2. Under **Build and deployment**:
   - Source: **Deploy from a branch**
   - Branch: **main**, folder: **/docs**
3. Click **Save**.

**Step 3: open the game**

Wait 1-2 minutes. You can watch progress in the repository's **Actions** tab (a green tick = live). The address
appears at the top of **Settings → Pages** ("Your site is live at ..."):

**https://kulurc.github.io/Platformer/**

(The address uses the repository's name. If you rename the repository, the address changes with it.)

### Updating the game later

1. Export again (Part 1). This updates `docs\`.
2. Commit and push (same command as Step 1).
3. Wait a minute, then open the address with **Ctrl+F5**. Browsers can hold on to the old files for a while, so a
   normal refresh may still show the previous version.

Usually only `index.pck` (your game, ~12 MB) changes. `index.wasm` only changes when you change Godot version, so
git doesn't store a new copy of it each time. Each pushed build does add the new `index.pck` to the repository's
history, so push builds when you want them live rather than after every small change.

### Sharing it

- **Link:** share `https://kulurc.github.io/Platformer/` or link to it from your portfolio.
- **Embed it in a page** (e.g. on your portfolio):

  ```html
  <iframe src="https://kulurc.github.io/Platformer/" width="1280" height="720"
          allow="autoplay; fullscreen" style="border:0; max-width:100%;"></iframe>
  ```

- **Phones and tablets:** the page loads on recent Android/iPhone browsers, but the game uses keyboard and mouse
  only, with no on-screen touch controls. Phone players can't play it yet.
- **First load** downloads about 50 MB (less over the network, since GitHub compresses it). That's fine on Wi-Fi,
  slower on mobile data. Later visits load from the browser's cache.

### Taking it down

Settings → Pages → set Source to **None**. The repository and the build stay as they are.

### Other places to host (same build)

- **itch.io:** zip the *contents* of `platformer\docs\` (with `index.html` at the top of the zip), create a project,
  set Kind to **HTML**, upload the zip, tick **This file will be played in the browser**, and set the viewport to 1280×720.
