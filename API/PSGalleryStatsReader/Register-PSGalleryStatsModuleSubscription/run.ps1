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
$payload = $Request.Body | ConvertFrom-Json
$emailRaw  = $payload.email
$moduleRaw = $payload.moduleId

if ([string]::IsNullOrWhiteSpace($emailRaw) -or [string]::IsNullOrWhiteSpace($moduleRaw)) {
        $statusCode = [HttpStatusCode]::BadRequest
        $body = @{ ok = $false; error = "Body must include non-empty 'email' and 'moduleId'." }
    }

$email = $emailRaw.Trim().ToLowerInvariant()
$moduleId = $moduleRaw.Trim().ToLowerInvariant()

if ($email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    $statusCode = [HttpStatusCode]::BadRequest
    $body = @{ ok = $false; error = "Invalid email format." }
}

$body = @{
    ok        = $true
    action    = if ($existing) { "updated" } else { "created" }
    email     = $email
    moduleId  = $moduleId
    timestamp = get-date -Format o
}
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $statusCode
    Body = $body
})
