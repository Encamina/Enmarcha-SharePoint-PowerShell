Param(

	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.SPWeb]$rootWeb,

	[Parameter(Mandatory=$true)]
	[System.Xml.XmlElement]$variations
)

Process{
	
    $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }  
      
	Function ConfigureVariationsSettings
	{
		Param
		(
		
			[Parameter(Mandatory=$true)]
			[Microsoft.SharePoint.SPWeb]$rootWeb,

			[Parameter(Mandatory=$true)]
			[System.Xml.XmlElement]$variations
		)

		Process
		{
				Write-Host `n "Configurando variaciones..." -ForegroundColor Green
				$guid = [Guid]$rootWeb.GetProperty("_VarRelationshipsListId");
				  $list = $rootWeb.Lists[$guid];
				$rootFolder = $list.RootFolder;
				$rootFolder.Properties["EnableAutoSpawnPropertyName"] = (Get-BoolValueOrNull $variations.EnableAutoSpawnPropertyName)
				$rootFolder.Properties["AutoSpawnStopAfterDeletePropertyName"] = (Get-BoolValueOrNull $variations.AutoSpawnStopAfterDeletePropertyName)
				$rootFolder.Properties["UpdateWebPartsPropertyName"] = (Get-BoolValueOrNull $variations.UpdateWebPartsPropertyName)
				$rootFolder.Properties["CopyResourcesPropertyName"] = (Get-BoolValueOrNull $variations.CopyResourcesPropertyName)
				$rootFolder.Properties["SendNotificationEmailPropertyName"] = (Get-BoolValueOrNull $variations.SendNotificationEmailPropertyName)
				$rootFolder.Properties["SourceVarRootWebTemplatePropertyName"] = $variations.SourceVarRootWebTemplatePropertyName
				$rootFolder.Update();
				$item = $null;
				if (($list.Items.Count -gt 0))
				{
				   $item = $list.Items[0];
				}
				else
				{
					$item = $list.Items.Add();
					$item["GroupGuid"] = new-object System.Guid("3A102CA3-6BD0-4A7B-A856-9C346483CDDB");
				}

				$item["Deleted"] = $false;
				$item["ObjectID"] = $rootWeb.ServerRelativeUrl;
				$item["ParentAreaID"] = [System.String]::Empty;
				$item.Update();
			}
	}

	Function CreateVariations
	{
		Param
		(
			[Parameter(Mandatory=$true)]
			[Microsoft.SharePoint.SPWeb]$rootWeb,

			[Parameter(Mandatory=$true)]
			[System.Xml.XmlElement]$variations
		)

		Process{

				Write-Host "Creando variaciones..." -ForegroundColor Green
				$guid = [Guid]$rootWeb.GetProperty("_VarLabelsListId")
				$list = $rootWeb.Lists[$guid];
            
				
					foreach($variation in $variations.Variation)
					{
						$var = $list.Items | where {$_.Title -eq $variation.Title}
						if($var -eq $null)
						{
							$item = $list.Items.Add()
							$item["Title"] = $variation.Title
							$item["Description"] = $variation.Description
							$item["Flag Control Display Name"] = $variation.FlagControlDisplayName
							$item["Language"] = $variation.Language
							$item["Locale"] = $variation.Locale
							$item["Hierarchy Creation Mode"] = $variation.HierarchyCreationMode
							$item["Is Source"] = (Get-BoolValueOrNull $variation.IsSource)
							$item["Hierarchy Is Created"] = $false
							$item.Update()
						}
					}
				

			}
	}


	Function CreateHierarchies
	{
		Param
		(
			[Parameter(Mandatory=$true)]
			[Microsoft.SharePoint.SPWeb]$rootWeb
		)
   
		Process
		{ 
			Write-Host "Creando jerarquias..." -ForegroundColor Green
			$id = [Guid]("e7496be8-22a8-45bf-843a-d1bd83aceb25");
			$rootWeb.Site.AddWorkItem([System.Guid]::Empty, [System.DateTime]::Now.ToUniversalTime(), $id, $rootWeb.ID, $rootWeb.Site.ID, 1, $false, [System.Guid]::Empty, [System.Guid]::Empty, $rootWeb.CurrentUser.ID, $null, [System.String]::Empty, [System.Guid]::Empty, $false);
      
			$webApplication = $rootWeb.Site.WebApplication;
			$variationsJob = $webApplication.JobDefinitions | where { $_.Name -match "VariationsCreateHierarchies" };

			$lastRun = $variationsJob.LastRunTime
			$variationsJob.RunNow();

			while ($variationsJob.LastRunTime -eq $lastRun)
			{
				Write-Host -NoNewLine .
				Start-Sleep -Seconds 2

				$variationsJob = $webApplication.JobDefinitions | where { $_.Name -match "VariationsCreateHierarchies" };
			}
			Write-Host .
			Write-Host "Job terminado." -ForegroundColor Green
		}
	}
      
    $guid = [Guid]$rootWeb.GetProperty("_VarLabelsListId");
    $list = $rootWeb.Lists[$guid];
    $createVariations = $false;
    foreach($variation in $variations.Variation)
    {
        $var = $list.Items | where {$_.Title -eq $variation.Title}
        if($var -eq $null){$createVariations = $true;}
    }

    if($createVariations){
             
        ConfigureVariationsSettings -variations $variations -rootWeb $rootWeb
      
        CreateVariations -variations $variations -rootWeb $rootWeb
      
        CreateHierarchies -rootWeb $rootWeb
    }
	else{
		Write-Host "Las variaciones ya estaban creadas..." -ForegroundColor Green
	}
}