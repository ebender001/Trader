/**
 * Shared enums for Alpaca order parameters. Centralized here so future
 * modules (e.g. market data, watchlists) can reuse them instead of
 * redefining locally.
 */

const ORDER_SIDES = ['buy', 'sell'];
const ORDER_TYPES = ['market', 'limit', 'stop', 'stop_limit', 'trailing_stop'];
const TIME_IN_FORCE = ['day', 'gtc', 'opg', 'cls', 'ioc', 'fok'];

module.exports = { ORDER_SIDES, ORDER_TYPES, TIME_IN_FORCE };
