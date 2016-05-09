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

    [Microsoft.SharePoint.SPList]$list = New-List -Web $Web -TemplateType ([Microsoft.SharePoint.SPListTemplateType]::PictureLibrary) -Item $manifest.List

	$manifest.List.NintexWF.WF | % {
		if ($_.Name -ne $null -and $_.DisplayName -ne $null) {
			& "$currentPath\New-NintexWF.ps1" -UrlWebApplication $Web.Url -WFPath ($Path + "\" + $_.Name) -ListName $list.Title -WFName $_.DisplayName 
		}
	}

	if ($manifest.List.Permissions -ne $null) {
		Modify-Permissions -Web $Web -List $list -Permissions $manifest.List.Permissions
	}

    if ($manifest.List.EnableRating -in "true", "false")
    {
        $assembly = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Portal")
        $reputationHelper =$assembly.GetType("Microsoft.SharePoint.Portal.ReputationHelper")         
        [System.Reflection.BindingFlags]$flags = [System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::NonPublic
 
        if ([System.Convert]::ToBoolean($manifest.List.EnableRating))
        {
            $methodInfo = $reputationHelper.GetMethod("EnableReputation", $flags)
            $values = @($list, "Ratings", $false)
            $methodInfo.Invoke($null, @($values))
        }
        else
        {
            $methodInfo = $reputationHelper.GetMethod("DisableReputation", $flags)
            $values = @($list)
            $methodInfo.Invoke($null, @($values))
        }
    }

    if ($manifest.List.EnableRating -in "true", "false")
    {
        $list.EnableModeration = [System.Convert]::ToBoolean($manifest.List.EnableRating)
        $list.Update()
    }

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