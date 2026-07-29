/**
 * Position management endpoints.
 */

const { alpacaRequest } = require('../lib/alpacaClient');
const { requireParams } = require('../lib/validation');
const { handleAlpacaError } = require('../lib/errors');

Parse.Cloud.define('getPositions', async () => {
  try {
    return await alpacaRequest('GET', '/v2/positions');
  } catch (err) {
    handleAlpacaError(err);
  }
});

Parse.Cloud.define('getPosition', async (request) => {
  requireParams(request, ['symbol']);
  try {
    return await alpacaRequest(
      'GET',
      `/v2/positions/${encodeURIComponent(request.params.symbol)}`
    );
  } catch (err) {
    handleAlpacaError(err);
  }
});

Parse.Cloud.define('closePosition', async (request) => {
  requireParams(request, ['symbol']);
  const { symbol, qty, percentage } = request.params;
  const params = {};
  if (qty !== undefined) params.qty = qty;
  if (percentage !== undefined) params.percentage = percentage;
  try {
    return await alpacaRequest(
      'DELETE',
      `/v2/positions/${encodeURIComponent(symbol)}`,
      { params }
    );
  } catch (err) {
    handleAlpacaError(err);
  }
});

Parse.Cloud.define('closeAllPositions', async (request) => {
  const params = {};
  if (request.params.cancelOrders !== undefined) {
    params.cancel_orders = request.params.cancelOrders;
  }
  try {
    return await alpacaRequest('DELETE', '/v2/positions', { params });
  } catch (err) {
    handleAlpacaError(err);
  }
});
