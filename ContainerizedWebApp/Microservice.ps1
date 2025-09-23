param(
[string[]]
$ListenerPrefix = @('http://localhost:6161/')
)

function Set-ResponseContentType {
    param(
        [Parameter(Mandatory)] [System.Net.HttpListenerResponse] $Response,
        [Parameter(Mandatory)] [string] $FilePath
    )
    $MimeTypes = @{
      '.html' = 'text/html; charset=utf-8'
      '.htm'  = 'text/html; charset=utf-8'
      '.css'  = 'text/css; charset=utf-8'
      '.js'   = 'application/javascript; charset=utf-8'
      '.json' = 'application/json; charset=utf-8'
      '.svg'  = 'image/svg+xml'
      '.svgz' = 'image/svg+xml'
      '.png'  = 'image/png'
      '.jpg'  = 'image/jpeg'
      '.jpeg' = 'image/jpeg'
      '.gif'  = 'image/gif'
      '.webp' = 'image/webp'
      '.ico'  = 'image/x-icon'
      '.woff' = 'font/woff'
      '.woff2'= 'font/woff2'
      '.ttf'  = 'font/ttf'
      '.map'  = 'application/json; charset=utf-8'
    }
    $ext = [IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    if ($MimeTypes.ContainsKey($ext)) {
        $Response.ContentType = $MimeTypes[$ext]
    } else {
        # Try framework mapping when available (PS 5.1 / .NET Framework)
        try {
            $Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping($FilePath)
        } catch {
            $Response.ContentType = 'application/octet-stream'
        }
    }

    # Good security practice; browsers won’t “sniff” a different type
    $Response.Headers['X-Content-Type-Options'] = 'nosniff'
}

# If we're running in a container and the listener prefix is not http://*:80/,
if ($env:IN_CONTAINER -and $listenerPrefix -ne 'http://*:80/') {
    # then set the listener prefix to http://*:80/ (listen to all incoming requests on port 80).
    $listenerPrefix = 'http://*:80/'
}

# If we do not have a global HttpListener object,   
if (-not $global:HttpListener) {
    # then create a new HttpListener object.
    $global:HttpListener = [Net.HttpListener]::new()
    # and add the listener prefixes.
    foreach ($prefix in $ListenerPrefix) {
        if ($global:HttpListener.Prefixes -notcontains $prefix) {
            $global:HttpListener.Prefixes.Add($prefix)
        }    
    }
}

# The WebServerJob will start the HttpListener and listen for incoming requests.
$script:WebServerJob = 
    Start-ThreadJob -Name WebServer -ScriptBlock {
        param([Net.HttpListener]$Listener)
        # Start the listener.
        try { $Listener.Start() }
        # If the listener cannot start, write a warning and return.
        catch { Write-Warning "Could not start listener: $_" ;return }
        # While the listener is running,
        while ($true) {
            # get the context of the incoming request.
            $listener.GetContextAsync() |
                . { process {
                    # by enumerating the result, we effectively 'await' the result
                    $context = $(try { $_.Result } catch { $_ })
                    # and can just return a context object
                    $context
                } }
        }    
    } -ArgumentList $global:HttpListener

# If PowerShell is exiting, close the HttpListener.
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    $global:HttpListener.Close()
}

# Keep track of the creation time of the WebServerJob.
$WebServerJob | Add-Member -MemberType NoteProperty Created -Value ([DateTime]::now) -Force
# Jobs have .Output, which in turn has a .DataAdded event.
# this allows us to have an event-driven webserver.
$subscriber = Register-ObjectEvent -InputObject $WebServerJob.Output -EventName DataAdded -Action {
    $context = $event.Sender[$event.SourceEventArgs.Index]
    # When a context is added to the output, create a new event with the context and the time.
    New-Event -SourceIdentifier HTTP.Request -MessageData ($event.MessageData + [Ordered]@{
        Context = $context        
        Time    = [DateTime]::Now
    })
} -SupportEvent -MessageData ([Ordered]@{Job = $WebServerJob})
# Add the subscriber to the WebServerJob (just in case).
$WebServerJob | Add-Member -MemberType NoteProperty OutputSubscriber -Value $subscriber -Force



# Our custom 'HTTP.Request' event will process the incoming requests.
Register-EngineEvent -SourceIdentifier HTTP.Request -Action {
    $context = $event.MessageData.Context
    # Get the request and response objects from the context.
    $request, $response = $context.Request, $context.Response
    # Do everything from here on in a try/catch block, so errors don't hurt the server.
    try {
        Import-Module PSGalleryModuleScore
        $IndexPageHTML=Get-Content $(Join-Path -Path "$PSScriptRoot\Web" -ChildPath "index.html")
        if($IndexPageHTML -match "<TableTemplate>" ){
            
            Get-PSTopModule -Top 10
        }
        
        # Forget favicons.
        if ($request.Url.LocalPath -eq '/favicon.ico') {
            $response.StatusCode = 404
            $response.Close()
            return
        }

        if ($request.Url.LocalPath -eq '/search' -and $request.HttpMethod -eq 'GET') {
            $query = $request.QueryString['query']-replace '[^a-zA-Z0-9.-]', ''

            Get-PSModuleInfo -Query $query
            $searchResultsPath = Join-Path -Path "$PSScriptRoot\Web" -ChildPath "search.html"
            $outputBuffer=[System.IO.File]::ReadAllBytes($searchResultsPath)
            $response.OutputStream.Write($outputBuffer, 0, $outputBuffer.Length)
            $response.StatusCode = 200
            $response.Close()
            return
        }

        # Handle static file serving
        $localPath = $request.Url.LocalPath.TrimStart('/')
        if ([string]::IsNullOrEmpty($localPath)) {
            
            $localPath = "index.html"  # Default to index.html if no specific file is requested
        }
        $filePath = Join-Path -Path "$PSScriptRoot\Web" -ChildPath $localPath
        
        # If the request is for the root, return home page.
        if (Test-Path $filePath) {
           $outputBuffer=[System.IO.File]::ReadAllBytes($filePath)
            Set-ResponseContentType -Response $response -FilePath $searchResultsPath
            $response.OutputStream.Write($outputBuffer, 0, $outputBuffer.Length)
            $response.StatusCode = 200
        } else {
            $response.StatusCode = 404
            $errorFilePath = Join-Path -Path "$PSScriptRoot\Web" -ChildPath "index.html#t5"
            $outputBuffer = [System.IO.File]::ReadAllBytes($errorFilePath)
            $response.OutputStream.Write($outputBuffer, 0, $outputBuffer.Length)
        }
        $response.Close()
    } catch {
        # If anything goes wrong, write a warning
        # (this will be written to the console, making it easier for an admin to see what went wrong).
        Write-Warning "Error processing request: $_"
    }    
}


# Write a message to the console that the PowerShell Gallery Stats server has started.
@{"Message" = "PowerShell Gallery Stats server started on $listenerPrefix @ $([datetime]::now.ToString('o'))"} | ConvertTo-Json | Out-Host

# Wait for the PowerShell.Exiting event.
while ($true) {
    $exiting = Wait-Event -SourceIdentifier PowerShell.Exiting -Timeout (Get-Random -Minimum 1 -Maximum 5)
    if ($exiting) {
        # If the WebServerJob is still running, stop it.
        $WebServerJob | Stop-Job
        # and break out of the loop.
        break
    }
}
