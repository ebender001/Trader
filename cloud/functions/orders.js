/**
 * Order management endpoints.
 */

const { alpacaRequest } = require('../lib/alpacaClient');
const { requireParams, requireOneOf } = require('../lib/validation');
const { handleAlpacaError } = require('../lib/errors');
const { ORDER_SIDES, ORDER_TYPES, TIME_IN_FORCE } = require('../lib/constants');

Parse.Cloud.define('placeOrder', async (request) => {
  requireParams(request, ['symbol', 'side', 'type', 'timeInForce']);
  const {
    symbol,
    qty,
    notional,
    side,
    type,
    timeInForce,
    limitPrice,
    stopPrice,
    trailPrice,
    trailPercent,
    extendedHours,
    clientOrderId,
  } = request.params;

  if (qty === undefined && notional === undefined) {
    throw new Parse.Error(Parse.Error.INVALID_JSON, 'Provide either qty or notional.');
  }
  requireOneOf(side, ORDER_SIDES, 'side');
  requireOneOf(type, ORDER_TYPES, 'type');
  requireOneOf(timeInForce, TIME_IN_FORCE, 'timeInForce');
  if ((type === 'limit' || type === 'stop_limit') && limitPrice === undefined) {
    throw new Parse.Error(
      Parse.Error.INVALID_JSON,
      'limitPrice is required for limit and stop_limit orders.'
    );
  }
  if ((type === 'stop' || type === 'stop_limit') && stopPrice === undefined) {
    throw new Parse.Error(
      Parse.Error.INVALID_JSON,
      'stopPrice is required for stop and stop_limit orders.'
    );
  }

  const data = { symbol, side, type, time_in_force: timeInForce };
  if (qty !== undefined) data.qty = qty;
  if (notional !== undefined) data.notional = notional;
  if (limitPrice !== undefined) data.limit_price = limitPrice;
  if (stopPrice !== undefined) data.stop_price = stopPrice;
  if (trailPrice !== undefined) data.trail_price = trailPrice;
  if (trailPercent !== undefined) data.trail_percent = trailPercent;
  if (extendedHours !== undefined) data.extended_hours = extendedHours;
  if (clientOrderId !== undefined) data.client_order_id = clientOrderId;

  try {
    return await alpacaRequest('POST', '/v2/orders', { data });
  } catch (err) {
    handleAlpacaError(err);
  }
});

Parse.Cloud.define('listOrders', async (request) => {
  const { status, limit, after, until, direction, symbols } = request.params;
  const params = {};
  if (status !== undefined) params.status = status;
  if (limit !== undefined) params.limit = limit;
  if (after !== undefined) params.after = after;
  if (until !== undefined) params.until = until;
  if (direction !== undefined) params.direction = direction;
  if (symbols !== undefined) params.symbols = symbols;
  try {
    return await alpacaRequest('GET', '/v2/orders', { params });
  } catch (err) {
    handleAlpacaError(err);
  }
});

Parse.Cloud.define('getOrder', async (request) => {
  requireParams(request, ['orderId']);
  try {
    return await alpacaRequest(
      'GET',
      `/v2/orders/${encodeURIComponent(request.params.orderId)}`
    );
  } catch (err) {
    handleAlpacaError(err);
  }
});

Parse.Cloud.define('cancelOrder', async (request) => {
  requireParams(request, ['orderId']);
  try {
    await alpacaRequest(
      'DELETE',
      `/v2/orders/${encodeURIComponent(request.params.orderId)}`
    );
    return { success: true };
  } catch (err) {
    handleAlpacaError(err);
  }
});

Parse.Cloud.define('cancelAllOrders', async () => {
  try {
    return await alpacaRequest('DELETE', '/v2/orders');
  } catch (err) {
    handleAlpacaError(err);
  }
});
