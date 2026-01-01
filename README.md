# Gaming Mouse Track v2.4
**Global Canvas Interaction & Stabilized Source Tracking for Streamers.**

`Gaming Mouse Track v2.4` is a versatile Lua script for OBS Studio that bridges the gap between your mouse and your stream's canvas. Designed for gaming, streaming and professional tutorials, it allows any source—regardless of its resolution or size—to dynamically follow your cursor with surgical precision.

[![Watch the video]](https://youtu.be/eX2jvM8XAiE?si=qzD1at-zKMlYHJsm)
---

## ✨ Core Features

* **Global Canvas Adaptability:** Works seamlessly across multiple canvases. Whether your source is the same size as your stream or a smaller windowed element, the tracking scales to fit.
* **Multi-Source Support:** Independent settings for up to **10 different sources** simultaneously.
* **Dual-Filter Logic:** Automatically manages **Crop + Scale** filters to ensure a 100% canvas fill—no black bars, even when the source resolution doesn't match the output.
* **Zoom:** Use a hotkey to instantly "punch in" on a specific area for a sniper-cam or detail-focused effect.

---

## ️ Specialized Gaming Logic

* **Tracking Modes :** * **Both:** Full axis tracking (standard).
* **Horizontal Only:** Locks the vertical axis; the camera only follows left-to-right movements.
* **Vertical Only:** Locks the horizontal axis; the camera only follows up-and-down movements.
* **Anti-Jitter (Movement Threshold):** Ignores micro-movements (customizable in pixels) caused by in-game breathing animations or shaky hands, keeping the stream rock-steady.
* **Deadzone Buffers:** Create a "safe zone" in the center of your screen. The camera won't move while your mouse is inside this area, preventing motion sickness for viewers during micro-aim adjustments.
* **Smart Inventory Toggle (Auto-Disable):** Designed for games where "Interact" and "Inventory" share a key. This feature automatically disables and centers the camera after a short idle period in menus.
* **Intelligent Auto-Reset:**
* **On-Screen Idle Reset:** Automatically returns to center if the mouse stops moving for a set duration.
* **Boundary Safety:** Instantly snaps back to center if the mouse leaves the game window or designated monitor.

---

## ️ Configuration & Settings

| Setting | Gamer's Use Case |
| :--- | :--- |
| **Tracking Mode** | Choose between **Both**, **Horizontal**, or **Vertical** for axis-locked movement. |
| **Movement Threshold** | **15-25px** — Prevents the camera from twitching due to crosshair "wiggle." |
| **Deadzone %** | **5-10%** — Creates a center "safe zone" for micro-aiming without camera movement. |
| **Auto-Disable Time** | **1-2 sec** — Safely toggles tracking off after you finish looting. |
| **On-Screen Idle Reset** | Sets how long you must be still before the camera centers itself. |
| **Tracking Speed** | **40-60%** — Balances responsiveness with smooth, cinematic movement. |



---

## Installation & Usage

1. **Download** the `Gaming Mouse Track v2.4.lua` file.
2. Open OBS Studio and go to **Tools** -> **Scripts**.
3. Click the **+** button and select the script.
4. **Setup Hotkeys:** Go to **Settings -> Hotkeys** to assign:
* `Toggle / Enable Mouse Tracking`
* `Toggle Zoom Level`
* `Reset Tracker Position` (Manual snap-back to center)

---

## ⚠️ Technical Notes
* **Zoom Rescaling:** Note that version 2.4 has a known visual offset bug during high-multiplier zooming which is being addressed in the next update.
* **Filter Management:** The script manages "Track_P" and "Stretch_P" filters automatically. Manual changes to these filters may be overwritten.

