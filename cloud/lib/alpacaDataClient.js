/**
 * Client for Alpaca's Market Data API (quotes, trades, bars).
 *
 * Uses the same paper trading key/secret as the trading API — market
 * data access is tied to the account, not the paper/live split — but
 * talks to a different host and defaults to the free IEX feed.
 *
 * Optional environment variables (not required — sensible defaults):
 *   ALPACA_DATA_BASE_URL   default https://data.alpaca.markets
 *   ALPACA_DATA_FEED       default "iex" (use "sip" if you have that
 *                           subscription on Alpaca)
 */

const { createAlpacaRequest } = require('./httpClient');

function getConfig() {
  const baseURL = process.env.ALPACA_DATA_BASE_URL || 'https://data.alpaca.markets';
  const keyId = process.env.ALPACA_PAPER_KEY_ID;
  const secretKey = process.env.ALPACA_PAPER_SECRET_KEY;
  const feed = process.env.ALPACA_DATA_FEED || 'iex';

  if (!keyId || !secretKey) {
    throw new Error(
      'Missing Alpaca credentials. Ensure ALPACA_PAPER_KEY_ID and ' +
        'ALPACA_PAPER_SECRET_KEY are set as environment variables on ' +
        'Back4App (or in a local .env file for local testing).'
    );
  }

  return { baseURL, keyId, secretKey, feed };
}

const alpacaDataRequest = createAlpacaRequest({ getConfig, errorLabel: 'Alpaca Data API' });

module.exports = { alpacaDataRequest, getConfig };
