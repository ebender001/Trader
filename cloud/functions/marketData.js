/**
 * Market data endpoints — latest quotes, polled by the app on an
 * interval. (Market open/closed status lives in account.js as
 * getClock; it changes rarely so it doesn't need this treatment.)
 *
 * A true push-based stream would need Alpaca's market data websocket
 * held open by an always-on process — Back4App Cloud Code isn't built
 * for that (it's request/response, not long-running). If real-time
 * push ever becomes worth the extra infrastructure, that would be a
 * separate Back4App Container relaying into Parse via LiveQuery, not
 * something added here.
 */

const { alpacaDataRequest, getConfig } = require('../lib/alpacaDataClient');
const { requireParams } = require('../lib/validation');
const { handleAlpacaError } = require('../lib/errors');

function parseSymbols(symbols) {
  if (Array.isArray(symbols)) return symbols;
  if (typeof symbols === 'string') {
    return symbols
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
  }
  return [];
}

Parse.Cloud.define('getQuote', async (request) => {
  requireParams(request, ['symbol']);
  const { feed } = getConfig();
  try {
    return await alpacaDataRequest(
      'GET',
      `/v2/stocks/${encodeURIComponent(request.params.symbol)}/quotes/latest`,
      { params: { feed } }
    );
  } catch (err) {
    handleAlpacaError(err);
  }
});

Parse.Cloud.define('getQuotes', async (request) => {
  requireParams(request, ['symbols']);
  const symbolList = parseSymbols(request.params.symbols);
  if (symbolList.length === 0) {
    throw new Parse.Error(
      Parse.Error.INVALID_JSON,
      'symbols must be a non-empty array or comma-separated string.'
    );
  }
  const { feed } = getConfig();
  try {
    return await alpacaDataRequest('GET', '/v2/stocks/quotes/latest', {
      params: { symbols: symbolList.join(','), feed },
    });
  } catch (err) {
    handleAlpacaError(err);
  }
});

/**
 * Latest index values (S&P 500, Nasdaq, Dow, etc.) — Alpaca added this
 * endpoint in June 2026 (GET /v1beta1/indices/latest/values), separate
 * from stock quotes since indexes aren't tradable equities. This just
 * proxies whatever Alpaca returns, so the response shape isn't reshaped
 * or assumed here — only the iOS-side model needs to match Alpaca's
 * actual field names, and that hasn't been verified against a live
 * response yet. Index symbols are Alpaca's own (e.g. SPX, DJI, IXIC) —
 * confirm exact symbols against Alpaca's docs/dashboard.
 */
Parse.Cloud.define('getIndexValues', async (request) => {
  requireParams(request, ['symbols']);
  const symbolList = parseSymbols(request.params.symbols);
  if (symbolList.length === 0) {
    throw new Parse.Error(
      Parse.Error.INVALID_JSON,
      'symbols must be a non-empty array or comma-separated string.'
    );
  }
  try {
    return await alpacaDataRequest('GET', '/v1beta1/indices/latest/values', {
      params: { index_symbols: symbolList.join(',') },
    });
  } catch (err) {
    handleAlpacaError(err);
  }
});
