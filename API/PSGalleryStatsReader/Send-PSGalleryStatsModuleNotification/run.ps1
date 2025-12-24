# Input bindings are passed in via param block.
param($Timer)

Import-Module -Name Az.Communication
$message = @{
    ContentSubject = "Test Email"
    RecipientTo = @($env:emailRecipientTo)  
    SenderAddress = 'donotreply@stats.psfundamentals.com'   
    ContentHtml = "<html><head><title>Enter title</title></head><body><img src='cid:inline-attachment' alt='Company Logo'/><h1>This is the first email from ACS - Azure PowerShell</h1></body></html>"
    ContentPlainText = "This is the first email from ACS - Azure PowerShell"  
}

Send-AzEmailServicedataEmail -Message $Message -endpoint $($env:ACSEndpoint>)
