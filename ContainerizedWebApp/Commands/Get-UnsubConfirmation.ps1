
function Get-UnsubConfirmation
{
    <#
    .Synopsis
       Short description
    .DESCRIPTION
       Long description
    .EXAMPLE
       Example of how to use this cmdlet
    #>
    [CmdletBinding(SupportsShouldProcess=$true, 
                  ConfirmImpact='Medium')]
    [Alias()]
    Param
    (
        # ModuleId to unsubscribe
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("Module","Name")] 
        $Module,
        
       # Email to unsubscribe
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Email
    )
    Begin
    {
    }
    Process
    {
        if ($pscmdlet.ShouldProcess("$Module module and email - $Email"))
        {

            connect-AzAccount -Subscription "6e606d01-ff42-4cab-bcf2-b8888ab2fdc4" -Identity | Out-Null
            $KeyVaultName="PSGalleryStats-KV"
            $apiKey=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "PSGlrStatsFprEmailNotif" -AsPlainText
            $apiUrl = "https://psgallerystats.azure-api.net/Set-PSGalleryStatsModuleSubscription?subscription-key=$apiKey"
            $Body=@{
              email=$email,
              moduleid=$module
            }
            $apiResponse = Invoke-RestMethod -Uri $apiUrl -Body

            $HTMLTemplate=Get-Content $(Join-Path -Path "/usr/local/share/powershell/Modules/PSGalleryModuleScore/Web" -ChildPath "index.html") -Raw
            $TextResult="You have successufully unsubscribed from the $module score updates"
            $htmlResponse = $HTMLTemplate.Replace("<TextTemplate>","`'$TextResult`'")
            $targetUrl =  "/unsubscribe#t6"
            $targetUrlJs = $targetUrl -replace "'", "\\'"   # escape single quotes for JS string
            $forceHash = @"
<script>
(function () {
var target = '$targetUrlJs';
// Only rewrite if needed (no extra history entry)
if (location.pathname + location.search + location.hash !== target) {
history.replaceState(null, '', target);
}
})();
</script>
"@
        $htmlResponse = $htmlResponse.Replace("<DefaultHashScriptTemplate>", $forceHash)
        return $htmlResponse
           
        }
    }
    End
    {
    }
}
