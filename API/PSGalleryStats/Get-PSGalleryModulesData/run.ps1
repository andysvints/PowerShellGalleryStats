# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()
$HourAgo=$currentUTCtime.AddHours(-1).GetDateTimeFormats() -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}([+-]\d{2}:\d{2}|Z)?$'

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

$Datafilter="IsLatestVersion%20eq%20true%20and%20Created%20gt%20DateTime'$($HourAgo)'"
$URL="https://www.powershellgallery.com/api/v2/Packages()?`$filter=$Datafilter"
Write-Host "URL: $Url"

#region helper function(s)
function Invoke-PSGalleryModulesProcessing
{
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
    [CmdletBinding(SupportsShouldProcess=$true, 
                  ConfirmImpact='Medium')]
    [Alias()]
    Param
    (
        # PSGallery API url filtering modules to be processed
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias("URI")] 
        $URL
    )

    Begin
    {
    }
    Process
    {
        if ($pscmdlet.ShouldProcess("$URL"))
        {
            $count=1
            $PSGalleryResp=(Invoke-WebRequest -Uri $URL).Content
            $List=New-Object System.Collections.Generic.List[PsObject]
            $PSGalleryLatestModuleVersion=[System.Xml.XmlDocument]$PSGalleryResp
            $ModulesCount=$($PSGalleryLatestModuleVersion.feed.entry|Measure-Object | Select-Object -ExpandProperty count)
            Write-host "Modules published in the last hour: $ModulesCount"
            foreach($module in $($PSGalleryLatestModuleVersion.feed.entry)){
                $count++
                if($count -eq 20){
                    Start-Sleep 10
                    $count=1
                }
                Write-Host "Module Name: $($module.properties.id)"
                $doc=$($module |Select-Object @{l="id";e={$_.properties.id}}, 
                @{l="Version";e={$_.properties.Version}},
                @{l="NormalizedVersion";e={$_.properties.NormalizedVersion}},
                @{l="Authors";e={$_.properties.Authors}},
                @{l="Copyright";e={$_.properties.Copyright}},
                @{l="Created";e={$_.properties.Created."#text"}}, 
                @{l="Dependencies";e={$_.properties.Dependencies}},
                @{l="Description";e={$_.properties.Description}},
                @{l="DownloadCount";e={$_.properties.DownloadCount."#text"}},
                @{l="GalleryDetailsUrl";e={$_.properties.GalleryDetailsUrl}},
                @{l="IconUrl";e={$_.properties.IconUrl}}, 
                @{l="IsLatestVersion";e={$_.properties.IsLatestVersion."#text"}},
                @{l="IsAbsoluteLatestVersion";e={$_.properties.IsAbsoluteLatestVersion."#text"}},
                @{l="IsPrerelease";e={$_.properties.IsPrerelease."#text"}},
                @{l="Language";e={$_.properties.Language}},
                @{l="LastUpdated";e={$_.properties.LastUpdated."#text"}},
                @{l="Published";e={$_.properties.Published."#text"}},
                @{l="PackageHash";e={$_.properties.PackageHash}},
                @{l="PackageHashAlgorithm";e={$_.properties.PackageHashAlgorithm}},
                @{l="PackageSize";e={$_.properties.PackageSize."#text"}},
                @{l="ProjectUrl";e={$_.properties.ProjectUrl}},
                @{l="ReportAbuseUrl";e={$_.properties.ReportAbuseUrl}},
                @{l="ReleaseNotes";e={$_.properties.ReleaseNotes}},
                @{l="RequireLicenseAcceptance";e={$_.properties.RequireLicenseAcceptance."#text"}},
                @{l="Summary";e={$_.properties.Summary}},
                @{l="Tags";e={$_.properties.Tags}}, 
                @{l="TagsCount";e={$_.properties.Tags.split().count}},
                @{l="Title";e={$_.properties.Title}},
                @{l="VersionDownloadCount";e={$_.properties.VersionDownloadCount."#text"}},
                @{l="LicenseUrl";e={$_.properties.LicenseUrl}},
                @{l="ItemType";e={$_.properties.ItemType}},
                @{l="FileList";e={$_.properties.FileList}},
                @{l="FileCount";e={$_.properties.FileList.split('|').count}},
                @{l="GUID";e={$_.properties.GUID}},
                @{l="PowerShellVersion";e={$_.properties.PowerShellVersion}},
                @{l="DotNetFrameworkVersion";e={$_.properties.DotNetFrameworkVersion}},
                @{l="CLRVersion";e={$_.properties.CLRVersion}},
                @{l="ProcessorArchitecture";e={$_.properties.ProcessorArchitecture}},
                @{l="CompanyName";e={$_.properties.CompanyName}},
                @{l="Owners";e={$_.properties.Owners}},
                @{l="OwnersCount";e={$_.properties.Owners.split(',').count}},
                @{l="NugetPkgLink";e={$module.content.src}},
                @{l="Updated";e={$_.properties.updated}},
                @{l="Scoring";e={"NaN"}})
                #|ConvertTo-Json)
                $List.Add($doc)
            
            }

            if($PSGalleryLatestModuleVersion.feed.link.href.count -eq 2){
                Start-sleep 30
                $NextLink=$PSGalleryLatestModuleVersion.feed.link.href[-1]
                Write-Verbose "Next Link: $($NextLink)"
                $Templist=Invoke-PSGalleryModulesProcessing -Uri $NextLink
                $Templist | ForEach-Object{ $List.Add($_)}
            }
            $List | ConvertTo-Json -Depth 10
            
        }
    }
    End
    {
    }
}

#endregion
$documents=Invoke-PSGalleryModulesProcessing -URL $URL
if($null -ne $documents){
    Push-OutputBinding -Name PSModuleDocument -Value $documents
}


