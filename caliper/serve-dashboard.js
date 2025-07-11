const http = require('http');
const fs = require('fs');
const path = require('path');

const server = http.createServer((req, res) => {
    if (req.url === '/' || req.url === '/dashboard') {
        fs.readFile(path.join(__dirname, 'dashboard.html'), (err, data) => {
            if (err) {
                res.writeHead(500);
                res.end('Error loading dashboard');
                return;
            }
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(data);
        });
    } else if (req.url === '/report') {
        fs.readFile(path.join(__dirname, 'performance-report.json'), (err, data) => {
            if (err) {
                res.writeHead(500);
                res.end('Error loading report');
                return;
            }
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(data);
        });
    } else {
        res.writeHead(404);
        res.end('Not found');
    }
});

const PORT = 8080;
server.listen(PORT, () => {
    console.log(`📊 Caliper Dashboard running at http://localhost:${PORT}`);
    console.log(`📋 Performance report available at http://localhost:${PORT}/report`);
});
