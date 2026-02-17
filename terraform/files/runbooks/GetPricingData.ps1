#Requires -Modules Az.Accounts, Az.Sql

<#
.SYNOPSIS
    Collects Azure VM pricing data from Azure Retail Prices API and stores it in SQL Database

.DESCRIPTION
    This runbook connects to Azure Retail Prices API, retrieves current VM pricing information,
    and stores it in the VMPricing table. Supports multiple regions, pricing models, and currencies.

.NOTES
    Author: Azure Automation
    Date: 2026-02-16
    Version: 2.0
#>

#Connect to Azure
Write-Output "Starting Azure Pricing Data Collection..."

# Ensures you do not inherit an AzContext in your runbook
$null = Disable-AzContextAutosave -Scope Process

# Connect using a Managed Service Identity
try {
    $AzureConnection = (Connect-AzAccount -Identity).context
    Write-Output "Successfully connected to Azure using Managed Identity"
}
catch {
    Write-Output "ERROR: There is no system-assigned user identity. Aborting."
    Write-Error $_.Exception.Message
    exit
}

# Configuration
$RGName = 'DataAPIBuilder'
$SQLServer = 'dataapibuilderdemo'
$DB = 'vmsizes'
$CurrencyCode = 'USD'

# Azure Retail Prices API endpoint
$PricingAPIBaseURL = 'https://prices.azure.com/api/retail/prices'

# Get SQL Server FQDN
$SqlServerFQDN = "$SQLServer.database.windows.net"

Write-Output "Configuration:"
Write-Output "  Resource Group: $RGName"
Write-Output "  SQL Server: $SqlServerFQDN"
Write-Output "  Database: $DB"
Write-Output "  Currency: $CurrencyCode"

# =============================================
# Function: Get Azure Retail Prices
# =============================================
function Get-AzureVMPricing {
    param(
        [string]$CurrencyCode = 'USD',
        [string]$ServiceFamily = 'Compute',
        [string]$ServiceName = 'Virtual Machines'
    )

    $allPrices = @()
    $pageNumber = 1
    $maxPages = 50 # Limit to prevent runaway

    Write-Output "Fetching VM pricing data from Azure Retail Prices API..."

    # Build filter for Virtual Machines in specific currency
    $filter = "serviceName eq 'Virtual Machines' and priceType eq 'Consumption' and currencyCode eq '$CurrencyCode'"

    # Initial request
    $uri = "$PricingAPIBaseURL`?`$filter=$([System.Web.HttpUtility]::UrlEncode($filter))"

    do {
        try {
            Write-Output "  Fetching page $pageNumber..."
            $response = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json"

            if ($response.Items -and $response.Items.Count -gt 0) {
                $allPrices += $response.Items
                Write-Output "    Retrieved $($response.Items.Count) items (Total so far: $($allPrices.Count))"
            }

            # Get next page URL
            $uri = $response.NextPageLink
            $pageNumber++

            # Small delay to be nice to the API
            Start-Sleep -Milliseconds 500

        } catch {
            Write-Output "ERROR: Failed to fetch pricing data from API"
            Write-Error $_.Exception.Message
            break
        }

    } while ($uri -and $pageNumber -le $maxPages)

    Write-Output "Completed fetching pricing data. Total items: $($allPrices.Count)"
    return $allPrices
}

# =============================================
# Function: Parse VM Size from Product Name
# =============================================
function Get-VMSizeFromProduct {
    param([string]$ProductName)

    # Extract VM size name from product name
    # Example: "Virtual Machines Dv3 Series" -> Look for size in armSkuName or meterName

    if ($ProductName -match 'Standard[_ ]([A-Z]+\d+[a-z]*(?:_v\d+)?)') {
        return $matches[1]
    }

    return $null
}

# =============================================
# Function: Parse Region from armRegionName
# =============================================
function Get-RegionMapping {
    param([string]$ArmRegionName)

    # Map ARM region names to friendly names
    $regionMap = @{
        'eastus' = 'eastus'
        'eastus2' = 'eastus2'
        'westus' = 'westus'
        'westus2' = 'westus2'
        'westus3' = 'westus3'
        'centralus' = 'centralus'
        'northcentralus' = 'northcentralus'
        'southcentralus' = 'southcentralus'
        'westcentralus' = 'westcentralus'
        'northeurope' = 'northeurope'
        'westeurope' = 'westeurope'
        'uksouth' = 'uksouth'
        'ukwest' = 'ukwest'
        'eastasia' = 'eastasia'
        'southeastasia' = 'southeastasia'
        'japaneast' = 'japaneast'
        'japanwest' = 'japanwest'
        'australiaeast' = 'australiaeast'
        'australiasoutheast' = 'australiasoutheast'
        'canadacentral' = 'canadacentral'
        'canadaeast' = 'canadaeast'
    }

    if ($regionMap.ContainsKey($ArmRegionName.ToLower())) {
        return $regionMap[$ArmRegionName.ToLower()]
    }

    return $ArmRegionName
}

# =============================================
# Main Processing
# =============================================

try {
    # Fetch pricing data
    $pricingData = Get-AzureVMPricing -CurrencyCode $CurrencyCode

    Write-Output "`nProcessing pricing data..."

    # Filter for Linux Pay-As-You-Go pricing
    $vmPrices = $pricingData | Where-Object {
        $_.type -eq 'Consumption' -and
        $_.productName -like '*Virtual Machines*' -and
        $_.armSkuName -match '^Standard_' -and
        $_.armRegionName
    }

    Write-Output "Filtered to $($vmPrices.Count) relevant VM pricing records"

    # Group by VM Size
    $groupedPrices = $vmPrices | Group-Object -Property armSkuName

    Write-Output "Found pricing for $($groupedPrices.Count) unique VM sizes"

    # Get Access Token for SQL Authentication
    Write-Output "`nAuthenticating to SQL Database..."
    $token = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token

    # Build connection string with access token
    $connectionString = "Server=tcp:$SqlServerFQDN,1433;Database=$DB;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

    # Create SQL connection
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.AccessToken = $token

    Write-Output "Opening connection to SQL Database..."
    $connection.Open()
    Write-Output "Connection established successfully"

    # Process each VM size
    $processedCount = 0
    $insertedCount = 0
    $errorCount = 0

    foreach ($vmGroup in $groupedPrices | Select-Object -First 100) {
        $vmSizeName = $vmGroup.Name
        $processedCount++

        if ($processedCount % 10 -eq 0) {
            Write-Output "Processed $processedCount / $($groupedPrices.Count) VM sizes..."
        }

        foreach ($price in $vmGroup.Group) {
            try {
                $regionName = Get-RegionMapping -ArmRegionName $price.armRegionName
                $os = if ($price.productName -like '*Windows*') { 'Windows' } else { 'Linux' }
                $pricePerHour = [decimal]$price.retailPrice
                $meterID = $price.meterId
                $productName = $price.productName
                $skuName = $price.skuName

                # Call stored procedure to upsert pricing
                $command = $connection.CreateCommand()
                $command.CommandText = "EXEC dbo.usp_UpsertVMPricing @VMSizeName, @RegionName, @PricingModelCode, @CurrencyCode, @OperatingSystem, @PricePerHour, @MeterID, @ProductName"
                $command.Parameters.AddWithValue("@VMSizeName", $vmSizeName) | Out-Null
                $command.Parameters.AddWithValue("@RegionName", $regionName) | Out-Null
                $command.Parameters.AddWithValue("@PricingModelCode", "PayAsYouGo") | Out-Null
                $command.Parameters.AddWithValue("@CurrencyCode", $CurrencyCode) | Out-Null
                $command.Parameters.AddWithValue("@OperatingSystem", $os) | Out-Null
                $command.Parameters.AddWithValue("@PricePerHour", $pricePerHour) | Out-Null
                $command.Parameters.AddWithValue("@MeterID", $meterID) | Out-Null
                $command.Parameters.AddWithValue("@ProductName", $productName) | Out-Null

                $result = $command.ExecuteNonQuery()

                if ($result -eq 0 -or $result -eq 1) {
                    $insertedCount++
                }

            } catch {
                $errorCount++
                if ($errorCount -le 5) {
                    Write-Output "  ERROR processing $vmSizeName in $regionName : $($_.Exception.Message)"
                }
            }
        }
    }

    # Close connection
    $connection.Close()

    Write-Output "`n=========================================="
    Write-Output "Pricing Data Collection Summary"
    Write-Output "=========================================="
    Write-Output "Total VM Sizes Processed: $processedCount"
    Write-Output "Total Pricing Records Inserted/Updated: $insertedCount"
    Write-Output "Errors Encountered: $errorCount"
    Write-Output "=========================================="

    # Log to DataLoadHistory table
    $connection.Open()
    $logCommand = $connection.CreateCommand()
    $logCommand.CommandText = @"
        INSERT INTO dbo.DataLoadHistory (LoadType, LoadStatus, RecordsProcessed, RecordsInserted, ErrorMessage, RunbookName, ExecutedBy, EndTime)
        VALUES ('Pricing', 'Completed', $processedCount, $insertedCount, $(if($errorCount -gt 0){"'$errorCount errors'"}else{"NULL"}), 'GetPricingData', 'ManagedIdentity', GETDATE())
"@
    $logCommand.ExecuteNonQuery() | Out-Null
    $connection.Close()

    Write-Output "`nPricing data collection completed successfully!"

} catch {
    Write-Output "`nFATAL ERROR: $($_.Exception.Message)"
    Write-Error $_.Exception
    exit 1
} finally {
    if ($connection.State -eq 'Open') {
        $connection.Close()
    }
}
