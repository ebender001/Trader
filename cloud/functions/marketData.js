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
