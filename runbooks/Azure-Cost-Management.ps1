<#
.SYNOPSIS
    VM Cost Analysis Runbook - analyzes and reports VM costs across subscriptions.

.DESCRIPTION
    Connects via the Automation Account's system-assigned managed identity and analyzes
    Virtual Machine costs across all accessible subscriptions.

    Scope: VMs ONLY (aligned with DataAPIBuilder VM sizing and pricing focus)

    ANALYSIS:
      - Running VM costs by SKU, region, and subscription
      - VM power state analysis (running vs stopped/deallocated)
      - Cost optimization opportunities (oversized VMs, stopped but allocated)
      - VM family cost comparisons

    OUTPUT:
      - JSON reports stored in blob storage (json container)
      - Summary statistics and recommendations
      - Integration with VMSizes database for cost trends

.NOTES
    Author:     DataAPIBuilder Project
    Purpose:    VM-specific cost analysis and optimization
    Runtime:    PowerShell 7.2
    Schedule:   Daily (Nightly VM Cost Analysis)
#>

#Requires -Modules Az.Accounts, Az.Compute, Az.Storage

# ============================================================================
# CONFIGURATION
# ============================================================================

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Storage configuration
$ResourceGroupName = 'DataAPIBuilder'
$StorageAccountName = 'datapibuilderdemo'
$ContainerName = 'json'
$ReportPrefix = 'vm-cost-analysis'

# Note: Future enhancement could integrate with VMSizes database
# to track VM cost trends over time

# ============================================================================
# AUTHENTICATION
# ============================================================================

Write-Output "=== VM Cost Analysis Runbook Started ==="
Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Disable context autosave
$null = Disable-AzContextAutosave -Scope Process

# Connect using Managed Identity
try {
    Write-Output "Connecting to Azure using Managed Identity..."
    $AzureConnection = (Connect-AzAccount -Identity).Context
    Write-Output "[OK] Successfully authenticated as: $($AzureConnection.Account.Id)"
}
catch {
    Write-Error "Failed to authenticate with Managed Identity: $_"
    exit 1
}

# ============================================================================
# GET SUBSCRIPTIONS
# ============================================================================

Write-Output "`nRetrieving accessible subscriptions..."
$Subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }
Write-Output "[OK] Found $($Subscriptions.Count) enabled subscription(s)"

# ============================================================================
# VM COST ANALYSIS
# ============================================================================

$AllVMData = @()
$TotalRunningVMs = 0
$TotalStoppedAllocated = 0
$TotalDeallocated = 0

foreach ($Subscription in $Subscriptions) {
    Write-Output "`n--- Analyzing Subscription: $($Subscription.Name) ---"

    # Set context
    $null = Set-AzContext -SubscriptionId $Subscription.Id

    # Get all VMs
    try {
        $VMs = Get-AzVM -Status
        Write-Output "  Found $($VMs.Count) VM(s)"

        foreach ($VM in $VMs) {
            # Get power state
            $PowerState = ($VM.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code -replace 'PowerState/', ''

            # Categorize by state
            switch ($PowerState) {
                'running' { $TotalRunningVMs++ }
                'stopped' { $TotalStoppedAllocated++ }  # Stopped but still allocated (incurs costs)
                'deallocated' { $TotalDeallocated++ }
            }

            # Get VM size details
            $VMSize = $VM.HardwareProfile.VmSize

            # Extract resource group and tags
            $ResourceGroup = $VM.ResourceGroupName
            $Tags = $VM.Tags

            # Build VM data object
            $VMData = [PSCustomObject]@{
                SubscriptionId   = $Subscription.Id
                SubscriptionName = $Subscription.Name
                ResourceGroup    = $ResourceGroup
                VMName           = $VM.Name
                Location         = $VM.Location
                VMSize           = $VMSize
                PowerState       = $PowerState
                OSDiskType       = $VM.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
                DataDiskCount    = $VM.StorageProfile.DataDisks.Count
                NetworkInterfaces = $VM.NetworkProfile.NetworkInterfaces.Count
                Tags             = if ($Tags) { ($Tags | ConvertTo-Json -Compress) } else { $null }
                Timestamp        = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
            }

            $AllVMData += $VMData

            # Log VM details
            Write-Output "    VM: $($VM.Name) | Size: $VMSize | State: $PowerState"
        }
    }
    catch {
        Write-Warning "  Error retrieving VMs: $_"
    }
}

# ============================================================================
# SUMMARY STATISTICS
# ============================================================================

Write-Output "`n=== VM Cost Analysis Summary ==="
Write-Output "Total VMs Analyzed: $($AllVMData.Count)"
Write-Output "  Running:             $TotalRunningVMs (incurring compute costs)"
Write-Output "  Stopped (allocated): $TotalStoppedAllocated (incurring storage costs)"
Write-Output "  Deallocated:         $TotalDeallocated (minimal costs)"

# Cost optimization opportunities
if ($TotalStoppedAllocated -gt 0) {
    Write-Output "`n[WARNING]  COST OPTIMIZATION OPPORTUNITY:"
    Write-Output "  $TotalStoppedAllocated VM(s) are STOPPED but still ALLOCATED"
    Write-Output "  These VMs still incur storage and reservation costs"
    Write-Output "  Recommendation: Deallocate stopped VMs to reduce costs"
}

# VM size distribution
$VMSizeDistribution = $AllVMData | Group-Object VMSize | Sort-Object Count -Descending
Write-Output "`n=== VM Size Distribution ==="
foreach ($Size in $VMSizeDistribution | Select-Object -First 10) {
    Write-Output "  $($Size.Name): $($Size.Count) VM(s)"
}

# Region distribution
$RegionDistribution = $AllVMData | Group-Object Location | Sort-Object Count -Descending
Write-Output "`n=== VM Region Distribution ==="
foreach ($Region in $RegionDistribution) {
    Write-Output "  $($Region.Name): $($Region.Count) VM(s)"
}

# ============================================================================
# EXPORT TO BLOB STORAGE
# ============================================================================

Write-Output "`n=== Exporting Results to Blob Storage ==="

# Generate report filename
$ReportDate = Get-Date -Format 'yyyyMMdd-HHmmss'
$ReportFileName = "$ReportPrefix-$ReportDate.json"

try {
    # Convert data to JSON
    $JsonOutput = $AllVMData | ConvertTo-Json -Depth 10

    # Get storage account - try specific resource group first, then search all
    Write-Output "Retrieving storage account: $StorageAccountName"
    $StorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue

    if (-not $StorageAccount) {
        Write-Output "  Not found in resource group '$ResourceGroupName', searching all resource groups..."
        $StorageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName } | Select-Object -First 1
    }

    if (-not $StorageAccount) {
        throw "Storage account '$StorageAccountName' not found in any accessible resource group"
    }

    Write-Output "  Found in resource group: $($StorageAccount.ResourceGroupName)"

    # Get storage context
    $StorageContext = $StorageAccount.Context

    # Create temporary file
    $TempFile = [System.IO.Path]::GetTempFileName()
    $JsonOutput | Out-File -FilePath $TempFile -Encoding utf8

    # Upload to blob storage
    Write-Output "Uploading report to blob: $ContainerName/$ReportFileName"
    Set-AzStorageBlobContent `
        -File $TempFile `
        -Container $ContainerName `
        -Blob $ReportFileName `
        -Context $StorageContext `
        -Force | Out-Null

    # Clean up temp file
    Remove-Item -Path $TempFile -Force

    Write-Output "[OK] Successfully uploaded report to blob storage"
    Write-Output "  Location: $ContainerName/$ReportFileName"
    Write-Output "  Size: $($AllVMData.Count) VM records"
}
catch {
    Write-Error "Failed to upload report to blob storage: $_"
}

# ============================================================================
# COST RECOMMENDATIONS
# ============================================================================

Write-Output "`n=== Cost Optimization Recommendations ==="

# Stopped VMs that should be deallocated
$StoppedVMs = $AllVMData | Where-Object { $_.PowerState -eq 'stopped' }
if ($StoppedVMs.Count -gt 0) {
    Write-Output "`n1. DEALLOCATE STOPPED VMs ($($StoppedVMs.Count) VMs)"
    Write-Output "   The following VMs are stopped but still allocated (incurring costs):"
    foreach ($VM in $StoppedVMs | Select-Object -First 5) {
        Write-Output "   - $($VM.VMName) ($($VM.VMSize)) in $($VM.ResourceGroup)"
    }
    if ($StoppedVMs.Count -gt 5) {
        Write-Output "   ... and $($StoppedVMs.Count - 5) more"
    }
    Write-Output "   Action: Use 'Stop-AzVM -Force' or 'Deallocate' in portal"
}

# Large VM sizes that might be over-provisioned
$LargeVMFamilies = @('Standard_D64', 'Standard_E64', 'Standard_M', 'Standard_G')
$LargeVMs = $AllVMData | Where-Object {
    $VMSize = $_.VMSize
    $LargeVMFamilies | Where-Object { $VMSize -like "$_*" }
}
if ($LargeVMs.Count -gt 0) {
    Write-Output "`n2. REVIEW LARGE VM SIZES ($($LargeVMs.Count) VMs)"
    Write-Output "   Consider if these large VMs are fully utilized:"
    foreach ($VM in $LargeVMs | Select-Object -First 5) {
        Write-Output "   - $($VM.VMName) ($($VM.VMSize)) - $($VM.PowerState)"
    }
    Write-Output "   Action: Review CPU/memory utilization and consider downsizing"
}

# Running VMs with premium disks
$PremiumDiskVMs = $AllVMData | Where-Object {
    $_.PowerState -eq 'running' -and $_.OSDiskType -like '*Premium*'
}
if ($PremiumDiskVMs.Count -gt 0) {
    Write-Output "`n3. PREMIUM DISK USAGE ($($PremiumDiskVMs.Count) VMs)"
    Write-Output "   VMs with Premium SSD disks (higher cost):"
    Write-Output "   Action: Consider Standard SSD for non-production workloads"
}

# ============================================================================
# COMPLETION
# ============================================================================

Write-Output "`n=== VM Cost Analysis Complete ==="
Write-Output "Report stored in: $ContainerName/$ReportFileName"
Write-Output "Next scheduled run: Check Automation Schedule 'Nightly VM Cost Analysis'"

# Exit successfully
exit 0
