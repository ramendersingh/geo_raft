# 🔐 Access Guide - Geo-Aware Hyperledger Fabric Monitoring

## 📊 Grafana Dashboard Access

**URL:** http://localhost:3000

**Login Credentials:**
- **Username:** `admin`
- **Password:** `admin`

## 📈 Prometheus Metrics

**URL:** http://localhost:9090

*No authentication required - direct access*

## 🐳 Docker Services Status

Check all running services:
```bash
docker compose ps
```

View specific service logs:
```bash
docker compose logs grafana
docker compose logs prometheus
```

## 🌍 Geo-Aware Features Available in Grafana

Once logged in, go to **"Dashboards" → "Browse"** to access:

1. **Service Status Monitoring** - Real-time status of all network components
2. **Active Services Count** - Total count of operational services
3. **Geographic Service Distribution** - Visual distribution of services
4. **Consensus Performance Metrics** - Real-time consensus algorithm performance
5. **Cross-Region Analytics** - Inter-region communication patterns

**Dashboard Name:** "Geo-Aware Fabric Consensus Dashboard"

## 🚀 Quick Dashboard Setup

The dashboards are now automatically configured! After logging in:

1. Go to **"Dashboards" → "Browse"**
2. Look for **"Geo-Aware Fabric Consensus Dashboard"**
3. The dashboard should appear in the "Geo-Aware Fabric" folder
4. If not visible, wait a moment and refresh the page

**Quick Setup Command:**
```bash
./scripts/setup-grafana.sh
```

## 🔧 Troubleshooting

**If Grafana is not accessible:**
```bash
# Check if container is running
docker compose ps grafana

# Restart Grafana if needed
docker compose restart grafana

# Check logs for errors
docker compose logs grafana --tail 50
```

**If login fails:**
- Make sure you're using `admin` / `admin`
- Wait a moment for the container to fully initialize
- Try refreshing the page

---

**Note:** The password is set to `admin` for demo purposes. In production, use strong passwords and proper authentication.
