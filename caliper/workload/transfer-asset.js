'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class TransferAssetWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        this.assetIDs = [];
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.prefix = this.roundArguments.prefix || 'asset';
        this.workerIndex = workerIndex;
        
        // Generate asset IDs for transfer
        for (let i = 1; i <= 25; i++) {
            this.assetIDs.push(`${this.prefix}_${workerIndex}_${i}`);
        }
    }

    async submitTransaction() {
        this.txIndex++;
        
        const assetID = this.assetIDs[this.txIndex % this.assetIDs.length];
        const newOwner = `NewOwner_${this.txIndex}`;
        
        const args = {
            contractId: 'geo-asset',
            contractFunction: 'TransferAsset',
            contractArguments: [assetID, newOwner],
            readOnly: false
        };

        return this.sutAdapter.sendRequests(args);
    }
}

function createWorkloadModule() {
    return new TransferAssetWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
