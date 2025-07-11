package main

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// GeoAssetContract provides functions for managing geo-tagged assets
type GeoAssetContract struct {
	contractapi.Contract
}

// Asset represents a geo-tagged asset
type Asset struct {
	ID          string    `json:"ID"`
	Name        string    `json:"name"`
	Owner       string    `json:"owner"`
	Value       int       `json:"value"`
	Location    Location  `json:"location"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
	Region      string    `json:"region"`
	Zone        string    `json:"zone"`
}

// Location represents geographical coordinates
type Location struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Address   string  `json:"address"`
}

// Transaction represents a transaction with geo-metadata
type Transaction struct {
	ID          string    `json:"ID"`
	AssetID     string    `json:"asset_id"`
	FromOwner   string    `json:"from_owner"`
	ToOwner     string    `json:"to_owner"`
	Timestamp   time.Time `json:"timestamp"`
	TxType      string    `json:"tx_type"`
	Region      string    `json:"region"`
	ProcessedBy string    `json:"processed_by"`
}

// QueryResult structure used for handling result of query
type QueryResult struct {
	Key    string `json:"Key"`
	Record *Asset `json:"Record"`
}

// InitLedger adds a base set of assets to the ledger
func (s *GeoAssetContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	assets := []Asset{
		{
			ID:    "asset1",
			Name:  "Golden Gate Property",
			Owner: "Alice",
			Value: 1000000,
			Location: Location{
				Latitude:  37.8199,
				Longitude: -122.4783,
				Address:   "Golden Gate Bridge, San Francisco, CA",
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
			Region:    "us-west",
			Zone:      "us-west-1a",
		},
		{
			ID:    "asset2",
			Name:  "Times Square Building",
			Owner: "Bob",
			Value: 2000000,
			Location: Location{
				Latitude:  40.7589,
				Longitude: -73.9851,
				Address:   "Times Square, New York, NY",
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
			Region:    "us-east",
			Zone:      "us-east-1a",
		},
		{
			ID:    "asset3",
			Name:  "London Tower Property",
			Owner: "Charlie",
			Value: 1500000,
			Location: Location{
				Latitude:  51.5081,
				Longitude: -0.0759,
				Address:   "Tower of London, London, UK",
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
			Region:    "eu-west",
			Zone:      "eu-west-1a",
		},
		{
			ID:    "asset4",
			Name:  "Tokyo Skytree Land",
			Owner: "Diana",
			Value: 1800000,
			Location: Location{
				Latitude:  35.7101,
				Longitude: 139.8107,
				Address:   "Tokyo Skytree, Tokyo, Japan",
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
			Region:    "asia-northeast",
			Zone:      "asia-northeast-1a",
		},
		{
			ID:    "asset5",
			Name:  "Sydney Opera House Area",
			Owner: "Eve",
			Value: 1200000,
			Location: Location{
				Latitude:  -33.8568,
				Longitude: 151.2153,
				Address:   "Sydney Opera House, Sydney, Australia",
			},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
			Region:    "asia-southeast",
			Zone:      "asia-southeast-2a",
		},
	}

	for _, asset := range assets {
		assetJSON, err := json.Marshal(asset)
		if err != nil {
			return err
		}

		err = ctx.GetStub().PutState(asset.ID, assetJSON)
		if err != nil {
			return fmt.Errorf("failed to put to world state: %v", err)
		}
	}

	return nil
}

// CreateAsset issues a new asset to the world state with given details
func (s *GeoAssetContract) CreateAsset(ctx contractapi.TransactionContextInterface, id string, name string, owner string, value int, latitude float64, longitude float64, address string, region string, zone string) error {
	exists, err := s.AssetExists(ctx, id)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("the asset %s already exists", id)
	}

	asset := Asset{
		ID:    id,
		Name:  name,
		Owner: owner,
		Value: value,
		Location: Location{
			Latitude:  latitude,
			Longitude: longitude,
			Address:   address,
		},
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
		Region:    region,
		Zone:      zone,
	}

	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(id, assetJSON)
	if err != nil {
		return err
	}

	// Record transaction
	err = s.recordTransaction(ctx, id, "", owner, "CREATE")
	if err != nil {
		return err
	}

	return nil
}

// ReadAsset returns the asset stored in the world state with given id
func (s *GeoAssetContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if assetJSON == nil {
		return nil, fmt.Errorf("the asset %s does not exist", id)
	}

	var asset Asset
	err = json.Unmarshal(assetJSON, &asset)
	if err != nil {
		return nil, err
	}

	return &asset, nil
}

// UpdateAsset updates an existing asset in the world state with provided parameters
func (s *GeoAssetContract) UpdateAsset(ctx contractapi.TransactionContextInterface, id string, name string, owner string, value int, latitude float64, longitude float64, address string) error {
	exists, err := s.AssetExists(ctx, id)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("the asset %s does not exist", id)
	}

	// Get current asset to preserve region and zone
	currentAsset, err := s.ReadAsset(ctx, id)
	if err != nil {
		return err
	}

	// Overwriting original asset with new asset
	asset := Asset{
		ID:    id,
		Name:  name,
		Owner: owner,
		Value: value,
		Location: Location{
			Latitude:  latitude,
			Longitude: longitude,
			Address:   address,
		},
		CreatedAt: currentAsset.CreatedAt,
		UpdatedAt: time.Now(),
		Region:    currentAsset.Region,
		Zone:      currentAsset.Zone,
	}

	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(id, assetJSON)
	if err != nil {
		return err
	}

	// Record transaction
	err = s.recordTransaction(ctx, id, currentAsset.Owner, owner, "UPDATE")
	if err != nil {
		return err
	}

	return nil
}

// DeleteAsset deletes an given asset from the world state
func (s *GeoAssetContract) DeleteAsset(ctx contractapi.TransactionContextInterface, id string) error {
	exists, err := s.AssetExists(ctx, id)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("the asset %s does not exist", id)
	}

	// Get current asset for transaction record
	currentAsset, err := s.ReadAsset(ctx, id)
	if err != nil {
		return err
	}

	err = ctx.GetStub().DelState(id)
	if err != nil {
		return err
	}

	// Record transaction
	err = s.recordTransaction(ctx, id, currentAsset.Owner, "", "DELETE")
	if err != nil {
		return err
	}

	return nil
}

// AssetExists returns true when asset with given ID exists in world state
func (s *GeoAssetContract) AssetExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}

	return assetJSON != nil, nil
}

// TransferAsset updates the owner field of asset with given id in world state
func (s *GeoAssetContract) TransferAsset(ctx contractapi.TransactionContextInterface, id string, newOwner string) error {
	asset, err := s.ReadAsset(ctx, id)
	if err != nil {
		return err
	}

	oldOwner := asset.Owner
	asset.Owner = newOwner
	asset.UpdatedAt = time.Now()

	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(id, assetJSON)
	if err != nil {
		return err
	}

	// Record transaction
	err = s.recordTransaction(ctx, id, oldOwner, newOwner, "TRANSFER")
	if err != nil {
		return err
	}

	return nil
}

// GetAllAssets returns all assets found in world state
func (s *GeoAssetContract) GetAllAssets(ctx contractapi.TransactionContextInterface) ([]*Asset, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var assets []*Asset
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var asset Asset
		err = json.Unmarshal(queryResponse.Value, &asset)
		if err != nil {
			continue // Skip non-asset entries
		}

		assets = append(assets, &asset)
	}

	return assets, nil
}

// GetAssetsByRegion returns all assets in a specific region
func (s *GeoAssetContract) GetAssetsByRegion(ctx contractapi.TransactionContextInterface, region string) ([]*Asset, error) {
	allAssets, err := s.GetAllAssets(ctx)
	if err != nil {
		return nil, err
	}

	var regionAssets []*Asset
	for _, asset := range allAssets {
		if asset.Region == region {
			regionAssets = append(regionAssets, asset)
		}
	}

	return regionAssets, nil
}

// GetAssetsByZone returns all assets in a specific zone
func (s *GeoAssetContract) GetAssetsByZone(ctx contractapi.TransactionContextInterface, zone string) ([]*Asset, error) {
	allAssets, err := s.GetAllAssets(ctx)
	if err != nil {
		return nil, err
	}

	var zoneAssets []*Asset
	for _, asset := range allAssets {
		if asset.Zone == zone {
			zoneAssets = append(zoneAssets, asset)
		}
	}

	return zoneAssets, nil
}

// GetAssetsByProximity returns assets within a certain distance from given coordinates
func (s *GeoAssetContract) GetAssetsByProximity(ctx contractapi.TransactionContextInterface, latitude float64, longitude float64, radiusKm float64) ([]*Asset, error) {
	allAssets, err := s.GetAllAssets(ctx)
	if err != nil {
		return nil, err
	}

	var nearbyAssets []*Asset
	for _, asset := range allAssets {
		distance := calculateDistance(latitude, longitude, asset.Location.Latitude, asset.Location.Longitude)
		if distance <= radiusKm {
			nearbyAssets = append(nearbyAssets, asset)
		}
	}

	return nearbyAssets, nil
}

// recordTransaction records a transaction in the ledger
func (s *GeoAssetContract) recordTransaction(ctx contractapi.TransactionContextInterface, assetID string, fromOwner string, toOwner string, txType string) error {
	txID := ctx.GetStub().GetTxID()
	timestamp, _ := ctx.GetStub().GetTxTimestamp()

	// Get the orderer that processed this transaction (simplified)
	processedBy := "orderer1.example.com" // In real implementation, get from context

	// Determine region based on asset
	asset, err := s.ReadAsset(ctx, assetID)
	region := "unknown"
	if err == nil && asset != nil {
		region = asset.Region
	}

	transaction := Transaction{
		ID:          txID,
		AssetID:     assetID,
		FromOwner:   fromOwner,
		ToOwner:     toOwner,
		Timestamp:   time.Unix(timestamp.Seconds, int64(timestamp.Nanos)),
		TxType:      txType,
		Region:      region,
		ProcessedBy: processedBy,
	}

	transactionJSON, err := json.Marshal(transaction)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState("tx_"+txID, transactionJSON)
}

// GetTransactionHistory returns the transaction history for an asset
func (s *GeoAssetContract) GetTransactionHistory(ctx contractapi.TransactionContextInterface, assetID string) ([]*Transaction, error) {
	resultsIterator, err := ctx.GetStub().GetStateByPartialCompositeKey("tx_", []string{})
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var transactions []*Transaction
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var transaction Transaction
		err = json.Unmarshal(queryResponse.Value, &transaction)
		if err != nil {
			continue
		}

		if transaction.AssetID == assetID {
			transactions = append(transactions, &transaction)
		}
	}

	return transactions, nil
}

// calculateDistance calculates the distance between two geographic points using Haversine formula
func calculateDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadius = 6371 // Earth's radius in kilometers

	// Convert latitude and longitude from degrees to radians
	lat1Rad := lat1 * 3.14159265359 / 180
	lat2Rad := lat2 * 3.14159265359 / 180
	deltaLat := (lat2 - lat1) * 3.14159265359 / 180
	deltaLon := (lon2 - lon1) * 3.14159265359 / 180

	a := 0.5 - (1-((1+deltaLat)/2))/2 + (1-((1+lat1Rad)/2))*(1-((1+lat2Rad)/2))*(1-((1+deltaLon)/2))/2

	// Calculate the distance
	c := 2 * (0.5 - a + (a * (1 - a)))
	return earthRadius * c
}

func main() {
	assetChaincode, err := contractapi.NewChaincode(&GeoAssetContract{})
	if err != nil {
		log.Panicf("Error creating geo-asset chaincode: %v", err)
	}

	if err := assetChaincode.Start(); err != nil {
		log.Panicf("Error starting geo-asset chaincode: %v", err)
	}
}
