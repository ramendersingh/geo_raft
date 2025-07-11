'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class MixedWorkloadModule extends WorkloadModuleBase {
    constructor() {
        super();
        this.assetIndex = 0;
        this.totalAssets = 0;
        this.workerIndex = 0;
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.workerIndex = workerIndex;
        this.totalAssets = roundArguments.totalAssets || 50000;
        this.assetIndex = workerIndex * 1000;
        
        console.log(`Worker ${workerIndex}: Initialized mixed workload for ${this.totalAssets} total assets`);
    }

    async submitTransaction() {
        // Weighted random selection based on realistic usage patterns
        const random = Math.random() * 100;
        
        if (random < 40) {
            // 40% - Create Asset
            return this.createAsset();
        } else if (random < 75) {
            // 35% - Query Asset
            return this.queryAsset();
        } else if (random < 90) {
            // 15% - Transfer Asset
            return this.transferAsset();
        } else {
            // 10% - Geographic Query
            return this.geoQuery();
        }
    }

    async createAsset() {
        this.assetIndex++;
        const assetID = `asset_${this.workerIndex}_${this.assetIndex}`;
        
        // Generate realistic geographic coordinates
        const regions = [
            { lat: 38.9072, lng: -77.0369, name: 'Americas' },
            { lat: 51.5074, lng: -0.1278, name: 'Europe' },
            { lat: 35.6762, lng: 139.6503, name: 'Asia-Pacific' }
        ];
        
        const region = regions[Math.floor(Math.random() * regions.length)];
        const lat = region.lat + (Math.random() - 0.5) * 0.1; // Small variance
        const lng = region.lng + (Math.random() - 0.5) * 0.1;
        
        const args = {
            contractId: 'geo-asset',
            contractFunction: 'CreateAsset',
            contractArguments: [
                assetID,
                `Asset ${assetID}`,
                JSON.stringify({
                    type: 'digital_asset',
                    region: region.name,
                    coordinates: { lat, lng },
                    timestamp: Date.now(),
                    value: Math.floor(Math.random() * 10000) + 1000,
                    metadata: {
                        worker: this.workerIndex,
                        batch: Math.floor(this.assetIndex / 100)
                    }
                }),
                `owner_${this.workerIndex}_${Math.floor(Math.random() * 100)}`
            ],
            invokerIdentity: 'User1',
            readOnly: false
        };

        return this.sutAdapter.sendRequests(args);
    }

    async queryAsset() {
        // Query existing assets with some probability of finding them
        const randomAssetIndex = Math.floor(Math.random() * Math.min(this.assetIndex, 1000));
        const assetID = `asset_${Math.floor(Math.random() * this.sutAdapter.context.workerIndex + 1)}_${randomAssetIndex}`;

        const args = {
            contractId: 'geo-asset',
            contractFunction: 'ReadAsset',
            contractArguments: [assetID],
            invokerIdentity: 'User1',
            readOnly: true
        };

        return this.sutAdapter.sendRequests(args);
    }

    async transferAsset() {
        const randomAssetIndex = Math.floor(Math.random() * Math.min(this.assetIndex, 1000));
        const assetID = `asset_${Math.floor(Math.random() * this.sutAdapter.context.workerIndex + 1)}_${randomAssetIndex}`;
        const newOwner = `owner_${this.workerIndex}_${Math.floor(Math.random() * 100)}`;

        const args = {
            contractId: 'geo-asset',
            contractFunction: 'TransferAsset',
            contractArguments: [assetID, newOwner],
            invokerIdentity: 'User1',
            readOnly: false
        };

        return this.sutAdapter.sendRequests(args);
    }

    async geoQuery() {
        // Random geographic center for proximity search
        const regions = [
            { lat: 38.9072, lng: -77.0369 },
            { lat: 51.5074, lng: -0.1278 },
            { lat: 35.6762, lng: 139.6503 }
        ];
        
        const region = regions[Math.floor(Math.random() * regions.length)];
        const radius = 50 + Math.random() * 100; // 50-150 km radius

        const args = {
            contractId: 'geo-asset',
            contractFunction: 'GetNearbyAssets',
            contractArguments: [
                region.lat.toString(),
                region.lng.toString(),
                radius.toString()
            ],
            invokerIdentity: 'User1',
            readOnly: true
        };

        return this.sutAdapter.sendRequests(args);
    }

    async cleanupWorkloadModule() {
        console.log(`Worker ${this.workerIndex}: Mixed workload completed. Created ${this.assetIndex} assets.`);
    }
}

function createWorkloadModule() {
    return new MixedWorkloadModule();
}

module.exports.createWorkloadModule = createWorkloadModule;
