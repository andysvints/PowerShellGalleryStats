function Get-CommunityImpact
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
    ()

    Begin
    {
    }
    Process
    {
        if ($pscmdlet.ShouldProcess(""))
        {
            $FilePath = Join-Path -Path "/usr/local/share/powershell/Modules/PSGalleryModuleScore" -ChildPath "CommunityImpact.json"
            Write-Verbose "Community impact data path - $FilePath"
            $CommunityImpact=Get-Content $FilePath | ConvertFrom-Json -Depth 10
            $IndexPageHTML=Get-Content $(Join-Path -Path "/usr/local/share/powershell/Modules/PSGalleryModuleScore/Web" -ChildPath "index.html")
            #Generate HTML 
            $HTMLTable=[System.Text.StringBuilder]::new()
            $HTMLTable.AppendLine("
            Community impact: $($CommunityImpact.PRsSubmitted)+ PRs, $($CommunityImpact.IssuesOpened)+ issues · Updated daily <br>
<a href=`"https://github.com/search?q=stats.psfundamentals.com&type=pullrequests`" target=`"_blank`">See Details</a>
            ")
            #Inject Into index.html
            $IndexPageHTML=$IndexPageHTML.Replace("<CommunityImpactTemplate>",$($HTMLTable.ToString())) 
            $IndexPageHTML | Out-file "/usr/local/share/powershell/Modules/PSGalleryModuleScore/Web/index.html" -Force
            
        }
    }
    End
    {
    }
}
