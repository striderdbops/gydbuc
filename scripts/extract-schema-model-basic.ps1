$serverName = "localhost\bartender"
$databaseName = "TasteWhisky"
$outputDirectory = "dbatools"
#$credential = Get-Credential

# Connect to the SQL instance
$server = Connect-DbaInstance -SqlInstance $serverName -TrustServerCertificate #-SqlCredential $credential 

# Get all database objects
$allObjects = $server.Databases[$databaseName].Tables + $server.Databases[$databaseName].Views + $server.Databases[$databaseName].StoredProcedures + $server.Databases[$databaseName].UserDefinedFunctions

# Export each object to a file
foreach ($object in $allObjects) {
    if (-not $object.IsSystemObject) {
        $fileName = "$($object.Schema).$($object.Name).sql"
        $folderName = "$($object.GetType().Name)s"
        $path = Join-Path $outputDirectory $folderName $fileName 
        $null = $object.Script() | New-Item -Path $path -Force
    }
}