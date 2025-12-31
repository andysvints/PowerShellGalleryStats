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
            PowerShell Gallery Stats - Module Score Update
          </td>
        </tr>
        <tr><td height="16"></td></tr>
        <tr>
          <td style="font-size:20px; font-weight:700;">
            $($moduleId.ToUpper())
          </td>
        </tr>
        <tr>
          <td style="color:#6b7280;">
            by $(if($apiResponse.Owners -like "*,*"){$apiResponse.Owners.split(',')[0]}else{$apiResponse.Owners})
          </td>
        </tr>
        <tr><td height="12"></td></tr>
        <tr>
          <td style="font-size:16px;">
            <strong>Score:</strong> $currentScore  
            <span style="color:$(($currentScore -gt $last) ? "#00A36C;" : "#DE3163")">($("{0:+#;-#;0}" -f $($currentScore-$last)) / $("{0:+#;-#;0}" -f $(($currentScore-$last)/$last*100))%)</span>
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
            License: $(if($apiResponse.LicenseUrl){"<a href=`"$($apiResponse.LicenseUrl)`" target=`"_blank`">$($apiResponse.LicenseUrl)</a>"}else{"NaN"})<br/>
            Last published: $($apiResponse.Published)<br/>
            Project: $(if($apiResponse.ProjectUrl){"<a href=`"$($apiResponse.ProjectUrl)`" target=`"_blank`">$($apiResponse.ProjectUrl)</a>"}else{"NaN"})
          </td>
        </tr>
        <tr><td height="16"></td></tr>
        <tr><td height="20"></td></tr>
        <tr>
          <td align="center">
            <a href="https://stats.psfundamentals.com/searchbyid?query=$moduleid"
               style="display:inline-block; padding:10px 16px; background:#2563eb; color:#ffffff; text-decoration:none; border-radius:4px;" target="_blank">
              View More Details
            </a>
          </td>
        </tr><tr><td height="24"></td></tr>
        <tr>
          <td style="font-size:12px; color:#6b7280;" align="center">
            You’re receiving this email because you subscribed to updates for PowerShell Module $($moduleId.ToUpper()).<br/>
            <a href="https://stats.psfundamentals.com/unsubscribe">Unsubscribe</a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
"@
$EmailPlain=@"
PowerShell Gallery Stats — Module Score Update
───────────────────────
$($moduleId.ToUpper()) by $(if($apiResponse.Owners -like "*,*"){$apiResponse.Owners.split(',')[0]}else{$apiResponse.Owners})
Score: $currentScore ($("{0:+#;-#;0}" -f $($currentScore-$last)) / $("{0:+#;-#;0}" -f $(($currentScore-$last)/$last*100))%)

Module Info
 - Version: $($apiResponse.Version)
 - License: $(if($apiResponse.LicenseUrl){"$($apiResponse.LicenseUrl)"}else{"NaN"})
 - Last published: $($apiResponse.Published)
 - Project: $(if($apiResponse.ProjectUrl){"$($apiResponse.ProjectUrl)"}else{"NaN"})

View full analysis:
https://stats.psfundamentals.com/searchbyid?query=$moduleid

Unsubscribe from $($moduleId.ToUpper()) updates:
https://stats.psfundamentals.com/unsubscribe

───────────────────────
You are receiving this email because you subscribed to updates for the
PowerShell module "$($moduleId.ToUpper())".
"@
        $message = @{
            ContentSubject = "[PSGallery Stats] $($moduleId.ToUpper()) - Score Update "
            RecipientTo = $to 
            SenderAddress = $($env:SenderAddress) 
            ContentHtml = $EmailHTML
            ContentPlainText = $EmailPlain  
        }
         Write-Host "Sending email to $email"
         Send-AzEmailServicedataEmail -Message $Message -endpoint $($env:ACSEndpoint) -NoWait
        
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


