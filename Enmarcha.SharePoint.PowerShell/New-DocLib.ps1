Param
(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [Microsoft.SharePoint.SPWeb]$Web,

	[switch]$CreateContent,

	[switch]$OnlySchema
)
Process
{
    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

    $currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Import-Module "$currentPath\ENMARCHAFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

    [Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.UserProfiles") | Out-Null

    Write-Host -ForegroundColor Cyan "Iniciando la función New-DocLib en $Path"
	$strFileName="$Path\manifest.xml"
	If (Test-Path $strFileName){
    [xml]$manifest = Get-Content "$Path\manifest.xml"
	 [Microsoft.SharePoint.SPList]$list = $null;
	
	$list = $Web.Lists[$manifest.List.Name]
	if ($list -eq $null)
	{
		$list = New-List -Web $Web -TemplateType ([Microsoft.SharePoint.SPListTemplateType]::DocumentLibrary) -Item $manifest.List
	}

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

        $list.EnableModeration = [System.Convert]::ToBoolean($manifest.List.EnableModeration)
    }

	if ($manifest.List.EnableVersioning -in "true", "false")
    {
		$list.EnableVersioning = [System.Convert]::ToBoolean($manifest.List.EnableVersioning)
	}
	
	if ($manifest.List.EnableMinorVersions -in "true", "false")
    {
		$list.EnableMinorVersions = [System.Convert]::ToBoolean($manifest.List.EnableMinorVersions)
	}

	if ($manifest.List.ForceCheckout -in "true", "false")
    {
		$list.ForceCheckout = [System.Convert]::ToBoolean($manifest.List.ForceCheckout)
	}
	
    $list.Update()

	if ($OnlySchema)
	{
	}
	else
	{
		Get-ChildItem -Path $Path -Filter "PAGE-*" | % {
			$page = & "$currentPath\New-Page.ps1" -Path $_.FullName -Web $web
		}

		if ($list.ItemCount -eq 0){
			Get-ChildItem -Path $Path -Filter "DOC-*" | % {
				$page = & "$currentPath\New-Doc.ps1" -Path $_.FullName -Web $web -List $list
				
			}
		}

		
	}
	}
}