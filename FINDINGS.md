# AniTaku New-Episode Notification Patch — Findings & Deliverables
Date: 2026-10-20 · App: com.anitaku v0.1 (EasyPlex template) · Target: Android 13/14 (tested on emulator API 34 x86_64)

## Deliverables
- `anitaku-notif-v6.apk` — final signed APK (v1+v2+v3 signing, debug key). Install with
  `adb install -r` (keeps login/data) or via file manager (signature differs from Play build → uninstall first).
- `smali\PollRunnable.smali` — rewritten poller (v3 design + instrumentation).
- `smali\EpisodePoller.smali` — notification poster (rewritten to bypass broken z2/o wrapper).
- `smali\PollReceiver.smali` — alarm/boot receiver (unchanged).
- `stale\` — retired pre-fix APK + expired access token (kept for reference only).
- `access_token_fresh.txt` — static app token (base64, still works as Bearer for content routes).

## What the patch does
1. `PollReceiver` fires from a 15-minute `AlarmManager` repeating alarm (set when app runs) and on BOOT_COMPLETED.
2. `PollRunnable` GETs `https://anitakuapp.hasalaty.com/public/api/media/mobile/en` (the app's real home endpoint)
   with the exact headers the API demands (see below).
3. Tracks the max id of 3 sections across polls (silent init on first run, notify on increase):
   - `latest_episodes[]` → key `episode_id` → pref `patch_last_ep`
   - `latest_episodes_animes[]` → key `episode_id` → pref `patch_last_ep_anime`
   - `anime[]` → key `id` → pref `patch_last_anime`
   (anime sections are currently empty on the server — code is ready for when the admin adds anime)
4. On increase → notification "New episode available" / "<name> - <episode_name>" on channel `anitaku_episodes`,
   then stores the new max (dedupe: repeats never re-notify).

## API reverse-engineering (the 401 "404" mystery — SOLVED)
Content routes return HTTP 200 only with BOTH:
- Header `packagename: com.anitaku`
- User-Agent in the exact app format built by `xa/a;->c()`:
  `EasyPlex (Android <RELEASE>; <MODEL>; <BRAND> <DEVICE>; <LANGUAGE>)`
  e.g. `EasyPlex (Android 14; sdk_gphone64_x86_64; google emu64xa; en)`
Without either: HTTP 401 with 3-byte body `"404"` (not an HTTP 404).
- Static app token (`ob/b;->g`, base64 `greenfubukitatsumakisaitamayellowgenosopmthirdseaoson`) works as
  Bearer for content routes; `/user` needs the logged-in user token (app stores it after normal login).
- `animes/latestadded/{code}` returns 200 but `data:[]` for every code (ar/en/fr/es) — dead endpoint on this
  server; do not use. `media/mobile/en` (426 KB JSON) is the real data source.

## Bugs found & fixed during development (for future patch work)
1. **Dalvik `if-lez` = "if ≤ 0"** (NOT "> 0"). Two guards written as `if-lez vN, :positive` were inverted:
   non-empty arrays bailed out, empty arrays fell through and stored `-1`. Fixed to `if-gtz`.
   Symptom: `patch_last_ep` never stored; legacy `-1` prefs values explained.
2. **z2/o notification wrapper is broken on Android 8+**: it builds via `Notification$Builder(Context)`
   (no channel) and the ctor's channel string is stored in a dead field (`u` is never read anywhere).
   → `notify()` enqueues a channel-less notification → system drops it
   (`numEnqueuedByApp=1, numPostedByApp=0`, no NotificationRecord). The app's own FCM notifications
   (com.anitaku.ui.notifications.NotificationManager) go through the same helper family — likely the
   second reason (besides dead server pushes) the app never shows notifications.
   **Fix**: bypass z2/o; post directly with `Notification.Builder(ctx, "CHANNEL_ID")`
   (the channel created by `b1/o;->b()` — id literal `CHANNEL_ID`, display name `anitaku_episodes`,
   importance 3/sound — is reused), fixed notify id `0x51ca` (updates in place, no stacking).

## Verified live on emulator (2026-10-20, API 34, WHPX)
- HTTP 200 poll with full media JSON (EPPOLL log), max `episode_id` = 17956.
- Silent init: first poll stores max, no notification.
- Notify demo: pref forced to 17000 → poll → **NotificationRecord pkg=com.anitaku id=20938
  channel=CHANNEL_ID importance=3**, extras `android.title="New episode available"`,
  `android.text="Dark Machine: The Animation - الحلقة 2"`, `numPostedByApp` 0→1.
- Second poll 5s later stayed silent (dedupe OK).
- Proof screenshot: `%TEMP%\anitaku\notif_proof.png`.

## Build procedure (from decoded tree)
```
C:\tools\jdk-17.0.20.1+1\bin\java.exe -jar <apktool.jar> b decoded -o patched-unsigned.apk
C:\tools\jdk-17.0.20.1+1\bin\java.exe -jar <uber-apk-signer.jar> -a patched-unsigned.apk -o signed
adb install -r signed\*-debugSigned.apk
adb shell pm grant com.anitaku android.permission.POST_NOTIFICATIONS
```
- Trigger a poll manually: `adb shell am broadcast -n com.anitaku/.patch.PollReceiver` (~40–60 s on the
  CPU-starved emulator), then check `logcat -s EPPOLL:V` and `dumpsys notification --noredact`.
- Decoded tree: `%TEMP%\anitaku\decoded` · tools: `%TEMP%\opencode\toolchain\tools\`

## Notes / limits
- Client-side only — server still never pushes FCM (topic `all` never messaged; legacy FCM API is dead,
  backend would need HTTP v1 migration + real pushes). The patch polls instead, so new episodes are
  detected whenever the app process runs (alarm re-arms itself; also fires on boot).
- On the emulator the app must be launched at least once after boot for the alarm to re-arm
  (unless BOOT_COMPLETED fired).
- ColorOS note (realme phone, if installed there): set battery to Unrestricted + allow autostart,
  otherwise the 15-minute alarm gets deferred.
