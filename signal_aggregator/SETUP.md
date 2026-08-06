# Signal Aggregator — setup checklist (current)

Your to-do list to get the app from "built code" to "running on my phone with
push alerts". Tick each box as you complete it. Everything already finished in
the code is marked **DONE**.

**The short version:** you never install Android Studio and you never keep your
PC on. The APK is built in the cloud, the scanning runs 24/7 on a free Google
Cloud backend, and your phone gets pinged the moment the cloud finds a new
70%+ signal — even with the app closed.

**How it fits together:**
```
Google Cloud backend (scans Reddit + news + Telegram, scores vs Binance)
        │  scans on its own every 5 min
        │  pushes to your phone via Firebase (FCM) when a NEW 70%+ signal appears
        ▼
   GitHub (stores code, builds the APK in the cloud)
        │
        ▼
   Your phone (shows signals, paper trading, goals)
```

---

## ✅ Already done (in the code)
- Full Flutter app written (5 screens: Home, Signals, Portfolio, Learn, Settings)
- Live market data (Binance), 3 signal sources (Reddit, News, Telegram), rightness % scoring
- Paper trading with win-rate / accuracy tracking
- Weekly goals (Realistic / Optimistic × Week 1 / Week 2), paper vs real-money phase
- **Cloud backend** (`server/`): scans + scores **on its own every 5 minutes**, REST API, FCM push
- **Push notifications** wired end-to-end: phone registers a token, cloud pushes on new strong signals
- **Cloud APK build** (`.github/workflows/build-apk.yml` at the repo root — builds
  on every push, APK downloadable from the **Actions → Artifacts** section)
- **Browser IDE config** (`.devcontainer` for GitHub Codespaces)
- `flutter analyze`: 0 issues · 8 Flutter tests pass · 14 backend tests pass
- Code is already pushed to **GitHub** (Task 1 — nothing to do)

---

## ☁️ Task 1 — Deploy the cloud backend (free, ~20 min)

This makes the app work with your PC off. The backend scans on its own, so you
do **not** need the old cron job anymore.

1. Create a free Google account if you don't have one.
2. Open **Google Cloud Shell** in your browser: https://shell.cloud.google.com
   (a real Linux terminal in the cloud — nothing to download).
3. Copy-paste these one at a time, replacing the repo URL:
   ```bash
   git clone https://github.com/lumeierecollection-blip/tradeapp.git
   cd tradeapp/server
   gcloud projects create signal-aggregator-backend --name="Signal Aggregator Backend"
   gcloud config set project signal-aggregator-backend
   gcloud services enable run.googleapis.com
   gcloud run deploy signal-backend --source . --region us-central1 \
     --allow-unauthenticated --min-instances 1 --memory 512Mi --cpu 1
   ```
   - It asks you to link a billing account (needed even for free tier) and pick
     a region. The free tier covers this easily.
   - **`--min-instances 1` is important:** it keeps one instance always warm so
     the 5-minute scanner runs 24/7 and pushes work even between app requests.
   - When it finishes it prints a URL like
     `https://signal-backend-xxxx.a.run.app` — **copy it**.
4. Test it in the browser:
   `https://signal-backend-xxxx.a.run.app/api/status` should return JSON that
   includes `"pushEnabled"` and `"scanIntervalMs": 300000`.
5. On your phone: open the app → **Settings → Cloud feed** → paste the URL →
   **Save URL** → pull-to-refresh. The app now shows cloud-scanned signals.

> Skip this task and you still get signals when the app is open (scanned on the
> phone), but nothing when your PC is off and no push alerts.

---

## 🔔 Task 2 — Turn on push alerts (free, ~15 min, optional but the point)

Do this after Task 1. Requires a free Firebase project.

1. Create a project at https://console.firebase.google.com.
2. Add an **Android app** to it with package name **`com.signalhub.signal_aggregator`**.
3. Download **`google-services.json`** → put it in `android/app/` of the project.
4. In Firebase → **Project settings → Service accounts** → **Generate new private
   key**. This downloads a JSON file.
5. In Cloud Shell, redeploy the backend with that key:
   ```bash
   gcloud run deploy signal-backend --source . --region us-central1 \
     --allow-unauthenticated --min-instances 1 --memory 512Mi --cpu 1 \
     --set-env-vars "FIREBASE_SERVICE_ACCOUNT_JSON=<paste the whole JSON here>"
   ```
6. Build an APK **with** the `google-services.json` present (Task 3) and install it.
7. In the app: **Settings** shows **"Cloud push alerts: Active"** once the Cloud
   URL is saved. You'll get a push the moment the cloud finds a NEW 70%+ signal.

> The backend only alerts you about **new** signals and never repeats ones it
> has already pushed (`seen_signals.json`), so no spam.

---

## 📱 Task 3 — Build & install the APK

The GitHub Actions workflow builds an APK on every push, **but** the Firebase
file (`google-services.json`) is not committed, so the Actions APK has no push.
For a push-enabled APK, build where that file exists. Two ways:

**Option A — Codespaces (recommended, all in the browser):**
1. On the repo page → **Code → Codespaces → Create codespace on main**.
   (Free ~120 core-hours/month; Flutter + Android are pre-installed.)
2. Wait for it to start, then drag your `google-services.json` into
   `android/app/` (in the Explorer).
3. Open the terminal and run:
   ```bash
   flutter pub get
   flutter build apk --debug
   ```
4. Download the APK: right-click `build/app/outputs/flutter-apk/app-debug.apk`
   → **Download**. Send it to your phone (Google Drive / USB / WhatsApp) and tap
   it (allow "install from unknown sources" on Android).

**Option B — let GitHub Actions do it (simplest, but push stays off):**
1. Go to the repo → **Actions** tab.
2. It builds **automatically after every push to `main`**. To force a fresh
   build without changing code: open the **Build APK (cloud)** workflow →
   **Run workflow** → **Run workflow** (it has a manual trigger button).
3. Open the finished run → under **Artifacts** download `signal-aggregator-apk`
   → unzip → install the `.apk`. This build has everything except push.

> If you ever want the Actions APK to include push too, commit the
> `google-services.json` to your private repo (`git add -f` it). Fine for a
> personal private repo; the APK then has push built in on every push.

---

## 🎨 Task 4 — Edit the UI (optional)

All in Codespaces (Task 3, Option A): edit `lib/ui/`, then
`flutter analyze` → `flutter test` → commit & push. Pushing triggers a fresh
Actions APK automatically.

---

## 🔥 Task 5 — Find more Telegram channels (optional)

- Create a free account at https://firecrawl.dev (500 free credits/month)
- Search: `firecrawl search "free bitcoin signals telegram channel"`
- Scrape: `firecrawl scrape https://t.me/s/ChannelName`
- **Only add channels that open at `t.me/s/NAME`** — private channels won't work.
  Add them in **Settings → Telegram channels** (comma-separated).

---

## 💰 Task 6 — Set up your exchange (only for the real-money phase)

1. **Bybit** (learn + demo first): sign up → use their **testnet / demo trading**.
2. **MEXC** (when you go live with $5): deposit USDT via crypto transfer (free,
   no minimum) → trade coins the app rates 70%+ → withdraw on **TRC-20** for
   same-day withdrawals (~$1 fee).
3. Do **NOT** auto-connect the app to your exchange. You confirm every trade
   yourself — that's by design.

---

## 🎯 Task 7 — Your week 1 & 2 plans (start paper, then real)

| | Realistic W1 | Optimistic W1 | Realistic W2 | Optimistic W2 |
|---|---|---|---|---|
| Buys/day | 2 | 3 | 2 | 4 |
| Trades/week | 7 | 12 | 8 | 14 |
| Risk per trade | 2% (~$0.10) | 3% | 2% | 3% |
| Profit target | +3% | +12% | +5% | +18% |
| Loss stop | -10% | -15% | -8% | -12% |
| Accuracy goal | 50% | 60% | 52% | 60% |

**Your weekly routine (15 min/day):**
1. Act on **push alerts / top signals** — only those with **70%+ rightness**, and
   within your daily trade limit.
2. Each trade = 1 buy + 1 close. Don't let positions pile up.
3. End of week, check the **Goals** screen: hit target AND accuracy → scale up
   slightly. Hit the loss limit → stop, review, restart smaller.
4. Stay in **Paper** phase until accuracy holds 50%+ across 20+ trades. Only then
   flip to **Real money**.

---

## ❓ Common problems

| Problem | Fix |
|---|---|
| No push on phone | Needs all three: `google-services.json` in the APK (Task 3), `FIREBASE_SERVICE_ACCOUNT_JSON` on the backend (Task 2), and the Cloud URL saved in Settings. Settings must read "Cloud push alerts: Active". |
| Cloud backend shows nothing in the app | Settings → Cloud feed: URL must have no trailing slash; `https://…/api/status` must return JSON. |
| Backend "sleeps" between app opens | You deployed without `--min-instances 1`. Redeploy with it so the 5-min scanner stays alive. |
| Telegram channels show nothing | Only channels with a working `t.me/s/NAME` preview work. Datacenter IPs can be blocked by Telegram — Reddit + news still work. |
| Rightness % always low | Signals only appear when a post AND the market agree — that's correct behavior. |
| App gets no notification when open | Grant notification permission (Android 13+). Foreground pushes show as an in-app notification. |
| Backend deploy says "billing required" | Link any billing account in the Google Cloud console; the free tier means you won't be charged for this usage. |
| `flutter build` errors in Codespaces | First run downloads Android build tools — wait for `flutter doctor` to finish before building. |
| `flutter build` hangs on a low-RAM PC (≤ 4 GB) | Don't build locally — use the cloud instead: Actions APK (Task 3, Option B) or Codespaces (Task 3, Option A). Android builds need more memory than a 4 GB machine can spare. |
| APK won't install | Allow "install from unknown sources" (Settings → Apps → Special access); download the file directly to the phone. |

---

## ✅ Definition of "done"

- [ ] Cloud backend deployed (`--min-instances 1`); `/api/status` returns JSON
- [ ] Cloud URL saved in Settings; app shows cloud-scanned signals
- [ ] Push enabled: Settings says **"Cloud push alerts: Active"**
- [ ] Push-enabled APK built (Codespaces) and running on your phone
- [ ] App opens, shows live signals, paper trades work
- [ ] Bybit account open, demo trading practiced
- [ ] Paper phase: 20+ trades logged with 50%+ accuracy
- [ ] Only then: $5 deposit on MEXC, Real-money phase on
