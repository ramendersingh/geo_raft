'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class QueryAssetsWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        this.regions = ['us-west', 'us-east', 'eu-west', 'asia-northeast', 'asia-southeast'];
        this.queryCoordinates = [
            { lat: 37.7749, lon: -122.4194, radius: 100 }, // San Francisco
            { lat: 40.7128, lon: -74.0060, radius: 150 },  // New York
            { lat: 51.5074, lon: -0.1278, radius: 200 },   // London
            { lat: 35.6762, lon: 139.6503, radius: 120 },  // Tokyo
            { lat: -33.8688, lon: 151.2093, radius: 180 }  // Sydney
        ];
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.contractId = this.roundArguments.contractId || 'geo-asset';
        this.queryType = this.roundArguments.queryType || 'regional';
        this.workerIndex = workerIndex;
    }

    async submitTransaction() {
        this.txIndex++;
        
        let request;

        switch (this.queryType) {
            case 'regional':
                request = await this.createRegionalQuery();
                break;
            case 'proximity':
                request = await this.createProximityQuery();
                break;
            case 'zone':
                request = await this.createZoneQuery();
                break;
            default:
                request = await this.createAllAssetsQuery();
        }

        await this.sutAdapter.sendRequests(request);
    }

    async createRegionalQuery() {
        const randomRegion = this.regions[Math.floor(Math.random() * this.regions.length)];
        
        return {
            contractId: this.contractId,
            contractFunction: 'GetAssetsByRegion',
            contractArguments: [randomRegion],
            readOnly: true
        };
    }

    async createProximityQuery() {
        const randomCoordinate = this.queryCoordinates[Math.floor(Math.random() * this.queryCoordinates.length)];
        
        return {
            contractId: this.contractId,
            contractFunction: 'GetAssetsByProximity',
            contractArguments: [
                randomCoordinate.lat.toString(),
                randomCoordinate.lon.toString(),
                randomCoordinate.radius.toString()
            ],
            readOnly: true
        };
    }

    async createZoneQuery() {
        const zones = ['us-west-1a', 'us-east-1a', 'eu-west-1a', 'asia-northeast-1a', 'asia-southeast-2a'];
        const randomZone = zones[Math.floor(Math.random() * zones.length)];
        
        return {
            contractId: this.contractId,
            contractFunction: 'GetAssetsByZone',
            contractArguments: [randomZone],
            readOnly: true
        };
    }

    async createAllAssetsQuery() {
        return {
            contractId: this.contractId,
            contractFunction: 'GetAllAssets',
            contractArguments: [],
            readOnly: true
        };
    }

    async cleanupWorkloadModule() {
        // Cleanup if needed
    }
}

function createWorkloadModule() {
    return new QueryAssetsWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
