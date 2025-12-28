using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$statusCode = [HttpStatusCode]::OK
$body = @{
    ok = $true
}

 if ([string]::IsNullOrWhiteSpace($Request.Body)) {
        $statusCode = [HttpStatusCode]::BadRequest
        $body = @{ ok = $false; error = "Missing request body. Expected JSON: { email, moduleId }." }
    }
$payload = $Request.Body 
$emailRaw  = $payload.email
$moduleRaw = $payload.moduleid

Import-Module AzTable -ErrorAction Stop
$ctx = New-AzStorageContext -StorageAccountName $env:SUBSCRIPTIONS_STORAGE_ACCOUNT -UseConnectedAccount -Endpoint "core.windows.net"
$storageTable = Get-AzStorageTable -Name $($env:SUBSCRIPTIONS_TABLE_NAME) -Context $ctx
$rowKey = $moduleid+","+$email
$partitionKey = $moduleid
$now=get-date -Format o
$client = $storageTable.TableClient
$entity = $client.GetEntity($partitionKey, $rowKey, $null, [System.Threading.CancellationToken]::None)
$entity.Value["Unsubscribed"] = [bool]$true
$entity.Value["UpdatedAt"]    = [string]$now
$entity.Value["UnsubscribedAt"] = [string]$now

$client.UpsertEntity(
            $entity.Value,
            [TableUpdateMode]::Merge,
            [System.Threading.CancellationToken]::None
        )

$body = @{
    ok      = $true
    status  = "unsubscribed"
    email   = $email
    moduleId = $moduleId
    timestamp = $now
}
        
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
