# Input bindings are passed in via param block.
param($InboundPSModuleDocument, $TriggerMetadata)

$List=New-Object System.Collections.Generic.List[PsObject]

$ScoringSystem=Import-CSv "/home/site/wwwroot/PSGalleryStatsScoring.csv" | Where-Object {$_.Category -eq "Metadata"}
$updated=$false
foreach($Module in $InboundPSModuleDocument){
    if ($Module.Scoring -eq "NaN") {
        Write-Host "Document Id: $($Module.id)"
        #perform scoring calculations
        $MetadataScoring=@{}
        foreach($rule in $ScoringSystem){
            $ruleResult=Invoke-Expression -Command $rule.ScoreLogic
            if($ruleResult)
            {
                $score=1
            }else {
                $score=0
            }
            Write-Host "$($rule.Title), $($score), $($rule.ScoreLogic)"
            $MetadataScoring.Add($($rule.Title),$score)
        }
        $Scoring=@{
            "Details"=@{
                "Metadata"=$MetadataScoring
                "SourceCode"="NaN"
            }
        }
        ($Module.Scoring)=$($Scoring)
        $updated=$true
        $List.Add($Module)
    }
}
if($updated){
    Push-OutputBinding -Name OutboundPSModuleDocument -Value $($List|ConvertTo-Json -Depth 10)
}
