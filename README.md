# 🖱️ Mouse Track V2.4 for OBS
**Precision Mouse Tracking & Auto-Zoom for Content Creators.**

`Mouse Track V2.4` is a nice Lua script for OBS Studio that allows your sources to dynamically follow your mouse cursor. Perfect for TikTok/Shorts creators, tutorial makers, and gamers who want to maintain focus on the action without manual camera panning.
 
 Mostly created and with features for gameplay on vertical it tracks the monitor position so you can use in a vertical canvas and multiple sources.

---

## ✨ Key Features

* **Multi-Source Support:** Track up to 10 different sources simultaneously with independent settings for each.
* **Intelligent Panning:** Smooth, physics-based movement with adjustable speed and deadzones.
* **Monitor Tracking** Monitor base tracking can be used in any source or source clone , also individualy tracked for the monitor selected.
* **Auto Disable** Automatically disables tracking if there is "no mouse movement|**idle**" (useful for games openening inventory and using the same key to open door/interact will reset the traking to center).
* **Movement Threshold:** In pixel set a limit of mouse detection as **idle** or ignores small movements (useful if game dont have a centered crosshair or have a movement mechanic).
* **Zoom:** Automatically manages **Crop** and **Scale** filters to ensure a 100% canvas fill.
* **Smart Auto-Reset:** * **On-Screen Idle Reset:** Returns to center if the mouse stops moving for a set duration.
    * **Off-Screen Reset:** Automatically centers the view if the mouse leaves the designated monitor.
* **Presets Included:** Instant setup for **TikTok (608x1080)** and **Square (1080x1080)** or custom formats, if used in a small Canvas and crop suggest to use source clone.
* **Deadzone** Deadzone linked to the preset or custom resolution not the original source size.
* **Advanced Hotkeys:** 
    * Toggle/Enable Tracking
    * Dedicated Disable (Split Mode)
    * Manual Position Reset
    * Instant Zoom: Toggle a secondary zoom level on the fly.

---

## 🚀 Installation

1. **Download** the `Mouse Track V2.4.lua` file from this repository.
2. Open OBS Studio.
3. Go to **Tools** -> **Scripts**.
4. Click the **+** button and select the `Mouse Track V2.4.lua` file.
5. Select your source and monitor in the script settings panel.

---

## 🛠️ Configuration Options

| Setting | Description |
| :--- | :--- |
| **Center View Before Disabling** | Smoothly moves the camera back to center before turning off. |
| **Movement Threshold** | Ignores tiny mouse jitters (measured in pixels). |
| **Deadzone %** | Defines an area in the center where the mouse can move without the camera following. |
| **Zoom Multiplier** | Sets the magnification level when the Zoom Hotkey is activated. |
| **Monitor Boundary** | Restricts tracking to a specific monitor in a multi-head setup. |

---

## ⌨️ Hotkeys

To get the most out of the script, assign these in **Settings -> Hotkeys**:
* `Toggle / Enable Mouse Tracking`
* `Toggle Zoom Level`
* `Reset Tracker Position`

---

## ⚠️ Known Issues
* **Zoom Scaling:** Zooming currently has a known visual offset bug that is being addressed in the next version.
* **Filter Stacking:** The script handles filter creation automatically; manual changes to the "Track_P" or "Stretch_P" filters may be overwritten.
