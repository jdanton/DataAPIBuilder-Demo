# Container Build and Deployment Guide

## Dockerfile Options

This repository includes two Dockerfile options:

### 1. Dockerfile (Build from SDK)
Builds Data API Builder from the .NET SDK and includes the configuration.

**Pros:**
- Full control over the build process
- Can customize the runtime environment
- Smaller final image (multi-stage build)

**Cons:**
- Longer build time
- More complex configuration

### 2. Dockerfile.alternative (Use Official Image)
Uses Microsoft's pre-built Data API Builder image.

**Pros:**
- Fast builds (just copies config)
- Official Microsoft image
- Regularly updated and patched

**Cons:**
- Less customization
- Slightly larger image

**Recommended:** Use `Dockerfile.alternative` for most scenarios.

## Configuration Files

### dab-config.template.json
Template configuration for Data API Builder. Copy this to `dab-config.json` and customize:

```bash
cp dab-config.template.json dab-config.json
```

**Key Configuration Sections:**

1. **data-source**: Database connection settings
2. **runtime**: API endpoints (REST/GraphQL) configuration
3. **entities**: Table mappings and permissions

## Building the Container

### Option 1: Build for ACR (Production)

```bash
# Login to Azure Container Registry
az acr login --name dataapibuilderdemojd

# Build and push
docker build -f Dockerfile.alternative -t dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:v1.0 .
docker push dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:v1.0

# Tag as latest
docker tag dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:v1.0 \
           dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:latest
docker push dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:latest
```

### Option 2: Build for Local Development

```bash
# Build locally
docker build -f Dockerfile.alternative -t vmsizes-api:local .

# Run locally
docker run -d -p 5000:5000 \
  -e DATABASE_CONNECTION_STRING="Server=..." \
  vmsizes-api:local
```

### Option 3: Use Docker Compose (Recommended for Local Dev)

```bash
# Start all services (API + SQL Server)
docker-compose up -d

# View logs
docker-compose logs -f data-api-builder

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

## Environment Variables

The container accepts these environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_CONNECTION_STRING` | SQL connection string | `Server=tcp:...` |
| `ASPNETCORE_ENVIRONMENT` | Runtime environment | `Production` or `Development` |
| `ASPNETCORE_URLS` | Listening URLs | `http://+:5000` |

### Connection String Formats

**Azure SQL with Managed Identity:**
```
Server=tcp:dataapibuilderdemo.database.windows.net,1433;Database=VMSizes;Authentication=Active Directory Default;
```

**Azure SQL with Username/Password:**
```
Server=tcp:dataapibuilderdemo.database.windows.net,1433;Database=VMSizes;User ID=username;Password=password;Encrypt=True;
```

**Local SQL Server:**
```
Server=localhost;Database=VMSizes;User Id=sa;Password=YourPassword;TrustServerCertificate=True;
```

## Testing the Container

### 1. Check Health
```bash
curl http://localhost:5000/api/health
```

### 2. Test REST API
```bash
# Get all VM sizes
curl http://localhost:5000/api/vmsizes

# Filter by region
curl "http://localhost:5000/api/vmsizes?\$filter=region eq 'eastus'"

# Select specific fields
curl "http://localhost:5000/api/vmsizes?\$select=name,cpu,memoryGB"

# Pagination
curl "http://localhost:5000/api/vmsizes?\$top=10&\$skip=0"
```

### 3. Test GraphQL API
```bash
curl -X POST http://localhost:5000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ vmsizes(filter: { region: { eq: \"eastus\" } }) { items { name cpu memoryGB region } } }"
  }'
```

## Deploying to Azure App Service

### Via Azure CLI

```bash
# Update the Web App to use new image
az webapp config container set \
  --resource-group DataAPIBuilder \
  --name vmsizesazure \
  --docker-custom-image-name dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:latest \
  --docker-registry-server-url https://dataapibuilderdemojd.azurecr.io

# Restart the app
az webapp restart \
  --resource-group DataAPIBuilder \
  --name vmsizesazure

# Stream logs
az webapp log tail \
  --resource-group DataAPIBuilder \
  --name vmsizesazure
```

### Via Azure Portal

1. Go to App Service → **vmsizesazure**
2. Navigate to **Deployment Center**
3. Configure container settings:
   - Registry: dataapibuilderdemojd.azurecr.io
   - Image: azure-databases/data-api-builder
   - Tag: latest
4. Click **Save**
5. Monitor deployment in the **Logs** section

## CI/CD Pipeline

### GitHub Actions Example

Create `.github/workflows/deploy-container.yml`:

```yaml
name: Build and Deploy Container

on:
  push:
    branches: [ main ]
    paths:
      - 'Dockerfile*'
      - 'dab-config.json'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Login to ACR
      uses: azure/docker-login@v1
      with:
        login-server: dataapibuilderdemojd.azurecr.io
        username: ${{ secrets.ACR_USERNAME }}
        password: ${{ secrets.ACR_PASSWORD }}

    - name: Build and push
      run: |
        docker build -f Dockerfile.alternative \
          -t dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:${{ github.sha }} \
          -t dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:latest .
        docker push dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder --all-tags

    - name: Deploy to App Service
      uses: azure/webapps-deploy@v2
      with:
        app-name: vmsizesazure
        images: dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:${{ github.sha }}
```

## Troubleshooting

### Container Fails to Start

Check logs:
```bash
docker logs <container-id>
```

Common issues:
- Invalid connection string
- Missing dab-config.json file
- Port already in use
- Network connectivity to SQL Server

### Database Connection Errors

Test connection from container:
```bash
docker exec -it <container-id> /bin/bash
curl -v telnet://dataapibuilderdemo.database.windows.net:1433
```

### API Returns 404

- Verify dab-config.json is mounted correctly
- Check entity mappings match your database schema
- Ensure database tables exist

## Security Best Practices

1. **Never commit sensitive data**
   - Keep connection strings in environment variables
   - Use Azure Key Vault for secrets
   - Configure Managed Identity

2. **Use HTTPS in production**
   - Configure SSL certificates
   - Enable HTTPS-only on App Service

3. **Limit API access**
   - Configure authentication in dab-config.json
   - Set up API Management for rate limiting
   - Use Application Gateway with WAF

4. **Regular updates**
   - Update base images regularly
   - Scan for vulnerabilities
   - Monitor security advisories

## Performance Tuning

### Container Resources

Set resource limits in docker-compose.yml:
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
    reservations:
      cpus: '1'
      memory: 1G
```

### Database Configuration

- Enable connection pooling
- Use read replicas for heavy read workloads
- Optimize database indexes
- Cache frequently accessed data

## Monitoring

### Application Insights Integration

Add to dab-config.json:
```json
{
  "runtime": {
    "telemetry": {
      "application-insights": {
        "connection-string": "@env('APPLICATIONINSIGHTS_CONNECTION_STRING')",
        "enabled": true
      }
    }
  }
}
```

### Container Metrics

View metrics:
```bash
docker stats <container-id>
```

## Additional Resources

- [Data API Builder Documentation](https://learn.microsoft.com/azure/data-api-builder/)
- [Data API Builder GitHub](https://github.com/Azure/data-api-builder)
- [Container Registry Best Practices](https://learn.microsoft.com/azure/container-registry/container-registry-best-practices)
- [App Service Docker Containers](https://learn.microsoft.com/azure/app-service/configure-custom-container)
