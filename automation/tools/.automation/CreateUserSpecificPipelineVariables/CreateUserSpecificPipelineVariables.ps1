param ($configFile, $sqlServerInstanceName) 
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
        exit 1
    }
    else {
        $config = Get-Content -Path $configFilePath  -ErrorAction Stop | ConvertFrom-Yaml -Ordered -ErrorAction Stop -Verbose
    } 

    Write-Information -Message "Get SqlServerInstance settings from configuration file."
    $sqlServerInstanceMachineName = $config.SqlServerInstance.MachineName
    $sqlServerInstanceUsername = $config.SqlServerInstance.Username
    $sqlServerInstancePassword = $config.SqlServerInstance.Password
    Write-Information -Message "SqlServerInstance.ServerMachineName: $sqlServerInstanceMachineName"
    Write-Information -Message "SqlServerInstance.UserName: $sqlServerInstanceUsername"
    if ($pipelineRun) {
        Write-Information -Message "SqlServerInstance.Password: ***"
    } else {
        Write-Information -Message "SqlServerInstance.Password: $sqlServerInstancePassword"
    }

    # This part retrieves the sqlServerInstanceName, but only for pipeline runs (so $pipelineRun = true)
    # $sqlServerInstanceName could also be specified in specific pipeline scenarios, therefore the IF has 2 conditions
    if (($null -eq $sqlServerInstanceName) -And ($pipelineRun)) {
    
        $approvalInfo = Get-ReleaseApprovalInfo -releaseId $env:RELEASE_RELEASEID -releaseEnvironmentName $env:RELEASE_ENVIRONMENTNAME
        $sqlServerInstanceName = $approvalInfo.ApproverDirectoryAlias
        $skipActions = $approvalInfo.skipActions

        # Set variable ApproverDirectoryAlias. This variable can be read by other tasks in the release pipelines.
        # A copy files task will use variable ApproverDirectoryAlias to copy files to a user specific directory.
        # So if for example ApproverDirectoryAlias is jdoe (John Doe) then files wil be copied to user specific directory.
        Write-Information -Message "Set variable ApproverDirectoryAlias: $($approvalInfo.ApproverDirectoryAlias)"
        Write-Information "##vso[task.setvariable variable=ApproverDirectoryAlias]$sqlServerInstanceName"
    }

    if ((!$skipActions) -And ($pipelineRun)) {
        $instance = $config.SqlServerInstance.NamedInstances | Where-Object Name -eq $sqlServerInstanceName

        # Check if instance was found in config file.
        if ($null -eq $instance) {
            Write-Warning -Message "Instance $sqlServerInstanceName was not found in configuration file."
            exit
        }
        Write-Information -Message "Found instance $sqlServerInstanceName in configuration file."

        # Retrieve portnumber from config, this is used for connecting SQL-cmd. The DMZ has no access via the instance name, only via the port number (firewall rule)
        $port = $instance.Port
        Write-Information -Message "Port: $port"

        # Load the encryption Dll
        $encryptionPath = Join-Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY $env:RELEASE_PRIMARYARTIFACTSOURCEALIAS $env:BUILD_BUILDNUMBER "Modulo.Encryption.dll"
        [Reflection.Assembly]::LoadFile($encryptionPath)
        $Encryption = new-object Modulo.Encryption.EncryptionHelper

        $releaseId = $env:RELEASE_RELEASEID
        $environmentId = $env:RELEASE_ENVIRONMENTID

        $token = $env:SYSTEM_ACCESSTOKEN;
        $header = @{"Authorization" = "Bearer $token" }

        write-host -Message "Trying to Get release vars via API: $releaseId"
        $uri = "https://vsrm.dev.azure.com/ATS-Global-Products/ATS%20Modulo/_apis/Release/releases/$releaseId/environments/$environmentId" + "?api-version=6.0-preview.6"

        $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $header -UseBasicParsing
        $json = convertFrom-JSON $result.content

        $variables = @{}

        $varsToUpdate = $json.variables | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($item in $json.variables) { 
            ForEach ($varToUpdate in $varsToUpdate) {
                if ( $varToUpdate -like 'connectionString.*') {
                    $variableName = $varToUpdate 
                    $variableValue = $($item.$varToUpdate.value)

                    $serverInstance = $sqlServerInstanceMachineName + ",$port"
                    $variableValue = $variableValue.Replace('<ReleaseDataSource>', $serverInstance  )
                    $variableValue = $variableValue.Replace('<ReleaseUserId>', $sqlServerInstanceUsername )
                    $variableValue = $variableValue.Replace('<ReleasePassword>', $sqlServerInstancePassword )
                    # $variableValue = $variableValue.Replace('<ReleaseApplicationName>', $applicationName ) #local config 
                    $encryptedVariableValue = $Encryption.Encrypt($($variableValue))
    
                    $variables.Add($variableName, $encryptedVariableValue)

                    Write-Host "$variableName = $encryptedVariableValue"
                }
            }
        }
        # Add $sqlServerInstanceName to see for what sqlServerInstanceName this is encrypted
        $variables.Add('sqlServerInstanceName', $sqlServerInstanceName)

        $variables = $variables | ConvertTo-Json

        $path = Join-Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY $env:RELEASE_PRIMARYARTIFACTSOURCEALIAS $env:BUILD_BUILDNUMBER

        Write-Information -Message "The instance vars are stored in path $path"

        New-Item -Path $path -Name "instanceVariables.json" -ItemType "file" -Value $variables -Force
    }
}
catch {
    Write-Error -Message "Script $scriptName failed."     
    $_
}
finally {
    Write-Information -Message "** Finished script $scriptName **"
}
