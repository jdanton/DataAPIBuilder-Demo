# Data API Builder Dockerfile
# Based on Microsoft Data API Builder for Azure Databases
# https://github.com/Azure/data-api-builder

# Use the official Data API Builder image as base
# OR build from Microsoft's .NET SDK
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 5000
EXPOSE 5001

# Build stage (if building from source)
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Install Data API Builder CLI
RUN dotnet tool install -g Microsoft.DataApiBuilder

# Add tool to PATH
ENV PATH="${PATH}:/root/.dotnet/tools"

# Copy Data API Builder configuration
WORKDIR /app
COPY dab-config.json /app/dab-config.json

# Runtime stage
FROM base AS final
WORKDIR /app

# Install Data API Builder
RUN dotnet tool install -g Microsoft.DataApiBuilder
ENV PATH="${PATH}:/root/.dotnet/tools"

# Copy configuration
COPY --from=build /app/dab-config.json /app/dab-config.json

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5000/api/health || exit 1

# Set environment variables
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production

# Run Data API Builder
ENTRYPOINT ["dab", "start", "--config", "dab-config.json"]
