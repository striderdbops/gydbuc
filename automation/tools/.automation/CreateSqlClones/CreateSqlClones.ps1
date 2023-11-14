#*************************************
#****** Script Create SQL Clones *****
#*************************************
param ($configFile, $sqlServerInstanceName, $imageNamePrefix="") 
try {
    Import-Module powershell-yaml
    Import-Module RedGate.SqlClone.PowerShell
    Import-Module SqlServer

    # Import functions in the Utils script.
    . $PSScriptRoot/../Utils/Utils.ps1
	
    $scriptName = $($MyInvocation.MyCommand.Name)
    Write-Information -Message "** Start script $scriptName **"
	
    $configFilePath = Join-Path $PSScriptRoot "\..\$configFile"
	
    # Settings from configuration file.
    Write-Information -Message "Trying to open configuration file $configFile"
	
    if (!(Test-Path $configFilePath)) {
        Write-Error -Message "Config file ($configFilePath) not found" 
        if ($configFile -like "*config-manual-run*") {
            Write-Error -Message "Does config-manual-run.yaml exist? If not create one from the existing .yamls"
            Write-Error -Message "E.g. copy V3A-APP-ATS01.yaml to config-manual-run.yaml"
        }
        throw "Config file not found exception"
    }
    else {
        $config = Get-Content -Path $configFilePath  -ErrorAction Stop | ConvertFrom-Yaml -Ordered -ErrorAction Stop -Verbose
    } 

    Write-Information -Message "Get SqlServerInstance settings from configuration file."
    $sqlServerInstanceMachineName = $config.SqlServerInstance.MachineName
    $sqlServerInstanceUsername = $config.SqlServerInstance.Username
    $sqlServerInstancePassword = $config.SqlServerInstance.Password
    Write-Information -Message "SqlServerInstance.ServerMachineName: $sqlServerInstanceMachineName"
    if ($pipelineRun) {
        Write-Information -Message "SqlServerInstance.UserName: ***"
        Write-Information -Message "SqlServerInstance.Password: ***"
    } else {
        Write-Information -Message "SqlServerInstance.UserName: $sqlServerInstanceUsername"
        Write-Information -Message "SqlServerInstance.Password: $sqlServerInstancePassword"
    }

    # Initiate a connection with a SQL Clone Server.
    Write-Information -Message "Get SqlCloneServer settings from configuration file."

    $serverUrl = $config.SqlCloneServer.ServerUrl
    $userName = $config.SqlCloneServer.Username
    $password = ConvertTo-SecureString $config.SqlCloneServer.Password -AsPlaintext -Force
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $password -ErrorAction Stop
    Write-Information -Message "Connect-SqlClone. ServerUrl: $serverUrl Username: $username"
    $firstDeleteClone = $config.SqlServerInstance.FirstDeleteClone
    Connect-SqlClone -ServerUrl  $serverUrl -credential $credential -ErrorAction Stop -Verbose

    # Gets SQL Server instance details from a SQL Clone Server (Connect-SqlClone must be called before this cmdlet).
    $machineName = $config.SqlServerInstance.Machinename
   
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

        # Retrieve portnumber from config, this is used for connecting SQL-cmd. The DMZ has no access via the instance name, only via the port number (firewall rule)
        $port = $instance.Port
        Write-Information -Message "Port: $port"

        Write-Information -Message "Get-SqlCloneSqlServerInstance. MachineName: $machineName InstanceName: $sqlServerInstanceName"
        $sqlServerInstance = Get-SqlCloneSqlServerInstance -MachineName $machineName -InstanceName $sqlServerInstanceName -ErrorAction Stop -Verbose
        if ($null -eq $sqlServerInstance) {
            throw "Get-SqlCloneSqlServerInstance return value is null."
        }

        # Set the releasename for the extended propertie in the clone database
        if ($pipelineRun) {
            $releaseName = $env:RELEASE_RELEASENAME
        }
        else {
            # Manual runs will just get a timestamp of the date
            $dateTimestamp = Get-Date -Format yyyyMMdd
            $releaseName = "manualRun-$dateTimestamp"
        }

        Write-Information -Message "Start create SQL Clones for databases in configuration file."
        foreach ( $database in $config.Databases) {
            try {
                if ($pipelineRun) {
                    Write-Host "##[group]Database: $database"
                }
                Write-Information -Message "** Start create SQL Clone for database $database **"

                # Check the clone server if there is an active clone for the database
                $activeClone = Get-SqlClone -Name $database -Location $sqlServerInstance -ErrorAction SilentlyContinue
                if ($activeClone) {
                    # From this active clone we want to know what release (branch) triggered the clone
                    # This is stored in the extended property SQLCloneReleaseName of the database

                    $sql = "
                    SELECT value
                    FROM   sys.fn_listextendedproperty(
                                     'SQLCloneReleaseName',
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL
                                  );"
                    $datarow = $null
                        
                    Write-Information -Message "Invoke-Sqlcmd. -ServerInstance: $sqlServerInstanceMachineName Database: $database Username: $sqlServerInstanceUsername"
                    $serverInstance = $sqlServerInstanceMachineName + ",$port"
                    $datarow = Invoke-Sqlcmd -ServerInstance $serverInstance `
                        -Username $sqlServerInstanceUsername `
                        -Password $sqlServerInstancePassword `
                        -Database $database `
                        -Query $sql `
                        -ErrorAction Stop `
                        -Verbose

                    # If the EP is found, the database is renamed to <Database>_<ReleaseName>
                    # Unless the current release is the same as the already present database, then the clone is reset
                    if ($null -ne $datarow) {                  
                        $datarowSQLCloneReleaseName = $datarow['value']
                        Write-Information -Message "Found SQLCloneReleaseName: $datarowSQLCloneReleaseName"

                        if ($releaseName -eq $datarowSQLCloneReleaseName) {
                            Write-Information -Message "Existing clone of $database is the same as this release, clone will be reset."
                            Write-Information -Message "Reset-SqlClone. Database: $database" 
                            $resetOperation = Reset-SqlClone -Clone $activeClone
                            
                            Write-Information -Message "Wait-SqlCloneOperation."
                            Wait-SqlCloneOperation -Operation $resetOperation -ErrorAction Stop -Verbose 

                            Add-ExtendedPropertiesToClone -releaseName $releaseName -sqlServerInstanceMachineName $sqlServerInstanceMachineName -port $port -database $database -sqlServerInstanceUsername $sqlServerInstanceUsername -sqlServerInstancePassword $sqlServerInstancePassword 
                            continue
                        }
                        else {
                            $sqlCloneNewName = $database + "_" + $datarowSQLCloneReleaseName
                            Write-Information -Message "Existing clone will be renamed to $sqlCloneNewName"
                            Write-Information -Message "Rename-SqlClone. Database: $database" 
                            $renameOperation = Rename-SqlClone $activeClone -NewName $sqlCloneNewName
                            
                            Write-Information -Message "Wait-SqlCloneOperation."
                            Wait-SqlCloneOperation -Operation $renameOperation -ErrorAction Stop -Verbose 
                        }                  
                    }
                    else {
                        Write-Warning -Message "Unable to find SQLCloneReleaseName in EPs of database $database"    
                        # When no EP is found the clone will be deleted (old scenario)
                        switch ($firstDeleteClone) {
                            $True {
                                Write-Information -Message "Clone exist, but without a SQLCloneReleaseName and will be deleted"
                                Write-Information -Message "Remove-SqlClone. Database: $database" 
                                $deletedCloneInfo = [string]::Format(“Created on {0} from ParentImageId {1}”, $activeClone.createdDate, $activeClone.ParentImageId)
                                Write-Information -Message $deletedCloneInfo

                                $removeOperation = Remove-SqlClone $activeClone -ErrorAction Stop -Verbose
                                
                                Write-Information -Message "Wait-SqlCloneOperation."
                                Wait-SqlCloneOperation -Operation $removeOperation -ErrorAction Stop -Verbose
                            }
                            Default {
                                Write-Warning -Message "Clone exist, but will be NOT be deleted first."
                            }
                        }
                    }
                }

                # If a stashed database named <Database>_<ReleaseName> is found in as clone, this database should be renamed back to <database>
                # Else a new clone is created
                $stashedCloneDatabaseName = $database + "_" + $releaseName
                $activeRenamedClone = Get-SqlClone -Name $stashedCloneDatabaseName -Location $sqlServerInstance -ErrorAction SilentlyContinue
                if ($activeRenamedClone) {

                    Write-Information -Message "Stashed clone will be renamed to back to $database"
                    Write-Information -Message "Rename-SqlClone. Database: $database" 
                    $reRenameOperation = Rename-SqlClone $activeRenamedClone -NewName $database
                            
                    Write-Information -Message "Wait-SqlCloneOperation."
                    Wait-SqlCloneOperation -Operation $reRenameOperation -ErrorAction Stop -Verbose 
                                   
                }
                else {
                    # Select the latest version of the database image
                    $imageName = $imageNamePrefix + "$database-*"
                    Write-Information -Message "Get-SqlCloneImage. ImageName: $imageName"
                    $image = Get-SqlCloneImage -Name $imageName  -ErrorAction Stop -Verbose | Sort-Object -Property { [int]$_.Id } -Descending | Select-Object -First 1
                    if ($null -eq $image) {
                        $imageName = "$database-*"
                        Write-Information -Message "Get-SqlCloneImage. ImageName: $imageName fallback"
                        $image = Get-SqlCloneImage -Name $imageName  -ErrorAction Stop -Verbose | Sort-Object -Property { [int]$_.Id } -Descending | Select-Object -First 1
                        if ($null -eq $image) {
                            throw "Get-SqlCloneImage return value is null."
                        }
                    }

                    Write-Information -Message "New-SqlClone. Database: $database ImageName: $($image.Name)"
                    $operation = New-SqlClone -Name $database -Location $sqlServerInstance -Image $image  -ErrorAction Stop -Verbose
                    
                    Write-Information -Message "Wait-SqlCloneOperation."
                    Wait-SqlCloneOperation -Operation $operation -ErrorAction Stop -Verbose

                    Add-ExtendedPropertiesToClone -releaseName $releaseName -sqlServerInstanceMachineName $sqlServerInstanceMachineName -port $port -database $database -sqlServerInstanceUsername $sqlServerInstanceUsername -sqlServerInstancePassword $sqlServerInstancePassword 
                }

                Write-Information -Message "Finished create SQL Clone for database $database"
            }
            catch {
                Write-Error -Message "Create SQL Clone failed for database $database"  -WithLog $true
                $_
            }
            if ($pipelineRun) {
                Write-Host "##[endgroup]"
            }
        }
    }
    Write-Information -Message "** Finished script $scriptName **"
}
catch {
    Write-Error -Message "Script $scriptName failed." -WithLog $true
    $_
}