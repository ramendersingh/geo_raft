package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/hyperledger/fabric/common/flogging"
	"github.com/hyperledger/fabric/orderer/consensus"
)

var consenterLogger = flogging.MustGetLogger("geo-consenter")

// GeoConsenter implements the Consenter interface for geo-aware consensus
type GeoConsenter struct {
	mu          sync.RWMutex
	chains      map[string]*GeoEtcdRaft
	config      *GeoConfig
	metrics     *ConsenterMetrics
	httpServer  *http.Server
}

// ConsenterMetrics tracks overall consenter performance
type ConsenterMetrics struct {
	ActiveChains    int                `json:"active_chains"`
	TotalRequests   int64              `json:"total_requests"`
	FailedRequests  int64              `json:"failed_requests"`
	AvgResponseTime time.Duration      `json:"avg_response_time"`
	ChainMetrics    map[string]*GeoMetrics `json:"chain_metrics"`
}

// NewGeoConsenter creates a new geo-aware consenter
func NewGeoConsenter(config *GeoConfig) *GeoConsenter {
	consenter := &GeoConsenter{
		chains:  make(map[string]*GeoEtcdRaft),
		config:  config,
		metrics: &ConsenterMetrics{
			ChainMetrics: make(map[string]*GeoMetrics),
		},
	}
	
	// Start metrics collection
	go consenter.collectMetrics()
	
	// Start HTTP API server for monitoring
	consenter.startHTTPServer()
	
	return consenter
}

// HandleChain creates and manages a new consensus chain
func (gc *GeoConsenter) HandleChain(support consensus.ConsenterSupport, metadata *protos.OrdererConfig) (consensus.Chain, error) {
	chainID := support.ChannelID()
	
	consenterLogger.Infof("Creating new geo-aware chain for channel: %s", chainID)
	
	// Create base etcdraft chain (this would integrate with actual Fabric etcdraft)
	// For this example, we'll simulate the base chain creation
	baseChain := &etcdraft.Chain{} // This should be properly initialized
	
	// Create geo-enhanced chain
	geoChain := NewGeoEtcdRaft(baseChain, gc.config)
	
	// Initialize with default geo-nodes (these would come from network configuration)
	gc.initializeGeoNodes(geoChain, chainID)
	
	gc.mu.Lock()
	gc.chains[chainID] = geoChain
	gc.metrics.ActiveChains = len(gc.chains)
	gc.mu.Unlock()
	
	consenterLogger.Infof("Successfully created geo-aware chain for channel: %s", chainID)
	
	return geoChain, nil
}

// initializeGeoNodes sets up initial geo-nodes for a chain
func (gc *GeoConsenter) initializeGeoNodes(chain *GeoEtcdRaft, chainID string) {
	// Default geo-nodes configuration (in production, this would come from network config)
	defaultNodes := []struct {
		nodeID   uint64
		location GeoLocation
	}{
		{
			nodeID: 1,
			location: GeoLocation{
				Latitude:   37.7749,  // San Francisco
				Longitude:  -122.4194,
				Region:     "us-west",
				Zone:       "us-west-1a",
				DataCenter: "sf-dc1",
			},
		},
		{
			nodeID: 2,
			location: GeoLocation{
				Latitude:   40.7128,  // New York
				Longitude:  -74.0060,
				Region:     "us-east",
				Zone:       "us-east-1a",
				DataCenter: "ny-dc1",
			},
		},
		{
			nodeID: 3,
			location: GeoLocation{
				Latitude:   51.5074,  // London
				Longitude:  -0.1278,
				Region:     "eu-west",
				Zone:       "eu-west-1a",
				DataCenter: "london-dc1",
			},
		},
		{
			nodeID: 4,
			location: GeoLocation{
				Latitude:   35.6762,  // Tokyo
				Longitude:  139.6503,
				Region:     "asia-northeast",
				Zone:       "asia-northeast-1a",
				DataCenter: "tokyo-dc1",
			},
		},
		{
			nodeID: 5,
			location: GeoLocation{
				Latitude:   -33.8688, // Sydney
				Longitude:  151.2093,
				Region:     "asia-southeast",
				Zone:       "asia-southeast-2a",
				DataCenter: "sydney-dc1",
			},
		},
	}
	
	for _, node := range defaultNodes {
		err := chain.RegisterNode(node.nodeID, node.location)
		if err != nil {
			consenterLogger.Errorf("Failed to register node %d: %v", node.nodeID, err)
		}
	}
}

// collectMetrics continuously collects metrics from all chains
func (gc *GeoConsenter) collectMetrics() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-ticker.C:
			gc.updateConsenterMetrics()
		}
	}
}

// updateConsenterMetrics aggregates metrics from all chains
func (gc *GeoConsenter) updateConsenterMetrics() {
	gc.mu.Lock()
	defer gc.mu.Unlock()
	
	gc.metrics.ActiveChains = len(gc.chains)
	
	for chainID, chain := range gc.chains {
		chainMetrics := chain.GetMetrics()
		gc.metrics.ChainMetrics[chainID] = chainMetrics
	}
}

// startHTTPServer starts the monitoring HTTP server
func (gc *GeoConsenter) startHTTPServer() {
	mux := http.NewServeMux()
	
	// Metrics endpoint
	mux.HandleFunc("/metrics", gc.handleMetrics)
	
	// Topology endpoint
	mux.HandleFunc("/topology", gc.handleTopology)
	
	// Health check endpoint
	mux.HandleFunc("/health", gc.handleHealth)
	
	// Chain-specific metrics
	mux.HandleFunc("/chains", gc.handleChains)
	
	gc.httpServer = &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}
	
	go func() {
		consenterLogger.Infof("Starting geo-consensus monitoring server on :8080")
		if err := gc.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			consenterLogger.Errorf("HTTP server error: %v", err)
		}
	}()
}

// handleMetrics serves aggregated metrics
func (gc *GeoConsenter) handleMetrics(w http.ResponseWriter, r *http.Request) {
	gc.mu.RLock()
	defer gc.mu.RUnlock()
	
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	
	response := map[string]interface{}{
		"timestamp":        time.Now(),
		"consenter_metrics": gc.metrics,
		"summary": map[string]interface{}{
			"total_chains":     gc.metrics.ActiveChains,
			"total_requests":   gc.metrics.TotalRequests,
			"failed_requests":  gc.metrics.FailedRequests,
			"avg_response_time": gc.metrics.AvgResponseTime.Milliseconds(),
		},
	}
	
	json.NewEncoder(w).Encode(response)
}

// handleTopology serves network topology information
func (gc *GeoConsenter) handleTopology(w http.ResponseWriter, r *http.Request) {
	gc.mu.RLock()
	defer gc.mu.RUnlock()
	
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	
	topology := make(map[string]interface{})
	
	for chainID, chain := range gc.chains {
		topology[chainID] = chain.GetTopology()
	}
	
	response := map[string]interface{}{
		"timestamp": time.Now(),
		"topology":  topology,
	}
	
	json.NewEncoder(w).Encode(response)
}

// handleHealth serves health check information
func (gc *GeoConsenter) handleHealth(w http.ResponseWriter, r *http.Request) {
	gc.mu.RLock()
	activeChains := len(gc.chains)
	gc.mu.RUnlock()
	
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	
	health := map[string]interface{}{
		"status":        "healthy",
		"timestamp":     time.Now(),
		"active_chains": activeChains,
		"uptime":        time.Since(time.Now().Add(-time.Hour)), // Placeholder
	}
	
	json.NewEncoder(w).Encode(health)
}

// handleChains serves information about specific chains
func (gc *GeoConsenter) handleChains(w http.ResponseWriter, r *http.Request) {
	gc.mu.RLock()
	defer gc.mu.RUnlock()
	
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	
	chainID := r.URL.Query().Get("id")
	
	if chainID != "" {
		// Return specific chain information
		if chain, exists := gc.chains[chainID]; exists {
			response := map[string]interface{}{
				"chain_id":  chainID,
				"metrics":   chain.GetMetrics(),
				"topology":  chain.GetTopology(),
				"timestamp": time.Now(),
			}
			json.NewEncoder(w).Encode(response)
		} else {
			http.Error(w, fmt.Sprintf("Chain %s not found", chainID), http.StatusNotFound)
		}
	} else {
		// Return all chains summary
		chains := make(map[string]interface{})
		for id, chain := range gc.chains {
			chains[id] = map[string]interface{}{
				"metrics":  chain.GetMetrics(),
				"topology": chain.GetTopology(),
			}
		}
		
		response := map[string]interface{}{
			"timestamp": time.Now(),
			"chains":    chains,
		}
		json.NewEncoder(w).Encode(response)
	}
}

// Shutdown gracefully shuts down the consenter
func (gc *GeoConsenter) Shutdown() error {
	consenterLogger.Info("Shutting down geo-aware consenter")
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	if gc.httpServer != nil {
		if err := gc.httpServer.Shutdown(ctx); err != nil {
			consenterLogger.Errorf("Error shutting down HTTP server: %v", err)
			return err
		}
	}
	
	// Clean up chains
	gc.mu.Lock()
	for chainID := range gc.chains {
		delete(gc.chains, chainID)
	}
	gc.mu.Unlock()
	
	consenterLogger.Info("Geo-aware consenter shutdown complete")
	return nil
}

// GetMetrics returns overall consenter metrics
func (gc *GeoConsenter) GetMetrics() *ConsenterMetrics {
	gc.mu.RLock()
	defer gc.mu.RUnlock()
	
	return gc.metrics
}
