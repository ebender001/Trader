/**
 * Small request-validation helpers shared across cloud functions.
 */

function requireParams(request, names) {
  const missing = names.filter((n) => {
    const v = request.params[n];
    return v === undefined || v === null || v === '';
  });
  if (missing.length) {
    throw new Parse.Error(
      Parse.Error.INVALID_JSON,
      `Missing required parameter(s): ${missing.join(', ')}`
    );
  }
}

function requireOneOf(value, allowed, paramName) {
  if (!allowed.includes(value)) {
    throw new Parse.Error(
      Parse.Error.INVALID_JSON,
      `${paramName} must be one of: ${allowed.join(', ')}`
    );
  }
}

module.exports = { requireParams, requireOneOf };
