/**
 * Shared HTTP request factory for talking to Alpaca's REST APIs
 * (trading API and market data API use different hosts but identical
 * auth headers and error shapes, so both clients build on this).
 */

const axios = require('axios');

/**
 * @param {object} opts
 * @param {() => {baseURL: string, keyId: string, secretKey: string}} opts.getConfig
 *   Called fresh on every request so credential/env-var changes are
 *   picked up without needing a process restart.
 * @param {string} opts.errorLabel - prefix used in wrapped error messages
 * @returns {(method: string, path: string, opts?: {params?: object, data?: object}) => Promise<any>}
 */
function createAlpacaRequest({ getConfig, errorLabel }) {
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

  return async function request(method, path, opts = {}) {
    const { params, data } = opts;
    try {
      const response = await client().request({ method, url: path, params, data });
      return response.data;
    } catch (err) {
      if (err.response) {
        const body = err.response.data;
        const message = body && body.message ? body.message : JSON.stringify(body);
        const wrapped = new Error(`${errorLabel} error (${err.response.status}): ${message}`);
        wrapped.status = err.response.status;
        wrapped.alpacaData = body;
        throw wrapped;
      }
      throw err;
    }
  };
}

module.exports = { createAlpacaRequest };
