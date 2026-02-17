#Requires -Modules Az.Accounts, Az.Compute, Az.Sql

<#
.SYNOPSIS
    Collects Azure VM SKU data and stores it in SQL Database (Version 2.0 - New Schema)

.DESCRIPTION
    This runbook connects to Azure, retrieves VM SKU capabilities across all regions,
    and stores the information in the new normalized database schema with proper relationships.

.NOTES
    Author: Azure Automation
    Date: 2026-02-16
    Version: 2.0 - Updated for new schema with VMSizes, Regions, and Availability tables
#>

#Connect to Azure
Write-Output "Starting Azure VM Data Collection (Version 2.0)..."

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

# Get SQL Server FQDN
$SqlServerFQDN = "$SQLServer.database.windows.net"

Write-Output "Configuration:"
Write-Output "  Resource Group: $RGName"
Write-Output "  SQL Server: $SqlServerFQDN"
Write-Output "  Database: $DB"

# =============================================
# Function: Extract VM Family from VM Size Name
# =============================================
function Get-VMFamily {
    param([string]$VMSizeName)

    # Extract family code from VM size name
    # Examples: Standard_D4s_v3 -> D, Standard_E16_v4 -> E, Standard_F8s_v2 -> F
    if ($VMSizeName -match 'Standard_([A-Z])') {
        return $matches[1]
    }

    return 'A' # Default to A-Series if unknown
}

# =============================================
# Function: Ensure Region Exists
# =============================================
function Ensure-Region {
    param(
        [string]$RegionName,
        [string]$DisplayName,
        [string]$Geography,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    # Check if region exists
    $checkCommand = $Connection.CreateCommand()
    $checkCommand.CommandText = "SELECT RegionID FROM dbo.AzureRegions WHERE RegionName = @RegionName"
    $checkCommand.Parameters.AddWithValue("@RegionName", $RegionName) | Out-Null

    $regionID = $checkCommand.ExecuteScalar()

    if ($null -eq $regionID) {
        # Insert new region
        $insertCommand = $Connection.CreateCommand()
        $insertCommand.CommandText = @"
            INSERT INTO dbo.AzureRegions (RegionName, DisplayName, RegionType, Geography)
            VALUES (@RegionName, @DisplayName, 'Physical', @Geography);
            SELECT SCOPE_IDENTITY();
"@
        $insertCommand.Parameters.AddWithValue("@RegionName", $RegionName) | Out-Null
        $insertCommand.Parameters.AddWithValue("@DisplayName", $DisplayName) | Out-Null
        $insertCommand.Parameters.AddWithValue("@Geography", $Geography) | Out-Null

        $regionID = $insertCommand.ExecuteScalar()
        Write-Output "  Created new region: $RegionName (ID: $regionID)"
    }

    return $regionID
}

# =============================================
# Main Processing
# =============================================

try {
    Write-Output "`nGathering Azure Region Data..."
    $regions = (Get-AzLocation | Where-Object { $_.RegionType -eq 'Physical' }).Location
    Write-Output "Found $($regions.Count) physical Azure regions"

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

    # Start transaction for data load
    $transaction = $connection.BeginTransaction()

    # Log start of data load
    $logCommand = $connection.CreateCommand()
    $logCommand.Transaction = $transaction
    $logCommand.CommandText = @"
        INSERT INTO dbo.DataLoadHistory (LoadType, LoadStatus, StartTime, RunbookName, ExecutedBy)
        OUTPUT INSERTED.LoadID
        VALUES ('VMSizes', 'Started', GETDATE(), 'GetData-v2', 'ManagedIdentity')
"@
    $loadID = $logCommand.ExecuteScalar()
    Write-Output "Started data load job (LoadID: $loadID)"

    $totalVMsProcessed = 0
    $totalVMsInserted = 0
    $totalVMsUpdated = 0
    $totalRegionsProcessed = 0
    $errorCount = 0

    # Process each region
    foreach ($region in $regions) {
        Write-Output "`n=========================================="
        Write-Output "Processing Region: $region"
        Write-Output "=========================================="

        try {
            # Ensure region exists in database
            $geography = 'US' # Default, should be enhanced with proper mapping
            if ($region -like '*europe*' -or $region -like '*uk*') { $geography = 'Europe' }
            elseif ($region -like '*asia*' -or $region -like '*japan*' -or $region -like '*australia*') { $geography = 'Asia Pacific' }

            $regionID = Ensure-Region -RegionName $region -DisplayName $region -Geography $geography -Connection $connection

            $totalRegionsProcessed++

            # Get VM SKUs for this region
            Write-Output "  Fetching VM SKUs..."
            $VMs = Get-AzComputeResourceSku -Location $region | Where-Object { $_.ResourceType -eq 'virtualMachines' }

            Write-Output "  Found $($VMs.Count) VM SKUs in $region"

            $regionVMCount = 0

            foreach ($VM in $VMs) {
                try {
                    $vmSizeName = $vm.Name
                    $familyCode = Get-VMFamily -VMSizeName $vmSizeName

                    # Extract capabilities
                    $capabilities = @{}
                    $vm.Capabilities | ForEach-Object {
                        $capabilities[$_.Name] = $_.Value
                    }

                    $vCPUs = [int]($capabilities['vCPUs'] ?? 0)
                    $memoryGB = [decimal]($capabilities['MemoryGB'] ?? 0)
                    $maxDataDisks = [int]($capabilities['MaxDataDiskCount'] ?? 0)
                    $maxNICs = [int]($capabilities['MaxNetworkInterfaces'] ?? 0)
                    $accelNet = if ($capabilities['AcceleratedNetworkingEnabled'] -eq 'True') { 1 } else { 0 }
                    $premiumIO = if ($capabilities['PremiumIO'] -eq 'True') { 1 } else { 0 }
                    $ephemeralOS = if ($capabilities['EphemeralOSDiskSupported'] -eq 'True') { 1 } else { 0 }
                    $maxIOPS = [int]($capabilities['UncachedDiskIOPs'] ?? 0)

                    # Upsert VM Size
                    $upsertCommand = $connection.CreateCommand()
                    $upsertCommand.Transaction = $transaction
                    $upsertCommand.CommandText = "EXEC dbo.usp_UpsertVMSize @VMSizeName, @FamilyCode, @vCPUs, @MemoryGB, NULL, @MaxDataDisks, @MaxNICs, @AcceleratedNetworkingEnabled, @PremiumIOSupported, @EphemeralOSDiskSupported"
                    $upsertCommand.Parameters.AddWithValue("@VMSizeName", $vmSizeName) | Out-Null
                    $upsertCommand.Parameters.AddWithValue("@FamilyCode", $familyCode) | Out-Null
                    $upsertCommand.Parameters.AddWithValue("@vCPUs", $vCPUs) | Out-Null
                    $upsertCommand.Parameters.AddWithValue("@MemoryGB", $memoryGB) | Out-Null
                    $upsertCommand.Parameters.AddWithValue("@MaxDataDisks", $maxDataDisks) | Out-Null
                    $upsertCommand.Parameters.AddWithValue("@MaxNICs", $maxNICs) | Out-Null
                    $upsertCommand.Parameters.AddWithValue("@AcceleratedNetworkingEnabled", $accelNet) | Out-Null
                    $upsertCommand.Parameters.AddWithValue("@PremiumIOSupported", $premiumIO) | Out-Null
                    $upsertCommand.Parameters.AddWithValue("@EphemeralOSDiskSupported", $ephemeralOS) | Out-Null

                    $vmSizeID = $upsertCommand.ExecuteScalar()

                    # Record regional availability
                    $availCommand = $connection.CreateCommand()
                    $availCommand.Transaction = $transaction
                    $availCommand.CommandText = @"
                        MERGE INTO dbo.VMSizeRegionalAvailability AS target
                        USING (SELECT @VMSizeID AS VMSizeID, @RegionID AS RegionID) AS source
                        ON target.VMSizeID = source.VMSizeID AND target.RegionID = source.RegionID
                        WHEN MATCHED THEN
                            UPDATE SET IsAvailable = 1, UpdatedDate = GETDATE()
                        WHEN NOT MATCHED THEN
                            INSERT (VMSizeID, RegionID, IsAvailable)
                            VALUES (@VMSizeID, @RegionID, 1);
"@
                    $availCommand.Parameters.AddWithValue("@VMSizeID", $vmSizeID) | Out-Null
                    $availCommand.Parameters.AddWithValue("@RegionID", $regionID) | Out-Null
                    $availCommand.ExecuteNonQuery() | Out-Null

                    $regionVMCount++
                    $totalVMsProcessed++

                } catch {
                    $errorCount++
                    if ($errorCount -le 5) {
                        Write-Output "  ERROR processing $($vm.Name): $($_.Exception.Message)"
                    }
                }
            }

            Write-Output "  Completed $region - Processed $regionVMCount VMs"

        } catch {
            Write-Output "  ERROR processing region $region : $($_.Exception.Message)"
            $errorCount++
        }
    }

    # Commit transaction
    Write-Output "`nCommitting transaction..."
    $transaction.Commit()

    # Update load history
    $updateLogCommand = $connection.CreateCommand()
    $updateLogCommand.CommandText = @"
        UPDATE dbo.DataLoadHistory
        SET LoadStatus = 'Completed',
            RecordsProcessed = @RecordsProcessed,
            RecordsInserted = @RecordsInserted,
            ErrorMessage = @ErrorMessage,
            EndTime = GETDATE()
        WHERE LoadID = @LoadID
"@
    $updateLogCommand.Parameters.AddWithValue("@LoadID", $loadID) | Out-Null
    $updateLogCommand.Parameters.AddWithValue("@RecordsProcessed", $totalVMsProcessed) | Out-Null
    $updateLogCommand.Parameters.AddWithValue("@RecordsInserted", $totalVMsProcessed) | Out-Null
    $updateLogCommand.Parameters.AddWithValue("@ErrorMessage", $(if($errorCount -gt 0){"$errorCount errors encountered"}else{[DBNull]::Value})) | Out-Null
    $updateLogCommand.ExecuteNonQuery() | Out-Null

    $connection.Close()

    Write-Output "`n=========================================="
    Write-Output "Data Collection Summary"
    Write-Output "=========================================="
    Write-Output "Total Regions Processed: $totalRegionsProcessed"
    Write-Output "Total VM SKUs Processed: $totalVMsProcessed"
    Write-Output "Errors Encountered: $errorCount"
    Write-Output "=========================================="

    Write-Output "`nData collection completed successfully!"

} catch {
    Write-Output "`nFATAL ERROR: $($_.Exception.Message)"

    if ($null -ne $transaction) {
        Write-Output "Rolling back transaction..."
        $transaction.Rollback()
    }

    # Log failure
    if ($connection.State -eq 'Open') {
        $failLogCommand = $connection.CreateCommand()
        $failLogCommand.CommandText = @"
            UPDATE dbo.DataLoadHistory
            SET LoadStatus = 'Failed',
                ErrorMessage = @ErrorMessage,
                EndTime = GETDATE()
            WHERE LoadID = @LoadID
"@
        $failLogCommand.Parameters.AddWithValue("@LoadID", $loadID) | Out-Null
        $failLogCommand.Parameters.AddWithValue("@ErrorMessage", $_.Exception.Message) | Out-Null
        $failLogCommand.ExecuteNonQuery() | Out-Null
    }

    Write-Error $_.Exception
    exit 1

} finally {
    if ($connection.State -eq 'Open') {
        $connection.Close()
    }
}
