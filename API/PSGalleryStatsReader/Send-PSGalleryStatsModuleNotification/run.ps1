# Input bindings are passed in via param block.
param($Timer)

$ct = [System.Threading.CancellationToken]::None
$now = (Get-Date).ToUniversalTime().ToString("o")

Import-Module -Name Az.Communication

$ctx = New-AzStorageContext -StorageAccountName $env:SUBSCRIPTIONS_STORAGE_ACCOUNT -UseConnectedAccount -Endpoint "core.windows.net"
$storageTable = Get-AzStorageTable -Name $($env:SUBSCRIPTIONS_TABLE_NAME) -Context $ctx

foreach ($e in $storageTable.TableClient.Query[Azure.Data.Tables.TableEntity]($(env:SubscriptionQueryFilter), $null, $null, $ct)) {
    $moduleId = [string]$e.PartitionKey
    if ([string]::IsNullOrWhiteSpace($moduleId)) { continue }

    if (-not $groups.ContainsKey($moduleId)) {
        $groups[$moduleId] = [List[TableEntity]]::new()
    }
    $null = $groups[$moduleId].Add($e)
}

Write-Host "Active subscriptions grouped into $($groups.Keys.Count) module partitions."

$to = @(
    @{
        Address = $env:emailRecipientTo
        DisplayName = $env:emailRecipientTo
    }
)

$message = @{
    ContentSubject = "Test Email"
    RecipientTo = $to 
    SenderAddress = $($env:SenderAddress) 
    ContentHtml = "<html><head><title>Enter title</title></head><body><img src='cid:inline-attachment' alt='Company Logo'/><h1>This is the first email from ACS - Azure PowerShell</h1></body></html>"
    ContentPlainText = "This is the first email from ACS - Azure PowerShell"  
}

# Send-AzEmailServicedataEmail -Message $Message -endpoint $($env:ACSEndpoint)
