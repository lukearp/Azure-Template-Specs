configuration DomainControllerConfig
{
    param
    (    
        [Parameter(mandatory = $true)]
        [string]$username,
        [Parameter(Mandatory = $true)]
        [string]$password,
        [Parameter(mandatory = $true)]
        [string]$domain,
        [Parameter(mandatory = $false)]
        [string]$site = "Default-First-Site-Name"
    )
    
    Import-DscResource -ModuleName PsDesiredStateConfiguration
    node localhost
    {
        WindowsFeature ADDSInstall {
            Ensure               = 'Present'
            Name                 = 'AD-Domain-Services'
            IncludeAllSubFeature = $true
        }
    
        Script SetupDisk {
            DependsOn = "[WindowsFeature]ADDSInstall"
            GetScript  = {
                return @{'Result' = '' }
            }
            SetScript  = {
                $disk = Get-Disk -Number 2
                New-Volume -Disk $disk -FileSystem NTFS -DriveLetter F -FriendlyName "AD-Files"
            }
            TestScript = {
                return ((Get-Volume -DriveLetter F -ErrorAction SilentlyContinue) -ne $null)
            }
        }
    
        Script DCPromo {
            GetScript  = {
                return @{'Result' = '' }
            }
            SetScript  = {
                
                $securepassword = ConvertTo-SecureString -String $using:password -AsPlainText -Force
                $domainCredential = New-Object System.Management.Automation.PSCredential ($using:username, $securepassword)
                New-Item -Path "F:\NTDS" -ItemType Directory;
                New-Item -Path "F:\SYSVOL" -ItemType Directory;    
                
                Install-ADDSDomainController -SkipPreChecks -DomainName $using:domain -SafeModeAdministratorPassword $securepassword -SiteName $using:site -Credential $domainCredential -DatabasePath "F:\NTDS" -SysvolPath "F:\SYSVOL" -Confirm:$false -Force;
            }
            TestScript = {
                return ((Get-Item -Path F:\SYSVOL -ErrorAction SilentlyContinue) -ne $null)
            }
        } 
    }
}