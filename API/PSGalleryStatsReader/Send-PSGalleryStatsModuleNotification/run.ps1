# Input bindings are passed in via param block.
param($Timer)

$ct = [System.Threading.CancellationToken]::None
$now = (Get-Date).ToUniversalTime().ToString("o")

Import-Module -Name Az.Communication

$ctx = New-AzStorageContext -StorageAccountName $env:SUBSCRIPTIONS_STORAGE_ACCOUNT -UseConnectedAccount -Endpoint "core.windows.net"
$storageTable = Get-AzStorageTable -Name $($env:SUBSCRIPTIONS_TABLE_NAME) -Context $ctx
$groups = @{}

foreach ($e in $storageTable.TableClient.Query[Azure.Data.Tables.TableEntity]($($env:SubscriptionQueryFilter), $null, $null, $ct)) {
    $moduleId = [string]$e.PartitionKey
    if ([string]::IsNullOrWhiteSpace($moduleId)) { continue }

    if (-not $groups.ContainsKey($moduleId)) {
        $groups[$moduleId] = [System.Collections.Generic.List[Azure.Data.Tables.TableEntity]]::new()
    }
    $null = $groups[$moduleId].Add($e)
}

Write-Host "Active subscriptions grouped into $($groups.Keys.Count) module partitions."
foreach ($moduleId in $groups.Keys) {

    
    $currentScore = 51 #Get-CurrentModuleScore -ModuleId $moduleId

    foreach ($e in $groups[$moduleId]) {

        $email = [string]$e.Email
        if ([string]::IsNullOrWhiteSpace($email)) { continue }

        $last = $null
        if ($e.ContainsKey("LastNotifiedScore")) { $last = $e["LastNotifiedScore"] }

        $shouldSend = ($null -eq $last) -or ([string]$last -ne [string]$currentScore)
        if (-not $shouldSend) { continue }
        $to = @(
            @{
                Address = $email
                DisplayName = $email
            }
        )
        $message = @{
            ContentSubject = "PSGallery Stats - Score Changes for $($e["ModuleId"])"
            RecipientTo = $to 
            SenderAddress = $($env:SenderAddress) 
            ContentHtml = "<html><head><title>Enter title</title></head><body><img src='cid:inline-attachment' alt='Company Logo'/><h1>This is the first email from ACS - Azure PowerShell</h1></body></html>"
            ContentPlainText = "This is the first email from ACS - Azure PowerShell"  
        }

         Send-AzEmailServicedataEmail -Message $Message -endpoint $($env:ACSEndpoint) 
        
        $e["LastNotifiedScore"] = $currentScore
        $e["LastNotifiedAt"]    = (Get-Date).ToUniversalTime().ToString("o")
    
        $storageTable.TableClient.UpdateEntity[Azure.Data.Tables.TableEntity](
            $e,
            $e.ETag,                       # or [Azure.ETag]::All
            [Azure.Data.Tables.TableUpdateMode]::Merge,
            $ct
        ) | Out-Null
        
    }
}


