# Data API Builder - Pricing API Examples

## Quick Reference Guide

This document provides ready-to-use examples for querying VM sizes and pricing data through the Data API Builder REST and GraphQL APIs.

## Base URL

```
https://vmsizesazure.azurewebsites.net
```

## REST API Examples

### 1. Get All VM Sizes with Pricing

```bash
curl https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing
```

### 2. Find Affordable VMs (< $200/month)

```bash
curl "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=LinuxPricePerMonth lt 200&\$orderby=LinuxPricePerMonth asc"
```

### 3. Get 4-CPU VMs in East US

```bash
curl "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=vCPUs eq 4 and RegionName eq 'eastus'"
```

### 4. Find High-Memory VMs (>= 32GB)

```bash
curl "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=MemoryGB ge 32&\$orderby=MemoryGB desc"
```

### 5. VMs with Accelerated Networking

```bash
curl "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=AcceleratedNetworkingEnabled eq true"
```

### 6. Best Value VMs (Low Price Per CPU)

```bash
curl "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=PricePerCPU lt 50&\$orderby=PricePerCPU asc&\$top=20"
```

### 7. Compare Specific VM Across Regions

```bash
curl "https://vmsizesazure.azurewebsites.net/api/price-comparison?\$filter=VMSizeName eq 'Standard_D4s_v3'&\$orderby=PricePerMonth asc"
```

### 8. Get All Regions

```bash
curl https://vmsizesazure.azurewebsites.net/api/regions
```

### 9. Get VM Families Information

```bash
curl https://vmsizesazure.azurewebsites.net/api/families
```

### 10. European VMs Only

```bash
curl "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=Geography eq 'Europe'"
```

## GraphQL API Examples

### Basic Query: VMs with Pricing

```bash
curl -X POST https://vmsizesazure.azurewebsites.net/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ vmsizesWithPricing(first: 10) { items { vmSizeName vCPUs memoryGB regionName linuxPricePerMonth currencySymbol } } }"
  }'
```

### Find Affordable Development VMs

```graphql
query AffordableDevVMs {
  vmsizesWithPricing(
    filter: {
      vCPUs: { ge: 2, le: 4 }
      memoryGB: { ge: 8, le: 16 }
      linuxPricePerMonth: { lt: 150 }
      regionName: { eq: "eastus" }
    }
    orderBy: { linuxPricePerMonth: ASC }
    first: 10
  ) {
    items {
      vmSizeName
      familyName
      vCPUs
      memoryGB
      linuxPricePerHour
      linuxPricePerMonth
      estimatedAnnualCost
      regionName
      currencyCode
    }
  }
}
```

### Compare VM Pricing Across Regions

```graphql
query PriceComparison {
  priceComparisons(
    filter: {
      vmSizeName: { eq: "Standard_D4s_v3" }
      operatingSystem: { eq: "Linux" }
    }
    orderBy: { pricePerMonth: ASC }
  ) {
    items {
      vmSizeName
      regionName
      geography
      pricePerMonth
      currencyCode
      pricingModel
    }
  }
}
```

### Get VM Families with Use Cases

```graphql
query VMFamilies {
  vmFamilies {
    items {
      familyCode
      familyName
      description
      useCase
    }
  }
}
```

### Find Best Performance Per Dollar

```graphql
query BestValue {
  vmsizesWithPricing(
    filter: {
      pricePerCPU: { isNull: false }
      regionName: { eq: "eastus" }
    }
    orderBy: { pricePerCPU: ASC }
    first: 20
  ) {
    items {
      vmSizeName
      familyName
      vCPUs
      memoryGB
      linuxPricePerMonth
      pricePerCPU
      pricePerGB
    }
  }
}
```

### High-Performance Computing VMs

```graphql
query HPCVMs {
  vmsizesWithPricing(
    filter: {
      vCPUs: { ge: 16 }
      acceleratedNetworkingEnabled: { eq: true }
      premiumIOSupported: { eq: true }
    }
    orderBy: { vCPUs: DESC }
  ) {
    items {
      vmSizeName
      familyCode
      vCPUs
      memoryGB
      maxDataDisks
      regionName
      linuxPricePerMonth
      estimatedAnnualCost
    }
  }
}
```

### Memory-Optimized VMs

```graphql
query MemoryOptimized {
  vmsizesWithPricing(
    filter: {
      familyCode: { in: ["E", "M"] }
      memoryGB: { ge: 64 }
      regionName: { eq: "eastus" }
    }
    orderBy: { memoryGB: DESC }
    first: 15
  ) {
    items {
      vmSizeName
      familyName
      vCPUs
      memoryGB
      linuxPricePerMonth
      pricePerGB
      regionName
    }
  }
}
```

### Get All Available Regions

```graphql
query AllRegions {
  regions(filter: { isActive: { eq: true } }) {
    items {
      regionName
      displayName
      geography
      pairedRegion
    }
  }
}
```

### Price History Query

```graphql
query PriceHistory {
  prices(
    filter: {
      vmSizeID: { eq: 123 }
      regionID: { eq: 1 }
      operatingSystem: { eq: "Linux" }
    }
    orderBy: { effectiveDate: DESC }
  ) {
    items {
      pricePerHour
      pricePerMonth
      effectiveDate
      expiryDate
      operatingSystem
    }
  }
}
```

## OData Query Options

### Filtering

```bash
$filter=<expression>
```

**Operators:**
- `eq` - equals
- `ne` - not equals
- `lt` - less than
- `le` - less than or equal
- `gt` - greater than
- `ge` - greater than or equal
- `and` - logical AND
- `or` - logical OR
- `not` - logical NOT

**Examples:**
```bash
$filter=vCPUs ge 4 and MemoryGB le 32
$filter=RegionName eq 'eastus' or RegionName eq 'westus2'
$filter=LinuxPricePerMonth lt 500
```

### Sorting

```bash
$orderby=<field> asc|desc
```

**Examples:**
```bash
$orderby=LinuxPricePerMonth asc
$orderby=vCPUs desc,MemoryGB desc
```

### Pagination

```bash
$top=<number>&$skip=<number>
```

**Examples:**
```bash
$top=20&$skip=0  # First 20 results
$top=20&$skip=20 # Next 20 results
```

### Field Selection

```bash
$select=<field1>,<field2>
```

**Examples:**
```bash
$select=VMSizeName,vCPUs,MemoryGB,LinuxPricePerMonth
```

### Combining Options

```bash
curl "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=vCPUs eq 4&\$orderby=LinuxPricePerMonth asc&\$top=10&\$select=VMSizeName,RegionName,LinuxPricePerMonth"
```

## Use Case Scenarios

### Scenario 1: Find Cheapest Dev/Test Environment

**Requirement**: 2-4 CPUs, 8-16GB RAM, under $100/month

```bash
curl "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=vCPUs ge 2 and vCPUs le 4 and MemoryGB ge 8 and MemoryGB le 16 and LinuxPricePerMonth lt 100&\$orderby=LinuxPricePerMonth asc&\$top=10"
```

### Scenario 2: Production Database Server Options

**Requirement**: >= 8 CPUs, >= 32GB RAM, Premium IO support, East US

```bash
curl "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=vCPUs ge 8 and MemoryGB ge 32 and PremiumIOSupported eq true and RegionName eq 'eastus'&\$orderby=LinuxPricePerMonth asc"
```

### Scenario 3: Cost Optimization - Compare Regions

**Requirement**: Find cheapest region for Standard_D8s_v3

```bash
curl "https://vmsizesazure.azurewebsites.net/api/price-comparison?\$filter=VMSizeName eq 'Standard_D8s_v3' and OperatingSystem eq 'Linux'&\$orderby=PricePerMonth asc"
```

### Scenario 4: Budget Calculation

**Requirement**: Calculate annual cost for 10 x Standard_D4s_v3 VMs in West US 2

```bash
# Get the price
PRICE=$(curl -s "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=VMSizeName eq 'Standard_D4s_v3' and RegionName eq 'westus2'" | jq '.[0].EstimatedAnnualCost')

# Calculate for 10 VMs
echo "Total annual cost for 10 VMs: \$$(echo "$PRICE * 10" | bc)"
```

### Scenario 5: Find Similar VMs at Lower Cost

**Requirement**: Find alternatives to Standard_E16_v4 that are cheaper but similar specs

```bash
# First get the specs of E16_v4
curl "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=VMSizeName eq 'Standard_E16_v4'"

# Then find similar VMs with lower price
curl "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$filter=vCPUs eq 16 and MemoryGB ge 100 and LinuxPricePerMonth lt 500&\$orderby=LinuxPricePerMonth asc"
```

## JavaScript/TypeScript Examples

### Fetch API

```javascript
// Get affordable VMs
async function getAffordableVMs() {
  const response = await fetch(
    'https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?$filter=LinuxPricePerMonth lt 200&$orderby=LinuxPricePerMonth asc&$top=10'
  );
  const vms = await response.json();
  console.table(vms);
}

// GraphQL Query
async function findBestValueVMs() {
  const query = `
    query {
      vmsizesWithPricing(
        filter: { pricePerCPU: { isNull: false } }
        orderBy: { pricePerCPU: ASC }
        first: 20
      ) {
        items {
          vmSizeName
          vCPUs
          memoryGB
          linuxPricePerMonth
          pricePerCPU
        }
      }
    }
  `;

  const response = await fetch(
    'https://vmsizesazure.azurewebsites.net/graphql',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query })
    }
  );

  const data = await response.json();
  return data.data.vmsizesWithPricing.items;
}
```

### Python

```python
import requests

# REST API
def get_vms_by_region(region):
    url = f"https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing"
    params = {
        "$filter": f"RegionName eq '{region}'",
        "$orderby": "LinuxPricePerMonth asc"
    }
    response = requests.get(url, params=params)
    return response.json()

# GraphQL
def get_affordable_vms(max_price):
    url = "https://vmsizesazure.azurewebsites.net/graphql"
    query = """
    query($maxPrice: Float!) {
      vmsizesWithPricing(
        filter: { linuxPricePerMonth: { lt: $maxPrice } }
        orderBy: { linuxPricePerMonth: ASC }
      ) {
        items {
          vmSizeName
          vCPUs
          memoryGB
          linuxPricePerMonth
          regionName
        }
      }
    }
    """
    response = requests.post(
        url,
        json={"query": query, "variables": {"maxPrice": max_price}}
    )
    return response.json()["data"]["vmsizesWithPricing"]["items"]

# Usage
vms = get_vms_by_region("eastus")
print(f"Found {len(vms)} VMs in East US")

affordable = get_affordable_vms(200)
print(f"Found {len(affordable)} VMs under $200/month")
```

## PowerShell

```powershell
# Get VMs with pricing
$response = Invoke-RestMethod -Uri "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?`$top=10"
$response | Format-Table VMSizeName, vCPUs, MemoryGB, LinuxPricePerMonth

# Find specific VM across regions
$vmName = "Standard_D4s_v3"
$priceComparison = Invoke-RestMethod -Uri "https://vmsizesazure.azurewebsites.net/api/price-comparison?`$filter=VMSizeName eq '$vmName'"
$priceComparison | Sort-Object PricePerMonth | Format-Table RegionName, Geography, PricePerMonth, CurrencyCode
```

## Testing with curl and jq

```bash
# Pretty print JSON
curl -s "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$top=5" | jq '.'

# Extract specific fields
curl -s "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing?\$top=10" | \
  jq '.[] | {name: .VMSizeName, cpu: .vCPUs, memory: .MemoryGB, price: .LinuxPricePerMonth}'

# Calculate statistics
curl -s "https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing" | \
  jq '[.[].LinuxPricePerMonth] | {avg: (add/length), min: min, max: max}'
```

## Response Format

### REST API Response

```json
[
  {
    "VMSizeID": 123,
    "VMSizeName": "Standard_D4s_v3",
    "FamilyCode": "D",
    "FamilyName": "D-Series",
    "vCPUs": 4,
    "MemoryGB": 16.0,
    "MaxDataDisks": 8,
    "MaxNICs": 2,
    "AcceleratedNetworkingEnabled": true,
    "PremiumIOSupported": true,
    "EphemeralOSDiskSupported": true,
    "RegionName": "eastus",
    "RegionDisplayName": "East US",
    "Geography": "US",
    "LinuxPricePerHour": 0.192,
    "LinuxPricePerMonth": 140.16,
    "CurrencyCode": "USD",
    "CurrencySymbol": "$",
    "EstimatedAnnualCost": 1681.92,
    "PricePerCPU": 35.04,
    "PricePerGB": 8.76
  }
]
```

### GraphQL Response

```json
{
  "data": {
    "vmsizesWithPricing": {
      "items": [
        {
          "vmSizeName": "Standard_D4s_v3",
          "vCPUs": 4,
          "memoryGB": 16.0,
          "linuxPricePerMonth": 140.16
        }
      ]
    }
  }
}
```

## Rate Limiting & Best Practices

1. **Cache responses** when possible
2. **Use pagination** for large result sets
3. **Select only needed fields** using `$select`
4. **Filter server-side** instead of client-side
5. **Use GraphQL** for complex queries spanning multiple entities

## Support

For API issues or questions:
- Check Data API Builder logs
- Review database views for data availability
- Verify runbooks have completed successfully
- Test SQL queries directly against the database
