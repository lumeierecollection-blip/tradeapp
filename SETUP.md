# Signal Aggregator — YOUR part (setup checklist)

This is your to-do list to get the app from "built code" to "running on my phone
and I'm trading with goals". Everything marked **DONE** is already finished in the
code. Everything else is your job, in order. Tick each box as you complete it.

---

## ✅ Already done (by the build)
- Full Flutter app written (5 screens: Home, Signals, Portfolio, Learn, Settings)
- Live market data (Binance), 3 signal sources (Reddit, News, Telegram), rightness % scoring
- Paper trading with win-rate / accuracy tracking
- Weekly goals (Realistic / Optimistic x Week 1 / Week 2), paper vs real-money phase
- 10 Telegram channels verified; 5 pre-loaded
- `flutter analyze`: 0 issues · 7 unit tests pass

---

## 🔧 Task 1 — Get the tools installed

**Install Android Studio** (the only reliable way to build + install on your phone)
1. Download from https://developer.android.com/studio
2. During install, accept the default **Android SDK + emulator** components
3. Open Android Studio once → it finishes installing the SDK

> `flutter doctor` in a terminal should show Android toolchain as ready.
> If it complains, open Android Studio → Settings → SDK Manager and install the
> latest SDK Platform + Build Tools.

**This machine currently has NO Android SDK** — this is the #1 blocker. Everything
below depends on it.

---

## 📱 Task 2 — Build the APK and put it on your phone

In a terminal, inside the project folder:

```
flutter build apk --debug
```

The file appears at `build\app\outputs\flutter-apk\app-debug.apk`.

**Install on your Android phone:**
1. On the phone: Settings → About → tap "Build number" 7 times (enables Developer options)
2. Settings → Developer options → enable **USB debugging**
3. Plug the phone in, then: `flutter install` (or copy the APK to the phone and tap it; allow "install from unknown sources")

> You only need a **debug** APK for personal use. Release builds are for sharing —
> you're not sharing.

---

## ☁️ Task 3 — Set up Firebase Studio (your UI studio)

1. Make this folder a git repo and push to GitHub:
   ```
   git init
   git add .
   git commit -m "signal aggregator v1"
   ```
   - Create a **private** repo at https://github.com/new
   - `git remote add origin https://github.com/YOURUSER/REPO.git`
   - `git push -u origin main`
2. Go to https://studio.firebase.google.com → sign in with Google
3. **New workspace → Import from GitHub → pick the repo**
4. Use the **Gemini chat** inside the workspace to improve the UI. Good first prompt:
   > "Make the dashboard cleaner: better spacing, larger balance number, subtle cards. Keep it professional, not flashy."
5. To get an updated APK from Firebase Studio, use its terminal:
   `flutter build apk --debug`, then download the APK file and install it on your phone.

---

## 🔔 Task 3b — Turn on cloud push alerts (optional, ~15 min)

This makes the app ping you the **moment** the cloud finds a new 70%+ signal —
even with the app closed and your PC off. Full steps are in `server/README.md`.

1. Create a free Firebase project at https://console.firebase.google.com
2. Add an **Android app** with package name **`com.signalhub.signal_aggregator`**
3. Download `google-services.json` → drop it in `android/app/`
4. In Firebase → Project settings → Service accounts → **Generate new private key**,
   and put that JSON in the server's `FIREBASE_SERVICE_ACCOUNT_JSON` env var
5. Rebuild the APK (GitHub Actions or `flutter build apk --debug`) and install it
6. In the app: **Settings → Cloud feed** → save your deployed backend URL

The server scans on its own every 5 minutes and only alerts you about *new*
signals (it never spams repeats or what you've already seen).

---

## 🔥 Task 4 — Log in to Firecrawl (optional, for finding more channels)

```
firecrawl login
```
- Create a free account at https://firecrawl.dev (500 free credits/month)
- Then you can search for channels yourself:
  ```
  firecrawl search "free bitcoin signals telegram channel"
  firecrawl scrape https://t.me/s/ChannelName
  ```
- **Only add channels that open at `t.me/s/NAME`** — those are the ones the app can read.
  If the link shows nothing, the channel is private and won't work.

---

## 💰 Task 5 — Set up your exchange (only for the real-money phase)

1. **Bybit** (learn + demo first)
   - Sign up → find their **testnet / demo trading** → practice for free
2. **MEXC** (when you go live with $5)
   - Sign up → deposit USDT via **crypto transfer** (free, no minimum)
   - Trade coins the app rates 70%+
   - Withdraw USDT on **TRC-20** for **same-day withdrawals** (~$1 fee)
3. Do **NOT** connect the app's API to your exchange automatically. You confirm every
   trade yourself — that's by design.

---

## 🎯 Task 6 — Your week 1 & 2 plans (start paper, then real)

| | Realistic W1 | Optimistic W1 | Realistic W2 | Optimistic W2 |
|---|---|---|---|---|
| Buys/day | 2 | 3 | 2 | 4 |
| Trades/week | 7 | 12 | 8 | 14 |
| Risk per trade | 2% (~$0.10) | 3% | 2% | 3% |
| Profit target | +3% | +12% | +5% | +18% |
| Loss stop | -10% | -15% | -8% | -12% |
| Accuracy goal | 50% | 60% | 52% | 60% |

**Your weekly routine (15 min/day):**
1. Open the app, tap refresh, read the top signals
2. Only act on signals with **70%+ rightness** — and only within your daily trade limit
3. Each trade = 1 buy + 1 close. Don't let positions pile up
4. At the end of the week, check the **Goals** screen:
   - Hit target AND accuracy? Move to the optimistic plan or scale up slightly
   - Hit the loss limit? Stop trading, review, and restart smaller
5. Stay in **Paper** phase until accuracy holds 50%+ across 20+ trades. Only then flip to **Real money**

---

## ❓ Common problems

| Problem | Fix |
|---|---|
| `flutter build` says "No Android SDK" | Finish Task 1 (Android Studio + SDK) |
| Telegram channels show nothing | Use channels with a working `t.me/s/NAME` preview; keep Telegram toggled ON in Settings |
| Rightness % always low | Signals only appear when a post AND the market agree — that's correct behavior |
| App gets no notifications | Grant notification permission; Android may still pause background scans to save battery — keep the app open for reliable 5-min scans |
| Background scans aren't every 5 min | Expected. Android limits background work. In-app scanning is exact; background is best-effort |

---

## ✅ Definition of "done"

- [ ] Android Studio installed, `flutter doctor` passes
- [ ] APK builds and runs on your phone
- [ ] App opens, shows live signals, paper trades work
- [ ] (Optional) Repo pushed to GitHub, imported into Firebase Studio
- [ ] Bybit account open, demo trading practiced
- [ ] Paper phase: 20+ trades logged with 50%+ accuracy
- [ ] Only then: $5 deposit on MEXC, Real-money phase on
