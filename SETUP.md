# Your Trading App — the no-jargon guide

This guide is for someone who has never built an app and doesn't want to learn
how. Every step is written in plain English, one step at a time. If a step uses
a word you've never heard, it's explained right there.

---

## First, the good news — most of it is already done

These three things are finished. You don't have to do them:

- [x] **The app is written.** It watches the market, and when it finds a good
      trade it shows you one clear thing on the home screen: **BUY** or **SELL**,
      plus the **exact time to buy** and the **exact time to sell**.
- [x] **It's saved on GitHub.** GitHub is a website that stores your app's code
      and can also build the app for you (we'll use that in a minute).
- [x] **Android Studio is installed on your PC.** It's a program used to build
      apps. You might not even need to open it.

So all we have to do now is: **make the app file**, **put it on your phone**,
and **use it**.

---

## Step 1 — Make the app file (easiest way, no typing needed)

Your app is built automatically on GitHub whenever you push code. You just
download the finished file. Here's how, click by click:

1. On your PC, open your web browser (Chrome or Edge).
2. Go to **https://github.com** and sign in.
3. Click your project. It's called **tradeapp**.
4. At the top of the page, click the **Actions** tab.
5. On the left you'll see a workflow named **Build APK (cloud)**. Click it.
6. You'll see a list of "runs". Click the **most recent green one** at the top.
   - If the list is empty: click the grey **Run workflow** button, then the green
     **Run workflow** button that appears. Then wait.
7. Watch the little yellow circle next to it. It does its thing for a few
   minutes, then turns into a **green checkmark**. (If it turns red, see the
   "If something goes wrong" section below.)
8. Scroll down. Under **Artifacts**, click **signal-aggregator-apk**. This
   downloads a `.zip` file to your PC (usually in your Downloads folder).
9. Find that file. Right-click it → **Extract All** → **Extract**.
10. Inside the extracted folder is a file called **app-debug.apk**. That is your
    app, as a single file.
11. Send that file to your phone, any way you like:
    - **WhatsApp / Telegram:** message the file to yourself, then open it on the phone.
    - **Email:** email the file to yourself, then open it on the phone.
    - **Cable:** plug your phone into the PC with the USB cable, copy the file across.
12. On your phone, **tap the file**. Android asks "Install this app?" → tap
    **Install**.
    - If it says it's blocked (you'll see the words "unknown sources"): tap
      **Settings** → turn on "Allow this app" / "Install unknown apps" → go
      back → tap **Install** again.
13. When it's done, tap **Open**. You're on the home screen. Done.

---

## Step 2 — (Only if you want) Build the app on your own PC

You don't need this if you did Step 1. But if you'd rather build it yourself:

1. First, open the project folder on your PC. It's the folder called
   **signal_aggregator** (inside your "New folder").
2. Right-click on an empty spot inside that folder and choose
   **Open in Terminal**. A black box opens — that's normal, it's called a
   "terminal" and it's where you type commands.
3. Click in the black box and type exactly this, then press **Enter**:
   ```
   flutter build apk --debug
   ```
4. Wait. The first time takes a few minutes (it's downloading stuff). Let it finish.
5. When it stops, your app file is here (find it in File Explorer):
   ```
   build\app\outputs\flutter-apk\app-debug.apk
   ```
6. Now follow Step 1 above, starting from point 11, to get it onto your phone.

> Tip: The first build on your PC is slow because it sets things up. Later builds
> are faster. And if building on your PC ever gives you trouble, just use Step 1 —
> it always works.

---

## Step 3 — How to actually use the app (2 minutes)

1. Open the app on your phone.
2. **Pull the screen down** (like you're refreshing a webpage) — or tap the
   refresh circle at the top right. The app checks the market and the news.
3. If a signal is found, the home screen shows you the only thing that matters:
   - **BUY** or **SELL** (in big letters)
   - the **exact time to buy** (big clock time)
   - the **exact time to sell** (big clock time)
4. **Tap anywhere on the card** to see the full story: why the app thinks this,
   how it scored, and where the tip came from.
5. If it says **"No signal right now"**, that just means no post and the market
   agree right now. Try again in a few minutes. This is normal, not a problem.

---

## Step 4 — (Optional, advanced) Make the app warn you by itself

This makes your phone ping you the moment the app finds a new strong signal —
even when the app is closed and your PC is off. It's genuinely fiddly to set up
(you need a free Firebase and a free Google Cloud account), so:

- **Skip it for now.** The app works fine without it — just open it and pull to refresh.
- **Or ask a techy friend to help.** The full instructions are in the folder
  called **server**, in the file **README.md**.

---

## Step 5 — The money rules (the actually-important part)

The app is just a helper. You stay in charge. Follow these rules:

1. **Practice first.** The app has a practice mode ("paper trading") with fake
   money. Do at least **20 practice trades** before you think about real money.
2. **Only trade when the app is confident.** It shows a "rightness" percentage.
   Only act on signals with **70% or higher**.
3. **One trade at a time.** Each trade = 1 buy + 1 sell. Don't stack them up.
4. **Follow the exact times.** When the home screen gives you a buy time and a
   sell time, that's your plan.
5. **Switch to real money only when** your practice accuracy is **50% or higher**.
   Then start small — about **$5** on an exchange like **MEXC** (free to deposit
   with crypto, and you can withdraw the same day on TRC-20, about a $1 fee).
   For learning first, open a free demo account on **Bybit**.
6. **Never connect the app to your exchange automatically.** You confirm every
   trade yourself. That's on purpose.

Weekly targets (a rough plan, don't overthink it):

| | Week 1 (ease in) | Week 2 (if it's going well) |
|---|---|---|
| Trades per week | 7 | 8–14 |
| Risk per trade | about 2% of your balance | 2–3% |
| Profit goal | +3% | +5% |
| Stop-loss (cut losses) | −10% | −8% to −12% |
| Accuracy goal | 50% | 52%+ |

---

## If something goes wrong

| Problem | What to do |
|---|---|
| The Actions page is empty / no green runs | Click the grey **Run workflow** button, then the green **Run workflow** button. Wait a few minutes. |
| The run turned red (failed) | Copy the red error text and ask a friend, or just wait — the next push builds it again automatically. |
| The `.zip` won't extract | Right-click → **Extract All** → make sure you're extracting (not just opening). |
| The APK won't install on your phone | You need to allow "unknown sources": on the phone, Settings → Apps → tap the app you used (WhatsApp etc.) → Install unknown apps → Allow. Then try again. |
| The app shows "No signal" | Normal. Pull to refresh, or wait a few minutes and try again. |
| Rightness is always low | That's correct — a signal only appears when a post AND the market agree. Be patient. |
| The app doesn't ping me | That's Step 4 (the advanced part). It needs setup. The app still works — just open it and refresh. |
| Something else | Take a screenshot of the problem and ask a friend for help. |

---

## You're done when...

- [ ] You downloaded (or built) the app file and it's installed on your phone
- [ ] The app opens and shows the home screen
- [ ] You've done a few **practice** trades
- [ ] (Later) You set up alerts with a helper — optional
- [ ] (Much later) You start real money with $5 after 20+ good practice trades
