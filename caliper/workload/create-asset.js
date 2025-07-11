'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class CreateAssetWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.prefix = this.roundArguments.prefix || 'asset';
        this.workerIndex = workerIndex;
    }

    async submitTransaction() {
        this.txIndex++;
        
        // Generate random geo-coordinates for different regions
        const regions = [
            { name: 'Americas', lat: 37.7749, lng: -122.4194 },
            { name: 'Europe', lat: 51.5074, lng: -0.1278 },
            { name: 'Asia-Pacific', lat: 35.6762, lng: 139.6503 }
        ];
        
        const region = regions[this.txIndex % regions.length];
        
        // Add some randomness to coordinates
        const lat = region.lat + (Math.random() - 0.5) * 0.1;
        const lng = region.lng + (Math.random() - 0.5) * 0.1;
        
        const assetID = `${this.prefix}_${this.workerIndex}_${this.txIndex}`;
        
        const args = {
            contractId: 'geo-asset',
            contractFunction: 'CreateAsset',
            contractArguments: [
                assetID,
                `Asset ${assetID}`,
                `Owner ${this.workerIndex}`,
                lat.toString(),
                lng.toString(),
                region.name,
                '100'
            ],
            readOnly: false
        };

        return this.sutAdapter.sendRequests(args);
    }
}

function createWorkloadModule() {
    return new CreateAssetWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
