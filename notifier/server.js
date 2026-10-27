'use strict';

const http = require('node:http');

const port = Number(process.env.PORT || 4000);

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'UP' }));
    return;
  }

  if (req.method === 'POST' && req.url === '/notify') {
    let body = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => {
      try {
        const notification = JSON.parse(body);
        console.log(`[notifier] nouveau produit : ${JSON.stringify(notification)}`);
        res.writeHead(202, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ received: true }));
      } catch {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'invalid_json' }));
      }
    });
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not_found' }));
});

server.listen(port, () => {
  console.log(`[notifier] started on port ${port}`);
});
