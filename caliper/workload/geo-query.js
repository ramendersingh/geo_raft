'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class GeoQueryWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.latitude = this.roundArguments.latitude || 37.7749;
        this.longitude = this.roundArguments.longitude || -122.4194;
        this.radius = this.roundArguments.radius || 1000;
        this.workerIndex = workerIndex;
    }

    async submitTransaction() {
        this.txIndex++;
        
        // Vary the search location slightly for each query
        const lat = this.latitude + (Math.random() - 0.5) * 0.01;
        const lng = this.longitude + (Math.random() - 0.5) * 0.01;
        
        const args = {
            contractId: 'geo-asset',
            contractFunction: 'GetNearbyAssets',
            contractArguments: [
                lat.toString(),
                lng.toString(),
                this.radius.toString()
            ],
            readOnly: true
        };

        return this.sutAdapter.sendRequests(args);
    }
}

function createWorkloadModule() {
    return new GeoQueryWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
