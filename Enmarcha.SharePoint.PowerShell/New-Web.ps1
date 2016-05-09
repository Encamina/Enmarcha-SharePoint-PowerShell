Param
(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [string]$UrlWebApplication,

	[Parameter(Mandatory=$false)]
	[string]$ContentTypeMinVersion = $null,

	[Parameter(Mandatory=$false)]
	[string]$ContentTypeMaxVersion = $null,

    [switch]$Force,

	[Parameter(Mandatory=$false)]
    [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
)
Process
{
    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

    $currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Import-Module "$currentPath\ENMARCHAFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null
    Import-Module "$currentPath\ContentTypeXmlFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null
    Import-Module "$currentPath\SecurityXmlFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

    [xml]$manifest = Get-Content "$Path\manifest.xml"

    $url = "$UrlWebApplication$($manifest.Site.RelativeUrl)"
    
	Write-Host -ForegroundColor Yello "Listo para crear el sitio $url"

    $existingWeb = Get-SPWeb -Identity $url -ErrorAction SilentlyContinue
    if ($existingWeb -ne $null)
	{
		Write-Host -ForegroundColor Yellow "Ya existe el sitio $url"
		if ($Force.IsPresent -and ($existingWeb.ID -ne $existingWeb.Site.RootWeb.ID))
		{
			Write-Host -ForegroundColor Green "Eliminando el sitio $url..." -NoNewline
			Remove-SPWeb $url -Confirm:$false
            $existingWeb = $null			
		}
	}
    if ($existingWeb -eq $null)
    {
		Write-Host -ForegroundColor Green "Creando el sitio $url..." -NoNewline

		if ($manifest.Site.AddToQuickLaunch -eq $null -and $manifest.Site.UseParentTopNav -eq $null)
		{
			$existingWeb = New-SPWeb -Url $url -Name $manifest.Site.Name -Description $manifest.Site.Description -Template $manifest.Site.Template -Language $manifest.Site.Language
		}
		else
		{
			if ($manifest.Site.AddToQuickLaunch -eq $null)
			{
				$existingWeb = New-SPWeb -Url $url -Name $manifest.Site.Name -Description $manifest.Site.Description -Template $manifest.Site.Template -Language $manifest.Site.Language -UseParentTopNav
			}
			else
			{
				if ($manifest.Site.UseParentTopNav -eq $null)
				{
					$existingWeb = New-SPWeb -Url $url -Name $manifest.Site.Name -Description $manifest.Site.Description -Template $manifest.Site.Template -Language $manifest.Site.Language -AddToQuickLaunch
				}
				else
				{
					$existingWeb = New-SPWeb -Url $url -Name $manifest.Site.Name -Description $manifest.Site.Description -Template $manifest.Site.Template -Language $manifest.Site.Language -AddToQuickLaunch -UseParentTopNav
				}
			}
		}

		Write-Host "Hecho"
    }
    
    $manifest.Site.WebFeatures.Feature | % {
	if ($_.Id -ne$null)
	{
        Write-Host -ForegroundColor Green "Activando la característica $($_.Id)... en el sitio $url" -NoNewline
        
        $feature = Get-SPFeature -Identity $_.Id -Web $url -ErrorAction SilentlyContinue
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
    }

	if ($manifest.Site.Permissions -ne $null) {
		Modify-Permissions -Web $existingWeb -Permissions $manifest.Site.Permissions
	}

    # Aplicar master
	if (($manifest.Site.SiteMasterPage -ne $null) -and ($manifest.Site.SiteMasterPage -ne ""))
	{
		$existingWeb.CustomMasterUrl = $manifest.Site.SiteMasterPage
		$existingWeb.Update()
	}
	if (($manifest.Site.SystemMasterPage -ne $null) -and ($manifest.Site.SystemMasterPage -ne ""))
	{
		$existingWeb.MasterUrl = $manifest.Site.SystemMasterPage
		$existingWeb.Update()
	}



	if ($manifest.Site.ResultSources -ne $null)
	{
		$manifest.Site.ResultSources.ResultSource | % {
			$sortProperties = $null
			if ($_.SortProperties -ne $null)
			{
				$sortProperties = @{}
				$_.SortProperties.SortProperty | % {
					$sortProperties.Add($_.PropertyName, $_.Direction)
				}
			}
			New-WebResultSource -Web $existingWeb -Name $_.Name -Query $_.Query -SortProperties $sortProperties | Out-Null
		}
	}

	if ($manifest.Site.SearchSettings -ne $null)
	{
		$searchCenterUrl = $manifest.Site.SearchSettings.SearchCenterUrl
		$searchResultsPageUrl = $manifest.Site.SearchSettings.SearchResultsPageUrl
		if ($searchCenterUrl -ne $null)
		{
			Set-SPWebSearchCenterUrl -Web $existingWeb -SearchCenterUrl $searchCenterUrl -LogLevel $LogLevel
		}
		if ($searchResultsPageUrl -ne $null)
		{
			Set-SPWebSearchResultsPage -Web $existingWeb -SearchResultsPageUrl $searchResultsPageUrl -LogLevel $LogLevel
		}
	}
	
	if ($manifest.Site.Groups -ne $null)
	{
		if ($existingWeb.HasUniqueRoleAssignments -eq $false)
		{
			$existingWeb.BreakRoleInheritance($true)
		}

		$manifest.Site.Groups.Add | % {
			$group = $existingWeb.SiteGroups[$_.GroupName]

            $roleAssignment = $null
            try
            {
			    $roleAssignment = $existingWeb.RoleAssignments.GetAssignmentByPrincipal($group)
            }
            catch [Exception]
            {}
            $isNewRoleAssignment = $false
			if ($roleAssignment -eq $null)
			{
				$roleAssignment = New-Object Microsoft.SharePoint.SPRoleAssignment($group)
                $isNewRoleAssignment = $true
			}

            $roleDefinition = $existingWeb.RoleDefinitions[$_.PermissionLevel]

			if (-not $roleAssignment.RoleDefinitionBindings.Contains($roleDefinition))
			{
				$roleAssignment.RoleDefinitionBindings.Add($roleDefinition)
                if (-not $isNewRoleAssignment)
                {
                    $roleAssignment.Update()
                }
            }

            if ($isNewRoleAssignment -eq $true)
            {
                $existingWeb.RoleAssignments.Add($roleAssignment)
            }

		}
        $existingWeb.Update()
	}

	if ($manifest.Site.WelcomePage.Url -ne $null)
	{
	    Write-Host "Modificando la página de bienvenida"
		$rootFolder=$existingWeb.RootFolder
		$rootFolder.WelcomePage = $manifest.Site.WelcomePage.Url
		$rootFolder.Update()	    
	}

	if ($manifest.Site.SiteLogo.Url -ne $null)
	{
		Write-Host "Modificando el icono"
		$existingWeb.SiteLogoUrl = $manifest.Site.SiteLogo.Url
		$existingWeb.Update()		
	}

    ActivateLanguages -spWeb $existingWeb -manifest $manifest

    return $existingWeb
}