$serverName = "localhost\bartender"
$databaseName = "TasteWhisky"
$outputDirectory = "C:\Users\Tonie\source\gydbuc\dbatools"
#$credential = Get-Credential

# Clean the folder, to spot any deletion of objects
Remove-Item -Path "$outputDirectory\*" -Recurse

# Connect to the SQL instance
$server = Connect-DbaInstance -SqlInstance $serverName -TrustServerCertificate #-SqlCredential $credential 

# Function to log message with timestamp
function Write-Log {
    param (
        [string]$Message
    )
    Write-Host "$(Get-Date -Format "HH:mm:ss"): $Message"
}

# Initialize a hashtable to store timing information
$timings = @{}

# Helper function to export and measure time for a specific object type
function Export-ObjectsOfType {
    param (
        [string]$Type,
        [System.Array]$Objects
    )

    # Ensure the output directory exists
    $outputPath = Join-Path $outputDirectory $Type
    if (-not (Test-Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    }

    $measure = Measure-Command {
        foreach ($object in $Objects) {
            if (-not $object.IsSystemObject) {
                if ($null -eq $($object.Schema)) {
                    $fileName = "$($object.Name).sql"
                }
                else {
                    $fileName = "$($object.Schema).$($object.Name).sql"
                }
                $path = Join-Path $outputPath $fileName 

                # Special handling for tables to include constraints
                if ($Type -eq "Tables") {
                    $scriptedTable = $object.Script()
                    $constraintsScripts = ($object.CheckConstraints + $object.DefaultConstraints + $object.ForeignKeys + $object.Indexes) | ForEach-Object { $_.Script() }
                    $finalScript = $scriptedTable + $constraintsScripts
                    $null = $finalScript | Out-File -FilePath $path -Force
                } else {
                    # Script the object and write to file
                    $null = $object.Script() | Out-File -FilePath $path -Force
                }
                Write-Log "Exported ($Type): $($object.Schema).$($object.Name)"
            }
        }
    }

    $timings[$Type] = $measure.TotalMilliseconds
    Write-Log "Extracting $Type took $($timings[$Type])ms"
}

# Measure and log the total time taken
$totalTime = Measure-Command {
    # Export Tables
    Export-ObjectsOfType -Type "Tables" -Objects ($server.Databases[$databaseName].Tables)

    # Export Views
    Export-ObjectsOfType -Type "Views" -Objects ($server.Databases[$databaseName].Views)
    
    # Export Stored Procedures
    Export-ObjectsOfType -Type "StoredProcedures" -Objects ($server.Databases[$databaseName].StoredProcedures)
    
    # Export User Defined Functions
    Export-ObjectsOfType -Type "UserDefinedFunctions" -Objects ($server.Databases[$databaseName].UserDefinedFunctions)

    # Export Users
    # Export-ObjectsOfType -Type "Users" -Objects ($server.Databases[$databaseName].Users)
}

Write-Log "Total extraction time: $($totalTime.TotalMilliseconds/1000) seconds"
