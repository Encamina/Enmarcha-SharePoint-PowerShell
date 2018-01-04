Param
(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [string]$UrlWebApplication,

    [Parameter(Mandatory=$true)]
    [string]$OwnerAlias,

    [Parameter(Mandatory=$false)]
    [string]$ContentDb = "",

	[switch]$DeployVariations,

	[Parameter(Mandatory=$false)]
	[string]$ContentTypeMinVersion = $null,

	[Parameter(Mandatory=$false)]
	[string]$ContentTypeMaxVersion = $null,

	[Parameter(Mandatory=$true)]  
    [string]$PathWsp =  $(Read-Host -Prompt "Path Wsp"),
		[Parameter(Mandatory=$true)]  
    [string]$PathConfiguration =  $(Read-Host -Prompt "Path Configuration"),

    [switch]$Force,
	[switch]$InstallWsp
)
Process
{
    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

    $currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Import-Module "$currentPath\EnmarchaFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

    [xml]$manifest = Get-Content "$PathConfiguration\manifest.xml"

    $url = "$UrlWebApplication$($manifest.Site.RelativeUrl)"
	Write-Host -ForegroundColor Green "Creando la colección de sitios $url"

    $existingSite = Get-SPSite -Identity $url -ErrorAction SilentlyContinue
	if ($existingSite -ne $null)
	{
		Write-Host -ForegroundColor Yellow "Ya existe la colección de sitios $url"
		if ($Force.IsPresent)
		{
			Write-Host -ForegroundColor Green "Eliminando la colección de sitios $url..." -NoNewline
			Remove-SPSite $url -Confirm:$false			
		}
	}
    if (($existingSite -eq $null) -or $Force.IsPresent)
    {
		Write-Host -ForegroundColor Green "Creando la colección de sitios $url..." -NoNewline
        if($ContentDb -eq "")
        {
            $existingSite = New-SPSite -Url $url -Name $manifest.Site.Name -Description $manifest.Site.Description -Template $manifest.Site.Template -Language $manifest.Site.Language -OwnerAlias $OwnerAlias
        }
        else
        {
            $Db = Get-SPContentDatabase | Where-Object { $_.Name -eq $ContentDb }
            if($Db -eq $null)
            {
                Write-Host -ForegroundColor Red "No se encuentra la BBDD de contenido '$ContentDb'. No se puede continuar"
            }
            else
            {
                Write-Host "utilizando la base de datos de contenido" $Db.Name
                $existingSite = New-SPSite -Url $url -Name $manifest.Site.Name -Description $manifest.Site.Description -Template $manifest.Site.Template -Language $manifest.Site.Language -OwnerAlias $OwnerAlias -ContentDatabase $Db
            }
        }		
    }

	
	$spWeb = Get-SPWeb $url

	if ($manifest.Site.Audit -ne $null)
	{
		Configure-Audit -Site $spWeb.Site -Audit $manifest.Site.Audit
	}

    ActivateLanguages -spWeb $spWeb -manifest $manifest
	Import-ContentTypesXmlFiles -Path "$PathConfiguration" -ContentTypeMinVersion $ContentTypeMinVersion -ContentTypeMaxVersion $ContentTypeMaxVersion -Web $spWeb 	


	if ($InstallWsp)
	{		
		Get-ChildItem -Path "$PathWsp" -Filter "*.wsp"  | Sort-Object -Property Name | % {
		Write-Host -ForegroundColor Cyan "Activando solución $_"
		$deploySolution = & "$currentPath\Deploy-Solution.ps1" -UrlWebApplication $UrlWebApplication -Path "$PathWsp" -SolutionName "$_"  -GACDeployment -Force
	
		}
		$deployUserSolution= & "$currentPath\Deploy-UserSolution.ps1" -UrlWebApplication $UrlWebApplication -PathConfiguration $PathConfiguration		
	}

  
  $manifest.Site.SiteFeatures.Feature | % {
        Write-Host -ForegroundColor Green "Activando la característica $($_.Id)..." -NoNewline
        
        $feature = Get-SPFeature -Identity $_.Id -Site $url -ErrorAction SilentlyContinue
        if($feature -ne $null)
        {
            Write-Host -ForegroundColor Yellow "La característica ya existe " -NoNewline
			if ($_.Reinstall -ne $null -and $_.Reinstall -eq "True")
			{
				Disable-SPFeature -Identity $_.Id -Url $url -Confirm:$false
				Write-Host "Característica desactivada"
				Enable-SPFeature -Identity $_.Id -Url $url
				Write-Host "Característica activada"
			}
        }
        else
        {
            Enable-SPFeature -Identity $_.Id -Url $url
        }

    }

	$spWeb = $existingSite.OpenWeb()
	if ($manifest.Site.PropertyBags.Value -ne $null)
	{
		$manifest.Site.PropertyBags.Value | %	{		
			Write-Host "Iniciando la creación de PropertyBag de colección de sitios $($_.Key)  $($_.Val)" -ForegroundColor Blue
			$sPropertyBagKey=$($_.Key)
			$sPropertyBagValue= $($_.Val)

			if($sPropertyBagKey -ne $null)
			{
				$sPropertyBag=$spWeb.AllProperties[$sPropertyBagKey]
				if($sPropertyBag -eq "" -or $sPropertyBag -eq $null)
				{
					Write-Host "Agregando la Property Bag $sPropertyBagKey to $sPropertyBagValue !!" -ForegroundColor Green
					$spWeb.AllProperties.Add($sPropertyBagKey,$sPropertyBagValue)
	
				}
				$spWeb.Update()
				Write-Host "PropertyBags de colección de sitios creadas" -ForegroundColor Green
			}
		}
	}
	if ($manifest.Site.SiteSearchSettings -ne $null)
	{
		$searchCenterUrl = $manifest.Site.SiteSearchSettings.SearchCenterUrl
		$searchResultsPageUrl = $manifest.Site.SiteSearchSettings.SearchResultsPageUrl
		if ($searchCenterUrl -ne $null)
		{
			Set-SPSiteSearchCenterUrl -Web $spWeb -SearchCenterUrl $searchCenterUrl
		}
		if ($searchResultsPageUrl -ne $null)
		{
			Set-SPSiteSearchResultsPage -Web $spWeb -SearchResultsPageUrl $searchResultsPageUrl
		}
	}

	if ($manifest.Site.Variations -ne $null)
	{
		& "$currentPath\New-Variation.ps1" -rootWeb $spWeb -variations $manifest.Site.Variations 
	}
    
    return $existingSite
}
