package main

import (
	"context"
	"fmt"
	"math/rand"
	"sort"
	"sync"
	"time"

	"github.com/hyperledger/fabric/common/flogging"
	"github.com/hyperledger/fabric/orderer/consensus/etcdraft"
	"github.com/hyperledger/fabric/protos/orderer"
	"go.etcd.io/etcd/raft/v3"
)

var logger = flogging.MustGetLogger("geo-consensus")

// GeoLocation represents geographical coordinates and metadata
type GeoLocation struct {
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	Region      string  `json:"region"`
	Zone        string  `json:"zone"`
	DataCenter  string  `json:"datacenter"`
}

// GeoNode represents a node with geographical information
type GeoNode struct {
	NodeID      uint64      `json:"node_id"`
	Location    GeoLocation `json:"location"`
	LastSeen    time.Time   `json:"last_seen"`
	Latency     map[uint64]time.Duration `json:"latency_map"`
	IsLeader    bool        `json:"is_leader"`
	RegionRank  int         `json:"region_rank"`
}

// GeoEtcdRaft extends the standard etcdraft with geo-awareness
type GeoEtcdRaft struct {
	*etcdraft.Chain
	nodes           map[uint64]*GeoNode
	regionLeaders   map[string]uint64
	proximityMatrix map[uint64]map[uint64]float64
	config          *GeoConfig
	mu              sync.RWMutex
	metrics         *GeoMetrics
}

// GeoConfig holds configuration for geo-aware consensus
type GeoConfig struct {
	LatencyThreshold    time.Duration `json:"latency_threshold"`
	RegionWeight        float64       `json:"region_weight"`
	ProximityWeight     float64       `json:"proximity_weight"`
	LoadBalanceEnabled  bool          `json:"load_balance_enabled"`
	CrossRegionRatio    float64       `json:"cross_region_ratio"`
	AdaptiveTimeout     bool          `json:"adaptive_timeout"`
	HierarchicalMode    bool          `json:"hierarchical_mode"`
}

// GeoMetrics tracks performance metrics
type GeoMetrics struct {
	TotalTransactions      int64         `json:"total_transactions"`
	AvgLatency            time.Duration `json:"avg_latency"`
	RegionLatencies       map[string]time.Duration `json:"region_latencies"`
	LeaderElections       int64         `json:"leader_elections"`
	CrossRegionMessages   int64         `json:"cross_region_messages"`
	ThroughputPerSecond   float64       `json:"throughput_per_second"`
}

// NewGeoEtcdRaft creates a new geo-aware etcdraft consensus
func NewGeoEtcdRaft(baseChain *etcdraft.Chain, config *GeoConfig) *GeoEtcdRaft {
	geo := &GeoEtcdRaft{
		Chain:           baseChain,
		nodes:           make(map[uint64]*GeoNode),
		regionLeaders:   make(map[string]uint64),
		proximityMatrix: make(map[uint64]map[uint64]float64),
		config:          config,
		metrics:         &GeoMetrics{
			RegionLatencies: make(map[string]time.Duration),
		},
	}
	
	// Initialize proximity calculations
	go geo.monitorNetwork()
	go geo.updateMetrics()
	
	return geo
}

// RegisterNode adds a new node with geographical information
func (g *GeoEtcdRaft) RegisterNode(nodeID uint64, location GeoLocation) error {
	g.mu.Lock()
	defer g.mu.Unlock()
	
	node := &GeoNode{
		NodeID:   nodeID,
		Location: location,
		LastSeen: time.Now(),
		Latency:  make(map[uint64]time.Duration),
	}
	
	g.nodes[nodeID] = node
	g.updateProximityMatrix(nodeID)
	
	logger.Infof("Registered geo-node %d at %s, region: %s", 
		nodeID, location.Zone, location.Region)
	
	return nil
}

// calculateDistance computes geographical distance between two locations
func (g *GeoEtcdRaft) calculateDistance(loc1, loc2 GeoLocation) float64 {
	// Haversine formula for great-circle distance
	const earthRadius = 6371 // km
	
	lat1Rad := loc1.Latitude * math.Pi / 180
	lat2Rad := loc2.Latitude * math.Pi / 180
	deltaLat := (loc2.Latitude - loc1.Latitude) * math.Pi / 180
	deltaLon := (loc2.Longitude - loc1.Longitude) * math.Pi / 180
	
	a := math.Sin(deltaLat/2)*math.Sin(deltaLat/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*
		math.Sin(deltaLon/2)*math.Sin(deltaLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	
	return earthRadius * c
}

// updateProximityMatrix calculates proximity scores between nodes
func (g *GeoEtcdRaft) updateProximityMatrix(nodeID uint64) {
	if g.proximityMatrix[nodeID] == nil {
		g.proximityMatrix[nodeID] = make(map[uint64]float64)
	}
	
	currentNode := g.nodes[nodeID]
	for otherID, otherNode := range g.nodes {
		if otherID == nodeID {
			continue
		}
		
		distance := g.calculateDistance(currentNode.Location, otherNode.Location)
		
		// Calculate proximity score (inverse of distance with region bonuses)
		proximityScore := 1.0 / (1.0 + distance)
		
		// Bonus for same region
		if currentNode.Location.Region == otherNode.Location.Region {
			proximityScore *= g.config.RegionWeight
		}
		
		// Bonus for same zone
		if currentNode.Location.Zone == otherNode.Location.Zone {
			proximityScore *= 1.5
		}
		
		g.proximityMatrix[nodeID][otherID] = proximityScore
		
		// Ensure bidirectional matrix
		if g.proximityMatrix[otherID] == nil {
			g.proximityMatrix[otherID] = make(map[uint64]float64)
		}
		g.proximityMatrix[otherID][nodeID] = proximityScore
	}
}

// selectOptimalLeader chooses the best leader based on geo-proximity and load
func (g *GeoEtcdRaft) selectOptimalLeader(candidates []uint64) uint64 {
	g.mu.RLock()
	defer g.mu.RUnlock()
	
	if len(candidates) == 0 {
		return 0
	}
	
	type candidateScore struct {
		nodeID uint64
		score  float64
	}
	
	var scores []candidateScore
	
	for _, candidateID := range candidates {
		candidate := g.nodes[candidateID]
		if candidate == nil {
			continue
		}
		
		score := g.calculateLeaderScore(candidateID)
		scores = append(scores, candidateScore{
			nodeID: candidateID,
			score:  score,
		})
	}
	
	// Sort by score descending
	sort.Slice(scores, func(i, j int) bool {
		return scores[i].score > scores[j].score
	})
	
	if len(scores) > 0 {
		selectedLeader := scores[0].nodeID
		g.updateLeaderElection(selectedLeader)
		return selectedLeader
	}
	
	return candidates[0] // Fallback
}

// calculateLeaderScore computes leadership score based on various factors
func (g *GeoEtcdRaft) calculateLeaderScore(nodeID uint64) float64 {
	node := g.nodes[nodeID]
	if node == nil {
		return 0
	}
	
	score := 0.0
	
	// Base proximity score (average to all other nodes)
	proximitySum := 0.0
	proximityCount := 0
	
	for otherID := range g.nodes {
		if otherID != nodeID {
			if proximity, exists := g.proximityMatrix[nodeID][otherID]; exists {
				proximitySum += proximity
				proximityCount++
			}
		}
	}
	
	if proximityCount > 0 {
		score += (proximitySum / float64(proximityCount)) * g.config.ProximityWeight
	}
	
	// Regional leadership bonus
	regionNodeCount := g.countNodesInRegion(node.Location.Region)
	if regionNodeCount > 1 {
		score += float64(regionNodeCount) * 0.1
	}
	
	// Latency penalty (higher latency = lower score)
	avgLatency := g.calculateAverageLatency(nodeID)
	if avgLatency > 0 {
		latencyPenalty := float64(avgLatency/time.Millisecond) / 1000.0
		score -= latencyPenalty
	}
	
	// Load balancing factor
	if g.config.LoadBalanceEnabled {
		loadFactor := g.calculateLoadFactor(nodeID)
		score -= loadFactor
	}
	
	return score
}

// countNodesInRegion counts nodes in the same region
func (g *GeoEtcdRaft) countNodesInRegion(region string) int {
	count := 0
	for _, node := range g.nodes {
		if node.Location.Region == region {
			count++
		}
	}
	return count
}

// calculateAverageLatency computes average latency to other nodes
func (g *GeoEtcdRaft) calculateAverageLatency(nodeID uint64) time.Duration {
	node := g.nodes[nodeID]
	if node == nil || len(node.Latency) == 0 {
		return 0
	}
	
	var total time.Duration
	count := 0
	
	for _, latency := range node.Latency {
		total += latency
		count++
	}
	
	if count > 0 {
		return total / time.Duration(count)
	}
	
	return 0
}

// calculateLoadFactor computes current load factor for a node
func (g *GeoEtcdRaft) calculateLoadFactor(nodeID uint64) float64 {
	// Simplified load calculation - can be enhanced with actual metrics
	node := g.nodes[nodeID]
	if node == nil {
		return 0
	}
	
	// Factor in recent activity, connection count, etc.
	timeSinceLastSeen := time.Since(node.LastSeen)
	if timeSinceLastSeen > time.Minute {
		return 1.0 // High penalty for inactive nodes
	}
	
	return 0.1 // Base load factor
}

// updateLeaderElection updates leadership tracking
func (g *GeoEtcdRaft) updateLeaderElection(leaderID uint64) {
	leader := g.nodes[leaderID]
	if leader == nil {
		return
	}
	
	// Update regional leadership
	g.regionLeaders[leader.Location.Region] = leaderID
	
	// Mark as leader
	for _, node := range g.nodes {
		node.IsLeader = false
	}
	leader.IsLeader = true
	
	g.metrics.LeaderElections++
	
	logger.Infof("New geo-aware leader elected: node %d in region %s", 
		leaderID, leader.Location.Region)
}

// monitorNetwork continuously monitors network conditions
func (g *GeoEtcdRaft) monitorNetwork() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-ticker.C:
			g.updateNetworkMetrics()
		}
	}
}

// updateNetworkMetrics refreshes network performance metrics
func (g *GeoEtcdRaft) updateNetworkMetrics() {
	g.mu.Lock()
	defer g.mu.Unlock()
	
	// Update latency measurements between nodes
	for nodeID, node := range g.nodes {
		for otherID := range g.nodes {
			if nodeID != otherID {
				// Simulate latency measurement (in real implementation, use actual network metrics)
				latency := g.measureLatency(nodeID, otherID)
				node.Latency[otherID] = latency
			}
		}
		node.LastSeen = time.Now()
	}
	
	// Update regional statistics
	g.updateRegionalMetrics()
}

// measureLatency simulates latency measurement (replace with actual implementation)
func (g *GeoEtcdRaft) measureLatency(from, to uint64) time.Duration {
	fromNode := g.nodes[from]
	toNode := g.nodes[to]
	
	if fromNode == nil || toNode == nil {
		return time.Millisecond * 100 // Default
	}
	
	distance := g.calculateDistance(fromNode.Location, toNode.Location)
	
	// Simulate latency based on distance (simplified model)
	baseLatency := time.Duration(distance * 0.1) * time.Millisecond
	
	// Add random jitter
	jitter := time.Duration(rand.Intn(20)) * time.Millisecond
	
	// Same region bonus
	if fromNode.Location.Region == toNode.Location.Region {
		baseLatency = baseLatency / 2
	}
	
	return baseLatency + jitter
}

// updateRegionalMetrics computes regional performance statistics
func (g *GeoEtcdRaft) updateRegionalMetrics() {
	regionLatencies := make(map[string][]time.Duration)
	
	for _, node := range g.nodes {
		for otherID, latency := range node.Latency {
			otherNode := g.nodes[otherID]
			if otherNode != nil {
				regionKey := fmt.Sprintf("%s-%s", 
					node.Location.Region, otherNode.Location.Region)
				regionLatencies[regionKey] = append(regionLatencies[regionKey], latency)
			}
		}
	}
	
	// Calculate average latencies per region pair
	for regionPair, latencies := range regionLatencies {
		if len(latencies) > 0 {
			var total time.Duration
			for _, lat := range latencies {
				total += lat
			}
			g.metrics.RegionLatencies[regionPair] = total / time.Duration(len(latencies))
		}
	}
}

// updateMetrics continuously updates performance metrics
func (g *GeoEtcdRaft) updateMetrics() {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()
	
	lastTransactionCount := int64(0)
	lastUpdate := time.Now()
	
	for {
		select {
		case <-ticker.C:
			now := time.Now()
			elapsed := now.Sub(lastUpdate)
			
			currentTransactions := g.metrics.TotalTransactions
			newTransactions := currentTransactions - lastTransactionCount
			
			if elapsed.Seconds() > 0 {
				g.metrics.ThroughputPerSecond = float64(newTransactions) / elapsed.Seconds()
			}
			
			lastTransactionCount = currentTransactions
			lastUpdate = now
		}
	}
}

// GetMetrics returns current performance metrics
func (g *GeoEtcdRaft) GetMetrics() *GeoMetrics {
	g.mu.RLock()
	defer g.mu.RUnlock()
	
	// Create a copy to avoid race conditions
	metrics := *g.metrics
	metrics.RegionLatencies = make(map[string]time.Duration)
	for k, v := range g.metrics.RegionLatencies {
		metrics.RegionLatencies[k] = v
	}
	
	return &metrics
}

// GetTopology returns current network topology information
func (g *GeoEtcdRaft) GetTopology() map[string]interface{} {
	g.mu.RLock()
	defer g.mu.RUnlock()
	
	topology := map[string]interface{}{
		"nodes":          g.nodes,
		"region_leaders": g.regionLeaders,
		"total_nodes":    len(g.nodes),
		"regions":        g.getUniqueRegions(),
		"config":         g.config,
	}
	
	return topology
}

// getUniqueRegions returns list of unique regions
func (g *GeoEtcdRaft) getUniqueRegions() []string {
	regions := make(map[string]bool)
	for _, node := range g.nodes {
		regions[node.Location.Region] = true
	}
	
	var result []string
	for region := range regions {
		result = append(result, region)
	}
	
	return result
}
