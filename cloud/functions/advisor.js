/**
 * AI trade-suggestion advisor.
 *
 * Goals/parameters live in a single AdvisorProfile Parse object (this is
 * a single-user app, so there's only ever one). getTradeSuggestions
 * reads that profile plus live account/position/quote data, asks
 * OpenAI for structured suggestions, and applies guardrails in code —
 * the model's output is never trusted blindly. Every run is logged to
 * the TradeSuggestion class, including runs that suggest nothing, so
 * suggestion quality can be reviewed later.
 *
 * This never places orders itself — placeOrder (orders.js) is still the
 * only thing that touches Alpaca's trading API. Suggestions are meant
 * to be reviewed and accepted/rejected by a human.
 */

const { alpacaRequest } = require('../lib/alpacaClient');
const { alpacaDataRequest, getConfig: getDataConfig } = require('../lib/alpacaDataClient');
const { runStructuredChat } = require('../lib/openaiClient');
const { requireParams, requireOneOf } = require('../lib/validation');
const { handleAlpacaError } = require('../lib/errors');

const ADVISOR_PROFILE_CLASS = 'AdvisorProfile';
const TRADE_SUGGESTION_CLASS = 'TradeSuggestion';
const RISK_TOLERANCES = ['conservative', 'moderate', 'aggressive'];
const DEFAULT_MAX_SUGGESTIONS_PER_RUN = 3;

// ---------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------

async function loadProfile() {
  const AdvisorProfile = Parse.Object.extend(ADVISOR_PROFILE_CLASS);
  const query = new Parse.Query(AdvisorProfile);
  return query.first({ useMasterKey: true });
}

function profileToJSON(profile) {
  if (!profile) return null;
  return {
    riskTolerance: profile.get('riskTolerance'),
    maxPositionPercent: profile.get('maxPositionPercent'),
    maxOpenPositions: profile.get('maxOpenPositions'),
    symbolUniverse: profile.get('symbolUniverse') || [],
    strategyBias: profile.get('strategyBias') || '',
    timeHorizon: profile.get('timeHorizon') || '',
    maxSuggestionsPerRun: profile.get('maxSuggestionsPerRun') || DEFAULT_MAX_SUGGESTIONS_PER_RUN,
    updatedAt: profile.updatedAt,
  };
}

Parse.Cloud.define('getAdvisorProfile', async () => {
  const profile = await loadProfile();
  return profileToJSON(profile);
});

Parse.Cloud.define('saveAdvisorProfile', async (request) => {
  requireParams(request, ['riskTolerance', 'maxPositionPercent', 'maxOpenPositions', 'symbolUniverse']);
  const {
    riskTolerance,
    maxPositionPercent,
    maxOpenPositions,
    symbolUniverse,
    strategyBias,
    timeHorizon,
    maxSuggestionsPerRun,
  } = request.params;

  requireOneOf(riskTolerance, RISK_TOLERANCES, 'riskTolerance');
  if (typeof maxPositionPercent !== 'number' || maxPositionPercent <= 0 || maxPositionPercent > 100) {
    throw new Parse.Error(
      Parse.Error.INVALID_JSON,
      'maxPositionPercent must be a number between 0 and 100.'
    );
  }
  if (typeof maxOpenPositions !== 'number' || maxOpenPositions <= 0) {
    throw new Parse.Error(Parse.Error.INVALID_JSON, 'maxOpenPositions must be a positive number.');
  }
  if (!Array.isArray(symbolUniverse) || symbolUniverse.length === 0) {
    throw new Parse.Error(
      Parse.Error.INVALID_JSON,
      'symbolUniverse must be a non-empty array of symbols.'
    );
  }

  const AdvisorProfile = Parse.Object.extend(ADVISOR_PROFILE_CLASS);
  let profile = await loadProfile();
  if (!profile) {
    profile = new AdvisorProfile();
  }
  profile.set('riskTolerance', riskTolerance);
  profile.set('maxPositionPercent', maxPositionPercent);
  profile.set('maxOpenPositions', maxOpenPositions);
  profile.set('symbolUniverse', symbolUniverse.map((s) => String(s).toUpperCase()));
  profile.set('strategyBias', strategyBias || '');
  profile.set('timeHorizon', timeHorizon || '');
  profile.set('maxSuggestionsPerRun', maxSuggestionsPerRun || DEFAULT_MAX_SUGGESTIONS_PER_RUN);
  await profile.save(null, { useMasterKey: true });

  return profileToJSON(profile);
});

// ---------------------------------------------------------------------
// Suggestions
// ---------------------------------------------------------------------

const SUGGESTION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    summary: {
      type: 'string',
      description:
        'One or two sentence overview of this run\'s reasoning. If ' +
        'suggesting nothing, explain why that is the right call.',
    },
    suggestions: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          symbol: { type: 'string' },
          action: { type: 'string', enum: ['buy', 'sell'] },
          quantity: { type: 'number' },
          orderType: { type: 'string', enum: ['market', 'limit'] },
          limitPrice: { type: ['number', 'null'] },
          confidence: { type: 'string', enum: ['low', 'medium', 'high'] },
          rationale: { type: 'string' },
        },
        required: ['symbol', 'action', 'quantity', 'orderType', 'limitPrice', 'confidence', 'rationale'],
      },
    },
  },
  required: ['summary', 'suggestions'],
};

function buildSystemPrompt() {
  return [
    'You are a cautious research assistant suggesting possible trades for a',
    'PAPER (fake-money) brokerage account. Base suggestions only on the',
    'account, position, and quote data provided in this message — you have',
    'no other data source and no memory of past runs.',
    '',
    'Rules:',
    '- Only ever suggest symbols that appear in the provided symbol universe.',
    '  Never suggest anything outside that list.',
    '- Respect the stated risk tolerance, max position size, and max open',
    '  position count. Do not propose a trade that obviously violates them.',
    '- Suggesting zero trades is a good, expected outcome when nothing in the',
    '  universe looks attractive right now. Do not force suggestions just to',
    '  have something to say.',
    '- This is paper trading with no real money at risk, but reason as if it',
    '  were real money: no wild speculation, and give a brief, concrete',
    '  rationale for each suggestion.',
    '- You are not a licensed financial advisor and this is not financial',
    '  advice.',
  ].join('\n');
}

Parse.Cloud.define('getTradeSuggestions', async () => {
  const profile = await loadProfile();
  const profileData = profileToJSON(profile);
  if (!profileData || profileData.symbolUniverse.length === 0) {
    throw new Parse.Error(
      Parse.Error.INVALID_JSON,
      'No advisor profile set up yet. Call saveAdvisorProfile first with ' +
        'your goals and an approved symbol universe.'
    );
  }

  let account;
  let positions;
  let clock;
  try {
    [account, positions, clock] = await Promise.all([
      alpacaRequest('GET', '/v2/account'),
      alpacaRequest('GET', '/v2/positions'),
      alpacaRequest('GET', '/v2/clock'),
    ]);
  } catch (err) {
    handleAlpacaError(err);
  }

  let quotes = {};
  try {
    const { feed } = getDataConfig();
    const quotesResponse = await alpacaDataRequest('GET', '/v2/stocks/quotes/latest', {
      params: { symbols: profileData.symbolUniverse.join(','), feed },
    });
    quotes = quotesResponse.quotes || {};
  } catch (err) {
    handleAlpacaError(err);
  }

  const userContent = JSON.stringify({
    profile: profileData,
    account: {
      equity: account.equity,
      cash: account.cash,
      buyingPower: account.buying_power,
    },
    positions: positions.map((p) => ({
      symbol: p.symbol,
      qty: p.qty,
      side: p.side,
      avgEntryPrice: p.avg_entry_price,
      marketValue: p.market_value,
      unrealizedPLPercent: p.unrealized_plpc,
    })),
    marketOpen: clock.is_open,
    quotes,
  });

  let result;
  try {
    result = await runStructuredChat({
      systemPrompt: buildSystemPrompt(),
      userContent,
      schemaName: 'trade_suggestions',
      schema: SUGGESTION_SCHEMA,
    });
  } catch (err) {
    throw new Parse.Error(Parse.Error.INTERNAL_SERVER_ERROR, err.message);
  }

  // --- Guardrails. The model's output is never trusted blindly. ---
  const equity = parseFloat(account.equity) || 0;
  const maxPositionValue = equity * (profileData.maxPositionPercent / 100);
  const openSymbols = new Set(positions.map((p) => p.symbol));
  const maxNewPositions = Math.max(0, profileData.maxOpenPositions - openSymbols.size);
  const maxSuggestions = profileData.maxSuggestionsPerRun;

  const accepted = [];
  let newPositionsCounted = 0;
  for (const suggestion of result.suggestions || []) {
    if (!suggestion || typeof suggestion.symbol !== 'string') continue;
    if (!profileData.symbolUniverse.includes(suggestion.symbol)) continue;
    if (!['buy', 'sell'].includes(suggestion.action)) continue;
    if (typeof suggestion.quantity !== 'number' || suggestion.quantity <= 0) continue;

    if (suggestion.action === 'buy') {
      const isNewPosition = !openSymbols.has(suggestion.symbol);
      if (isNewPosition && newPositionsCounted >= maxNewPositions) continue;
      const price = (quotes[suggestion.symbol] && quotes[suggestion.symbol].ap) || 0;
      const estimatedValue = price * suggestion.quantity;
      if (maxPositionValue > 0 && estimatedValue > maxPositionValue) continue;
      if (isNewPosition) newPositionsCounted += 1;
    }

    accepted.push(suggestion);
    if (accepted.length >= maxSuggestions) break;
  }

  const TradeSuggestion = Parse.Object.extend(TRADE_SUGGESTION_CLASS);
  const saved = [];

  if (accepted.length === 0) {
    const record = new TradeSuggestion();
    record.set('action', 'none');
    record.set('rationale', result.summary || 'No suggestions this run.');
    record.set('status', 'info');
    record.set('profileSnapshot', profileData);
    await record.save(null, { useMasterKey: true });
    saved.push(record);
  } else {
    for (const suggestion of accepted) {
      const record = new TradeSuggestion();
      record.set('symbol', suggestion.symbol);
      record.set('action', suggestion.action);
      record.set('quantity', suggestion.quantity);
      record.set('orderType', suggestion.orderType);
      record.set('limitPrice', suggestion.limitPrice);
      record.set('confidence', suggestion.confidence);
      record.set('rationale', suggestion.rationale);
      record.set('status', 'pending');
      record.set('profileSnapshot', profileData);
      await record.save(null, { useMasterKey: true });
      saved.push(record);
    }
  }

  return {
    summary: result.summary,
    suggestions: saved.map(suggestionToJSON),
  };
});

function suggestionToJSON(record) {
  return {
    id: record.id,
    symbol: record.get('symbol') || null,
    action: record.get('action'),
    quantity: record.get('quantity') || null,
    orderType: record.get('orderType') || null,
    limitPrice: record.get('limitPrice') != null ? record.get('limitPrice') : null,
    confidence: record.get('confidence') || null,
    rationale: record.get('rationale'),
    status: record.get('status'),
    resultingOrderId: record.get('resultingOrderId') || null,
    createdAt: record.createdAt,
  };
}

// ---------------------------------------------------------------------
// Decision tracking
// ---------------------------------------------------------------------

Parse.Cloud.define('recordSuggestionDecision', async (request) => {
  requireParams(request, ['suggestionId', 'decision']);
  const { suggestionId, decision, resultingOrderId } = request.params;
  requireOneOf(decision, ['accepted', 'rejected'], 'decision');

  const TradeSuggestion = Parse.Object.extend(TRADE_SUGGESTION_CLASS);
  const query = new Parse.Query(TradeSuggestion);
  let record;
  try {
    record = await query.get(suggestionId, { useMasterKey: true });
  } catch (err) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Suggestion not found.');
  }

  record.set('status', decision);
  if (resultingOrderId) {
    record.set('resultingOrderId', resultingOrderId);
  }
  await record.save(null, { useMasterKey: true });

  return { success: true };
});

Parse.Cloud.define('listTradeSuggestions', async (request) => {
  const { limit, status } = request.params;
  const TradeSuggestion = Parse.Object.extend(TRADE_SUGGESTION_CLASS);
  const query = new Parse.Query(TradeSuggestion);
  if (status) query.equalTo('status', status);
  query.descending('createdAt');
  query.limit(limit || 20);
  const results = await query.find({ useMasterKey: true });
  return results.map(suggestionToJSON);
});
