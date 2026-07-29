/**
 * Client for Alpaca's Trading API (paper trading).
 *
 * Reads credentials from environment variables. On Back4App these are
 * set in Dashboard > App Settings > Server Settings > Environment
 * Variables (Cloud Code section):
 *   ALPACA_PAPER_BASE_URL   e.g. https://paper-api.alpaca.markets
 *   ALPACA_PAPER_KEY_ID
 *   ALPACA_PAPER_SECRET_KEY
 *   TRADING_MODE            e.g. "paper" (informational, used for logging)
 */

const { createAlpacaRequest } = require('./httpClient');

function getConfig() {
  const baseURL = process.env.ALPACA_PAPER_BASE_URL;
  const keyId = process.env.ALPACA_PAPER_KEY_ID;
  const secretKey = process.env.ALPACA_PAPER_SECRET_KEY;
  const tradingMode = process.env.TRADING_MODE || 'paper';

  if (!baseURL || !keyId || !secretKey) {
    throw new Error(
      'Missing Alpaca credentials. Ensure ALPACA_PAPER_BASE_URL, ' +
        'ALPACA_PAPER_KEY_ID and ALPACA_PAPER_SECRET_KEY are set as ' +
        'environment variables on Back4App (or in a local .env file for ' +
        'local testing).'
    );
  }

  return { baseURL, keyId, secretKey, tradingMode };
}

const alpacaRequest = createAlpacaRequest({ getConfig, errorLabel: 'Alpaca API' });

module.exports = { alpacaRequest, getConfig };
