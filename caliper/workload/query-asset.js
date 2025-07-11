'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class QueryAssetWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        this.assetIDs = [];
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.prefix = this.roundArguments.prefix || 'asset';
        this.workerIndex = workerIndex;
        
        // Generate asset IDs that should exist from previous round
        for (let i = 1; i <= 25; i++) { // Assuming 100 assets created with 4 workers
            this.assetIDs.push(`${this.prefix}_${workerIndex}_${i}`);
        }
    }

    async submitTransaction() {
        this.txIndex++;
        
        // Query a random asset that should exist
        const assetID = this.assetIDs[this.txIndex % this.assetIDs.length];
        
        const args = {
            contractId: 'geo-asset',
            contractFunction: 'GetAsset',
            contractArguments: [assetID],
            readOnly: true
        };

        return this.sutAdapter.sendRequests(args);
    }
}

function createWorkloadModule() {
    return new QueryAssetWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
