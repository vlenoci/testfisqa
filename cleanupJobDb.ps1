[CmdletBinding()]
Param(
    [parameter(Position=0)]$deletedHostname
)

# Defining global variable and load modules
$scriptName = Get-DFScript -Name
$param = Get-DFParametersSet -Type Custom -Path ".\$($scriptName).config"
$timeStamp = Get-Date -UFormat "%Y%m%d-%H%m%S"
$SqlParam = @{ QueryTimeout = 0 }
$isOk = $true
Import-Module DFrEESQLServer

#Test Parameters
Test-DFParameter -Value $param.SYSTEM.LogFolder -Required -TypeString -InitializeFolderPath -RaiseError Terminating
Test-DFParameter -Value $param.GENERAL.TalentiaJobServerName -Required -TypeString -RaiseError Terminating


#Initialize parameters variable
$jobAppServer = $param.GENERAL.TalentiaJobServerName
$jobDbName = $param.GENERAL.TalentiaJobDbName

#Initialize log
$logFile =  Join-Path $param.SYSTEM.LogFolder "cleanupJob_$env:COMPUTERNAME-$timeStamp.log"
$logId = Initialize-DFLog -LogType FILE -LogParam $logFile -LogMsg $param.SYSTEM.ToolName -LogLevel $param.SYSTEM.LogLevel -DefDisplayLevel $param.SYSTEM.LogLevel

#Start Job Queue cleanup
$jobDbo = New-DFSQLDbObject -DbInstance $jobAppServer -dbName $jobDbName # -DbUser $jobDbName -DbPwd $jobDbPwd
$jobCleanupSql = "DELETE FROM LS_JOB_QUEUE WHERE PROVIDER_URL LIKE '%$($deletedHostname)%'"

try {
    $result = $jobDbo.ExecuteSqlCmd($jobCleanupSql,$SqlParam)
}
catch {
    $ErrorMessage = $_.Exception.Message
    $ErrorID = $_.FullyQualifiedErrorID
    $message = "An error occurred cleaningup job queue: ($ErrorID). The error message was $ErrorMessage"
    Write-DFLog $logId -LogMsg $message
    $isOk = $false
}
if ($isOk) {
    $message = "The job queue for $deletedHostname has been removed from $jobDbName"
    Write-DFLog -LogId $logId -LogMsg $message
}
else {
    $message = "Something went wrong cleaning up $deletedHostname job queue on $jobDbName database"
    Write-DFLog -LogId $logId -LogMsg $message
}


if ($isOk) { 
    Stop-DFLog $logId -Result OK 
} else {
    Stop-DFLog $logId -Result FAIL 
}
