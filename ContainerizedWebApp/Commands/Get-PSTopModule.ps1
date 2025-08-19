
function Get-PSTopModule
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
        # Number Top Modules to return
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("Top")] 
        $ModulesCount=10
    )

    Begin
    {
    }
    Process
    {
        if ($pscmdlet.ShouldProcess("Top $ModulesCount modules"))
        {
            #TODO: get top modules via API call
            $ModulesFilePath = Join-Path -Path "/usr/local/share/powershell/Modules/PSGalleryModuleScore" -ChildPath "TopModules.json"
            Write-Verbose "Top modules path - $ModulesFilePath"
            $TopModules=Get-Content $ModulesFilePath | ConvertFrom-Json -Depth 10 | Select-Object -First $ModulesCount
            $IndexPageHTML=Get-Content $(Join-Path -Path "/usr/local/share/powershell/Modules/PSGalleryModuleScore/Web" -ChildPath "index.html")
            #Generate HTML Table
            $HTMLTable=[System.Text.StringBuilder]::new()
            $HTMLTable.AppendLine("<table>
    <thead>
        <tr>
        <th>Module Name</th>
        <th>Author</th>
        <th>Score</th>
        </tr>
    </thead>
    <tbody>")
            for ($i = 0; $i -lt $ModulesCount; $i++)
            { 
                
                $HTMLTable.AppendLine("<tr>")
                $Author=if($TopModules[$i].Owners -like "*,*"){$TopModules[$i].Owners.split(',')[0]}else{$TopModules[$i].Owners}
                $HTMLTable.AppendLine("
                <td title=`"$($TopModules[$i].id)`"><b><a href='/search?query=$($TopModules[$i].id)' target='_blank'>$($TopModules[$i].id)</a></b></td>
                    <td title=`"Author:`">$Author</td>
                    <td title=`"Score:`">$($TopModules[$i].Score)</td>")
                $HTMLTable.AppendLine("</tr>")
            }
            $HTMLTable.AppendLine("<tbody></table>")
            #Inject Into index.html
            $IndexPageHTML.Replace("<TableTemplate>",$($HTMLTable.ToString())) | Out-file "/usr/local/share/powershell/Modules/PSGalleryModuleScore/Web/index.html" -Force
        }
    }
    End
    {
    }
}
