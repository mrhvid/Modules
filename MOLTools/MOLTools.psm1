$MOLErrorLogPreference = 'C:\MOLErrorLogging.log'
function Get-MOLSystemInfo {
<#
.SYNOPSIS
Retrives key system version and model information
.DESCRIPTION
Get-SystemInfo uses Windows Management Instrumentation (WMI) to retrive information fro one or more computers.
Sepcify computers by name or by IP addresss.
.PARAMETER ComputerName
One or more computer names or IP addresses, op to a maximum of 10.
.PARAMETER LogErrors
Spetify this switch to create a text logfile of computers that could not be queried.
.PARAMETER ErrorLog
When used with -LogErrors, specifies the file path and name to witch failed computer names will be written. 
Defaults to c:\Retry.txt.
.EXAMPLE
Get-Content names.txt | Get-MOLSystemInfo
.EXAMPLE
Get-MOLSystemInfo -ComputerName SERVER1,SERVER2
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   HelpMessage="Computer HOST name og IP address")]
        [ValidateCount(1,10)]
        [Alias('hostname')]
        [string[]]$ComputerName,

        [string]$ErrorLog = $MOLErrorLogPreference,

        [switch]$LogErrors
    )
    BEGIN{
        Write-Verbose "Error log will be $ErrorLog"
    }
    PROCESS{
        foreach ($Computer in $ComputerName) {
            Write-Verbose "Querying $Computer"
            $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Computer
            $comp = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $Computer
            $bios = Get-WmiObject -Class Win32_BIOS -ComputerName $Computer

            $props = @{'ComputerName'=$Computer;
                        'OSVersion'=$os.version;
                        'SPVersion'=$os.servicepackmajorversion;
                        'BIOSSerial'=$bios.serialnumber;
                        'Manufacturer'=$comp.manufacturer;
                        'Model'=$comp.model}
            Write-Verbose "WMI queries complete"
            $obj = New-Object -TypeName PSObject -Property $props
            $obj.PSObject.TypeNames.Insert(0,'MOL.SystemInfo')
            Write-Output $obj
        }
    }
    END{
        Write-Verbose "The script ended successfully... or something"
    }
}


function Get-MOLRemoteSmbShare
{
<#
.Synopsis
   Returns a list of shares on computer
.DESCRIPTION
   Returns a list of smb shares on computers. Requires WinRemoting enabled on remote computers.
.EXAMPLE
    Get-MOLRemoteSmbShare -CompeterName localhost
    Name                          Path                          Description                   ComputerName
    ----                          ----                          -----------                   ------------
    ADMIN$                        C:\Windows                    Remote Admin                  HVID-X230
    C$                            C:\                           Default share                 HVID-X230
    IPC$                                                        Remote IPC                    HVID-X230
    smbtest                       C:\test\smbtest                                             HVID-X230
.EXAMPLE
    Get-MOLRemoteSmbShare -CompeterName localhost -LogErrors 
    Will log errors to standard ErrorLogfile. This can be changed by -ErrorFile "C:\temp\test.log"
#>
    [CmdletBinding()]
    Param
    (
        # CompeterName
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [Alias("HostName")]
        [String[]]$ComputerName, 

        [String]$ErrorFile = $MOLErrorLogPreference,

        [Switch]$LogErrors
    )

    Begin
    {
    }
    Process
    {
        
        foreach($Computer in $ComputerName) 
        {
            Write-Verbose "Checking $Computer"
            if(Test-Connection -ComputerName $Computer -Quiet -Count 1) { 
                Write-Verbose "$Computer was online"
                
                try {
                    $Result = Invoke-Command -ComputerName $Computer -ScriptBlock { 
                                get-smbshare | select Name, Path, Description, @{n="ComputerName";e={gc Env:\COMPUTERNAME }}
                              }

                
                    Write-Output $Result | Select Name, Path, Description, ComputerName

                } catch {
                    Write-Verbose "Invoke-Command $Computer failed"

                    if($LogErrors) {
                        Write-Verbose "$Computer was online but Invoke-Command failed. Logged to $ErrorFile"
                        "$Computer was online, but Invoke-Command failed " | Out-File $ErrorFile -Append
                    }
                }
            } else {

                if($LogErrors) {
                    Write-Verbose "$Computer was not online. Logged to $ErrorFile"
                    "$Computer was offline" | Out-File $ErrorFile -Append
                } else {
                    Write-Verbose "$Computer was not online"
                }
            }
        }
    }
    End
    {
    }
}
Export-ModuleMember -Variable $MOLErrorLogPreference
Export-ModuleMember -Function Get-MOLSystemInfo,
                              Get-MOLRemoteSmbShare