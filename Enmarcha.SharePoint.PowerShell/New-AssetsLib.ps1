Param
(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [Microsoft.SharePoint.SPWeb]$Web,

	[switch]$CreateContent
)
Process
{
    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

    $currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Import-Module "$currentPath\EnmarchaFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

    [Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.UserProfiles") | Out-Null

    Write-Host -ForegroundColor Cyan "Iniciando la función New-DocLib en $Path"

    [xml]$manifest = Get-Content "$Path\manifest.xml"

    $assetTemplate = $Web.ListTemplates | ? { $_.InternalName -eq "AssetLibrary" };

    [Microsoft.SharePoint.SPList]$list = New-List -Web $Web -Template $assetTemplate -Item $manifest.List

	Get-ChildItem -Path $Path -Filter "PAGE-*" | % {
        $page = & "$currentPath\New-Page.ps1" -Path $_.FullName -Web $web
    }

	Get-ChildItem -Path $Path -Filter "DOC-*" | % {
        $page = & "$currentPath\New-Doc.ps1" -Path $_.FullName -Web $web -List $list
    }

	if ($CreateContent)
	{
		Get-ChildItem -Path $Path -Filter "PAGESAMPLE-*" | % {
			$page = & "$currentPath\New-Page.ps1" -Path $_.FullName -Web $web
		}

		Get-ChildItem -Path $Path -Filter "DOCSAMPLE-*" | % {
			$page = & "$currentPath\New-Doc.ps1" -Path $_.FullName -Web $web -List $list
		}
	}
}