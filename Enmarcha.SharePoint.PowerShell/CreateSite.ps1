Param
(
    
    [Parameter(Mandatory=$true)]
    [string]$UrlWebApplication = $(Read-Host -Prompt "Url"),  
    [Parameter(Mandatory=$true)]  
    [string]$OwnerAlias =  $(Read-Host -Prompt "dominioOwnerAlias"),
	[Parameter(Mandatory=$true)]  
    [string]$PathWsp =  $(Read-Host -Prompt "Path Wsp"),
	[Parameter(Mandatory=$true)]  
    [string]$PathConfiguration =  $(Read-Host -Prompt "Path Configuration"),
    [switch]$Force,
	[switch]$ConfigurationRelative

)
Process
{
    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }
	

    Function Process-Folder()
    {
        Param
        (
            [Parameter(Mandatory=$true)]
            [string]$Path,

            [Parameter(Mandatory=$true)]
            [string]$UrlWebApplication
        )
        Process
        {
            Write-Host -ForegroundColor Cyan "comenzando a procesar la carpeta $Path"
            
            $web = & "$currentPath\New-Web.ps1" -Path $Path -UrlWebApplication $UrlWebApplication

            if($web -eq $null) { $web = Get-SPWeb $UrlWebApplication }

            Get-ChildItem -Path $Path -Filter "DOCLIB-*" | % {
				if ($_.BaseName -eq "DOCLIB-Paginas")
				{
					$doclib = & "$currentPath\New-DocLibPaginas.ps1" -Path $_.FullName -Web $web
				}
				else
					{
					$doclib = & "$currentPath\New-DocLib.ps1" -Path $_.FullName -Web $web
					}
            }

			Get-ChildItem -Path $Path -Filter "LIST-*" | % {
                $list = & "$currentPath\New-List.ps1" -Path $_.FullName -Web $web
            }

            Get-ChildItem -Path $Path -Filter "WEB-*" | % {
			Write-Host -ForegroundColor Green "Substio: $web"			
                Process-Folder -Path $_.FullName -UrlWebApplication $UrlWebApplication
            }
        }
    }

    cls
   $currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	
	Import-Module "$currentPath\ContentTypeXmlFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null
	Import-Module "$currentPath\TaxonomyFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null
	Import-Module "$currentPath\GroupFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null
	Import-Module "$currentPath\SearchFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null
	
    #PowerShell ISE no soporta Start-Transcript
    if($Host.Name -notmatch "ISE")
    {
        $ErrorActionPreference = "SilentlyContinue"
        Stop-Transcript | out-null
        $ErrorActionPreference = "Continue"
        Start-Transcript -path "$currentPath\last script transcript.log" -ErrorAction Continue
    }
	
	if ($ConfigurationRelative)
	{
	  $folderConfiguration= Get-ChildItem -LiteralPath $PathConfiguration
	}
	else
	{
		$folderConfiguration= {"vacio"}
	}

	Foreach($item in $folderConfiguration)
	{
		Write-Host "Iniciando la carpeta $item" -ForegroundColor Green
		if ($item -notmatch ("vacio"))
		{		
			$strFileName="$PathConfiguration/$item/Taxonomy"
		}
		else
		{			
			$strFileName="$PathConfiguration/Taxonomy"
		}
		If (Test-Path $strFileName){
			$centralAdmin = Get-SPWebApplication -IncludeCentralAdministration | Where {$_.IsAdministrationWebApplication} | Get-SPSite  
			$session = new-object Microsoft.SharePoint.Taxonomy.TaxonomySession($centralAdmin)
			$store = $session.TermStores[0]   
			Get-ChildItem -Path "$strFileName"  | Sort-Object -Property Name | % {
			$termSet = Import-Csv "$strFileName/$_" -Delimiter ";"  -Encoding Default
			ImportTermSet $store "Enmarcha" $termSet
			}
			$store.CommitAll()
		}	
		Write-Host "Finalizando la carpeta $item" -ForegroundColor Green
	}

	Foreach($item in $folderConfiguration)
	{
		Write-Host "Iniciando la carpeta $item" -ForegroundColor Green
		if ($item -notmatch ("vacio"))
		{
			$strFileName="$PathConfiguration/$item/TaxonomyCustomProperties"
		}
		else
		{
			$strFileName="$PathConfiguration/TaxonomyCustomProperties"
		}
		If (Test-Path $strFileName)
		{
			$centralAdmin = Get-SPWebApplication -IncludeCentralAdministration | Where {$_.IsAdministrationWebApplication} | Get-SPSite  
			$session = new-object Microsoft.SharePoint.Taxonomy.TaxonomySession($centralAdmin)	
			$store = $session.TermStores[0]   	
			Get-ChildItem -Path "$strFileName"  | Sort-Object -Property Name | % {
				$termSet = Import-Csv "$strFileName/$_" -Delimiter ";"  -Encoding Default
		
				Foreach($i in $termSet)
				{				
					if ( $i.CustomValues1 -ne ""){
						$customProperties = & "$currentPath\TaxonomyCustomProperties.ps1" -store $store -groupName  "Enmarcha" -termSet $i.'Term Set Name' -l1term $i.'Level 1 Term' -l2term $i.'Level 2 Term' -l3term $i.'Level 3 Term' -propertyName $i.CustomProperties1 -propertyValue $i.CustomValues1
					}
					if ( $i.CustomValues2 -ne ""){
						$customProperties = & "$currentPath\TaxonomyCustomProperties.ps1" -store $store -groupName  "Enmarcha" -termSet $i.'Term Set Name' -l1term $i.'Level 1 Term' -l2term $i.'Level 2 Term' -l3term $i.'Level 3 Term' -propertyName $i.CustomProperties2 -propertyValue $i.CustomValues2
					}
					if ( $i.CustomProperties3 -ne ""){
						$customProperties = & "$currentPath\TaxonomyCustomProperties.ps1" -store $store -groupName  "Enmarcha" -termSet $i.'Term Set Name' -l1term $i.'Level 1 Term' -l2term $i.'Level 2 Term' -l3term $i.'Level 3 Term' -propertyName $i.CustomProperties3 -propertyValue $i.CustomValues3
					}				
		
					$store.CommitAll()
				}
			}						
		}
		else
		{
			Write-Host -ForegroundColor Cyan  "No hay propiedades personalizadas de taxonomia"
		}
		Write-Host "Finalizando la carpeta $item" -ForegroundColor Green
	}
    
	$count=0;
	Foreach($item in $folderConfiguration)
	{
		if ($count -eq 0)
		{
			if ($item -notmatch ("vacio"))
			{
				$site = & "$currentPath\New-Site.ps1" -UrlWebApplication $UrlWebApplication -Path "$PathConfiguration\$item" -OwnerAlias $OwnerAlias -Force:$Force -PathWsp "$PathWsp" -PathConfiguration "$PathConfiguration\$item" -InstallWsp:$true
			}
			else
			{
				$site = & "$currentPath\New-Site.ps1" -UrlWebApplication $UrlWebApplication -Path "$PathConfiguration" -OwnerAlias $OwnerAlias -Force:$Force -PathWsp "$PathWsp" -PathConfiguration "$PathConfiguration" -InstallWsp:$true
			}
		}
		else
		{
			$site = & "$currentPath\New-Site.ps1" -UrlWebApplication $UrlWebApplication -Path "$PathConfiguration\$item" -OwnerAlias $OwnerAlias  -PathWsp "$PathWsp" -PathConfiguration "$PathConfiguration\$item" -InstallWsp:$false
		}
		$count=1;
	}


	Foreach($item in $folderConfiguration)
	{
		Write-Host "Iniciando la carpeta $item" -ForegroundColor Green	
		if ($item -notmatch ("vacio"))
		{
			$strFileName="$PathConfiguration/$item/UsersAndGroups"
		}
		else
		{
			$strFileName="$PathConfiguration/UsersAndGroups"
		}
		If (Test-Path $strFileName){			
			If (Test-Path "$strFileName/Group.csv"){
				Write-Host -ForegroundColor Cyan  "Iniciando la creación de grupos"
			Created-Group -Path $strFileName -GroupsFile  "Groups.csv" -WebSiteUrl $UrlWebApplication	
				}
			If (Test-Path "$strFileName/Users.csv"){
			Write-Host -ForegroundColor Cyan  "Grupos creados"
			$res = & "$strFileName/CreateUsers.ps1" -UsersFile  "$strFileName/Users.csv" -WebSiteUrl $UrlWebApplication	
			}
		}
		else
		{
			Write-Host -ForegroundColor Cyan  "No hay Groups ni Usuarios para crear"
		}
		Write-Host "Finalizando la carpeta $item" -ForegroundColor Green
	}

	Foreach($item in $folderConfiguration)
	{
		Write-Host "Iniciando la carpeta $item" -ForegroundColor Green	
		if ($item -notmatch ("vacio"))
		{
			Process-Folder -Path "$PathConfiguration\$item\$_" -UrlWebApplication $UrlWebApplication	
		}
		else
		{
			Process-Folder -Path "$PathConfiguration\$_" -UrlWebApplication $UrlWebApplication	
		}
		Write-Host "Finalizando la carpeta $item" -ForegroundColor Green
	}

	Foreach($item in $folderConfiguration)
	{
		Write-Host "Iniciando la carpeta $item" -ForegroundColor Green	
		if ($item -notmatch ("vacio"))
		{
			$strNavigation = "$PathConfiguration/$item/Navigation"
		}
		else
		{
			$strNavigation = "$PathConfiguration/Navigation"
		}
		If (Test-Path $strNavigation)
		{
		$bool= & "$currentPath\New-Navigation.ps1" -siteUrl $UrlWebApplication -pathConfiguration $strNavigation
		}
		else
		{
		Write-Host -ForegroundColor Blue "No hay Path de Navegación"
		}
		Write-Host "Finalizando la carpeta $item" -ForegroundColor Green
	}

	Foreach($item in $folderConfiguration)
	{
		Write-Host "Iniciando la carpeta $item" -ForegroundColor Green	
		if ($item -notmatch ("vacio"))
		{
			$strFileName="$PathConfiguration/$item/Search"
		}
		else
		{
			$strFileName="$PathConfiguration/Search"
		}
		If (Test-Path $strFileName){
			Get-ChildItem -Path "$strFileName"  | Sort-Object -Property Name | % {
				$search = Import-Csv "$strFileName/$_" -Delimiter ";"  -Encoding UTF8
				foreach ($item in $search) {	
					SetCrawledAndManagedProperties -propertyMappings $item -category "SharePoint"	
				}
			}
		}		
		Write-Host "Finalizando la carpeta $item" -ForegroundColor Green
	}

	Foreach($item in $folderConfiguration)
	{
		Write-Host "Iniciando la carpeta $item" -ForegroundColor Green		
		if ($item -notmatch ("vacio"))
		{
			$strFileName="$PathConfiguration/$item/Lookup"
		}
		else
		{
			$strFileName="$PathConfiguration/Lookup"
		}
		If (Test-Path $strFileName){
		Write-Host -ForegroundColor Cyan "Creando Lookups"
		Get-ChildItem -Path "$strFileName"  | Sort-Object -Property Name | % {
			$lookup = Import-Csv "$strFileName/$_" -Delimiter ";"  -Encoding Default			
			Foreach($item in $lookup)
			{
				Write-Host $item.SourceListName
				Create-Lookup  -parentSiteUrl "$($UrlWebApplication)$($item.siteUrl)"  -ParentListName $item.parentListName -FieldName $item.fieldName	-LookupField $item.lookupField -SourceListName $item.SourceListName -Required $item.Required -DisplayName $item.DisplayName
			}
		}
		}
		Write-Host "Finalizando la carpeta $item" -ForegroundColor Green
	}
	
	#Load SharePoint User Profile assemblies
	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server")
	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.UserProfiles")
	Foreach($item in $folderConfiguration)
	{
		Write-Host "Iniciando la carpeta $item" -ForegroundColor Green		
		if ($item -notmatch ("vacio"))
		{	
			$strFileName="$PathConfiguration/$item/UsersAndGroups"
		}
		else
		{
			$strFileName="$PathConfiguration/UsersAndGroups"
		}

		If (Test-Path $strFileName){			
			$site = Get-SPSite $UrlWebApplication	
			$userProperties = Import-Csv "$strFileName/UserProperties.csv" -Delimiter ";"  -Encoding Default
			foreach ($userP in $userProperties) {	
				Set-UserProperty -UserProperty $userP -Site $site	
			}			

		}
		Write-Host "Finalizando la carpeta $item" -ForegroundColor Green			
	}

	Foreach($item in $folderConfiguration)
	{
		Write-Host "Iniciando la carpeta $item" -ForegroundColor Green		
		if ($item -notmatch ("vacio"))
		{	
			$strFileName="$PathConfiguration/$item/NintexConstants"
		}
		else
		{
			$strFileName="$PathConfiguration/NintexConstants"
		}

		If (Test-Path $strFileName){
			#Create Nintex Constants
			[xml]$manifest = Get-Content "$strFileName\manifest.xml"

			$manifest.NintexConstants.Constant | % {
				$sensitive = $_.Sensitive
				if ($_.Sensitive -eq $null)
				{
					$sensitive = $false
				}
				$adminOnly = $_.Sensitive
				if ($_.AdminOnly -eq $null)
				{
					$adminOnly = $false
				}
				& "$currentPath\New-NintexWFConstants.ps1" -Name $_.Name -Description $_.Description -Type $_.Type -Scope $_.Scope -Value $_.Value -Url $_.Url -Sensitive $sensitive -AdminOnly $adminOnly -Username $_.Username -Password $_.Password
			}
        
		}
		Write-Host "Finalizando la carpeta $item" -ForegroundColor Green			
	}

	& "$currentPath\AdditionalEndCommands.ps1" -UrlWebApplication $UrlWebApplication

    #Apagar el Transcript a fichero
    if($Host.Name -notmatch "ISE") { Stop-Transcript -ErrorAction SilentlyContinue }
}
