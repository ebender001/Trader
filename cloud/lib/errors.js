/**
 * Normalizes errors thrown by the Alpaca client into Parse.Error so the
 * app gets a consistent, readable error instead of a raw HTTP failure.
 */

function handleAlpacaError(err) {
  const code =
    err.status === 401 || err.status === 403
      ? Parse.Error.OPERATION_FORBIDDEN
      : Parse.Error.INTERNAL_SERVER_ERROR;
  throw new Parse.Error(code, err.message);
}

module.exports = { handleAlpacaError };
