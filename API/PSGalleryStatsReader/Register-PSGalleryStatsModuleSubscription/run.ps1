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

if ([string]::IsNullOrWhiteSpace($emailRaw) -or [string]::IsNullOrWhiteSpace($moduleRaw)) {
        $statusCode = [HttpStatusCode]::BadRequest
        $body = @{ ok = $false; error = "Body must include non-empty 'email' and 'moduleid'." }
    }

$email = $emailRaw.Trim().ToLower()
$moduleId = $moduleRaw.Trim().ToLower()

if ($email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    $statusCode = [HttpStatusCode]::BadRequest
    $body = @{ ok = $false; error = "Invalid email format." }
}
Import-Module AzTable -ErrorAction Stop
$ctx = New-AzStorageContext -StorageAccountName $env:SUBSCRIPTIONS_STORAGE_ACCOUNT -UseConnectedAccount -Endpoint "core.windows.net"
$storageTable = Get-AzStorageTable -Name $($env:SUBSCRIPTIONS_TABLE_NAME) -Context $ctx
$rowKey = New-Guid
$partitionKey = $email
$now=get-date -Format o
$entity = @{
    Email          = $email
    ModuleId       = $moduleId
    CreatedAt      = $now
    Unsubscribed   = $false
    UnsubscribedAt = $null
    Source         = "module-page"
}
Add-AzTableRow `
    -table $storageTable.CloudTable `
    -partitionKey $partitionKey `
    -rowKey $rowKey -property $entity -ErrorVariable e
    
$body = @{
    ok        = $e ? $false : $true
    action    = "created"
    email     = $email
    moduleId  = $moduleId
    timestamp = $now
}
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $statusCode
    Body = $body
})
