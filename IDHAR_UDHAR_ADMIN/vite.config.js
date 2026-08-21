import { loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

function netlifyFunctionsDev(env) {
  return {
    name: 'netlify-functions-dev',
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        const url = req.url?.split('?')[0] || '';
        if (!url.startsWith('/.netlify/functions/')) return next();

        const name = url.replace('/.netlify/functions/', '').replace(/\/$/, '');
        if (!name || name.includes('..') || name.includes('/') || name === 'lib') return next();

        process.env.ADMIN_EMAIL = process.env.ADMIN_EMAIL || env.ADMIN_EMAIL || '';
        process.env.ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || env.ADMIN_PASSWORD || '';

        const chunks = [];
        req.on('data', (chunk) => chunks.push(chunk));
        req.on('end', async () => {
          try {
            const fileUrl = pathToFileURL(path.resolve('netlify/functions', `${name}.js`)).href;
            const mod = await import(`${fileUrl}?t=${Date.now()}`);
            const body = Buffer.concat(chunks).toString('utf8');
            const result = await mod.handler({
              httpMethod: req.method,
              headers: req.headers,
              body,
              isBase64Encoded: false,
            });
            Object.entries(result.headers || {}).forEach(([key, value]) => {
              if (value != null) res.setHeader(key, value);
            });
            res.statusCode = result.statusCode || 200;
            res.end(result.body || '');
          } catch {
            res.statusCode = 500;
            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ success: false, message: 'Invalid email or password.' }));
          }
        });
      });
    },
  };
}

export default ({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  return {
    plugins: [react(), netlifyFunctionsDev(env)],
    server: {
      port: 5173,
      host: true,
    },
  };
};
