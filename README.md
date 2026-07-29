# Trader — Alpaca Paper Trading Backend

Back4App Cloud Code backend that proxies Alpaca's paper trading API for the
Trader iPhone app.

## Structure

```
cloud/
  main.js               Entry point Back4App loads — just requires ./functions
  package.json          npm deps for Cloud Code (axios) — installed by Back4App on deploy
  lib/
    alpacaClient.js      Alpaca HTTP client (reads env vars, builds requests)
    constants.js          Shared enums (order sides/types/time-in-force)
    validation.js          requireParams / requireOneOf helpers
    errors.js               Normalizes Alpaca errors into Parse.Error
  functions/
    index.js              Requires every function module below
    account.js             getAccount, getClock, getAsset
    positions.js            getPositions, getPosition, closePosition, closeAllPositions
    orders.js                placeOrder, listOrders, getOrder, cancelOrder, cancelAllOrders
    health.js                 hello (basic deploy sanity check)
  test/
    local-test.js         Standalone script to sanity-check credentials locally
    .env.example           Template for local testing env vars
public/
  index.html              Default Back4App landing page (unused, safe to ignore)
```

Adding a new feature (e.g. market data, watchlists): create `cloud/functions/marketData.js`
with its own `Parse.Cloud.define` calls, then add `require('./marketData');` to
`cloud/functions/index.js`. Reuse `lib/` for anything shared across modules.

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

### Errors

Alpaca error responses are normalized into `Parse.Error` with the Alpaca
message attached, so the app can display something meaningful instead of a
raw HTTP error.

## Next steps (not yet built)

- Market data (quotes/bars) if the app needs live pricing beyond order fills
- Watchlists
- Per-user auth, if this ever needs to support more than one person
