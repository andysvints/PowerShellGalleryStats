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
Write-Host "Processing module $moduleId"
    $apiKey=Get-AzKeyVaultSecret -VaultName "PSGalleryStats-KV" -Name "PSGlrStatsFprEmailNotif" -AsPlainText
    $apiUrl = "https://psgallerystats.azure-api.net/get-psgallerystatsbyid?subscription-key=$apiKey&module=$moduleId"
    $apiResponse = Invoke-RestMethod -Uri $apiUrl
    $currentScore = $apiResponse.cp_TotalScore
    Write-Host "Module $moduleId score $currentScore"
    foreach ($e in $groups[$moduleId]) {

        $email = [string]$e["Email"]
        if ([string]::IsNullOrWhiteSpace($email)) { continue }

        $last = $null
        if ($e.ContainsKey("LastNotifiedScore")) { $last = $e["LastNotifiedScore"] }

        $shouldSend = ($null -eq $last) -or ([string]$last -ne [string]$currentScore)
        Write-Host "Should Send Email - $shouldSend"
        if (-not $shouldSend) { continue }
        $to = @(
            @{
                Address = $email
                DisplayName = $email
            }
        )
$EmailHTML=@"
<table width="100%" cellpadding="0" cellspacing="0" style="font-family:Segoe UI, Arial, sans-serif; background:#f4f6f8; padding:20px;">
  <tr>
    <td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#e2f0fb; border-radius:6px; padding:24px;">
        <tr>
          <td style="font-size:18px; font-weight:600; color:#1f2937;">
            PowerShell Gallery Stats — Module Score Update
          </td>
        </tr>
        <tr><td height="16"></td></tr>
        <tr>
          <td style="font-size:20px; font-weight:700;">
            $moduleId
          </td>
        </tr>
        <tr>
          <td style="color:#6b7280;">
            by $($apiResponse.Owners)
          </td>
        </tr>
        <tr><td height="12"></td></tr>
        <tr>
          <td style="font-size:16px;">
            <strong>Score:</strong> $currentScore  
            <span style="color:#16a34a;">(+7 / +20%)</span>
          </td>
        </tr>
        <tr><td height="16"></td></tr>
        <tr>
          <td>
            <strong>Module Info</strong>
          </td>
        </tr>
        <tr>
          <td style="font-size:14px; line-height:1.6;">
            Version: $($apiResponse.Version)<br/>
            License: $($apiResponse.LicenseUrl)<br/>
            Last published: $($apiResponse.Published)<br/>
            Project: <a href="$($apiResponse.ProjectUrl)">$($apiResponse.ProjectUrl)</a>
          </td>
        </tr>
        <tr><td height="16"></td></tr>
        <tr><td height="20"></td></tr>
        <tr>
          <td align="center">
            <a href="https://stats.psfundamentals.com/searchbyid?query=$moduleid"
               style="display:inline-block; padding:10px 16px; background:#2563eb; color:#ffffff; text-decoration:none; border-radius:4px;" target="_about">
              View More Details
            </a>
          </td>
        </tr><tr><td height="24"></td></tr>
        <tr>
          <td style="font-size:12px; color:#6b7280;" align="center">
            You’re receiving this email because you subscribed to updates for PowerShell Module $moduleid.<br/>
            <a href="{{unsubscribeUrl}}">Unsubscribe</a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
"@
$EmailPlain=@"
 Plain text
"@
        $message = @{
            ContentSubject = "[PSGallery Stats] $moduleId Module Score Update "
            RecipientTo = $to 
            SenderAddress = $($env:SenderAddress) 
            ContentHtml = $EmailHTML
            ContentPlainText = $EmailPlain  
        }
         Write-Host "Sending email to $email"
         Send-AzEmailServicedataEmail -Message $Message -endpoint $($env:ACSEndpoint) 
        
        $e["LastNotifiedScore"] = $currentScore
        $e["LastNotifiedAt"]    = (Get-Date).ToUniversalTime().ToString("o")
        Write-Host "Updating the entity"
        $storageTable.TableClient.UpdateEntity[Azure.Data.Tables.TableEntity](
            $e,
            $e.ETag, 
            [Azure.Data.Tables.TableUpdateMode]::Merge,
            $ct
        ) 
        
    }
}


