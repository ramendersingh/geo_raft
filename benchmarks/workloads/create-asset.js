'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class CreateAssetWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        this.regions = {
            'us-west': { lat: 37.7749, lon: -122.4194, zone: 'us-west-1a' },
            'us-east': { lat: 40.7128, lon: -74.0060, zone: 'us-east-1a' },
            'eu-west': { lat: 51.5074, lon: -0.1278, zone: 'eu-west-1a' },
            'asia-northeast': { lat: 35.6762, lon: 139.6503, zone: 'asia-northeast-1a' },
            'asia-southeast': { lat: -33.8688, lon: 151.2093, zone: 'asia-southeast-2a' }
        };
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.contractId = this.roundArguments.contractId || 'geo-asset';
        this.region = this.roundArguments.region || 'us-west';
        this.zone = this.roundArguments.zone || 'us-west-1a';
        this.assetPrefix = this.roundArguments.assetPrefix || 'asset';
        this.workerIndex = workerIndex;
    }

    async submitTransaction() {
        this.txIndex++;
        
        const regionInfo = this.regions[this.region];
        const assetId = `${this.assetPrefix}-${this.workerIndex}-${this.txIndex}`;
        
        // Add some randomness to location within region
        const latVariation = (Math.random() - 0.5) * 0.1; // ±0.05 degrees
        const lonVariation = (Math.random() - 0.5) * 0.1; // ±0.05 degrees
        
        const latitude = regionInfo.lat + latVariation;
        const longitude = regionInfo.lon + lonVariation;
        
        const assetName = `Asset ${assetId} in ${this.region}`;
        const owner = `Owner-${this.workerIndex}-${this.txIndex}`;
        const value = Math.floor(Math.random() * 1000000) + 100000; // 100k to 1.1M
        const address = `Address ${this.txIndex}, ${this.region}`;

        const request = {
            contractId: this.contractId,
            contractFunction: 'CreateAsset',
            contractArguments: [
                assetId,
                assetName,
                owner,
                value.toString(),
                latitude.toString(),
                longitude.toString(),
                address,
                this.region,
                this.zone
            ],
            readOnly: false
        };

        await this.sutAdapter.sendRequests(request);
    }

    async cleanupWorkloadModule() {
        // Cleanup if needed
    }
}

function createWorkloadModule() {
    return new CreateAssetWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
