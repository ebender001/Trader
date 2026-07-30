# Trader — Alpaca Paper Trading Backend

Back4App Cloud Code backend that proxies Alpaca's paper trading API for the
Trader iPhone app.

## Structure

```
cloud/
  main.js               Entry point Back4App loads — just requires ./functions
  package.json          npm deps for Cloud Code (axios) — installed by Back4App on deploy
  lib/
    httpClient.js         Shared axios request/error-wrapping factory
    alpacaClient.js        Trading API client (paper-api.alpaca.markets)
    alpacaDataClient.js     Market Data API client (data.alpaca.markets)
    openaiClient.js          OpenAI Chat Completions client (Structured Outputs)
    constants.js               Shared enums (order sides/types/time-in-force)
    validation.js               requireParams / requireOneOf helpers
    errors.js                    Normalizes Alpaca errors into Parse.Error
  functions/
    index.js              Requires every function module below
    account.js             getAccount, getClock, getAsset
    positions.js            getPositions, getPosition, closePosition, closeAllPositions
    orders.js                placeOrder, listOrders, getOrder, cancelOrder, cancelAllOrders
    marketData.js              getQuote, getQuotes, getIndexValues, getBars
    advisor.js                   AI trade suggestions — see below
    health.js                      hello (basic deploy sanity check)
  test/
    local-test.js         Standalone script to sanity-check credentials locally
    .env.example           Template for local testing env vars
public/
  index.html              Default Back4App landing page (unused, safe to ignore)
```

Adding a new feature (e.g. watchlists): create `cloud/functions/watchlists.js`
with its own `Parse.Cloud.define` calls, then add `require('./watchlists');` to
`cloud/functions/index.js`. Reuse `lib/` for anything shared across modules —
e.g. both Alpaca clients share `lib/httpClient.js` rather than duplicating
the request/error logic.

`cloud/alpaca.js` is a leftover from before this refactor — it now just
re-exports `lib/alpacaClient.js` for safety. Delete it manually in Finder or
VSCode whenever you like; it isn't referenced anywhere anymore.

## Credentials

Set as environment variables on Back4App (Dashboard > App Settings > Server
Settings > Environment Variables, in the Cloud Code section):

- `ALPACA_PAPER_BASE_URL` — e.g. `https://paper-api.alpaca.markets`
- `ALPACA_PAPER_KEY_ID`
- `ALPACA_PAPER_SECRET_KEY`
- `TRADING_MODE` — e.g. `paper`

Cloud Code reads these via `process.env`. Nothing is hardcoded.

Optional (market data — only needed if you want to override the defaults):

- `ALPACA_DATA_BASE_URL` — default `https://data.alpaca.markets`
- `ALPACA_DATA_FEED` — default `iex` (free feed); use `sip` if you have that
  subscription on Alpaca

Market data reuses `ALPACA_PAPER_KEY_ID`/`ALPACA_PAPER_SECRET_KEY` — no
separate credentials needed.

AI advisor (required only if you use `getTradeSuggestions`):

- `OPENAI_API_KEY` — from platform.openai.com, separate billing from any
  ChatGPT/Claude subscription — this is pay-per-token API usage
- `OPENAI_MODEL` — optional, default `gpt-5`

## Local development

You can sanity-check the Alpaca wrapper without deploying:

```
cd cloud
npm install
npm install --save-dev dotenv
cp test/.env.example test/.env   # fill in the same values as on Back4App
node test/local-test.js
```

This calls Alpaca directly (account, clock, positions) to confirm your keys
and the request logic work before you push to Back4App.

## Deploying

From the project root:

```
b4a deploy
```

This uploads `cloud/` and `public/`. Back4App installs the npm dependencies
listed in `cloud/package.json` automatically — don't commit `node_modules`.

## Cloud functions

All functions are called from the iOS app via the Parse SDK, e.g.
`PFCloud.callFunction(inBackground: "getAccount", withParameters: nil)`.

### Account & market meta

- `getAccount` — account details (buying power, cash, equity, status)
- `getClock` — is the market currently open, next open/close times
- `getAsset({ symbol })` — asset info, whether it's tradable

### Positions

- `getPositions` — all open positions
- `getPosition({ symbol })` — one position
- `closePosition({ symbol, qty?, percentage? })` — liquidate part/all of a position
- `closeAllPositions({ cancelOrders? })` — liquidate everything

### Orders

- `placeOrder({ symbol, side, type, timeInForce, qty?, notional?, limitPrice?, stopPrice?, trailPrice?, trailPercent?, extendedHours?, clientOrderId? })`
  - `side`: `buy` | `sell`
  - `type`: `market` | `limit` | `stop` | `stop_limit` | `trailing_stop`
  - `timeInForce`: `day` | `gtc` | `opg` | `cls` | `ioc` | `fok`
  - Provide `qty` or `notional` (not both required, but at least one)
  - `limitPrice` required for `limit`/`stop_limit`; `stopPrice` required for `stop`/`stop_limit`
- `listOrders({ status?, limit?, after?, until?, direction?, symbols? })`
- `getOrder({ orderId })`
- `cancelOrder({ orderId })`
- `cancelAllOrders`

### Market data

- `getQuote({ symbol })` — latest bid/ask for one symbol
- `getQuotes({ symbols })` — latest bid/ask for multiple symbols (array or
  comma-separated string)
- `getIndexValues({ symbols })` — latest values for market indexes (S&P 500,
  Nasdaq, Dow, etc.), array or comma-separated string of Alpaca's index
  symbols (e.g. `SPX`, `DJI`, `IXIC`). This is a newer Alpaca endpoint
  (`/v1beta1/indices/latest/values`, added June 2026) — the Cloud Code side
  just proxies whatever Alpaca returns, but the exact response shape hasn't
  been verified against a live call yet, so treat the first real response as
  the source of truth rather than assuming a shape. Note: this needs a data
  subscription beyond the free IEX tier — a bare paper account gets
  `403 insufficient grants` on this one specifically. Index-tracking ETFs
  (SPY/QQQ/DIA) via `getQuote`/`getBars` work fine on the free tier instead.
- `getBars({ symbol, timeframe, start?, end?, limit?, adjustment? })` —
  historical OHLCV bars for charts. `timeframe` examples: `1Min`, `15Min`,
  `1Hour`, `1Day`. Uses the same `iex` feed as quotes by default, which is
  real-time (not the 15-minute-delayed feed free accounts get on `sip`), so
  a chart combining this with `getQuote` won't have a staleness gap.

There's no push/streaming layer — the app should poll these on an interval
(e.g. every 2–5 seconds while a screen showing live prices is open). Alpaca's
free tier rate-limits requests per key, so poll only what's on screen rather
than every symbol you've ever looked at. `getClock` (above) already covers
market open/closed status; poll that far less often since it barely changes.

A true real-time push stream would require an always-on process holding
Alpaca's market data websocket open — Back4App Cloud Code is request/response
and isn't built for that. If real-time push becomes worth it later, that's a
separate Back4App Container relaying into Parse via LiveQuery, not something
bolted onto Cloud Code.

### AI trade advisor

Suggests possible trades against the paper account using OpenAI, with goals
set by you. It never places orders itself — `placeOrder` is still the only
thing that touches Alpaca's trading API. This is meant to be reviewed by a
human (accept/reject), not run autonomously.

- `getAdvisorProfile` — reads your current goals/parameters (or `null` if
  none saved yet)
- `saveAdvisorProfile({ riskTolerance, maxPositionPercent, maxOpenPositions, symbolUniverse, strategyBias?, timeHorizon?, maxSuggestionsPerRun? })`
  — sets your goals. `riskTolerance`: `conservative` | `moderate` | `aggressive`.
  `symbolUniverse` is the only symbols the advisor is allowed to suggest —
  it's a hard allowlist, enforced in code, not just prompted. `maxPositionPercent`
  caps any single position as a % of account equity. There's only ever one
  profile (single-user app) — calling this again overwrites it.
- `getTradeSuggestions` — the main call. Pulls account/positions/clock/quotes
  for your symbol universe, asks OpenAI for structured suggestions (or
  explicitly "nothing looks good"), then applies guardrails in code before
  anything is saved or returned: suggested symbols outside your universe are
  dropped, position sizes over `maxPositionPercent` are dropped, and new
  positions beyond `maxOpenPositions` are dropped. Every run — including
  "suggested nothing" runs — is saved to the `TradeSuggestion` class so you
  can review history later, not just the trades you actually took.
- `recordSuggestionDecision({ suggestionId, decision, resultingOrderId? })`
  — mark a suggestion `accepted` or `rejected` once you've decided; pass
  `resultingOrderId` (from `placeOrder`'s response) if you acted on it, so
  the suggestion and the resulting order are linked for later review.
- `listTradeSuggestions({ limit?, status? })` — suggestion history.

Two Parse classes back this (created automatically the first time they're
written to — no manual schema setup needed):

- `AdvisorProfile` — your goals, one row
- `TradeSuggestion` — every suggestion ever generated, with the profile
  snapshot it was generated under, its status, and a link to the resulting
  order if accepted

### Errors

Alpaca error responses are normalized into `Parse.Error` with the Alpaca
message attached, so the app can display something meaningful instead of a
raw HTTP error. OpenAI errors are wrapped the same way.

## Next steps (not yet built)

- Watchlists
- Per-user auth, if this ever needs to support more than one person
- Real-time streaming (see Market data note above) if polling ever isn't enough
- Scheduled (rather than on-demand) advisor runs, once suggestion quality feels solid
