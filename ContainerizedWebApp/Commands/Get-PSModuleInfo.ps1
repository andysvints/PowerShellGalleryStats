
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
        [switch]$ById=$false
    )
    Begin
    {
    }
    Process
    {
        if ($pscmdlet.ShouldProcess("query $Query"))
        {

            connect-AzAccount -Subscription "6e606d01-ff42-4cab-bcf2-b8888ab2fdc4" -Identity | Out-Null
            $KeyVaultName="PSGalleryStats-KV"
            $apiKey=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "PSGalleryStatsAPIKey" -AsPlainText
            ###########################################
            if($ById){
                $apiUrl = "https://psgallerystats.azure-api.net/get-psgallerystatsbyid?subscription-key=$apiKey&module=$query"
            }else{
                $apiUrl = "https://psgallerystats.azure-api.net/get-psgallerystats?subscription-key=$apiKey&module=$query"
            }
            $apiResponse = Invoke-RestMethod -Uri $apiUrl

            $HTMLTemplate=Get-Content $(Join-Path -Path "/usr/local/share/powershell/Modules/PSGalleryModuleScore/Web" -ChildPath "index.html") -Raw
            $htmlResponse = $HTMLTemplate.Replace("<QueryTemplate>","`'$Query`'")
            $HTMLResults=[System.Text.StringBuilder]::new()
            if($apiResponse){
                #Get recommendations dictionary
                #TODO: get recommendations from Blob Storage
                $RecommendationDictionary=Import-Csv -Path "/usr/local/share/powershell/Modules/PSGalleryModuleScore/PSGalleryStatsScoring.csv"
                for ($i = 0; $i -lt $apiResponse.Count; $i++)
                {   
                    $RecommendationList=New-Object System.Collections.Generic.List[PSObject]
                    $IconURL=if(-not $apiResponse[$i].IconURL){"/Assets/PowerShellChevron.svg"}else{$apiResponse[$i].IconURL}
                    $Author=if($apiResponse[$i].Owners -like "*,*"){$apiResponse[$i].Owners.split(',')[0]}else{$apiResponse[$i].Owners}
                    $Description=if($apiResponse[$i].Description.Length -gt 64){$apiResponse[$i].Description.substring(0,61)+"..."}else{$apiResponse[$i].Description}
                    $LicenseHTMLString=if($apiResponse[$i].LicenseUrl){"<p><strong>License:</strong> <a href=`"$($apiResponse[$i].LicenseUrl)`" target=`"_blank`">$($apiResponse[$i].LicenseUrl)</a></p>"}else{"<p><strong>License:</strong>NaN</p>"}
                    $ProjectURLHTMLString=if($apiResponse[$i].ProjectUrl){"<p><strong>Project URL:</strong> <a href=`"$($apiResponse[$i].ProjectUrl)`" target=`"_blank`">$($apiResponse[$i].ProjectUrl)</a></p>"}else{"<p><strong>Project URL:</strong>NaN</p>"}
                    $Downloads=switch ($($apiResponse[$i].DownloadCount))
                    {
                        #Millions
                        {$_/1000000 -gt 1} {
                            "$([System.Math]::Truncate($_/1000000))M+"
                            break
                        }
                        #Thousands
                        {$_/1000 -gt 1} {
                            "$([System.Math]::Truncate($_/1000))k+"
                            break
                        }
                        Default {$_}
                    }
                    $ScoringCategories=$apiResponse[$i].scoring.details | Get-Member|Where-Object {$_.MemberType -eq "NoteProperty"} | Select-Object -ExpandProperty Name
                    $ScoreItemsDictionary=$ScoringCategories | foreach-object {$apiResponse[$i].Scoring.Details.$($_)| Get-Member|Where-Object {$_.MemberType -eq "NoteProperty"} | Select-Object -ExpandProperty Name }
                    
                    $Score=$apiResponse[$i].cp_TotalScore
                    foreach ($item in $ScoreItemsDictionary)
                    {
                        #Form recomendation collection here
                        if($apiResponse[$i].scoring.details.metadata."$item" -eq 0){
                            $RecommendationList.Add($($RecommendationDictionary | Where-Object {$_.title -eq "$item"} | Select-Object Recommendation,SuggestedTools))
                        }
                        if($apiResponse[$i].scoring.details.sourcecode."$item" -eq 0){
                            $RecommendationList.Add($($RecommendationDictionary | Where-Object {$_.title -eq "$item"} | Select-Object Recommendation,SuggestedTools))
                        }

                    }
                    
                   $null = $HTMLResults.AppendLine("<div class=`"card`" id=`"card`">
 <div class=`"card-container`">
  <div class=`"card-left`">
   <div class=`"card-img`" style=`"background-image: url('$($IconURL)');`"></div>
 </div>
 <div class=`"card-right`">
 <div class=`"card-content`">
 <div class=`"card-name`">$($apiResponse[$i].id)</div>
 ")
  if($apiResponse[$i].Scoring.Details.SourceCode.ScriptSecurity="0"){
     $null=$HTMLResults.AppendLine("<li class=`"fa fa-exclamation-triangle`" style=`"color: orange;`"></li>")
 }
 $null = $HTMLResults.AppendLine("<div class=`"card-title`">Author: $($Author)</div>
 <div class=`"card-name`">Score: $Score/100</div>
 <div class=`"card-title`">$($Description)</div>
 <ul class=`"card-skills`">         
")  
                        $Tags=$apiResponse[$i].tags -split ' ' | Select-Object -First 6
                        foreach($t in $Tags){
                            $null =$HTMLResults.Append("<li>$t</li>")    
                        }
                        $null =$HTMLResults.AppendLine("</ul></div></div></div>")
                        $null =$HTMLResults.AppendLine("<div class=`"card-expanded`">
<p><strong>Description:</strong> $($apiResponse[$i].Description) </p>
                    <p><strong>Version:</strong> $($apiResponse[$i].Version)</p>
                    <p><strong>Download Count:</strong> $Downloads</p>
                    <p><strong>Last Published:</strong>$($apiResponse[$i].Published)</p>
                    $LicenseHTMLString
                    <p><strong>Company Name:</strong> $($apiResponse[$i].CompanyName)</p>
                    $ProjectURLHTMLString
                    <p><strong>More Details:</strong> <a href=`"$($apiResponse[$i].GalleryDetailsUrl)`" target=`"_blank`">PowerShell Gallery</a></p>
")
                        if($RecommendationList){
                            $null =$HTMLResults.AppendLine("<p><strong>Recommendations:</strong><ul>")
                            foreach($r in $RecommendationList){
                                $null =$HTMLResults.AppendLine("<li>$($r.Recommendation)")
                                if($r.SuggestedTools){
                                    $SuggestedTool=$r.SuggestedTools -split ";"
                                    $null =$HTMLResults.AppendLine(" (<a href=`"$($SuggestedTool[1])`" target=`"_blank`">$($SuggestedTool[0])</a>)")
                                }
                                $null =$HTMLResults.AppendLine("</li>")
                            }
                            $null =$HTMLResults.AppendLine("</ul></p>")
                        }else{
                            $null =$HTMLResults.AppendLine("<p><strong>Recommendations:</strong> Nothing to add here. You are doing great!</p>")   
                        }
                        $null =$HTMLResults.AppendLine("</div></div>")  
                    }
                }else{
                    $null =$HTMLResults.AppendLine("<h2>Not Found, please check the module name and try again.</h2>")
                }
       
                $htmlResponse = $htmlResponse.Replace("<SearchResultsTemplate>",$($HTMLResults.ToString()))
                $targetUrl =  "/search?query=$query#t4"
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
