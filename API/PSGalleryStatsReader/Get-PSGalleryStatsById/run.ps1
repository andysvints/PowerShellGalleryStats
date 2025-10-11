using namespace System.Net

# Input bindings are passed in via param block.
param($Request,$PSDocument, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$module = $Request.Query.module
if (-not $module) {
    $module = $Request.Body.module
}

# Ensure we have a module name to query
if (-not $module) {
    return @{
        status = [HttpStatusCode]::BadRequest
        body = "Please provide a ModuleName in the query string or in the request body."
    }
}
Write-Host "sqlQuery param: $module"
$body=$($PSDocument | ConvertTo-Json -Depth 10)
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
