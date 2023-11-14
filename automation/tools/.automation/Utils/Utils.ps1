Import-Module  PSWriteColor

$agentID = $env:AGENT_ID;

if ($null -eq $agentID) {
    $pipelineRun = $false
}
else {
    $pipelineRun = $true
}

function Write-Information {
    param (
        $Message
    )
    if ($pipelineRun) {
        Write-Host $Message
    }
    else {
        Import-Module PSWriteColor
        Write-Color "[$(Get-Date) INF] ", $Message -Color Green, White
    }
}

function Write-Error {
    param (
        $Message,
        [bool] $WithLog = 0
    )
    if ($pipelineRun) {
        if ($WithLog) {
            Write-Host "##vso[task.logissue type=error]$Message"
        }
        else {
            Write-Host "##[error]$Message"
        }
    }
    else {
        Import-Module PSWriteColor
        Write-Color "[$(Get-Date) ERR] ", $Message -Color Red, White
    }
}

function Write-Warning {
    param (
        $Message,
        [bool] $WithLog = 0
    )
    if ($pipelineRun) {
        if ($WithLog) {
            Write-Host "##vso[task.logissue type=warning]$Message"
        }
        else {
            Write-Host "##[warning]$Message"
        }
    }
    else {
        Import-Module PSWriteColor
        Write-Color "[$(Get-Date) WRN] ", $Message -Color Yellow, White
    }
}

function Get-ReleaseApprovalInfo {
    param (
        $releaseId,
        $releaseEnvironmentName
    )

    $token = $env:SYSTEM_ACCESSTOKEN;
    $header = @{"Authorization" = "Bearer $token" }

    Write-Information -Message "Trying to retrieve the latest approval info of release: $releaseId"
    # Get the latest approval
    $uri = "https://vsrm.dev.azure.com/ATS-Global-Products/ATS%20Modulo/_apis/release/approvals?releaseIdsFilter=$releaseId&statusFilter=Approved&api-version=7.1-preview.3"

    $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $header -UseBasicParsing
    $json = convertFrom-JSON $result.content
    $currentReleaseEnvironment = $json.value | Where-Object { $_.releaseEnvironment.Name -eq $releaseEnvironmentName } | Select-Object -first 1
    $commentsByApprover = $currentReleaseEnvironment.comments
    $identityId = $currentReleaseEnvironment.approvedby.id

    $currentReleaseEnvironment = $json.value | Where-Object { $_.releaseEnvironment.Name -eq $releaseEnvironmentName } | Select-Object -first 1

    if ($commentsByApprover -like '*SKIP*') {
        Write-Information -Message "The approver choose to skip further actions by giving this approval comment in the release: $commentsByApprover"
        $skipActions = $true
    }
    else {
        $skipActions = $false
        Write-Information -Message "Trying to retrieve the identity object for: $identityId"
        
        # Get the identity object of the approver
        $uri = "https://vssps.dev.azure.com/ATS-Global-Products/_apis/identities?identityIds=$identityId&queryMembership=None&api-version=7.1-preview.1"
        
        $result = Invoke-WebRequest -Uri $uri -Method GET -Headers $header -UseBasicParsing
        $json = convertFrom-JSON $result.content
        $directoryAlias = $json.value.properties.DirectoryAlias.'$value'

        if ($null -eq $directoryAlias) {
            Write-Warning -Message "No valid DirectoryAlias (username) found that approved this release."
        }
        else {
            Write-Information -Message "$directoryAlias approved this release."
            $namedInstancesAlias = $config.NamedInstancesAlias | Where-Object Alias -eq $directoryAlias
            if ($null -ne $namedInstancesAlias) {
                $directoryAlias = $namedInstancesAlias.Name
                Write-Information -Message "The named instance alias $directoryAlias is used."
            }
        }
    }

    $approvalInfo = "" | Select-Object -Property SkipActions, ApproverDirectoryAlias
    $approvalInfo.SkipActions = $skipActions
    $approvalInfo.ApproverDirectoryAlias = $directoryAlias

    return $approvalInfo
}

function New-SQLCompareSnapshotCmd {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)] [string]$SnapshotPathAndFileName,
        [Parameter(Mandatory = $true, Position = 1)] [string]$TargetHost,
        [Parameter(Mandatory = $false, Position = 2)] [string]$Port,
        [Parameter(Mandatory = $true, Position = 3)] [string]$DatabaseName,
        [Parameter(Mandatory = $false, Position = 4)] [string]$User,
        [Parameter(Mandatory = $false, Position = 5)] [string]$Password,
        [Parameter(Mandatory = $false, Position = 6)] [string]$SqlCompareLicenseKey)

    try {
  
        # Build parameters to run with sql compare command line
        $params = 
        "/activateserial=$SqlCompareLicenseKey",
        "/s1:$TargetHost,$Port",
        "/db1:$DatabaseName",
        "/u1:$User",
        "/p1:$Password",
        "/makeSnapshot:$SnapshotPathAndFileName"

        &"C:\Program Files (x86)\Red Gate\SQL Compare 14\SQLCompare.exe"  @params
  
    }
    catch {
        Write-Error "Error invoking SQLCompare command line: $_"
        return $null
    }
}
function New-SQLCompareReportCmd {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)] [string]$ReportPathAndFileName,  
        [Parameter(Mandatory = $true, Position = 1)] [string]$Snapshot1PathAndFileName,
        [Parameter(Mandatory = $true, Position = 2)] [string]$Snapshot2PathAndFileName,
        [Parameter(Mandatory = $false, Position = 3)] [string]$SqlCompareLicenseKey)

    try {
  
        # Build parameters to run with sql compare command line
        $params = 
        "/activateserial=$SqlCompareLicenseKey",
        "/Snapshot1:$Snapshot1PathAndFileName",                   
        "/Snapshot2:$Snapshot2PathAndFileName" ,                  
        "/Report:$ReportPathAndFileName",                         
        '/Force',
        '/ReportType:Html',
        '/exclude:table:flyway_schema_history',
        '/exclude:table:__SchemaSnapshot',
        '/Assertidentical'
  
        &"C:\Program Files (x86)\Red Gate\SQL Compare 14\SQLCompare.exe" @params
    }
    catch {
        Write-Error "Error invoking SQLCompare command line: $_"
        return $null
    }
  
}

function Add-ExtendedPropertiesToClone {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)] [string]$releaseName,
        [Parameter(Mandatory = $true, Position = 1)] [string]$sqlServerInstanceMachineName,
        [Parameter(Mandatory = $false, Position = 2)] [string]$port,
        [Parameter(Mandatory = $true, Position = 3)] [string]$database,
        [Parameter(Mandatory = $false, Position = 4)] [string]$sqlServerInstanceUsername,
        [Parameter(Mandatory = $false, Position = 5)] [string]$sqlServerInstancePassword
    )  
    try {

        $buildRepositoryName = $env:BUILD_REPOSITORY_NAME;

        $sql = "
        IF EXISTS (
             SELECT value
             FROM   sys.fn_listextendedproperty(
                                                  'SQLCloneBuildRepositoryName',
                                                  NULL,
                                                  NULL,
                                                  NULL,
                                                  NULL,
                                                  NULL,
                                                  NULL
                                               )
          )
        BEGIN
            EXEC sys.sp_dropextendedproperty @name = N'SQLCloneDatabaseName';

            EXEC sys.sp_dropextendedproperty @name = N'SQLCloneReleaseName';

            EXEC sys.sp_dropextendedproperty @name = N'SQLCloneBuildRepositoryName';
        END;

        EXEC sys.sp_addextendedproperty
            @name = N'SQLCloneDatabaseName',
            @value = '$database';
            
        EXEC sys.sp_addextendedproperty
        @name = N'SQLCloneReleaseName',
        @value = '$releaseName';
                
        EXEC sys.sp_addextendedproperty
        @name = N'SQLCloneBuildRepositoryName',
        @value = '$buildRepositoryName';
        "
        $sqlCmdResult = $null

        Write-Information -Message "Invoke-Sqlcmd. -ServerInstance: $sqlServerInstanceMachineName Database: $database Username: $sqlServerInstanceUsername"
        $serverInstance = $sqlServerInstanceMachineName + ",$port"
        $sqlCmdResult = Invoke-Sqlcmd -ServerInstance $serverInstance `
            -Username $sqlServerInstanceUsername `
            -Password $sqlServerInstancePassword `
            -Database $database `
            -Query $sql `
            -ErrorAction Stop `
            -Verbose
        $sqlCmdResult
        if ($null -eq $sqlCmdResult) {
            Write-Information -Message "Added $database to the database as extended property SQLCloneDatabase"
            Write-Information -Message "Added $releaseName to the database as extended property SQLCloneReleaseName"
        }
        else {
            Write-Error -Message "Setting the extended properties for branch switching failed "  
            $sqlCmdResult 
        }
    }
    catch {
        Write-Error "Error Setting the extended properties for branch switching : $_"
        return $null
    }
  
}