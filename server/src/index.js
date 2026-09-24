import { createServer } from './api.js';

if (process.env.NODE_ENV === 'production' && !process.env.LUMALEX_APP_TOKEN) {
  throw new Error('LUMALEX_APP_TOKEN is required in production');
}

const port = Number(process.env.PORT || 8080);
createServer().listen(port, process.env.HOST || '127.0.0.1', () => {
  console.log(`LumaLex API listening on ${port}`);
});
