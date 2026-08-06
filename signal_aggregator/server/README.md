# Signal Aggregator — Cloud backend

Runs the signal scan 24/7 in the cloud, so the phone app works even when your
PC is off (or the app isn't running). It fetches the same public sources
(Reddit, crypto news, Telegram) and validates them against live Binance data,
then serves the result to the app over a simple REST API.

It also scans **on its own** (every 5 minutes by default) and pushes a
**Firebase Cloud Messaging notification** to your phone the moment it finds a
*new* signal with high rightness (70%+ by default) — no PC, no app running.

## API

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/signals` | GET | The app reads this. Returns fresh results (re-scans if older than 10 min). |
| `/api/status` | GET | Scan config, push status, registered device count. |
| `/api/health` | GET | Uptime check. |
| `/api/device/register` | POST | Body `{"token": "..."}` — the app registers its FCM token here. |
| `/api/device/unregister` | POST | Body `{"token": "..."}` — removes a device token. |
| `/refresh` | POST | Manual trigger; forces a scan. |

`/api/signals` returns:

```json
{
  "generatedAt": "2026-08-03T18:05:06Z",
  "cloud": true,
  "signals":  [ ...raw posts... ],
  "validated": [ ...ranked signals with probability... ],
  "markets": { "BTC": { ... }, "ETH": { ... } }
}
```

## How push works

1. The server scans every `SCAN_INTERVAL_MS` (default 5 min).
2. It remembers every strong signal it has already pushed (`seen_signals.json`).
3. The first scan after boot only seeds the "seen" list (no spam on startup).
4. Any *new* validated signal with `probability >= MIN_PROBABILITY` triggers an
   FCM push to every registered device.
5. The phone app registers its token at `/api/device/register` once you set the
   Cloud URL in Settings.

Push is **off by default**: it activates only when Firebase credentials are
provided (see below). Without them, the server still scans and serves signals.

## Run it locally

```bash
npm install
node server.js
# then:
curl http://localhost:8080/api/health
curl http://localhost:8080/api/signals
curl http://localhost:8080/api/status
```

Run the tests (mirror the Flutter unit tests):

```bash
npm test
```

## Configuration (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `PORT` | `8080` | HTTP port (Cloud Run injects `PORT=8080`). |
| `CACHE_TTL_MS` | `600000` | How long results are served without re-scanning. |
| `SCAN_INTERVAL_MS` | `300000` | How often the server scans on its own (5 min). |
| `MIN_PROBABILITY` | `70` | Rightness % threshold for push alerts. |
| `WATCHLIST` | `BTC,ETH,SOL,BNB,XRP` | Coins to always fetch market data for. |
| `TELEGRAM_CHANNELS` | 5 default channels | Comma-separated public channel usernames. |
| `ENABLED_SOURCES` | `reddit,news,telegram` | Which sources to scan. |
| `DEVICE_TOKENS_FILE` | `device_tokens.json` | Where registered FCM tokens are kept. |
| `SEEN_SIGNALS_FILE` | `seen_signals.json` | Where pushed-signal IDs are kept (dedup). |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | – | The full Firebase service-account JSON as a string. |
| `GOOGLE_APPLICATION_CREDENTIALS` | – | Or: path to the service-account JSON file. |

## Enabling push (Firebase)

1. Create a free Firebase project at https://console.firebase.google.com.
2. Add an **Android app** with package name `com.signalhub.signal_aggregator`.
3. Download `google-services.json` and put it in `android/app/` (the Flutter
   project). The app only activates FCM when that file is present.
4. In **Project settings → Service accounts**, generate a **new private key**
   (a JSON file). Put its contents in the `FIREBASE_SERVICE_ACCOUNT_JSON` env
   var of the deployed server (or point `GOOGLE_APPLICATION_CREDENTIALS` at it).
5. The app must be able to reach the server at your Cloud URL with the URL saved
   in **Settings → Cloud feed** — then it registers its token automatically.

---

## Deploy to Google Cloud Run (free tier, nothing installed on your PC)

You need a free Google account. Use **Google Cloud Shell** (browser terminal at
https://shell.cloud.google.com — no downloads) or the console. Cloud Run needs a
billing account on the project; the free tier (2M requests/mo, 240k
vCPU-seconds/mo) is comfortably enough for a scan every 5 minutes.

1. Push the repo to GitHub (see SETUP.md Task 1).

2. In Cloud Shell:

```bash
# clone your repo
git clone https://github.com/YOURUSER/YOURREPO.git
cd YOURREPO/server

# create a project and pick it
gcloud projects create signal-aggregator-backend --name="Signal Aggregator Backend"
gcloud config set project signal-aggregator-backend

# attach a billing account (free tier still applies)
# Easiest: open https://console.cloud.google.com/billing/link and link the project.

# enable the APIs we need
gcloud services enable run.googleapis.com scheduler.googleapis.com

# deploy (Cloud Shell gives you the gcloud CLI, no local install)
gcloud run deploy signal-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --max-instances 1 \
  --memory 512Mi \
  --cpu 1 \
  --set-env-vars "FIREBASE_SERVICE_ACCOUNT_JSON=<paste the whole JSON here>"

# it prints a Service URL like https://signal-backend-xxxx.a.run.app — copy it
```

> Tip: instead of pasting the JSON inline, save it in Cloud Shell as
> `firebase-key.json` and deploy with
> `--set-env-vars "GOOGLE_APPLICATION_CREDENTIALS=/app/firebase-key.json"`.
> Simplest reliable option for a personal app is the inline JSON var.

3. You **no longer need** the external `/refresh` cron — the server now scans on
   its own every 5 minutes. (Cloud Scheduler is optional.)

4. Open the app → **Settings → Cloud feed**, turn it on, paste the Service URL,
   tap **Save URL**. The app registers its push token; you'll get a push when a
   new 70%+ signal appears.

> Note: since Cloud Run scales to zero when idle, use `--min-instances 1` if you
> want the scan to keep running non-stop (costs a little more but is still on
> the free tier), or keep the default and rely on app requests to wake it.

> Optional: Telegram channel scraping can be blocked for datacenter IPs. If
> Telegram signals come back empty, adjust `TELEGRAM_CHANNELS` or leave the
> source off in Settings — Reddit + news still work.

## Deploy elsewhere

- **Render** (free web service): create a service from the `server/` folder,
  build command empty, start command `node server.js`, env `PORT=8080`. Free
  tier sleeps when idle; the built-in 5-min scanner only runs while awake, so
  for reliable push use a $7/month starter, or pair with a free external cron
  (e.g. crontap.com) hitting `/refresh` every 5 min.
- **Fly.io** (free allowance): `fly launch`, set the same env vars.
- **Any VPS / Docker**: `docker build -t signal-backend .` then run it.
