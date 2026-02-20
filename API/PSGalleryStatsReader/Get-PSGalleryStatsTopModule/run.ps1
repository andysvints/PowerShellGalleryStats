# Input bindings are passed in via param block.
param($Timer, $PSDocuments)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

$List=New-Object System.Collections.Generic.List[PSObject]
foreach ($PSDoc in $PSDocuments) { 
    # operate on each document
    Write-Host "Processing PowerShell Modules"
    Write-Host "$($PSDoc.id)"
    $List.Add($PSDoc)
} 
$TopModulesJSON=$($List | ConvertTo-Json -Depth 10)

#TODO: Get from Azure KeyVault
$githubToken = Get-AzKeyVaultSecret -VaultName "PSGalleryStats-KV" -Name "GitHubPAT" -AsPlainText
##############################

$owner = "andysvints"
$repo = "PowerShellGalleryStats"
$branch = "main"

$filePath = "ContainerizedWebApp/TopModules.json"
$commitMessage = "Update TopModules.json from Azure Function"

$headers = @{
    Authorization = "Bearer $githubToken"
    Accept = "application/vnd.github.v3+json"
}

# Get the file SHA (to update existing file)
$fileApiUrl = "https://api.github.com/repos/$owner/$repo/contents/$($filePath)?ref=$($branch)"
$response = Invoke-RestMethod -Uri $fileApiUrl -Headers $headers -Method Get
$fileSha = $response.sha
$TopModulesBase64=[Convert]::ToBase64String($OutputEncoding.GetBytes($TopModulesJSON))

# Create request body
$body = @{
    message = $commitMessage
    content = $TopModulesBase64
    sha     = $fileSha 
    branch  = $branch
}

$jsonBody = $body | ConvertTo-Json
$headers = @{
    Authorization = "Bearer $githubToken"
    Accept = "application/vnd.github+json"
    'Content-Type'='application/json'
}

# Commit file using GitHub API
$commitUrl = "https://api.github.com/repos/$owner/$repo/contents/$filePath"
$response = Invoke-WebRequest -Uri $commitUrl -Headers $headers -Method Put -Body $jsonBody

# Output the response
Write-Host "$response"

$CommunityImpactReqHeaders=@{Accept="application/vnd.github+json";"X-GitHub-Api-Version"='2022-11-28'}
$r=Invoke-RestMethod -Uri "https://api.github.com/search/issues?q=stats.psfundamentals.com" -Headers $CommunityImpactReqHeaders
$issue=$r.items | Where {$_.issue_dependencies_summary -ne $null}
$pr=$r.items | Where {$_.pull_request -ne $null}
$openPR=$pr | where {$_.state -eq "open"}
$openissue=$issue | where {$_.state -eq "open"}

$CommunityImpact=New-Object System.Collections.Generic.List[PSObject]
$CommunityImpact.Add(@{"PRsSubmitted"=$pr.count})
$CommunityImpact.Add(@{"PRsMerged"=$pr.count-$openPR.count})
$CommunityImpact.Add(@{"IssuesOpened"=$issue.count})
$CommunityImpact.Add(@{"IssuesClosed"=$issue.count-$openIssue.count})
$CommunityImpactJSON=$CommunityImpact | ConvertTo-Json -Depth 10

$filePath = "ContainerizedWebApp/CommunityImpact.json"
$commitMessage = "Update CommunityImpact.json from Azure Function"
$fileApiUrl = "https://api.github.com/repos/$owner/$repo/contents/$($filePath)?ref=$($branch)"
$response = Invoke-RestMethod -Uri $fileApiUrl -Headers $headers -Method Get
$fileSha = $response.sha
$CommunityImpactBase64=[Convert]::ToBase64String($OutputEncoding.GetBytes($CommunityImpactJSON))

$body = @{
    message = $commitMessage
    content = $CommunityImpactBase64
    sha     = $fileSha 
    branch  = $branch
}

$jsonBody = $body | ConvertTo-Json


$commitUrl = "https://api.github.com/repos/$owner/$repo/contents/$filePath"
$response = Invoke-WebRequest -Uri $commitUrl -Headers $headers -Method Put -Body $jsonBody

# Output the response
Write-Host "$response"
