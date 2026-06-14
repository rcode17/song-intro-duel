const { onRequest } = require('firebase-functions/v2/https');
const fetch = (...args) => import('node-fetch').then(({ default: f }) => f(...args));

// Proxy para la API de Deezer — resuelve el problema de CORS desde el navegador.
// La Cloud Function hace la petición desde el servidor y agrega los headers CORS.
exports.deezerProxy = onRequest(
  {
    cors: ['https://song-intro-duel.web.app', 'http://localhost:*'],
    region: 'us-central1',
  },
  async (req, res) => {
    const q = req.query.q;
    const limit = req.query.limit || '15';
    const order = req.query.order || 'RANKING';

    if (!q) {
      res.status(400).json({ error: 'Missing query parameter: q' });
      return;
    }

    try {
      const url = `https://api.deezer.com/search?q=${encodeURIComponent(q)}&limit=${limit}&order=${order}`;
      const response = await fetch(url);
      const data = await response.json();
      res.json(data);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  }
);
