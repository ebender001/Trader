/**
 * Local connectivity check for the Alpaca wrapper — run this in VSCode
 * before deploying to Back4App, so you can verify credentials and the
 * request logic without a deploy round-trip.
 *
 * Setup (one time):
 *   cd cloud
 *   npm install
 *   npm install --save-dev dotenv
 *   cp test/.env.example test/.env   (then fill in your real values)
 *
 * Run:
 *   node test/local-test.js
 */

require('dotenv').config({ path: __dirname + '/.env' });

// eslint-disable-next-line import/no-unresolved
const { alpacaRequest } = require('../lib/alpacaClient');

async function main() {
  console.log(`Trading mode: ${process.env.TRADING_MODE || 'paper'}`);
  console.log('Fetching Alpaca account...');
  const account = await alpacaRequest('GET', '/v2/account');
  console.log('Account status:', account.status);
  console.log('Buying power:', account.buying_power);

  console.log('\nFetching market clock...');
  const clock = await alpacaRequest('GET', '/v2/clock');
  console.log('Market open:', clock.is_open);

  console.log('\nFetching open positions...');
  const positions = await alpacaRequest('GET', '/v2/positions');
  console.log(`Open positions: ${positions.length}`);

  console.log('\nAll good — credentials and requests are working.');
}

main().catch((err) => {
  console.error('Local test failed:', err.message);
  process.exit(1);
});
