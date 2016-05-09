Param
(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [Microsoft.SharePoint.SPWeb]$Web
)
Process
{
	Function Get-WebPartReplacedContent()
	{
		Param
		(
			[Parameter(Mandatory=$true)]
			[string]$Content,

            [Parameter(Mandatory=$true)]
            [Microsoft.SharePoint.SPWeb]$Web
		)
		Process
		{
            $sspApp = Get-DefaultEnterpriseSearchServiceApplication -Site $Web.Site

	        $fedManager = New-Object Microsoft.Office.Server.Search.Administration.Query.FederationManager($sspApp) 
	        $searchOwner = New-Object Microsoft.Office.Server.Search.Administration.SearchObjectOwner([Microsoft.Office.Server.Search.Administration.SearchObjectLevel]::SPWeb, $Web) 

            $allMatches = $Content | Select-String "{{{\w*:(?<rs>[\w\s]*)}}}" -AllMatches
            if ($allMatches.Count -gt 0)
            {
                $replacements = @{}
                $allMatches.Matches | % {
                    $value = $_.Value
                    $resultSourceName = $value.TrimStart("{").TrimEnd("}").Split(":")[1]
                
                    if (-not $replacements.ContainsKey($value))
                    {
                        $resultSource = $fedManager.GetSourceByName($resultSourceName, $searchOwner)
                        $replacements.Add($value, $resultSource.Id)
                    }
                }

                $replacements.GetEnumerator() | % {
                    $Content = $Content.Replace($_.Key, $_.Value)
                }
            }

			return $Content
		}
	}

    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

    $currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Import-Module "$currentPath\EnmarchaFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

    Write-Host -ForegroundColor Cyan "Iniciando la función New-Page en $Path"

    [xml]$manifest = Get-Content "$Path\manifest.xml"

    [Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint") | Out-Null
    [Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.PowerShell") | Out-Null
    [Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Publishing") | Out-Null
    
    $pageUrl = $manifest.PublishingPage.Url

    Write-Host ""
    Write-Host -ForegroundColor blue "Creando la página $pageUrl"

    $pubWeb = [Microsoft.SharePoint.Publishing.PublishingWeb]::GetPublishingWeb($Web)
    $pubSite = New-Object Microsoft.SharePoint.Publishing.PublishingSite($Web.Site)

    $pageLayout = $pubSite.GetPageLayouts($false) | Where { $_.Name -eq $manifest.PublishingPage.PageLayout }
    $pagesListName = $pubWeb.PagesListName

    [Microsoft.SharePoint.Publishing.PublishingPage]$page = $null
    $file = $Web.GetFile("$pagesListName/$pageUrl")
    if ($file.Exists)
    {
        Write-Host -ForegroundColor Yellow "Ya existe la página $($file.ServerRelativeUrl)"
        Write-Host -ForegroundColor Green "Obteniendo la página $($file.ServerRelativeUrl)"
        $item = $file.Item
        $page = [Microsoft.SharePoint.Publishing.PublishingPage]::GetPublishingPage($item)
        if ($page.ListItem.File.CheckOutStatus -eq [Microsoft.SharePoint.SPFile+SPCheckOutStatus]::None)
        {
            $page.CheckOut()
        }
    }
    else
    {
        Write-Host -ForegroundColor Green "Creando la página $($file.ServerRelativeUrl)..." -NoNewline
        $page = $pubWeb.AddPublishingPage($pageUrl, $pageLayout)        
    }

    Write-Host -ForegroundColor Green "Obteniendo el webpart manager..." -NoNewline
    $wpManager = $Web.GetLimitedWebPartManager($page.Url, [System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)    
    Write-Host -ForegroundColor Green "Eliminando webparts existentes..." -NoNewline
    $wps = @()
    $wpManager.WebParts | % { $wps += $_ }
    $wps | % { $wpManager.DeleteWebPart($_) }    

    if($manifest.PublishingPage.Webparts.Webpart.Count -eq 0)
    {
        Write-Host -ForegroundColor Yellow "El manifiesto de página no contiene webparts..."        
    }
    else
    {
        Write-Host -ForegroundColor Green "Añadiendo nuevos webparts..."
		$manifest.PublishingPage.WebParts.WebPart | % {
            Write-Host -ForegroundColor Green "Añadiendo webpart $($_.File)" -NoNewline		                
            [string]$webPartContent = [System.IO.File]::ReadAllText("$Path\$($_.File)")
            [string]$webPartContentReplaced = Get-WebPartReplacedContent -Content $webPartContent -Web $Web
		    [System.Xml.XmlTextReader]$xmlTextReader = New-Object System.Xml.XmlTextReader(New-Object System.IO.StringReader($webPartContentReplaced))                        
            $error = $null
            $wp = $wpManager.ImportWebPart($xmlTextReader, [ref] $error)
            $wpManager.AddWebPart($wp, $_.WebPartZoneID, $_.WebPartOrder)            
        }
		
    }

    Write-Host -ForegroundColor Green "Actualizando el tipo de contenido y diseño de página..." -NoNewline
    $listItem = $page.ListItem
    $listItem["ContentTypeId"] = (Get-SPContentTypeByName -Web $Web -LCID $manifest.PublishingPage.ContentType.LCID -Name $manifest.PublishingPage.ContentType.Name).Id
    $listItem["PublishingPageLayout"] = "$($pageLayout.ServerRelativeUrl), $($pageLayout.Title)"

    Write-Host -ForegroundColor Green "Actualizando campos de la página..." -NoNewline
    $manifest.PublishingPage.Fields.Field | % {
        Write-Host -ForegroundColor Yellow "{" $_.Name "} " -NoNewline
        Set-ListItemFieldValue -ListItem $listItem -FieldName $_.Name -Item $_ -UpdateListItem:$false
    }

    Write-Host -ForegroundColor Green "Actualizando el elemento..." -NoNewline
    $listItem.Update()

    Write-Host -ForegroundColor Green "Protegiendo el elemento..." -NoNewline
	if ($page.ListItem.File.CheckOutStatus -ne [Microsoft.SharePoint.SPFile+SPCheckOutStatus]::None)
	{
		$page.CheckIn("A través de ENMARCHA")
	}
    
    $file = $page.ListItem.File

    if ($pubWeb.PagesList.EnableVersioning -and $pubWeb.PagesList.EnableMinorVersions)
    {
        Write-Host -ForegroundColor Green "Publicando el elemento..." -NoNewline
        $file.Publish("a través de ENMARCHA")    
    }

    if ($pubWeb.PagesList.EnableModeration)
    {
        Write-Host -ForegroundColor Green "Aprobando el elemento..." -NoNewline
        $file.Approve("A través de ENMARCHA")        
    }

	if ($manifest.PublishingPage.IsDefault -eq "true")
	{
		Write-Host -ForegroundColor Green "Estableciendo como página de inicio del site..." -NoNewline
		$pubWeb.DefaultPage = $file
		$pubWeb.Update()		
	}

    return $page
}