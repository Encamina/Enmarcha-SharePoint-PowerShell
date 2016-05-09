$snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$currentPath\EnmarchaFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null


Function New-SiteGroup()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$true)]
        [string]$Name,

		[Parameter(Mandatory=$false)]
        [string]$Description = $null,

		[Parameter(Mandatory=$false)]
        [string]$Owner = $null,

		[Parameter(Mandatory=$false)]
        [string]$DefaultUser = $null,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
		Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Creando el grupo de sitio '$Name'..."
		$group = $Web.SiteGroups[$Name]
		if ($group -ne $null)
		{
			Write-SPHost -LogLevel $LogLevel -MessageLevel Normal "El grupo de sitio '$Name' ya existe"
		}
		else
		{
			Write-SPHost -LogLevel $LogLevel -MessageLevel Normal "Creando el grupo de sitio '$Name'..."

			[string]$desc = $Name
			if ($Description -ne "")
			{
				$desc = $Description
			}

			[Microsoft.SharePoint.SPUser]$user = $null
			if ($Owner -ne "")
			{
				$user = $Web.EnsureUser($Owner)
			}
			if ($user -eq $null)
			{
				$user = $Web.Site.Owner
				Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "fijando $($user.Name) como propietario del grupo de sitio '$Name'..."
			}

			[Microsoft.SharePoint.SPMember]$member = $null
			if ($DefaultUser -ne "")
			{
				$member = $Web.Site.Users[$DefaultUser]
				if ($member -eq $null)
				{
					$member = $Web.Site.Roles[$DefaultUser]
					if ($member -eq $null)
					{
						$member = $Web.Site.SiteGroups[$DefaultUser]
					}
					if ($member -eq $null)
					{
						Write-SPHost -LogLevel $LogLevel -MessageLevel Normal  "No se puede resolver el miembro '$DefaultUser'"
					}
				}
			}

			$Web.SiteGroups.Add($Name, $user, $member, $desc)
			$group = $Web.SiteGroups[$Name]
		}
        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "El grupo de sitio '$Name' ha sido creado"
	}
}
