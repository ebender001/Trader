/**
 * Client for OpenAI's Chat Completions API using Structured Outputs
 * (strict JSON schema), used by the trade-suggestion advisor.
 *
 * Environment variables:
 *   OPENAI_API_KEY   required
 *   OPENAI_MODEL     optional, default "gpt-5"
 */

const axios = require('axios');

function getConfig() {
  const apiKey = process.env.OPENAI_API_KEY;
  const model = process.env.OPENAI_MODEL || 'gpt-5';

  if (!apiKey) {
    throw new Error(
      'Missing OpenAI credentials. Ensure OPENAI_API_KEY is set as an ' +
        'environment variable on Back4App.'
    );
  }

  return { apiKey, model };
}

function client() {
  const { apiKey } = getConfig();
  return axios.create({
    baseURL: 'https://api.openai.com/v1',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    timeout: 60000,
  });
}

/**
 * Calls Chat Completions with a strict JSON-schema response format and
 * returns the already-parsed JSON object (not OpenAI's raw envelope).
 *
 * @param {object} opts
 * @param {string} opts.systemPrompt
 * @param {string} opts.userContent - typically JSON.stringify'd context
 * @param {string} opts.schemaName
 * @param {object} opts.schema - JSON schema; strict mode requires every
 *   property to be listed in `required` (use nullable types instead of
 *   omitting truly-optional fields) and `additionalProperties: false`
 *   on every object.
 */
async function runStructuredChat({ systemPrompt, userContent, schemaName, schema }) {
  const { model } = getConfig();
  try {
    const response = await client().post('/chat/completions', {
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userContent },
      ],
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: schemaName,
          strict: true,
          schema,
        },
      },
    });

    const message = response.data.choices && response.data.choices[0] && response.data.choices[0].message;
    if (!message) {
      throw new Error('OpenAI response was missing a message.');
    }
    if (message.refusal) {
      throw new Error(`OpenAI refused the request: ${message.refusal}`);
    }
    return JSON.parse(message.content);
  } catch (err) {
    if (err.response) {
      const body = err.response.data;
      const detail = body && body.error && body.error.message ? body.error.message : JSON.stringify(body);
      const wrapped = new Error(`OpenAI API error (${err.response.status}): ${detail}`);
      wrapped.status = err.response.status;
      throw wrapped;
    }
    throw err;
  }
}

module.exports = { runStructuredChat, getConfig };
