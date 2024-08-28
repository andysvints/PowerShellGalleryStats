
function Get-PSModuleInfo
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
        [Alias("Module","Name")] 
        $Query,
        [Switch]
        $FullInfo
    )
    Begin
    {
    }
    Process
    {
        if ($pscmdlet.ShouldProcess("query $Query"))
        {
            #Get-API KEY from key vault
            
            ###########################################
            $apiUrl = "https://psgallerystats.azure-api.net/get-psgallerystats?subscription-key=$apiKey&module=$query"
            $apiResponse = Invoke-RestMethod -Uri $apiUrl
            if($FullInfo){
                $HTMLTemplate="ModuleInfo page"
                #TO DO
            }else{
                $HTMLTemplate=Get-Content $(Join-Path -Path "/usr/local/share/powershell/Modules/PSGalleryModuleScore/Web" -ChildPath "search-results.html")
                $htmlResponse = $HTMLTemplate.Replace("<QueryTemplate>","`'$Query`'")
                $HTMLResults=[System.Text.StringBuilder]::new()
                if($apiResponse){
                    for ($i = 0; $i -lt $apiResponse.Count; $i++)
                    {   
                        $IconURL=if(-not $apiResponse[$i].IconURL){"/Assets/PowerShellChevron.svg"}else{$apiResponse[$i].IconURL}
                        $Author=if($apiResponse[$i].Owners -like "*,*"){$apiResponse[$i].Owners.split(',')[0]}else{$apiResponse[$i].Owners}
                        $Description=if($apiResponse[$i].Description.Length -gt 64){$apiResponse[$i].Description.substring(0,61)+"..."}else{$apiResponse[$i].Description}
                        $ScoreItemsDictionary=$apiResponse[$i].scoring.details.metadata | Get-Member|Where-Object {$_.MemberType -eq "NoteProperty"} | Select-Object -ExpandProperty Name
                        $Score=0
                        foreach ($item in $ScoreItemsDictionary)
                        {
                            $Score+=$apiResponse[$i].scoring.details.metadata."$item"
                        }
                        
                        $HTMLResults.AppendLine("<div class=`"card`" id=`"card`">
 <div class=`"card-container`">
  <div class=`"card-left`">
   <div class=`"card-img`" style=`"background-image: url('$($IconURL)');`"></div>
 </div>
 <div class=`"card-right`">
 <div class=`"card-content`">
 <div class=`"card-name`">$($apiResponse[$i].id)</div>       
 <div class=`"card-title`">Author: $($Author)</div>
 <div class=`"card-name`">Score: $Score</div>
 <div class=`"card-title`">$($Description)</div>
 <ul class=`"card-skills`">         
")  
                        $Tags=$apiResponse[$i].tags -split ' ' | Select-Object -First 6
                        foreach($t in $Tags){
                            $HTMLResults.Append("<li>$t</li>")    
                        }
                        $HTMLResults.AppendLine("</ul></div></div></div></div>")  
                    }
                }else{
                    $HTMLResults.AppendLine("<h2>Not Found, please check the module name and try again.</h2>")
                }
       
                $htmlResponse = $htmlResponse.Replace("<SearchResultsTemplate>",$($HTMLResults.ToString()))
            }
            $htmlResponse | Out-file "/usr/local/share/powershell/Modules/PSGalleryModuleScore/Web/search.html" -Force
           
        }
    }
    End
    {
    }
}