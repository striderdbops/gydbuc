#********************************************
#****** Script Flyway Migrate Databases *****
#********************************************
param ($configFile, $sqlServerInstanceName,$workingDir) 
try {
    Import-Module powershell-yaml
    # Import functions in the Utils script.
    . $PSScriptRoot/../Utils/Utils.ps1

    $scriptName = $($MyInvocation.MyCommand.Name)
    Write-Information -Message "** Start script $scriptName **"
    $driftedVersionedDatabases = $env:driftedVersionedDatabases
    if ($driftedVersionedDatabases -gt 0) {
        Write-Error -Message "$scriptName aborted, please look at the driftreports of this date / time"
        Write-Error -Message "$driftedVersionedDatabases drifted versioned databases"
        Write-Error -Message "If the differences are out-of-scope or false-positive, redeploy this stage."
        throw "driftedVersionedDatabases found"
    }

    if ($null -eq $workingDir) { $workingDir = Join-Path $PSScriptRoot "/../../"}
    Write-Information -Message "Working directory: $workingDir"
   
    $configFilePath = Join-Path $PSScriptRoot "\..\$configFile"

    # Settings from configuration file.
    Write-Information -Message "Trying to open configuration file $configFile"

    if (!(Test-Path $configFilePath)) {
        Write-Error -Message "Config file ($configFilePath) not found" 
        if ($configFile -like "*config-manual-run*") {
            Write-Error -Message "Does config-manual-run.yaml exist? If not create one from the existing .yamls `r`nE.g. copy V3A-APP-ATS01.yaml to config-manual-run.yaml"
        }
        throw "Config file not found exception"
        
    }
    else {
        $config = Get-Content -Path $configFilePath  -ErrorAction Stop | ConvertFrom-Yaml -Ordered -ErrorAction Stop -Verbose
    } 

    Write-Information -Message "Get settings from configuration file."
    $sqlServerInstanceMachineName = $config.SqlServerInstance.MachineName
    $sqlServerInstanceUsername = $config.SqlServerInstance.Username
    $sqlServerInstancePassword = $config.SqlServerInstance.Password
    Write-Information -Message "SqlServerInstance.MachineName: $sqlServerInstanceMachineName"
    if ($pipelineRun) {
        Write-Information -Message "SqlServerInstance.UserName: ***"
        Write-Information -Message "SqlServerInstance.Password: ***"
    } else {
        Write-Information -Message "SqlServerInstance.UserName: $sqlServerInstanceUsername"
        Write-Information -Message "SqlServerInstance.Password: $sqlServerInstancePassword"
    }
  
    # This part retrieves the sqlServerInstanceName, but only for pipeline runs (so $pipelineRun = true)
    # $sqlServerInstanceName could also be specified in specific pipeline scenarios, therefore the IF has 2 conditions
    if (($null -eq $sqlServerInstanceName) -And ($pipelineRun)) {
        
        $approvalInfo = Get-ReleaseApprovalInfo -releaseId $env:RELEASE_RELEASEID -releaseEnvironmentName $env:RELEASE_ENVIRONMENTNAME
        $sqlServerInstanceName = $approvalInfo.ApproverDirectoryAlias
        $skipActions = $approvalInfo.skipActions
    }

    if (!$skipActions) {

        $instance = $config.SqlServerInstance.NamedInstances | Where-Object Name -eq $sqlServerInstanceName

        # Check if instance was found in config file.
        if ($null -eq $instance) {
            Write-Error -Message "Instance $sqlServerInstanceName was not found in configuration file."
            throw "SQL instance not found exception"
        }

        Write-Information -Message "Found instance $sqlServerInstanceName in configuration file."
        $port = $instance.Port
        Write-Information -Message "Port: $port"
            
        Write-Information -Message "Start Flyway migration for databases in configuration file."
        foreach ( $database in $config.Databases) {
            try {
                if ($pipelineRun) {
                    Write-Host "##[group]Database: $database"
                }
                Write-Information -Message "** Start Flyway migration for database $database **"
            
                $url = "jdbc:sqlserver://$($sqlServerInstanceMachineName):$port;encrypt=false;databaseName=$database;trustServerCertificate=true"

                # prepare other information for Flyway commands.
                $flywayProjectDirectory = Join-Path $workingDir $database

                if (Test-Path -Path $flywayProjectDirectory) {

                    # Parameters for Flyway command.
                    $params = 
                    'info', 
                    '-configFiles=flyway.conf',
                    "-workingDirectory=$flywayProjectDirectory",
                    "-url=$url",
                    "-user=$sqlServerInstanceUsername",
                    "-password=$sqlServerInstancePassword",
                    '-skipCheckForUpdate',
                    '-outputType=json',
                    '-teams'

                    if ($pipelineRun) {
                        Write-Information -Message "Execute Flyway info command with following parameters:"
                        $params
                    } else {
                        Write-Information -Message "Execute Flyway info command with following"
                    }

                    $flywayInfoJson = & 'flyway' @params

                    if ($null -eq $flywayInfoJson) {
                        throw "Output of Flyway info command is null."
                    }

                    $flywayInfo = $flywayInfoJson | ConvertFrom-Json -Depth 100

                    if ($null -ne $flywayInfo.error) {
                        Write-Error -Message "Flyway info command failed:"
                        $flywayInfoJson
                        throw $flywayInfo.error.message
                    }

                    if ($null -eq $flywayInfo.migrations) {
                        Write-Information -Message "No migrations found in output of Flyway info command."
                        continue 
                    }

                    $pendingMigrations = $flywayInfo.migrations | Where-Object { $_.state -eq 'Pending' }
                    if ($pendingMigrations.Count -eq 0) {
                        Write-Information -Message "No pending migrations found in output of Flyway info command."
                        continue
                    }

                    Write-Information -Message "Pending migrations found in output of Flyway info command."
                    Write-Information -Message "Showing output of Flyway info command (hiding migrations that are not pending):"
                    $flywayInfoPending = $flywayInfo
                    $flywayInfoPending.migrations = $flywayInfoPending.migrations | Where-Object { $_.state -eq 'Pending' }
                    $flywayInfoPending | ConvertTo-Json -Depth 100

                    # Parameters for Flyway command.
                    $params = 
                    'migrate', 
                    '-configFiles=flyway.conf',
                    "-workingDirectory=$flywayProjectDirectory",
                    "-url=$url",
                    "-user=$sqlServerInstanceUsername",
                    "-password=$sqlServerInstancePassword",
                    '-skipCheckForUpdate',
                    '-outputType=json',
                    '-teams'

                    if ($pipelineRun) {
                        Write-Information -Message "Execute Flyway info command with following parameters:"
                        $params
                    } else {
                        Write-Information -Message "Execute Flyway info command with following"
                    }

                    $flywayMigrateJson = & 'flyway' @params
                    $flywayMigrate = $flywayMigrateJson | ConvertFrom-Json -Depth 100
                    
                    if ($null -eq $flywayMigrate) {
                        throw "Output of Flyway migrate command is null."
                    }

                    if ($null -ne $flywayMigrate.error) {
                        Write-Error -Message "Flyway migrate command failed:"
                        $flywayMigrateJson
                        throw $flywayMigrate.error.message
                    }

                    if ($null -eq $flywayInfo.migrations) {
                        Write-Information -Message "No migrations found in output of Flyway migrate command."
                        continue 
                    }

                    Write-Information -Message "Migrations found in output of Flyway migrate command."
                    $flywayMigrateJson
                }
                else {
                    Write-Information -Message "No flyway folder found at $flywayProjectDirectory, so no migration possible."

                }
                Write-Information -Message "** Finished Flyway migration for database $database **"

            }
            catch {
                Write-Error -Message "Flyway migration failed for database $database" -WithLog $true
                $_.Exception.Message
            }
            if ($pipelineRun) {
                Write-Host "##[endgroup]"
            }
        }
    }
}
catch {
    $_
    Write-Error -Message "Script $scriptName failed." -WithLog $true
}
finally {
    Write-Information -Message "** Finished script $scriptName **"
}