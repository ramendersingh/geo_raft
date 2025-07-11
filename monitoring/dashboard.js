const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');
const axios = require('axios');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

const PORT = process.env.PORT || 8080;

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// API endpoints
app.get('/api/metrics', async (req, res) => {
    try {
        const prometheusUrl = process.env.PROMETHEUS_URL || 'http://prometheus:9090';
        
        // Fetch various metrics from Prometheus
        const queries = [
            'hyperledger_fabric_orderer_consensus_etcdraft_leader_changes_total',
            'hyperledger_fabric_orderer_consensus_etcdraft_proposal_failures_total',
            'hyperledger_fabric_orderer_consensus_etcdraft_data_persist_duration',
            'rate(hyperledger_fabric_orderer_consensus_etcdraft_normal_proposals_received[5m])',
            'hyperledger_fabric_orderer_broadcast_enqueue_duration',
            'hyperledger_fabric_orderer_broadcast_validate_duration'
        ];

        const metrics = {};
        
        for (const query of queries) {
            try {
                const response = await axios.get(`${prometheusUrl}/api/v1/query`, {
                    params: { query }
                });
                metrics[query] = response.data.data.result;
            } catch (error) {
                console.error(`Error fetching metric ${query}:`, error.message);
                metrics[query] = [];
            }
        }

        res.json({
            timestamp: new Date().toISOString(),
            metrics
        });
    } catch (error) {
        console.error('Error fetching metrics:', error);
        res.status(500).json({ error: 'Failed to fetch metrics' });
    }
});

app.get('/api/topology', async (req, res) => {
    try {
        // In a real implementation, this would fetch from the consensus service
        const topology = {
            timestamp: new Date().toISOString(),
            nodes: [
                {
                    id: 'orderer1',
                    region: 'us-west',
                    zone: 'us-west-1a',
                    latitude: 37.7749,
                    longitude: -122.4194,
                    status: 'active',
                    isLeader: true,
                    connections: ['orderer2', 'orderer3']
                },
                {
                    id: 'orderer2',
                    region: 'us-east',
                    zone: 'us-east-1a',
                    latitude: 40.7128,
                    longitude: -74.0060,
                    status: 'active',
                    isLeader: false,
                    connections: ['orderer1', 'orderer3']
                },
                {
                    id: 'orderer3',
                    region: 'eu-west',
                    zone: 'eu-west-1a',
                    latitude: 51.5074,
                    longitude: -0.1278,
                    status: 'active',
                    isLeader: false,
                    connections: ['orderer1', 'orderer2']
                }
            ],
            regions: {
                'us-west': { leader: 'orderer1', nodes: 1 },
                'us-east': { leader: 'orderer2', nodes: 1 },
                'eu-west': { leader: 'orderer3', nodes: 1 }
            }
        };

        res.json(topology);
    } catch (error) {
        console.error('Error fetching topology:', error);
        res.status(500).json({ error: 'Failed to fetch topology' });
    }
});

app.get('/api/performance', async (req, res) => {
    try {
        const prometheusUrl = process.env.PROMETHEUS_URL || 'http://prometheus:9090';
        
        // Fetch performance metrics
        const performanceQueries = [
            'rate(hyperledger_fabric_orderer_consensus_etcdraft_normal_proposals_received[1m])',
            'histogram_quantile(0.95, rate(hyperledger_fabric_orderer_broadcast_enqueue_duration_bucket[5m]))',
            'histogram_quantile(0.95, rate(hyperledger_fabric_orderer_broadcast_validate_duration_bucket[5m]))',
            'hyperledger_fabric_orderer_consensus_etcdraft_leader_changes_total'
        ];

        const performance = {};
        
        for (const query of performanceQueries) {
            try {
                const response = await axios.get(`${prometheusUrl}/api/v1/query`, {
                    params: { query }
                });
                performance[query] = response.data.data.result;
            } catch (error) {
                console.error(`Error fetching performance metric ${query}:`, error.message);
                performance[query] = [];
            }
        }

        // Calculate derived metrics
        const summary = {
            totalThroughput: 0,
            avgLatency: 0,
            leaderChanges: 0,
            regionalPerformance: {
                'us-west': { throughput: Math.random() * 100 + 50, latency: Math.random() * 50 + 10 },
                'us-east': { throughput: Math.random() * 100 + 50, latency: Math.random() * 50 + 15 },
                'eu-west': { throughput: Math.random() * 100 + 50, latency: Math.random() * 50 + 25 }
            }
        };

        res.json({
            timestamp: new Date().toISOString(),
            performance,
            summary
        });
    } catch (error) {
        console.error('Error fetching performance data:', error);
        res.status(500).json({ error: 'Failed to fetch performance data' });
    }
});

app.get('/api/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: '1.0.0'
    });
});

// WebSocket connections for real-time updates
io.on('connection', (socket) => {
    console.log('Client connected:', socket.id);
    
    socket.on('subscribe', (data) => {
        console.log('Client subscribed to:', data);
        socket.join(data.room || 'general');
    });
    
    socket.on('disconnect', () => {
        console.log('Client disconnected:', socket.id);
    });
});

// Real-time data broadcasting
setInterval(async () => {
    try {
        // Broadcast real-time metrics to connected clients
        const timestamp = new Date().toISOString();
        const realTimeData = {
            timestamp,
            throughput: Math.floor(Math.random() * 200) + 100,
            latency: Math.floor(Math.random() * 100) + 50,
            activeNodes: 3,
            consensusStatus: 'stable',
            leaderRegion: 'us-west',
            crossRegionLatency: {
                'us-west-us-east': Math.floor(Math.random() * 50) + 70,
                'us-west-eu-west': Math.floor(Math.random() * 80) + 150,
                'us-east-eu-west': Math.floor(Math.random() * 60) + 80
            }
        };
        
        io.emit('realtime-metrics', realTimeData);
    } catch (error) {
        console.error('Error broadcasting real-time data:', error);
    }
}, 5000); // Broadcast every 5 seconds

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Server error:', error);
    res.status(500).json({ error: 'Internal server error' });
});

server.listen(PORT, () => {
    console.log(`Geo-consensus monitoring dashboard running on port ${PORT}`);
    console.log(`Dashboard available at: http://localhost:${PORT}`);
});
