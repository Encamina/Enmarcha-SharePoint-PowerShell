$snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$currentPath\EnmarchaFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$currentPath\SecurityFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

Function New-SiteGroupFromXml()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$Xml,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Iniciando la función New-SiteGroupFromXml en el sitio $($Web.Url) Xml: $($Xml.OuterXml)"

        New-SiteGroup -Web $Web -Name $Xml.Name -Description $Xml.Description `
            -Owner $Xml.Owner -DefaultUser $Xml.DefaultUser `
            -LogLevel $LogLevel
    }
}

Function Import-SiteGroupsXmlFile()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        [xml]$manifest = Get-Content $Path -Encoding UTF8

        if ($manifest.SiteGroups.Add -ne $null)
        {
            $manifest.SiteGroups.Add | % {
                New-SiteGroupFromXml -Xml $_ -Web $Web -LogLevel $LogLevel | Out-Null
            }
        }
    }
}

Function Import-SiteGroupsXmlFiles()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [string]$SiteGroupMinVersion = $null,

        [Parameter(Mandatory=$false)]
        [string]$SiteGroupMaxVersion = $null,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        [string]$prefix = "SiteGroups-"
        Get-ChildItem -Path $Path -Filter "$prefix*" | Sort-Object -Property Name | % {
            [string]$version = $_.Name.Substring($prefix.Length).Split('-')[0]

            if ($SiteGroupMinVersion -eq $null -or $SiteGroupMinVersion -eq "" -or $version -ge $SiteGroupMinVersion)
            {
                if ($SiteGroupMaxVersion -eq $null -or $SiteGroupMaxVersion -eq "" -or $version -le $SiteGroupMaxVersion)
                {
                    Import-SiteGroupsXmlFile -Path $_.FullName -Web $Web -LogLevel $LogLevel
                }
            }
        }
    }
}