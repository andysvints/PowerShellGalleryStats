# Input bindings are passed in via param block.
param($InboundPSModuleDocument, $TriggerMetadata)

$List=New-Object System.Collections.Generic.List[PsObject]

$ScoringSystem=Import-CSv "/home/site/wwwroot/PSGalleryStatsScoring.csv" | Where-Object {$_.Category -eq "SourceCode"}
$updated=$false

foreach($Module in $InboundPSModuleDocument){
    if ($Module.Scoring.Details.SourceCode -eq "NaN") {
        Write-Host "Document Id: $($Module.id)"
        #1. Download nupkg
        #2. Rename to .zip
        $moduleDir="$($env:temp)/$($Module.id)"
        Invoke-WebRequest -Uri $Module.NugetPkgLink -OutFile "$moduleDir.zip"
        #3. unzip Expand-Archive
        Expand-Archive "$moduleDir.zip" -Force -DestinationPath $moduleDir
        #4. perform scoring calculations
        $SourceCodeScoring=@{}
        foreach($rule in $ScoringSystem){
            $ruleResult=Invoke-Expression -Command $rule.ScoreLogic
            if($ruleResult)
            {
                $score=0
            }else {
                $score=1
            }
            Write-Host "$($rule.Title), $($score), $($rule.ScoreLogic)"
            $SourceCodeScoring.Add($($rule.Title),$score)
        }
        ($Module.Scoring.Details.SourceCode)=$($SourceCodeScoring)
        $updated=$true
        $List.Add($Module)
        
        #5. remove zip
        Remove-Item "$moduleDir.zip" -Force
        #6. remove all downloaded files
        Remove-Item $moduleDir -Recurse -Force
    }
}
#7. update the document in DB
if($updated){
    Push-OutputBinding -Name OutboundPSModuleDocument -Value $($List|ConvertTo-Json -Depth 10)
}
