Param
(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [Microsoft.SharePoint.SPWeb]$Web,

	[switch]$CreateContent,

	[switch]$RecreateListsContent,

	[switch]$OnlySchema
)
Process
{
    Write-Host -ForegroundColor Yellow "Creando la lista $Path"

    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }     
    

    $currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Import-Module "$currentPath\ENMARCHAFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

	$strFileName="$Path\manifest.xml"
	If (Test-Path $strFileName){
    [xml]$manifest = Get-Content "$Path\manifest.xml"

    [Microsoft.SharePoint.SPList]$list = New-List -Web $Web -TemplateType ([Microsoft.SharePoint.SPListTemplateType]::GenericList) -Item $manifest.List

	$manifest.List.NintexWF.WF | % {
		if ($_.Name -ne $null -and $_.DisplayName -ne $null) {
			& "$currentPath\New-NintexWF.ps1" -UrlWebApplication $Web.Url -WFPath ($Path + "\" + $_.Name) -ListName $list.Title -WFName $_.DisplayName 
		}
	}

	if ($manifest.List.Permissions -ne $null) {
		Modify-Permissions -Web $Web -List $list -Permissions $manifest.List.Permissions
	}

	if ($OnlySchema)
	{
	}
	else
	{
		if ($RecreateListsContent.IsPresent)
		{
			Clear-SPList -List $list
		}

		if ($list.ItemCount -eq 0){			
			Get-ChildItem -Path $Path -Filter "ITEM-*.xml" | % {
				$listItem = & "$currentPath\New-ListItem.ps1" -Path $_.FullName -Web $Web -List $list
			}

			if ($CreateContent)
			{
				Get-ChildItem -Path $Path -Filter "ITEMSAMPLE-*.xml" | % {
					$listItem = & "$currentPath\New-ListItem.ps1" -Path $_.FullName -Web $Web -List $list
				}
			}
		}
	}
	}
}