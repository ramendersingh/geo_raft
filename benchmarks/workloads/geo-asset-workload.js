const { WorkerInterface, CaliperUtils } = require('@hyperledger/caliper-core');

class GeoAssetWorkload extends WorkerInterface {
    constructor() {
        super();
        this.assetCounter = 0;
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.workerIndex = workerIndex;
        this.totalWorkers = totalWorkers;
        this.roundIndex = roundIndex;
        this.roundArguments = roundArguments;
        
        // Initialize with some test data
        console.log(`Initializing worker ${workerIndex} for geo-asset workload`);
    }

    async submitTransaction() {
        this.assetCounter++;
        
        const assetId = `geo-asset-${this.workerIndex}-${this.assetCounter}`;
        
        // Simulate different geographic locations
        const locations = [
            { name: "New York", lat: 40.7128, lon: -74.0060 },
            { name: "London", lat: 51.5074, lon: -0.1278 },
            { name: "Tokyo", lat: 35.6762, lon: 139.6503 },
            { name: "Sydney", lat: -33.8688, lon: 151.2093 },
            { name: "San Francisco", lat: 37.7749, lon: -122.4194 },
            { name: "Singapore", lat: 1.3521, lon: 103.8198 }
        ];
        
        const location = locations[Math.floor(Math.random() * locations.length)];
        const value = Math.floor(Math.random() * 1000000) + 10000;
        
        const request = {
            contractId: 'geo-asset',
            contractFunction: 'CreateAsset',
            contractArguments: [
                assetId,
                `Asset in ${location.name}`,
                location.name,
                location.lat.toString(),
                location.lon.toString(),
                value.toString(),
                'USD',
                `Owner-${this.workerIndex}`
            ],
            timeout: 30
        };

        await this.sutAdapter.sendRequests(request);
    }

    async cleanupWorkloadModule() {
        console.log(`Worker ${this.workerIndex} cleanup completed`);
    }
}

function createWorkloadModule() {
    return new GeoAssetWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
