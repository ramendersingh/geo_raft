'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class TransferAssetWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        this.assets = [];
        this.regions = ['us-west', 'us-east', 'eu-west', 'asia-northeast', 'asia-southeast'];
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.contractId = this.roundArguments.contractId || 'geo-asset';
        this.crossRegion = this.roundArguments.crossRegion || false;
        this.workerIndex = workerIndex;
        
        // Populate assets list (in real scenario, query existing assets)
        await this.populateAssetsList();
    }

    async populateAssetsList() {
        try {
            const request = {
                contractId: this.contractId,
                contractFunction: 'GetAllAssets',
                contractArguments: [],
                readOnly: true
            };

            const response = await this.sutAdapter.sendRequests(request);
            if (response && response.status && response.status.success && response.result) {
                this.assets = JSON.parse(response.result);
            }
        } catch (error) {
            console.warn('Could not fetch existing assets, using generated list');
            // Generate some asset IDs for testing
            for (let i = 1; i <= 100; i++) {
                this.assets.push({
                    ID: `asset${i}`,
                    owner: `Owner${i}`,
                    region: this.regions[i % this.regions.length]
                });
            }
        }
    }

    async submitTransaction() {
        this.txIndex++;
        
        if (this.assets.length === 0) {
            throw new Error('No assets available for transfer');
        }

        // Select a random asset
        const randomAssetIndex = Math.floor(Math.random() * this.assets.length);
        const asset = this.assets[randomAssetIndex];
        
        // Generate new owner
        const newOwner = `NewOwner-${this.workerIndex}-${this.txIndex}`;
        
        // For cross-region testing, we simulate transfers that would cross regions
        // For same-region testing, we ensure transfers stay within region
        
        const request = {
            contractId: this.contractId,
            contractFunction: 'TransferAsset',
            contractArguments: [
                asset.ID,
                newOwner
            ],
            readOnly: false
        };

        await this.sutAdapter.sendRequests(request);
        
        // Update local asset owner for next iteration
        asset.owner = newOwner;
    }

    async cleanupWorkloadModule() {
        // Cleanup if needed
    }
}

function createWorkloadModule() {
    return new TransferAssetWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
