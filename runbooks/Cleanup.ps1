#Connect to Azure

# Ensures you do not inherit an AzContext in your runbook
$null = Disable-AzContextAutosave -Scope Process

# Connect using a Managed Service Identity
try {
    $AzureConnection = (Connect-AzAccount -Identity).context
}
catch {
    Write-Output "There is no system-assigned user identity. Aborting." 
    exit
}

#Resize Database

#import-module AzCompute 

$RGName = 'DataAPIBuilder'
$SQLServer = 'dataapibuilderdemo'
$DB = 'VMsizes'
$Storage = 'datapibuilderdemo'


Write-Output "Resizing Database"

Set-AzSqlDatabase -ResourceGroupName $RGName -DatabaseName $DB -ServerName $SQLServer -Edition "Standard" -RequestedServiceObjectiveName "S0"

#Clean Storage

$ContainerName='json'
$Context=new-AzStorageContext -storageaccountname $storage -useConnectedAccount

Get-AzStorageBlob -Container $ContainerName -Context $context| Remove-AzStorageBlob

#
