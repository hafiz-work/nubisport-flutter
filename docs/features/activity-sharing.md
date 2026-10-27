# Activity Sharing — Strava Research & NubiSport Design

**Status:** implemented baseline + roadmap
**Last checked:** 26 Oct 2026

---

## 1. Strava’s share flow (research)

### Standard activity share

1. Open the activity (or tap Share directly in the feed).
2. Tap the share icon.
3. If the activity has photos, Strava asks **Map** or **Photo**. Without photos it uses the map.
4. Strava renders an image with stats.
5. The OS share tray opens. The user picks Instagram, WhatsApp, Messages, email, etc.
6. Sharing from the website is limited (e.g. “Share on X”).

### Rules Strava applies

- The share icon is only shown on **your own** activities.
- Activity privacy must be **Followers** or **Everyone**; “Only You” has no share icon.
- Map/stats sharing requires a **GPS activity**. Stationary, indoor and manually created activities cannot use the map image.
- Stats are not user-selectable:
  - runs/swims: moving time, distance, pace;
  - rides: moving time, distance, elevation.
- Share image uses the user’s selected units and the phone language.

### Transparent Instagram sticker (Strava v482+)

Strava has a second flow specifically for social stories:

1. Share icon → choose a sticker with a **checkered background**.
2. Tap **Save**; the PNG goes to the camera roll.
3. Open Instagram Story, choose any photo/video as background.
4. Use Instagram’s sticker picker → Photo → choose the saved sticker.
5. Strava does **not** add the background for you.

Details:

- Sticker sharing works on iOS and Android.
- Free for all athletes, though some stickers are subscriber-only.
- Any activity can be shared as a sticker, including private activities.
- Hidden stats/map portions are not included.

### Other surfaces

- Snapchat has a Strava lens that overlays stats/route; hidden map parts are excluded.
- Share links are available only for public/followers activities.

---

## 2. What NubiSport has now

### Own activity

`showActivityShareSheet(..., isMine: true)`

- Custom `FamilyModalSheet`.
- Template picker (2-column grid, live mini previews):
  - Klasik — 4:5 feed card
  - Story — 9:16
  - Statistik — transparent PNG sticker
  - Laluan — transparent route sticker
  - Jarak Besar — 1:1
  - Minimal — 1:1 light
  - Poster — 4:5
  - Resit — 4:5
- Transparent templates show a checkered preview, so the alpha is obvious.
- Selected template is captured through `RepaintBoundary` at pixelRatio 3.
- PNG is shared with the caption through `share_plus` (native tray).
- “Salin kapsyen” copies the text.

### Someone else’s activity

- Simple sheet: “Kongsi ke…” text share + “Salin kapsyen”.
- No image templates, matching Strava’s rule that the share icon belongs to the owner.

---

## 3. Gap analysis vs Strava

| Strava behaviour                                 | NubiSport                                        | Priority    |
| ------------------------------------------------ | ------------------------------------------------ | ----------- |
| Map or photo choice when the activity has photos | No photo model yet                               | Later       |
| Fixed run stats (time, distance, pace)           | Same stats; adds elevation                       | Fine        |
| GPS required for image sharing                   | Route is optional; falls back to icon            | Fine        |
| Native share tray                                | `share_plus` opens native tray                   | Done        |
| Transparent Instagram sticker with checkerboard  | Two transparent sticker templates + checkerboard | Done        |
| Save sticker directly to camera roll             | Native share tray only                           | **Next**    |
| Copy/share activity link                         | Not available (no public activity URL yet)       | Next        |
| Share icon only on own activities                | `isMine` gate                                    | Done        |
| Privacy Followers/Everyone                       | No activity privacy model yet                    | Later       |
| Hide stats/map portions                          | No hidden-data model                             | Later       |
| Units/language follow app                        | Hardcoded metric/Malay labels                    | Later       |
| Snapchat/Snap lens                               | None                                             | Not planned |

---

## 4. Improvements made in this pass

- Corrected template dimensions so the hints match the output:
  - Klasik and Poster/Resit are 4:5 (360×450).
  - Story and stickers are 9:16 (360×640).
  - Jarak Besar and Minimal are 1:1 (360×360).
- Added a small format badge (`4:5`, `9:16`, `1:1`, `PNG`) on every template tile.
- Kept the 3× PNG capture, so the shared file is 1080×1350 / 1080×1920 / 1080×1080 depending on the template.
- Kept the checkerboard only for transparent templates, so users understand what will be transparent.
- Replaced the circular icon actions with full-width `FilledButton` / `OutlinedButton` actions that follow the app theme, with a divider instead of a separate footer colour. The same treatment is used for the text-only “other activity” sheet.

---

## 5. Next improvements (recommended order)

1. **Save image / sticker to gallery**
   - Capture the selected template once, then offer `Simpan` and `Kongsi`.
   - Required for the full Strava sticker flow (save → Instagram Story).
2. **Activity link**
   - Define the public activity URL on the web app, then add “Salin pautan” and include it in the caption.
   - Only for public/followers activities.
3. **Photo support**
   - Add activity photos, then let the user choose Map or Photo as the card background.
4. **Privacy and hidden data**
   - Respect hidden stats/map portions in the generated image.
5. **Instagram direct handoff**
   - Optional: use the Instagram Stories URL scheme / share extension when installed; otherwise keep the native tray.

---

## 6. Sources

- [Sharing Your Strava Activities — Strava Help Center](https://support.strava.com/en-us/articles/15401840-sharing-your-strava-activities)
- [How do I share my Strava activity to Instagram Stories as a transparent sticker?](https://support.strava.com/en-us/articles/17718841-how-do-i-share-my-strava-activity-to-instagram-stories-as-a-transparent-sticker)
- [How do I get and share links from Strava?](https://support.strava.com/en-us/articles/15401717-how-do-i-get-and-share-links-from-strava)
- [Snapchat and Strava](https://support.strava.com/en-us/articles/15401686-snapchat-and-strava)
