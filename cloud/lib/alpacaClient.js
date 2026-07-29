/**
 * Thin wrapper around the Alpaca Trading API (paper trading).
 *
 * Reads credentials from environment variables. On Back4App these are
 * set in Dashboard > App Settings > Server Settings > Environment
 * Variables (Cloud Code section):
 *   ALPACA_PAPER_BASE_URL   e.g. https://paper-api.alpaca.markets
 *   ALPACA_PAPER_KEY_ID
 *   ALPACA_PAPER_SECRET_KEY
 *   TRADING_MODE            e.g. "paper" (informational, used for logging)
 */

const axios = require('axios');

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

function client() {
  const { baseURL, keyId, secretKey } = getConfig();
  return axios.create({
    baseURL,
    headers: {
      'APCA-API-KEY-ID': keyId,
      'APCA-API-SECRET-KEY': secretKey,
      'Content-Type': 'application/json',
    },
    timeout: 15000,
  });
}

/**
 * Make a request against the Alpaca Trading API.
 * @param {string} method - HTTP method (GET, POST, DELETE, ...)
 * @param {string} path - API path, e.g. "/v2/account"
 * @param {{params?: object, data?: object}} [opts]
 */
async function alpacaRequest(method, path, opts = {}) {
  const { params, data } = opts;
  try {
    const response = await client().request({ method, url: path, params, data });
    return response.data;
  } catch (err) {
    if (err.response) {
      const body = err.response.data;
      const message = body && body.message ? body.message : JSON.stringify(body);
      const wrapped = new Error(`Alpaca API error (${err.response.status}): ${message}`);
      wrapped.status = err.response.status;
      wrapped.alpacaData = body;
      throw wrapped;
    }
    throw err;
  }
}

module.exports = { alpacaRequest, getConfig };
