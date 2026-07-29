/**
 * Account and market-meta endpoints.
 */

const { alpacaRequest } = require('../lib/alpacaClient');
const { requireParams } = require('../lib/validation');
const { handleAlpacaError } = require('../lib/errors');

Parse.Cloud.define('getAccount', async () => {
  try {
    return await alpacaRequest('GET', '/v2/account');
  } catch (err) {
    handleAlpacaError(err);
  }
});

Parse.Cloud.define('getClock', async () => {
  try {
    return await alpacaRequest('GET', '/v2/clock');
  } catch (err) {
    handleAlpacaError(err);
  }
});

Parse.Cloud.define('getAsset', async (request) => {
  requireParams(request, ['symbol']);
  try {
    return await alpacaRequest(
      'GET',
      `/v2/assets/${encodeURIComponent(request.params.symbol)}`
    );
  } catch (err) {
    handleAlpacaError(err);
  }
});
