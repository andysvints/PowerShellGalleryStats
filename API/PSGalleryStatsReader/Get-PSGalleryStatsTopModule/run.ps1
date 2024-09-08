# Input bindings are passed in via param block.
param($Timer)

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

# Commit file using GitHub API
$commitUrl = "https://api.github.com/repos/$owner/$repo/contents/$filePath"
$response = Invoke-RestMethod -Uri $commitUrl -Headers $headers -Method Put -Body $jsonBody

# Output the response
Write-Host "$response"