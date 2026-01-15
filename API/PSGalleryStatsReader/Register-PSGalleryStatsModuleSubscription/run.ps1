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
if($payload -is [string]) {$payload=$payload | ConvertFrom-Json}
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
$apiKey=Get-AzKeyVaultSecret -VaultName "PSGalleryStats-KV" -Name "PSGlrStatsFprEmailNotif" -AsPlainText
$apiUrl = "https://psgallerystats.azure-api.net/get-psgallerystatsbyid?subscription-key=$apiKey&module=$moduleId"
$apiResponse = Invoke-RestMethod -Uri $apiUrl
$currentScore = $apiResponse.cp_TotalScore
$ctx = New-AzStorageContext -StorageAccountName $env:SUBSCRIPTIONS_STORAGE_ACCOUNT -UseConnectedAccount -Endpoint "core.windows.net"
$storageTable = Get-AzStorageTable -Name $($env:SUBSCRIPTIONS_TABLE_NAME) -Context $ctx
$rowKey = $moduleid+","+$email
$partitionKey = $moduleid
$now=get-date -Format o
$entity = [Azure.Data.Tables.TableEntity]::new($partitionKey, $rowKey)
$entity["Email"]        = [string]$email
$entity["ModuleId"]     = [string]$moduleId
$entity["CreatedAt"]    = [string]$now
$entity["UpdatedAt"]    = [string]$now
$entity["Unsubscribed"] = [bool]$false
$entity["Source"]       = [string]"module-page"
$entity["LastNotifiedScore"]=[string]$currentScore

$updateMode = [Azure.Data.Tables.TableUpdateMode]::Merge
$ct = [System.Threading.CancellationToken]::None
$storageTable.TableClient.UpsertEntity($entity, $updateMode, $ct)
    
$body = @{
    ok        = $e ? $false : $true
    action    = $e ? "failed" : "created"
    email     = $email
    moduleId  = $moduleId
    timestamp = $now
}
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $statusCode
    Body = $body
})
