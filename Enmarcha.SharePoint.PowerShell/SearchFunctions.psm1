$snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

   Function SetCrawledAndManagedProperties()
    {
	Param
    (
       [Parameter(Mandatory=$true)]
        [object]$propertyMappings = $null,		      
		[Parameter(Mandatory=$true)]
        [string]$category = "ENMARCHA"
		)
	 Process
    {
	Write-Host "Iniciando el agregar los campos de búsqueda" -ForegroundColor Blue

    $searchServiceApplication= Get-SPEnterpriseSearchServiceApplication

            Write-Host "Fijando la propiedad administrada:" $propertyMappings[0].ManagedPropertyName
           $managedproperty = Get-SPEnterpriseSearchMetadataManagedProperty    -Identity $propertyMappings[0].ManagedPropertyName -SearchApplication $searchServiceApplication -ErrorAction:SilentlyContinue
            if ($managedproperty -eq $null)
            {
                Write-Host " - Creando la propiedad administrada" $propertyMappings[0].ManagedPropertyName -ForegroundColor Green
                if ($propertyMappings[0].ExcludeFromSearch -eq "true")
                {
                    $managedproperty = New-SPEnterpriseSearchMetadataManagedProperty    -Name $propertyMappings[0].ManagedPropertyName -SearchApplication $searchServiceApplication -Type $propertyMappings[0].'Type id'    -FullTextQueriable $false -Queryable $false -Retrievable $false -EnabledForScoping $true    -NameNormalized $true -Safe $true    -NoWordBreaker $true
                }
                else
                {
                    $managedproperty = New-SPEnterpriseSearchMetadataManagedProperty    -Name $propertyMappings[0].ManagedPropertyName -SearchApplication $searchServiceApplication -Type $propertyMappings[0].'Type id'    -FullTextQueriable $true -Queryable $true -Retrievable $true -EnabledForScoping $true    -NameNormalized $true -Safe $true -NoWordBreaker $true
                }
            }
                
            $crawledProperties = $managedproperty.GetMappings()
            $crawledProperties.Clear()

            foreach ($cProperty in $propertyMappings[0].'Crawled Property named'.Split("#")) {
                Write-Host "Fijando la propiedad rastreada:" $cProperty
                    # Check if crawled property exists. If not, create it.
                    $crawledproperty = Get-SPEnterpriseSearchMetadataCrawledProperty -Name $cProperty -SearchApplication $searchServiceApplication
                if (!$crawledproperty)
                {
                    $message = " - Mapping " + $cProperty + " to " + $propertyMappings[0].ManagedPropertyName
                    Write-Host $message -ForegroundColor Green
                    $crawledproperty = New-SPEnterpriseSearchMetadataCrawledProperty -SearchApplication $searchServiceApplication -Category $category -VariantType $propertyMappings[0].'variant type'    -PropSet $propertyMappings[0].'Propertyset id' -Name $cProperty -IsNameEnum $false
                    if ([boolean]::Parse($propertyMappings[0].ExcludeFromSearch) -eq $true)
                    {
                        $crawledproperty.IsMappedToContents = $false
                        $crawledproperty.update()
                    }
                }
                else {
					    Write-Host " - La propiedad rastreada" $cProperty " ya existe, creando propiedad administrada sólo." -ForegroundColor Yellow
                }

                if ($crawledproperty -is [system.array]) {
                    
                    foreach ($crawledprop in $crawledproperty) {
                        $mapping = New-SPEnterpriseSearchMetadataMapping -SearchApplication $searchServiceApplication -ManagedProperty $managedproperty -CrawledProperty $crawledprop
                        $crawledProperties.Add($mapping)
                    }

                } else {
                    $mapping = New-SPEnterpriseSearchMetadataMapping -SearchApplication $searchServiceApplication -ManagedProperty $managedproperty -CrawledProperty $crawledproperty               
                    $crawledProperties.Add($mapping)
                }
            }


            $managedproperty.SetMappings($crawledProperties)
               
            $managedproperty.HasMultipleValues = [boolean]::Parse($propertyMappings[0].'Has multiple values')
			$managedproperty.Refinable = [boolean]::Parse($propertyMappings[0].Refinable)
            $managedproperty.Sortable = [boolean]::Parse($propertyMappings[0].Sortable)
			$managedproperty.Queryable = [boolean]::Parse($propertyMappings[0].Queryable)
            $managedproperty.Retrievable = [boolean]::Parse($propertyMappings[0].Retrievable)
			$managedproperty.Searchable = [boolean]::Parse($propertyMappings[0].Searchable)
            $managedproperty.RespectPriority = $true
            $managedproperty.NoWordBreaker = $false
               
            $managedproperty.update()
           
            
           Write-Host ""
        }

		
	}
