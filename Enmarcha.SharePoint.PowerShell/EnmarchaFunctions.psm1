
if (-not ("SPLogLevel" -as [type]))
{
    Add-Type -TypeDefinition @"

       public enum SPLogLevel
       {
          Normal,
          Verbose
       }
"@
}

[SPLogLevel]$Global:_logLevel = [SPLogLevel]::Normal

Function Set-SPLogLevel()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [SPLogLevel]$LogLevel
    )
    Process
	{
		$Global:_logLevel = $LogLevel
	}
}

Function Get-BoolValueOrNull()
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$Value = $null
    )
    Process
    {
        if ($Value -eq $null -or $Value -eq "") { return $null }
        return ([System.Convert]::ToBoolean($Value))
    }
}

Function Get-IntValueOrNull()
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$Value = $null
    )
    Process
    {
        if ($Value -eq $null -or $Value -eq "") { return $null }
        return ([System.Convert]::ToInt32($Value))
    }
}

Function Set-ListItemFieldValue()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPListItem]$ListItem,

        [Parameter(Mandatory=$true)]
        [string]$FieldName,

        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$Item,

        [switch]$UpdateListItem
    )
    Process
    {
        [Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Taxonomy") | Out-Null
        [Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Publishing") | Out-Null

        [Microsoft.SharePoint.SPWeb]$web = $ListItem.Web

        switch ($Item.Type)
        {
            "TaxonomyFieldType" {
                <#
                    Si el campo no es multievaluado:
                    <Field Name="name" Type="TaxonomyFieldType">
                        <Term>nombre término<Term>
                    </Field>

                    Si el campo es multievaluado:
                    <Field Name="name" Type="TaxonomyFieldType">
                        <Terms>
                            <Term>nombre término 1<Term>
                            <Term>nombre término 2<Term>
                            <Term>nombre término 3<Term>
                        </Terms>
                    </Field>
                #>
                [Microsoft.SharePoint.Taxonomy.TaxonomyField]$field = $ListItem.Fields[$FieldName] -as [Microsoft.SharePoint.Taxonomy.TaxonomyField]

                $session = Get-SPTaxonomySession -Site $web.Site
                $termStore = $session.TermStores[$field.SspId]     
                $termSet = $termStore.GetTermSet($field.TermSetId)

                if ($field.AllowMultipleValues)
                {
                    [Microsoft.SharePoint.Taxonomy.TaxonomyFieldValueCollection]$taxCollection = New-Object Microsoft.SharePoint.Taxonomy.TaxonomyFieldValueCollection($field)

                    $Item.Terms.Term | % {
                        Set-Variable -Name term -Value ($termSet.GetTerms($_.Trim(), $true) | Select-Object -First 1)
                        Set-Variable -Name taxValue -Value (New-Object Microsoft.SharePoint.Taxonomy.TaxonomyFieldValue($field))

                        $taxValue.TermGuid = $term.Id.ToString()
                        $taxValue.Label = $term.Name

                        $taxCollection.Add($taxValue)
                    }
                    $field.SetFieldValue($ListItem, $taxCollection)
                }
                else
                {
                    $termToAdd = $Item.Term | Select-Object -First 1 

                    Set-Variable -Name term -Value ($termSet.GetTerms($termToAdd, $true) | Select-Object -First 1)
                    Set-Variable -Name taxValue -Value (New-Object Microsoft.SharePoint.Taxonomy.TaxonomyFieldValue($field))

                    $taxValue.TermGuid = $term.Id.ToString()
                    $taxValue.Label = $term.Name

                    $field.SetFieldValue($ListItem, $taxValue)
                }
            }
            "User" {
                <#
                    <Field Name="name" Type="User">
                        DOMAIN\user
                    </Field>
                #>
                [Microsoft.SharePoint.SPUser]$user = $web.EnsureUser($Item.InnerText.Trim())
                $ListItem[$FieldName] = $user
            }
            "Image" {
                <#
                    <Field Name="name" Type="Image">
                        /Fototeca/PublishingImages/a.jpg
                    </Field>
                #>
                $imgValue = $ListItem[$FieldName]
                if ($imgValue -eq $null)
                {
                    Set-Variable -Name imgValue -Value (New-Object Microsoft.SharePoint.Publishing.Fields.ImageFieldValue)
                }
                $imgValue.ImageUrl = $Item.InnerText.Trim()

                $ListItem[$FieldName] = $imgValue.ToString()
                
            }
            "URL" {
                <#
                    <Field Name="name" Type="URL">
                        <RelativeUrl>/Fototeca/PublishingImages/a.jpg</RelativeUrl>
                        <Description>descripcion</Description>
                    </Field>
                #>
                $ListItem[$FieldName] = "$($web.Site.WebApplication.Url.TrimEnd('/'))$($Item.RelativeUrl), $($Item.RelativeUrl)"
            }
            default {
                $ListItem[$FieldName] = $Item.InnerText.Trim()
            }
        }

        if ($UpdateListItem.IsPresent)
        {
            $ListItem.Update()
        }
    }
}

Function New-List()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

        [Parameter(Mandatory=$true, ParameterSetName="TemplateType")]
        [Microsoft.SharePoint.SPListTemplateType]$TemplateType,

		[Parameter(Mandatory=$true, ParameterSetName="Template")]
        [Microsoft.SharePoint.SPListTemplate]$Template,

        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$Item,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal,

        [switch]$Force
    )
    Process
    {
        $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
        if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

        #necesario para el update de propiedades de lista
        [int]$lcidThread = [System.Threading.Thread]::CurrentThread.CurrentUICulture.LCID
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo([int]$Web.Language)


        # Obtenemos la librería para ver si xiste
        $list = $Web.Lists[$Item.Name]
        if ($list -ne $null)
        {
            if ($Force.IsPresent)
            {
                $Web.Lists.Delete($list.ID)
            }
        }

        $list = $Web.Lists[$Item.Name]
        if ($list -eq $null)
        {
            # Creamos la lista
			switch ($PsCmdlet.ParameterSetName)
			{
				"TemplateType" { $listId = $Web.Lists.Add($Item.Url, $Item.Description, $TemplateType); break }
				"Template" { $listId = $Web.Lists.Add($Item.Url, $Item.Description, $Template); break }
			}
            $list = $Web.Lists[$listId]
        }

        # Actualizamos el nombre y la descripción
        $list.Title = $Item.Name
        $list.Description = $Item.Description

		# Fijamos la visibilidad en la navegación actual
		$list.OnQuickLaunch = (Get-BoolValueOrNull $Item.OnQuickLaunch)

        # Activamos el uso de content types
        $list.ContentTypesEnabled = $true
        $list.Update()

        [System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($lcidThread)


        # Añadimos los content types
        if($item.ContentTypes -ne $null)
        {
            [string]$newDefaultContentTypeName = ""
            $Item.ContentTypes.ContentType | % {
                $ct = Get-SPContentTypeByName -Web $Web -LCID $_.LCID -Name $_.Name

                $existingContentType = $list.ContentTypes | ? { $_.Id.Parent -eq $ct.Id}
                if ($existingContentType -eq $null)
                {
                    $list.ContentTypes.Add($ct) | Out-Null
                }
                $existingContentType = $list.ContentTypes | ? { $_.Id.Parent -eq $ct.Id}

                if ($newDefaultContentTypeName -eq "")
                {
                    [Microsoft.SharePoint.SPContentTypeId]$newDefaultContentTypeId = $existingContentType.Id
                    $newDefaultContentTypeName = $existingContentType.Name
                }
            }

            # Obtenemos la carpeta raíz y la colección de content types que se muestra en el "new"
            $folder = $list.RootFolder
            $cts = $folder.ContentTypeOrder

            # Guardamos el que ahora se muestra como default
            [Microsoft.SharePoint.SPContentTypeId]$defaultContentTypeId = $cts[0].Id

            # Si el nuevo default es distinto del actual, lo cambiamos
            if ($defaultContentTypeId -ne $newDefaultContentTypeId)
            {
                # Obtenemos el que va a ser el nuevo default
                $newDefaultContentType = $cts | ? { $_.Id -eq $newDefaultContentTypeId }

                # Ponemos en la primera posicion el que va a ser el nuevo default
                if ($newDefaultContentType -eq $null)
                {
                    # Si no se obtiene el nuevo CT de $cts es porque no está para mostrarse en el "new", así que se obtiene de los CTs de la lista 
                    $newDefaultContentType = $list.ContentTypes | ? { $_.Id -eq $newDefaultContentTypeId}
                }
                else
                {
                    # Si está, lo eliminamos antes de añadirlo en la primera posición
                    $i = $cts.IndexOf($newDefaultContentType)
                    $cts.RemoveAt($i)
                }
                $cts.Insert(0, $newDefaultContentType)
                $folder.UniqueContentTypeOrder = $cts
                $folder.Update()
            }

            # Eliminamos los content types que no vengan en el manifest
            $contentTypesToDelete = @()
            $list.ContentTypes | %  {
                $currentCt = $_
                [bool]$existingContentTypeInManifest = $false

                <#
                $Item.ContentTypes.ContentType | % {
                    if ($existingContentTypeInManifest -eq $false)
                    {
                        [int]$lcid = $_.LCID
                        $name = $_.Name
                        $localizedName = Get-SPContentTypeLocalizedName -ContentType $currentCt -LCID $lcid

                        $localizedNameInXml = ""
                        $ctInXml = $Web.AvailableContentTypes | ? { $_.Name -eq $name }
                        if ($ctInXml -ne $null)
                        {
                            $localizedNameInXml = Get-SPContentTypeLocalizedName -ContentType $ctInXml -LCID $lcid
                        }

                        $existingContentTypeInManifest = ($localizedName -eq $localizedNameInXml)
                    }
                }
                #>
                
                $Item.ContentTypes.ContentType.LCID | % {
                    if ($existingContentTypeInManifest -eq $false)
                    {
                        [int]$lcid = $_
                        # Buscamos el nombre del padre porque currentCt contiene el CT de la lista, que es hijo del CT del sitio. El CT
                        # del sitio sí está multi-idiomado, pero el de la lista solo tiene el idioma default del sitio
                        $localizedName = Get-SPContentTypeLocalizedName -ContentType $currentCt.Parent -LCID $lcid
                        $existingContentTypeInManifest = ($Item.ContentTypes.ContentType | ? { $_.LCID -eq $lcid -and $_.Name -eq $localizedName }) -ne $null
                    }
                }
                
                if ($existingContentTypeInManifest -eq $false)
                {
                    $contentTypesToDelete += $currentCt.Id
                }
            }
            <#
            [int]$lcidThread = [System.Threading.Thread]::CurrentThread.CurrentUICulture.LCID
			[System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo(1033)
			$contentTypesToDelete = @()
            $list.ContentTypes | %  {
                $contentTypeName = $_.Name
                $contentTypeId = $_.Id
                $existingContentTypeInManifest = $Item.ContentTypes.ContentType | ? { $_.Name -eq $contentTypeName }
                if ($existingContentTypeInManifest -eq $null)
                {
                    $contentTypesToDelete += $contentTypeId
                }
            }
	        [System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($lcidThread)
            #>

            $contentTypesToDelete | % {
                $list.ContentTypes.Delete($_)
            }

            <#
            Bug detectado: cuando se añade un tipo de contenido que contiene campos de tipo MultiLineText, el atributo RichText
            no se propaga desde la columna de sitio al campo del content type de la librería. Con este trozo del script se
            actualiza el campo
            #>
            [array]$fieldsToUpdate = $list.Fields | ? { $_.GetType().Name -eq "SPFieldMultiLineText" }
            $fieldsToUpdate | % {
                $fieldId = $_.Id
                
                $siteField = $list.ParentWeb.Site.RootWeb.Fields | ? { $_.Id -eq $fieldId }
                if ($siteField -ne $null)
                {
                    Write-Host -ForegroundColor Yellow "Actualizando campo $($_.Title) del tipo de contenido $ctName"
                    $_.RichText = $siteField.RichText
                    $_.Update()
                }
                
            }
        }
		# Ocultamos los campos si fuera necesario (marcados en el manifest como <Hide><Column InternalName="InternalNameDelCampo"/></Hide>)
		$list = $Web.Lists[$Item.Name]	
		$cols = $Item.Hide.Column

		if($cols.Length -gt 0)
		{
			$list.ContentTypes | % {
				$ct = $_
                $ctName = $_.Name

				$cols | % { 
				    $fieldName = $_.InternalName

					Write-Host -ForegroundColor Green "Ocultando campo $fieldName en $ctName..." -NoNewline
					$field = $ct.FieldLinks[$fieldName]

					# Si existe, lo ocultamos
					if($field){
						$field.Hidden = $true
                        $ct.Update()	
						Write-Host "Hecho"
					}
				}
			}
		}
        $list.Update()

		# Ordenamos los campos si fuera necesario (marcados en el manifest como <ContentType><Column InternalName="InternalNameDelCampo"/></ContentType>)
        $list = $Web.Lists[$Item.Name]	
		$fields = @()
		$Item.ContentTypes.ContentType | % { 
            $fields += $_.Column.InternalName 
            if($fields.Length -gt 0)
            {
				$ctName = $_.Name
                $ct = $list.ContentTypes | ? { $_.Name -eq $ctName }
                if($ct)
                {
					Write-Host -ForegroundColor Green "Ordenando los campos de $ctName..." -NoNewline
                    $ct.FieldLinks.Reorder($fields)
                    $ct.Update()
					Write-Host "Hecho"
                }
            }
        }
        $list.Update()

		if ($Item.Views -ne $null)
		{
			$Item.Views.View | % {
				[array]$fieldsToShow = @()
                $_.Fields.Field.InternalName | % { $fieldsToShow += $_ }
				New-SPView -List $list -ViewName $_.Name -FieldsToShow $fieldsToShow -CAMLQuery $_.Query.InnerText.Trim() -LogLevel $LogLevel -IsDefaultView (Get-BoolValueOrNull $_.IsDefaultView) | Out-Null
			}
		}

        if ($Item.EnableRating -in "true", "false")
        {
            $assembly = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Portal")
            $reputationHelper = $assembly.GetType("Microsoft.SharePoint.Portal.ReputationHelper")
 
            #$bindings = @("EnableReputation", "NonPublic", "Static")
            [System.Reflection.BindingFlags]$flags = [System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::NonPublic
 
            if ([System.Convert]::ToBoolean($Item.EnableRating))
            {
                $methodInfo = $reputationHelper.GetMethod("EnableReputation", $flags)
                $values = @($list, "Ratings", $false)
                $methodInfo.Invoke($null, @($values)) | Out-Null
            }
            else
            {
                $methodInfo = $reputationHelper.GetMethod("DisableReputation", $flags)
                $values = @($list)
                $methodInfo.Invoke($null, @($values)) | Out-Null
            }
        }

        if ($Item.EnableModeration -in "true", "false")
        {
            $list.EnableModeration = [System.Convert]::ToBoolean($Item.EnableModeration)
            $list.Update()
        }

        if ($Item.EnableVersioning -in "true", "false")
        {
            $list.EnableVersioning = [System.Convert]::ToBoolean($Item.EnableVersioning)
            $list.Update()
        }

        if ($Item.EnableMinorVersions -in "true", "false")
        {
            $list.EnableMinorVersions = [System.Convert]::ToBoolean($Item.EnableMinorVersions)
            $list.Update()
        }

        if ($Item.ForceCheckout -in "true", "false")
        {
            $list.ForceCheckout = [System.Convert]::ToBoolean($Item.ForceCheckout)
            $list.Update()
        }

        if ($Item.MajorVersionLimit -ne $null)
        {
            $list.MajorVersionLimit = [System.Convert]::ToInt32($Item.MajorVersionLimit)
            $list.Update()
        }

        if ($Item.MajorWithMinorVersionsLimit -ne $null)
        {
            $list.MajorWithMinorVersionsLimit = [System.Convert]::ToInt32($Item.MajorWithMinorVersionsLimit)
            $list.Update()
        }

        if ($Item.ItemLevelPermissionRead -in "AllItems", "ItemsCreatedByUser")
        {

            switch ($Item.ItemLevelPermissionRead)
			{
			    "AllItems" { $list.ReadSecurity = 1; break }
				"ItemsCreatedByUser" { $list.ReadSecurity = 2; break }
			}
            $list.Update()
        }

        if ($Item.ItemLevelPermissionWrite -in "CreateAndEditAll", "CreateAllAndEditCreatedByUser", "None")
        {

            switch ($Item.ItemLevelPermissionWrite)
			{
			    "CreateAndEditAll" { $list.WriteSecurity = 1; break }
			    "CreateAllAndEditCreatedByUser" { $list.WriteSecurity = 2; break }
			    "None" { $list.WriteSecurity = 4; break }
			}
            $list.Update()
        }

		if ($Item.DraftVersionVisibility -in "Reader", "Author", "Approver")
		{
			switch ($Item.DraftVersionVisibility)
			{
			    "Reader" { $list.DraftVersionVisibility = 0; break }
				"Author" { $list.DraftVersionVisibility = 1; break }
				"Approver" { $list.DraftVersionVisibility = 2; break }
			}
            $list.Update()
		}

        if ($Item.EnableAssignToEmail -in "true", "false")
        {
            $list.EnableAssignToEmail = [System.Convert]::ToBoolean($Item.EnableAssignToEmail)
            $list.Update()
        }

		if ($Item.BreakRoleInheritance -in "None", "CopyParent")
		{
			$list.BreakRoleInheritance($Item.BreakRoleInheritance -eq "CopyParent")
			$list.Update()
		}

		if ($Item.Groups -ne $null)
		{
			if ($list.HasUniqueRoleAssignments -eq $true)
			{
				$list.ResetRoleInheritance()
			}
			if ($Item.Groups.BreakRoleInheritance -eq $null -or $Item.Groups.BreakRoleInheritance -eq "CopyParent")
			{
				$list.BreakRoleInheritance($true)
			}
			else
			{
				$list.BreakRoleInheritance($false)
			}

			$Item.Groups.Add | % {
				$web = $list.ParentWeb
				$group = $web.SiteGroups[$_.GroupName]

                $roleAssignment = $null
				try
				{
					$roleAssignment = $list.RoleAssignments.GetAssignmentByPrincipal($group)
				}
				catch [Exception]
				{}
                $isNewRoleAssignment = $false
				if ($roleAssignment -eq $null)
				{
					$roleAssignment = New-Object Microsoft.SharePoint.SPRoleAssignment($group)
                    $isNewRoleAssignment = $true
				}

                $roleDefinition = $web.RoleDefinitions[$_.PermissionLevel]

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
                    $list.RoleAssignments.Add($roleAssignment)
                }

			}
            $list.Update()
		}
		return $list
    }
}

Function Clear-ManagedMetadataTermSet()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPSite]$Site,

        [Parameter(Mandatory=$true)]
        [string]$ManagedMetadataName,

        [Parameter(Mandatory=$true)]
        [System.Guid]$TermSetId
    )
    Process
    {
        $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
        if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }


		$session = Get-SPTaxonomySession -Site $Site
		if ($session -eq $null)
		{
			return $false
		}        
		$termStore = $session.TermStores[0]
		if ($termStore -eq $null)
		{
			return $false
		}
        $termSet = $termStore.GetTermSet($TermSetId)
		if ($termSet -eq $null)
		{
			return $false
		}

		$termset.Terms | % { $_.Delete() }
		$termStore.CommitAll()
    }
}

Function New-ManagedProperty()
{
	Param
	(
		[Parameter(Mandatory=$true)]
		[string]$SearchServiceApplicationName,

		[Parameter(Mandatory=$true)]
		[string]$Name,

		[Parameter(Mandatory=$true)]
		[string]$ManagedType,
		<#
		Type:
			1 = Text 
			2 = Integer 
			3 = Decimal 
			4 = DateTime 
			5 = YesNo 
			6 = Binary 
			7 = Double 
		#>

		[Parameter(Mandatory=$false)]
		$Description = $null,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$Retrievable,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$RespectPriority,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$RemoveDuplicates,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$NoWordBreaker,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$NameNormalized,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$FullTextQueriable,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$EnabledForScoping,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$Refinable = $null,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$Queryable = $null,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$Sortable = $null,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$HasMultipleValues = $null,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$OverrideValueOfHasMultipleValues = $null,

		[Parameter(Mandatory=$false)]
		[nullable[bool]]$SafeForAnonymous = $null,

		[Parameter(Mandatory=$false)]
		[array]$CrawledPropertyNames
	)
	Process
	{
		$types = @{"Text" = 1; "Integer" = 2; "Decimal" = 3; "DateTime" = 4; "YesNo" = 5; "Binary" = 6; "Double" = 7 }
		$type = $types[$ManagedType]
			
		$managedProp = Get-SPEnterpriseSearchMetadataManagedProperty -SearchApplication $SearchServiceApplicationName -Identity $Name -ErrorAction SilentlyContinue
		if ($managedProp -eq $null)
		{
			$managedProp = New-SPEnterpriseSearchMetadataManagedProperty -SearchApplication $SearchServiceApplicationName -Name $Name -Type $type
		}


        if ($Description -ne $null) { $managedProp.Description = $Description }
        if ($Retrievable -ne $null) { $managedProp.Retrievable = $Retrievable }
        if ($RespectPriority -ne $null) { $managedProp.RespectPriority = $RespectPriority }
        if ($RemoveDuplicates -ne $null) { $managedProp.RemoveDuplicates = $RemoveDuplicates }
        if ($NoWordBreaker -ne $null) { $managedProp.NoWordBreaker = $NoWordBreaker }
        if ($NameNormalized -ne $null) { $managedProp.NameNormalized = $NameNormalized }
        if ($FullTextQueriable -ne $null) { $managedProp.FullTextQueriable = $FullTextQueriable }
        if ($EnabledForScoping -ne $null) { $managedProp.EnabledForScoping = $EnabledForScoping }
        if ($Refinable -ne $null) { $managedProp.Refinable = $Refinable }
        if ($Queryable -ne $null) { $managedProp.Queryable = $Queryable }
        if ($Sortable -ne $null) { $managedProp.Sortable = $Sortable }
        if ($HasMultipleValues -ne $null) { $managedProp.HasMultipleValues = $HasMultipleValues }
        if ($OverrideValueOfHasMultipleValues -ne $null) { $managedProp.OverrideValueOfHasMultipleValues = $OverrideValueOfHasMultipleValues }
        if ($SafeForAnonymous -ne $null) { $managedProp.SafeForAnonymous = $SafeForAnonymous }
        $managedProp.Update()
    
		if ($CrawledPropertyNames -ne $null)
		{
			Get-SPEnterpriseSearchMetadataMapping -SearchApplication $SearchServiceApplicationName -ManagedProperty $Name | Remove-SPEnterpriseSearchMetadataMapping -Confirm:$false

			$CrawledPropertyNames | % {
				$crawledProp = Get-SPEnterpriseSearchMetadataCrawledProperty -SearchApplication $SearchServiceApplicationName -Name $_ -ErrorAction SilentlyContinue
				if ($crawledProp -eq $null)
				{
					$category = Get-SPEnterpriseSearchMetadataCategory -SearchApplication $SearchServiceApplicationName -Identity "SharePoint"
					$crawledProp = New-SPEnterpriseSearchMetadataCrawledProperty -SearchApplication $SearchServiceApplicationName -Name $_ `
						-Category $category -PropSet "158d7563-aeff-4dbf-bf16-4a1445f0366c" -IsNameEnum $false -VariantType 0
				}
				New-SPEnterpriseSearchMetadataMapping -SearchApplication $SearchServiceApplicationName -ManagedProperty $managedProp -CrawledProperty $crawledProp | Out-Null
			}
		}

		return $managedProp
	}
}

Function Set-VariationsSettings()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPSite]$Site,

		[Parameter(Mandatory=$true)]
		[bool]$SiteListPageCreationEverywhere,
		
		[Parameter(Mandatory=$true)]
		[bool]$RecreateDeletedTargetPage,
		
		[Parameter(Mandatory=$true)]
		[bool]$UpdateTargetPageWebparts,
		
		[Parameter(Mandatory=$true)]
		[bool]$CopyResources,
		
		[Parameter(Mandatory=$true)]
		[bool]$SendNotificationEmail,
		
		[Parameter(Mandatory=$true)]
		[string]$SourceVarRootWebTemplate
    )
    Process
    {
		$web = $Site.RootWeb

		[Guid]$varRelationshipsListId = $web.GetProperty("_VarRelationshipsListId")

		$varRelationshipsList = $web.Lists[$varRelationshipsListId]

		$varRelationshipsList.RootFolder.Properties["EnableAutoSpawnPropertyName"] = $SiteListPageCreationEverywhere.ToString()
		$varRelationshipsList.RootFolder.Properties["AutoSpawnStopAfterDeletePropertyName"] = (-not $RecreateDeletedTargetPage).ToString()
		$varRelationshipsList.RootFolder.Properties["UpdateWebPartsPropertyName"] = $UpdateTargetPageWebparts.ToString()
		$varRelationshipsList.RootFolder.Properties["CopyResourcesPropertyName"] = $CopyResources.ToString()
		$varRelationshipsList.RootFolder.Properties["SendNotificationEmailPropertyName"] = $SendNotificationEmail.ToString()
		$varRelationshipsList.RootFolder.Properties["SourceVarRootWebTemplatePropertyName"] = $SourceVarRootWebTemplate
		$varRelationshipsList.RootFolder.Update()

		if ($varRelationshipsList.Items.Count -gt 0)
		{
			$item = $varRelationshipsList.Items[0]
		}
		else
		{
			$item = $varRelationshipsList.Items.Add()
			$item["GroupGuid"] = New-Object System.Guid("F68A02C8-2DCC-4894-B67D-BBAED5A066F9")
		}

		$item["Deleted"] = $false
		$item["ObjectID"] = $Web.ServerRelativeUrl
		$item["ParentAreaID"] = [System.String]::Empty
		$item.Update()
	}
}

Function Set-VariationsLabels()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPSite]$Site,

		[Parameter(Mandatory=$true)]
		[array]$Labels
    )
    Process
    {
		$web = $Site.RootWeb

		[Guid]$varLabelsListId = $web.GetProperty("_VarLabelsListId")

		$varLabelsList = $web.Lists[$varLabelsListId]

		$Labels | % {
			$item = $varLabelsList.Items.Add()
			$item["Title"] = $_.Title
			$item["Description"] = $_.Description
			$item["Flag Control Display Name"] = $_.FlagControlDisplayName
			$item["Language"] = $_.Language
			$item["Locale"] = $_.Locale
			$item["Hierarchy Creation Mode"] = $_.HierarchyCreationMode
			$item["Is Source"] = $_.IsSource
			$item["Hierarchy Is Created"] = $_.HierarchyIsCreated
			$item.Update()
		}
	}
}

Function Start-CreateHierarchiesJob()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPSite]$Site
    )
    Process
    {
		[Guid]$id = "e7496be8-22a8-45bf-843a-d1bd83aceb25"

		$site.AddWorkItem([System.Guid]::Empty, [System.DateTime]::Now.ToUniversalTime(), $id, $Site.RootWeb.ID, $Site.ID, -1, $false,
						  [System.Guid]::Empty, [System.Guid]::Empty, ($Site.RootWeb.AllUsers | ? { $_.UserLogin -eq "SHAREPOINT\system" }).ID, $null,
						  "2", [System.Guid]::Empty, $false)

		$webApp = $Site.WebApplication
		Get-SPTimerJob –WebApplication $webApp | Where-Object { $_.Name -match "VariationsCreateHierarchies" } | Start-SPTimerJob 
	}
}

Function Get-DefaultEnterpriseSearchServiceApplication()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPSite]$Site
    )
	Process
    {
		$webApp = $Site.WebApplication

        $proxies = $webapp.ServiceApplicationProxyGroup.DefaultProxies

        # Por algún problema con el Enumerator, hay que recorrerse la colección una vez para luego poder recuperar bien los valores
        $proxies | % {}
        
        $proxy = $proxies | ? { $_.TypeName -eq "Search Service Application Proxy"} | Select-Object -First 1

		$ssp = Get-SPEnterpriseSearchServiceApplication -Identity $proxy.GetSearchApplicationName()

		return $ssp
	}
}

Function Get-DefaultManagedMetadataServiceApplication()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPSite]$Site
    )
	Process
    {
		
		$centralAdmin = Get-SPWebApplication -IncludeCentralAdministration | Where {$_.IsAdministrationWebApplication} | Get-SPSite  
	    $session = new-object Microsoft.SharePoint.Taxonomy.TaxonomySession($centralAdmin)
		$serviceApp = Get-SPServiceApplication | Where {$_.TypeName -like "*Metadata*"}  
		return $serviceApp	
	}
}

Function New-WebResultSource()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$true)]
		[string]$Name,

		[Parameter(Mandatory=$true)]
		[string]$Query,

		[Parameter(Mandatory=$false)]
		[hashtable]$SortProperties,

		[switch]$Force
    )
	Process
    {
		$sspApp = Get-DefaultEnterpriseSearchServiceApplication -Site $Web.Site

		$fedManager = New-Object Microsoft.Office.Server.Search.Administration.Query.FederationManager($sspApp) 
		$searchOwner = New-Object Microsoft.Office.Server.Search.Administration.SearchObjectOwner([Microsoft.Office.Server.Search.Administration.SearchObjectLevel]::SPWeb, $Web) 

		$resultSource = $fedManager.GetSourceByName($Name, $searchOwner)

		if ($resultSource -ne $null)
		{
			if ($Force.IsPresent)
			{
				$fedManager.RemoveSource($resultSource)
				$resultSource = $null
			}
		}

		$queryProperties = New-Object Microsoft.Office.Server.Search.Query.Rules.QueryTransformProperties

		if (($SortProperties -ne $null) -and ($SortProperties.Count -gt 0))
		{
			$sortCollection = New-Object Microsoft.Office.Server.Search.Query.SortCollection
			$SortProperties.GetEnumerator() | % {
				$sortCollection.Add($_.Key, [Microsoft.Office.Server.Search.Query.SortDirection]$_.Value)
			}
			$queryProperties["SortList"] = [Microsoft.Office.Server.Search.Query.SortCollection]$sortCollection
		}

        if ($resultSource -eq $null)
        {
		    $resultSource = $fedManager.CreateSource($searchOwner)
		    $resultSource.Name = $Name
	        $resultSource.ProviderId = $fedManager.ListProviders()['Local SharePoint Provider'].Id
		}
		$resultSource.CreateQueryTransform($queryProperties, $Query) | Out-Null
		$resultSource.Commit()

		return $resultSource
	}
}

Function New-SiteResultSource()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPSite]$Site,

		[Parameter(Mandatory=$true)]
		[string]$Name,

		[Parameter(Mandatory=$true)]
		[string]$Query,

		[Parameter(Mandatory=$false)]
		[hashtable]$SortProperties,

		[switch]$Force
    )
	Process
    {
		$sspApp = Get-DefaultEnterpriseSearchServiceApplication -Site $Site

		$fedManager = New-Object Microsoft.Office.Server.Search.Administration.Query.FederationManager($sspApp) 
		$searchOwner = Get-SPEnterpriseSearchOwner -Level SPSite -SPWeb $Site.RootWeb

		$resultSource = $fedManager.GetSourceByName($Name, $searchOwner)

		if ($resultSource -ne $null)
		{
			if ($Force.IsPresent)
			{
				$fedManager.RemoveSource($resultSource)
				$resultSource = $null
			}
		}

		$queryProperties = New-Object Microsoft.Office.Server.Search.Query.Rules.QueryTransformProperties

		if (($SortProperties -ne $null) -and ($SortProperties.Count -gt 0))
		{
			$sortCollection = New-Object Microsoft.Office.Server.Search.Query.SortCollection
			$SortProperties.GetEnumerator() | % {
				$sortCollection.Add($_.Key, [Microsoft.Office.Server.Search.Query.SortDirection]$_.Value)
			}
			$queryProperties["SortList"] = [Microsoft.Office.Server.Search.Query.SortCollection]$sortCollection
		}

        if ($resultSource -eq $null)
        {
		    $resultSource = $fedManager.CreateSource($searchOwner)
		    $resultSource.Name = $Name
	        $resultSource.ProviderId = $fedManager.ListProviders()['Local SharePoint Provider'].Id
		}
		$resultSource.CreateQueryTransform($queryProperties, $Query) | Out-Null
		$resultSource.Commit()

		return $resultSource
	}
}

Function Import-SPFolder()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$UrlWebApplication,

        [Parameter(Mandatory=$true)]
        [array]$ExcludedPaths,

        [switch]$CreateContent,

        [switch]$Force
    )
	Process
    {
        Write-Host -ForegroundColor Cyan "Iniciando la función Import-SPFolder en $Path"

        $currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
        $web = & "$currentPath\New-Web.ps1" -Path $Path -UrlWebApplication $UrlWebApplication

        Get-ChildItem -Path $Path -Filter "DOCLIB-*" | % {
            if (-not $ExcludedPaths.Contains($_.FullName))
            {
                $doclib = & "$currentPath\New-DocLib.ps1" -Path $_.FullName -Web $web
            }
        }

		Get-ChildItem -Path $Path -Filter "LIST-*" | % {
            if (-not $ExcludedPaths.Contains($_.FullName))
            {
                $list = & "$currentPath\New-List.ps1" -Path $_.FullName -Web $web
            }
        }

        Get-ChildItem -Path $Path -Filter "WEB-*" | % {
            if (-not $ExcludedPaths.Contains($_.FullName))
            {
                Import-SPFolder -Path $_.FullName -UrlWebApplication $UrlWebApplication -ExcludedPaths $ExcludedPaths -CreateContent:$CreateContent -Force:$Force
            }
        }
    }
}

Function Get-SPContentTypeLocalizedName()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPContentType]$ContentType,

        [Parameter(Mandatory=$true)]
        [int]$LCID
    )
	Process
	{
        [int]$lcidThread = [System.Threading.Thread]::CurrentThread.CurrentUICulture.LCID
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($LCID)

        [string]$localizedName = $ContentType.Name

        [System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($lcidThread)

		return $localizedName
	}
}

Function Get-SPContentTypeByName()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

        [Parameter(Mandatory=$true)]
        [int]$LCID,

        [Parameter(Mandatory=$true)]
        [string]$Name
    )
	Process
	{
		[int]$lcidThread = [System.Threading.Thread]::CurrentThread.CurrentUICulture.LCID
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($LCID)

		[Microsoft.SharePoint.SPContentType]$ct = $Web.AvailableContentTypes | ? { $_.Name -eq $Name }

        [System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($lcidThread)

		return $ct
	}
}

Function Get-SPContentTypeByEnglishName()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

        [Parameter(Mandatory=$true)]
        [string]$EnglishName
    )
	Process
	{
	    [int]$lcidThread = [System.Threading.Thread]::CurrentThread.CurrentUICulture.LCID
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo(1033)

		[Microsoft.SharePoint.SPContentType]$ct = $Web.AvailableContentTypes | ? { $_.Name -eq $EnglishName }

        [System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($lcidThread)

		return $ct
	}
}


Function New-SPView()
{
    Param
    (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.SPList]$List,
        
		[Parameter(Mandatory=$true)]
		[string]$ViewName,
        
		[Parameter(Mandatory=$true)]
		[array]$FieldsToShow,

        [Parameter(Mandatory=$true)]
		[string]$CAMLQuery,

        [Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal,

        [Parameter(Mandatory=$false)]
		[nullable[bool]]$IsDefaultView = $false
    )
    Process
	{
	    $web = $List.ParentWeb

        Write-SPHost -LogLevel $LogLevel "Iniciando la función New-SPView en la lista $($List.ParentWeb.Url+ $List.RootFolder.Url) ListViewsCount=$($List.Views.Count) ViewName=$ViewName FieldsToShow=$($FieldsToShow -join ",") CAMLQuery=$CAMLQuery" 

        $currentView = $List.Views[$ViewName]

        if($currentView -ne $null)
        {
            Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Eliminando las vistas existentes"
                
            #$web.AllowUnsafeUpdates = $true
            $List.Views.Delete($currentView.ID.Guid)
            $List.Update()
            $web.Update()
        }
        
        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Creando la vista"
        $newView = $List.Views.Add($ViewName, $FieldsToShow, $CAMLQuery, 30, $true, $IsDefaultView)

        Write-SPHost -LogLevel $LogLevel "Hecho. ViewId=$($newView.ID)"

        return $newView
    }
}

Function Write-SPHost()
{ 
    Param
    (
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, Position=0)]
		[Object]$Object,

        [Parameter(Mandatory=$false)]
		[switch]$NoNewline,

        [Parameter(Mandatory=$false)]
		[Object]$Separator = " ",

        [Parameter(Mandatory=$false)]
		[ConsoleColor]$ForegroundColor = [ConsoleColor]"White",
        
        [Parameter(Mandatory=$false)]
		[ConsoleColor]$BackgroundColor = [ConsoleColor]"DarkBlue",

        [Parameter(Mandatory=$false)]
        [SPLogLevel]$MessageLevel = [SPLogLevel]::Normal,

        [Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
	{
        if ($true -or ($Global:_logLevel -eq "Verbose") -or ($LogLevel -eq "Verbose") -or ($MessageLevel -eq "Normal"))
        {
			Write-Host "[$((Get-Date).ToLongTimeString())]: " -NoNewline -ForegroundColor Black -BackgroundColor White
            Write-Host -Object $Object -NoNewline:$NoNewline -Separator $Separator -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
        }
    }
}

Function Set-SPWebSearchCenterUrl()
{
    Param
    (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.SPWeb]$Web,
        
		[Parameter(Mandatory=$true)]
		[string]$SearchCenterUrl,
		
        [Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
	{
        Write-SPHost -LogLevel $LogLevel "Iniciando la función Set-SPWebSearchCenterUrl en el sitio $($Web.Url) SearchCenterUrl=$SearchCenterUrl" 

		$Web.AllProperties["SRCH_ENH_FTR_URL_WEB"] = $SearchCenterUrl
		$Web.Update()

        Write-SPHost -LogLevel $LogLevel "Finalizada la función Set-SPWebSearchCenterUrl"
    }
}

Function Set-SPSiteSearchCenterUrl()
{
    Param
    (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.SPWeb]$Web,
        
		[Parameter(Mandatory=$true)]
		[string]$SearchCenterUrl,
		
        [Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
	{
        Write-SPHost -LogLevel $LogLevel "Iniciando la función Set-SPSiteSearchCenterUrl en el sitio $($Web.Url) SearchCenterUrl=$SearchCenterUrl" 

		$Web.AllProperties["SRCH_ENH_FTR_URL"] = $SearchCenterUrl
		$Web.Update()

        Write-SPHost -LogLevel $LogLevel "Finalizada la función Set-SPSiteSearchCenterUrl"
    }
}

Function Set-SPWebSearchResultsPage()
{
    Param
    (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$true, ParameterSetName="Inherit")]
		[switch]$Inherit,

		[Parameter(Mandatory=$true, ParameterSetName="SearchResultsPageUrl")]
		[string]$SearchResultsPageUrl,

		[Parameter(Mandatory=$true, ParameterSetName="ShowNavigation")]
		[switch]$ShowNavigation,
		
        [Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
	{
        Write-SPHost -LogLevel $LogLevel "Iniciando la función Set-SPWebSearchResultsPageUrl en el sitio $($Web.Url) SearchResultsPageUrl=$SearchResultsPageUrl" 

		[string]$existingSetting = $Web.AllProperties["SRCH_SB_SET_WEB"]

		switch ($PsCmdlet.ParameterSetName)
		{
			"Inherit" {
				if (($existingSetting -eq $null) -or ($existingSetting -eq ""))
				{
					$newSetting = "{`"Inherit`":true,`"ResultsPageAddress`":`"`",`"ShowNavigation`":false}"
				}
				else
				{
					$newSetting = $existingSetting.Replace("`"Inherit`":false", "`"Inherit`":true").Replace("`"ShowNavigation`":true", "`"ShowNavigation`":false")
				}
				break
			}
			"ShowNavigation" {
				if (($existingSetting -eq $null) -or ($existingSetting -eq ""))
				{
					$newSetting = "{`"Inherit`":false,`"ResultsPageAddress`":`"`",`"ShowNavigation`":true}"
				}
				else
				{
					$newSetting = $existingSetting.Replace("`"Inherit`":true", "`"Inherit`":false").Replace("`"ShowNavigation`":false", "`"ShowNavigation`":true")
				}
				break
			}
			"SearchResultsPageUrl" {
				$newSetting = "{`"Inherit`":false,`"ResultsPageAddress`":`"$SearchResultsPageUrl`",`"ShowNavigation`":false}"
				break
			}
		}

		$Web.AllProperties["SRCH_SB_SET_WEB"] = $newSetting
		$Web.Update()

        Write-SPHost -LogLevel $LogLevel "Finalizada la función Set-SPWebSearchResultsPageUrl"
    }
}

Function Set-SPSiteSearchResultsPage()
{
    Param
    (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$true, ParameterSetName="Inherit")]
		[switch]$Inherit,

		[Parameter(Mandatory=$true, ParameterSetName="SearchResultsPageUrl")]
		[string]$SearchResultsPageUrl,

		[Parameter(Mandatory=$true, ParameterSetName="ShowNavigation")]
		[switch]$ShowNavigation,
		
        [Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
	{
        Write-SPHost -LogLevel $LogLevel "Iniciando la función Set-SPSiteSearchResultsPageUrl en el sitio $($Web.Url) SearchResultsPageUrl=$SearchResultsPageUrl" 

		[string]$existingSetting = $Web.AllProperties["SRCH_SB_SET_SITE"]

		switch ($PsCmdlet.ParameterSetName)
		{
			"Inherit" {
				if (($existingSetting -eq $null) -or ($existingSetting -eq ""))
				{
					$newSetting = "{`"Inherit`":true,`"ResultsPageAddress`":`"`",`"ShowNavigation`":false}"
				}
				else
				{
					$newSetting = $existingSetting.Replace("`"Inherit`":false", "`"Inherit`":true").Replace("`"ShowNavigation`":true", "`"ShowNavigation`":false")
				}
				break
			}
			"ShowNavigation" {
				if (($existingSetting -eq $null) -or ($existingSetting -eq ""))
				{
					$newSetting = "{`"Inherit`":false,`"ResultsPageAddress`":`"`",`"ShowNavigation`":true}"
				}
				else
				{
					$newSetting = $existingSetting.Replace("`"Inherit`":true", "`"Inherit`":false").Replace("`"ShowNavigation`":false", "`"ShowNavigation`":true")
				}
				break
			}
			"SearchResultsPageUrl" {
				$newSetting = "{`"Inherit`":false,`"ResultsPageAddress`":`"$SearchResultsPageUrl`",`"ShowNavigation`":false}"
				break
			}
		}

		$Web.AllProperties["SRCH_SB_SET_SITE"] = $newSetting
		$Web.Update()

        Write-SPHost -LogLevel $LogLevel "Finalizada la función Set-SPSiteSearchResultsPageUrl"
    }
}

Function Clear-SPList()
{
    Param
    (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.SPList]$List,

        [Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
	{
		$List.Items | % { $List.GetItemById($_.Id).Delete() }
	}
}

Function Add-Workflow()
{
    Param
    (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$true)]
		[string]$ListName,

		[Parameter(Mandatory=$true)]
		[string]$WorkflowTemplateName, # Aprobación de publicación / Publishing Approval

		[Parameter(Mandatory=$true)]
		[string]$TaskListName, # Tareas de flujo de trabajo / Workflow Tasks

		[Parameter(Mandatory=$true)]
		[string]$HistoryListName, # Historial del flujo de trabajo / Workflow History

		[Parameter(Mandatory=$true)]
		[string]$WorkflowName,

		[switch]$AllowManual,

		[switch]$AutoStartChange,

		[switch]$AutoStartCreate,

        [switch]$EnableModeration,

        [Parameter(Mandatory=$True,HelpMessage='Introduzca el array de aprobadores en la forma: @("Aprobadores|SharePointGroup","Aprobador|User")')]
        [string[]]$ApproversArray,

		[switch]$Serial,

		[switch]$ExpandGroups,

		[Parameter(Mandatory=$false)]
		[string]$NotificationMessage,

        [switch]$CancelonRejection,

        [switch]$CancelonChange,

        [Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        if ($Web -ne $null)
        {
            # Get the List to which we wanted to associate the Workflow
            $SPList = $Web.Lists[$ListName];
            
            if ($SPList -ne $null)
            {
                $SPList.EnableModeration = $EnableModeration;

                # Get the Approval Workflow Template by specifying Culture Info
                [int]$lcid = $Web.Language;
                $Culture = New-Object System.Globalization.CultureInfo($lcid);
                $Template = $Web.WorkflowTemplates.GetTemplateByName($WorkflowTemplateName, $Culture); # Aprobación de publicación / Publishing Approval

                $TaskList = $Web.Lists[$TaskListName];
                $HistoryList = $Web.Lists[$HistoryListName];

                try
                {
                    # Create Workflow History List if it doesn't exist by default
                    if ($HistoryList -eq $null)
                    {
						[int]$templateType = 140;
                        $Web.Lists.Add($HistoryListName, "", "Lists/WorkflowHistory", "00bfea71-4ea5-48d4-a4ad-305cf7030140", $templateType, "101"); # Historial del flujo de trabajo / Workflow History
                        $HistoryList = $Web.Lists[$HistoryListName];
                    }
                }
                catch
                {
                }

                if ($HistoryList -ne $null -and $TaskList -ne $null -and $Template -ne $null)
                {
                    # Create the Workflow Association by using Workflow Template, Task List and History List
                    $Association = [Microsoft.SharePoint.Workflow.SPWorkflowAssociation]::CreateListAssociation($Template, $WorkflowName, $TaskList, $HistoryList);

                    $Association.AllowManual = $AllowManual;
                
                    if (-not $EnableModeration)
                    {
                        $Association.AutoStartChange = $AutoStartChange;
                        $Association.AutoStartCreate = $AutoStartCreate;
                    }

                    $AssignmentType;

                    if ($Serial)
                    {
                        $AssignmentType = "Serial";
                    }
                    else
                    {
                        $AssignmentType = "Parallel";
                    }

                    $strExpandGroups;

                    if ($ExpandGroups)
                    {
                        $strExpandGroups = "true";
                    }
                    else
                    {
                        $strExpandGroups = "false";
                    }

                    $strCancelonRejection;

                    if ($CancelonRejection)
                    {
                        $strCancelonRejection = "true";
                    }
                    else
                    {
                        $strCancelonRejection = "false";
                    }

                    $strCancelonChange;

                    if ($CancelonChange)
                    {
                        $strCancelonChange = "true";
                    }
                    else
                    {
                        $strCancelonChange = "false";
                    }

                    $strEnableModeration;

                    if ($EnableModeration)
                    {
                        $strEnableModeration = "true";
                    }
                    else
                    {
                        $strEnableModeration = "false";
                    }

                    $approvalAssociationData = "
                    <dfs:myFields xmlns:xsd='http://www.w3.org/2001/XMLSchema'
                                  xmlns:dms='http://schemas.microsoft.com/office/2009/documentManagement/types'
                                  xmlns:dfs='http://schemas.microsoft.com/office/infopath/2003/dataFormSolution'
                                  xmlns:q='http://schemas.microsoft.com/office/infopath/2009/WSSList/queryFields'
                                  xmlns:d='http://schemas.microsoft.com/office/infopath/2009/WSSList/dataFields'
                                  xmlns:ma='http://schemas.microsoft.com/office/2009/metadata/properties/metaAttributes'
                                  xmlns:pc='http://schemas.microsoft.com/office/infopath/2007/PartnerControls'
                                  xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>
                        <dfs:queryFields></dfs:queryFields>
                        <dfs:dataFields>
                            <d:SharePointListItem_RW>
                                <d:Approvers>";

                                    foreach ($Assignment in $ApproversArray)
                                    {
                                        $AccountName = $Assignment.Split("|")[0];
                                        $AccountType = $Assignment.Split("|")[1];

                                        if ($AccountName -ne $null -and $AccountName -ne "" -and $AccountType -ne $null -and $AccountType -ne "" -and ($AccountType -eq "SharePointGroup" -or $AccountType -eq "User"))
                                        {
                                            $approvalAssociationData = $approvalAssociationData + "<d:Assignment>
                                        <d:Assignee>
                                            <pc:Person>
                                                <pc:DisplayName>" + $AccountName + "</pc:DisplayName>
                                                <pc:AccountId>" + $AccountName + "</pc:AccountId>
                                                <pc:AccountType>" + $AccountType + "</pc:AccountType>
                                            </pc:Person>
                                        </d:Assignee>
                                        <d:Stage xsi:nil='true' />
                                        <d:AssignmentType>$AssignmentType</d:AssignmentType>
                                    </d:Assignment>";
                                        }
                                    }

                                $approvalAssociationData = $approvalAssociationData + "</d:Approvers>
                                <d:ExpandGroups>$strExpandGroups</d:ExpandGroups>
                                <d:NotificationMessage>$NotificationMessage</d:NotificationMessage>
                                <d:DueDateforAllTasks xsi:nil='true' />
                                <d:DurationforSerialTasks xsi:nil='true' />
                                <d:DurationUnits>Day</d:DurationUnits>
                                <d:CC />
                                <d:CancelonRejection>$strCancelonRejection</d:CancelonRejection>
                                <d:CancelonChange>$strCancelonChange</d:CancelonChange>
                                <d:EnableContentApproval>$strEnableModeration</d:EnableContentApproval>
                            </d:SharePointListItem_RW>
                        </dfs:dataFields>
                    </dfs:myFields>";

                    $Association.AssociationData = $approvalAssociationData;

                    # Associate the Workflow to List
                    $Workflow = $SPList.WorkflowAssociations.Add($Association);

                    if ($EnableModeration)
                    {
                        $SPList.DefaultContentApprovalWorkflowId = $Association.Id;
                        $SPList.Update();
                    }

                    Write-SPHost -LogLevel $LogLevel "Flujo de trabajo: $WorkflowName, asociado a la lista: $ListName"
                }
                else
                {
                    Write-SPHost -LogLevel $LogLevel "Plantilla de flujo de trabajo, tarea or lista de histórico no encontrada"
                }
            }
            else
            {
                Write-SPHost -LogLevel $LogLevel "Lista: $ListName, no encontrada"
            }
        }
    }
}

Function Remove-Workflow()
{
    Param
    (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$true)]
		[string]$ListName,

		[Parameter(Mandatory=$true)]
		[string]$WorkflowName,

        [Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        if ($Web -ne $null)
        {
            # Get the List to which we wanted to associate the Workflow
            $SPList = $Web.Lists[$ListName];
            
            if ($SPList -ne $null)
            {
                [int]$lcid = $Web.Language;
                $Culture = New-Object System.Globalization.CultureInfo($lcid);

                $Association = $SPList.WorkflowAssociations.GetAssociationByName($WorkflowName, $Culture);

                if ($Association -ne $null)
                {
                    $SPList.RemoveWorkflowAssociation($Association);
                    $SPList.Update();

                    Write-SPHost -LogLevel $LogLevel "Asociación de flujo de trabajo eliminada correctamente"
                }
                else
                {
                    Write-SPHost -LogLevel $LogLevel "Flujo de trabajo: $WorkflowName, asociado a la lista: $ListName, con cultura: $($Culture.Name), no encontrado"
                }
            }
            else
            {
                Write-SPHost -LogLevel $LogLevel "Lista: $ListName, no encontrada"
            }
        }
    }
}

Function Set-UserProperty(){
	Param
	(
		[Parameter(Mandatory=$true)]
        [object]$UserProperty = $null,		      
		[Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPSite]$Site
	)
	Process
	{		
		Write-Host -ForegroundColor Yellow "Iniciando la asignación de propiedad de usuario "
		if($UserProperty -ne $null){
			#Obtener Parámetros
			$PropertyName = $UserProperty[0].PropertyName
			$PropertyDisplayName = $UserProperty[0].PropertyDisplayName
			$Privacy = $UserProperty[0].Privacy
			$PrivacyPolicy = $UserProperty[0].PrivacyPolicy
			$PropertyType = $UserProperty[0].PropertyType
			$PropertyLength = $UserProperty[0].PropertyLength
			$ADAttributeName = $UserProperty[0].ADAttributeName
			$VisibleOnViewer = [boolean]::Parse($UserProperty[0].VisibleOnViewer)
			$VisibleOnEditor = [boolean]::Parse($UserProperty[0].VisibleOnEditor)
			$Replicable = [boolean]::Parse($UserProperty[0].Replicable)
			$UserEditable = [boolean]::Parse($UserProperty[0].UserCanEdit)
			$UserOverride = [boolean]::Parse($UserProperty[0].UserCanOverride)
			$NewsFeed = [boolean]::Parse($UserProperty[0].NewsFeed)			

			$serviceContext = [Microsoft.SharePoint.SPServiceContext]::GetContext($Site)
			$userProfileConfigManager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileConfigManager($serviceContext)
			$userProfilePropertyManager = $userProfileConfigManager.ProfilePropertyManager
			$corePropertyManager = $userProfilePropertyManager.GetCoreProperties()
			$userProfileTypeProperties = $userProfilePropertyManager.GetProfileTypeProperties([Microsoft.Office.Server.UserProfiles.ProfileType]::User)
			$userProfileSubTypeManager = [Microsoft.Office.Server.UserProfiles.ProfileSubTypeManager]::Get($serviceContext)
			$userProfile = $userProfileSubTypeManager.GetProfileSubtype([Microsoft.Office.Server.UserProfiles.ProfileSubtypeManager]::GetDefaultProfileName([Microsoft.Office.Server.UserProfiles.ProfileType]::User))
			$userProfileProperties = $userProfile.Properties 
			
			if($corePropertyManager.GetPropertyByName($PropertyName) -eq $null){
				#Set Custom Property values
				$coreProperty = $corePropertyManager.Create($false)
			    $coreProperty.Name = $PropertyName
                $coreProperty.Type = $PropertyType
			    $coreProperty.Length = $PropertyLength
			}else{
                $coreProperty = $corePropertyManager.GetPropertyByName($PropertyName)
            }
			$coreProperty.DisplayName = $PropertyDisplayName			

			if($userProfileTypeProperties.GetPropertyByName($PropertyName) -ne $null){			
				$coreProperty.Commit()
				$profileTypeProperty = $userProfileTypeProperties.GetPropertyByName($PropertyName)
			}else{
				#Add Custom Property
				$corePropertyManager.Add($coreProperty)
				$profileTypeProperty = $userProfileTypeProperties.Create($coreProperty)
			}
	  
			#Display Settings 
			#Show on the Edit Details page
			$profileTypeProperty.IsVisibleOnEditor = $VisibleOnEditor 
			#Show in the profile properties section of the user's profile page
			$profileTypeProperty.IsVisibleOnViewer = $VisibleOnViewer 
			#Show updates to the property in newsfeed
			$profileTypeProperty.IsEventLog = $NewsFeed
			$profileTypeProperty.IsReplicable = $Replicable
 

			if($userProfileProperties.GetPropertyByName($PropertyName) -ne $null){			
				$profileTypeProperty.Commit()
				$profileSubTypeProperty = $userProfileProperties.GetPropertyByName($PropertyName)
			}else{
				$userProfileTypeProperties.Add($profileTypeProperty)
				$profileSubTypeProperty = $userProfileProperties.Create($profileTypeProperty)
			}
			
			$profileSubTypeProperty.DefaultPrivacy =[Microsoft.Office.Server.UserProfiles.Privacy]::$Privacy
			$profileSubTypeProperty.PrivacyPolicy =[Microsoft.Office.Server.UserProfiles.PrivacyPolicy]::$PrivacyPolicy
			$profileSubTypeProperty.UserOverridePrivacy = $UserOverride
            $profileSubTypeProperty.IsUserEditable = $UserEditable

			if($userProfileProperties.GetPropertyByName($PropertyName) -eq $null){
				$userProfileProperties.Add($profileSubTypeProperty)
			}else{
				$profileSubTypeProperty.Commit()
			}
 
			#Add New Mapping for synchronization user profile data  
			$UPAConnMgr = $userProfileConfigManager.ConnectionManager  
			$Connection = ($UPAConnMgr | select -First 1)  
			if ($Connection.Type -eq "ActiveDirectoryImport" -and ($ADAttributeName -ne $null -and $ADAttributeName -ne "")){  
				$Connection.AddPropertyMapping($ADAttributeName,$PropertyName)  
				$Connection.Update()  
			}  
	
		}
		Write-Host -ForegroundColor Yellow "Finalización de asignación de la propiedad de usuario $UserProperty"
	}
}

Function Create-Lookup(){
	Param
	(
		[Parameter(Mandatory=$true)]
		[string]$parentSiteUrl = $(Read-Host -Prompt "Site URL"),
		[Parameter(Mandatory=$true)]
		[string]$ParentListName,
		[Parameter(Mandatory=$true)]
		[string]$SourceListName,
		[Parameter(Mandatory=$true)]
		[string]$FieldName,		
		[Parameter(Mandatory=$true)]
		[string]$LookupField,
		[Parameter(Mandatory=$true)]
		[string]$Required,
		[Parameter(Mandatory=$true)]
		[string]$DisplayName
	)
	Process
	{		

		$WebObj = Get-SPWeb -identity $parentSiteUrl 
		$list = $WebObj.Lists[$ParentListName]
		$lookupList=$WebObj.Lists[$SourceListName]
		$lookupFieldName = $lookupList.Fields[$FieldName]		
		$requerido= [boolean]::Parse($Required)
		$strPrimaryCol = $list.Fields.AddLookup( $DisplayName, $lookupList.Id, $requerido)
        $primaryCol = [Microsoft.SharePoint.SPFieldLookup] $list.Fields[$DisplayName]		
		
		$primaryCol.LookupField = $lookupFieldName		
        $primaryCol.Update()			
		
	
		Write-Host "Nueva columna de sitio creada (búsqueda)." -ForegroundColor green 		
	}
}



Function WaitForDeploymentJob([string]$SolutionFileName)
{ 
    $JobName = "*solution-deployment*$SolutionFileName*"
    WaitForJob $JobName
}

Function WaitForJob([string]$JobName)
{ 
    $job = Get-SPTimerJob | ?{ $_.Name -like $JobName }
    if ($job -eq $null) 
    {
        Write-Host "Timer job no encontrado." -ForegroundColor Yellow
    }
    else
    {
        $JobFullName = $job.Name
        Write-Host "Esperando a que termine el job '$JobFullName'..." -ForegroundColor Green
        
        while ((Get-SPTimerJob $JobFullName) -ne $null) 
        {
            Write-Host -NoNewLine .
            Start-Sleep -Seconds 2
        }
        Write-Host .
        Write-Host "Job terminado." -ForegroundColor Green
    }
}


Function Modify-Permissions()
{
<#
Ejemplo del elemento Permissions:

<List>
    <.......>

    <Permissions Inherit="True" Reset="True">
        <Add User="CONTOSO\sp_admin" Permission="Contribute"/>
        <Add Group="Director RRHH" Permission="Contribute"/>

        <Remove Group="Director RRHH" />
        <Remove User="CONTOSO\sp_admin" />
        <Remove DefaultGroup="Visitantes"/>
        <Remove DefaultGroup="Colaboradores"/>
        <Remove DefaultGroup="Administradores"/>
    </Permissions>
</List>
#>

	Param
	(
		[Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

        [Microsoft.SharePoint.SPList]$List,

        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$Permissions
	)
	Process
	{
		$element = $List
		if ($element -eq $null) {
			$element = $Web
		}

		#Restablecemos los permisos si está marcado
		if ($Permissions.Reset -ne $null -and $Permissions.Reset -eq "True" -and $element.HasUniqueRoleAssignments -eq $true) {
			$element.ResetRoleInheritance()
		}
	
		if ($Permissions.Inherit -ne $null) {
			#Romper permisos
			if ($element.HasUniqueRoleAssignments -eq $false) {
				$inherit = $true
				if ($Permissions.Inherit -ne $null -and $Permissions.Inherit -eq "False") {    
					$inherit = $false
				}

				$element.BreakRoleInheritance($inherit)
				$element.Update()
			}

			#Quitar permisos
			$Permissions.Remove | % {
				$account = $null

				if ($_.User -ne $null) {
					$account = $Web.Site.RootWeb.EnsureUser($_.User)
				}
				else {
					if ($_.Group -ne $null) {
						$account = $Web.Site.RootWeb.SiteGroups[$_.Group]
					}
					else {
						if ($_.DefaultGroup -ne $null) {

							if ($_.DefaultGroup -eq "Visitantes")
							{
								$account = $Web.AssociatedVisitorGroup
							} 
							else 
							{
								if ($_.DefaultGroup -eq "Colaboradores")
								{
									$account = $Web.AssociatedMemberGroup
								} 
								else
								{
									if ($_.DefaultGroup -eq "Administradores")
									{
										$account = $Web.AssociatedOwnerGroup
									}
								}
							}			    
						}
					}
				}
        
				if ($account -ne $null) {
					[Microsoft.SharePoint.SPRoleAssignmentCollection] $spRoleAssignments = $element.RoleAssignments
					for([int] $a=$spRoleAssignments.Count-1; $a -ge 0;$a--)
					{
						if($spRoleAssignments[$a].Member.Name -eq $account.Name)
						{
							$spRoleAssignments.Remove($a)
							break
						}
					}
				}
			}

			#Agregar permisos
			$Permissions.Add | % {
				$account = $null

				if ($_.User -ne $null) {
					$account = $Web.Site.RootWeb.EnsureUser($_.User)
				}
				else {
					if ($_.Group -ne $null) {
						$account = $Web.Site.RootWeb.SiteGroups[$_.Group]
					}
					else {
						if ($_.DefaultGroup -ne $null) {

							if ($_.DefaultGroup -eq "Visitantes")
							{
								$account = $Web.AssociatedVisitorGroup
							} 
							else 
							{
								if ($_.DefaultGroup -eq "Colaboradores")
								{
									$account = $Web.AssociatedMemberGroup
								} 
								else
								{
									if ($_.DefaultGroup -eq "Administradores")
									{
										$account = $Web.AssociatedOwnerGroup
									}
								}
							}			    
						}
					}
				}
        
				if ($account -ne $null) {
					try {
						$role = $Web.Site.RootWeb.RoleDefinitions[$_.Permission]
						$assignment = New-Object Microsoft.SharePoint.SPRoleAssignment($account)
						$assignment.RoleDefinitionBindings.Add($role)
						$element.RoleAssignments.Add($assignment)
					} catch {}
				}
			}
		}

		if ($Permissions.AnonymousUser -ne $null) {
			switch ($Permissions.AnonymousUser){
				"EntireWeb" {
					$element.AnonymousState = [Microsoft.SharePoint.SPWeb+WebAnonymousState]::On
				}
				"Lists" {
					$element.AnonymousState = [Microsoft.SharePoint.SPWeb+WebAnonymousState]::Enabled
				}
				"Nothing" {
					$element.AnonymousState = [Microsoft.SharePoint.SPWeb+WebAnonymousState]::Disabled
				}
			}
		}
	}
}

Function OrderTaxonomyTerms($navigationSet, $terms){

	if($navigationSet -ne $null)
	{
		$parent = $navigationSet
		$level1Arr = @()
		foreach($term in $terms){
			$l1Term = [Microsoft.SharePoint.Taxonomy.TermSet]::NormalizeName($term.'Level 1 Term') 
			$t = $navigationSet.Terms[$l1Term]
			if($t -ne $null -and $t.Id -ne $null -and -not($level1Arr.Contains($t.Id))){
				$level1Arr += $t.Id                   
			}
		}
		$order = $level1Arr -join ':'
		$parent.CustomSortOrder = $order
		$level2Arr = @()
		$l2Parent = $null
		foreach($term in $terms){         
			$l1Term = [Microsoft.SharePoint.Taxonomy.TermSet]::NormalizeName($term.'Level 1 Term')   
			$parentTerm = $navigationSet.Terms[$l1Term]
			if($term.'Level 2 Term' -ne $null -and $term.'Level 2 Term' -ne "" -and ($l2Parent -eq $null -or $l2Parent -eq $parentTerm)){
				$t = $parentTerm.Terms[$term.'Level 2 Term']
				if($t -ne $null -and $t.Id -ne $null -and -not($level2Arr.Contains($t.Id))){
					$level2Arr += $t.Id   
					$l2Parent = $parentTerm                
				}
			}elseif($l2Parent -ne $null -and $level2Arr.Length -gt 0){
					$order = $level2Arr -join ':'
					$l2Parent.CustomSortOrder = $order
					$level2Arr.Clear()
					$l2Parent = $null
			}
		}  
		Write-Host "Todos los conjuntos de términos han sido ordenados"    
	}
} 

Function ActivateLanguages($spWeb, $manifest){
	$additionalLanguages = $manifest.Site.AdditionalLanguages
    if ($additionalLanguages -ne $null)
	{
		$allToggle = $additionalLanguages.Equals("All")
		$langs = @()
		if(!$allToggle){
			if($additionalLanguages.Contains(";")){
				$langs = $additionalLanguages.Split(';')
			}else{
				$langs += $additionalLanguages
			}        
		}else{
			$installed = [Microsoft.SharePoint.SPRegionalSettings]::GlobalInstalledLanguages
			foreach ($lang in $installed)
			{
				$cultureinfo = [System.Globalization.CultureInfo]::GetCultureInfo($lang.LCID);
				$exists = $supportedCultures | Where-Object{$_.LCID -eq $lang.LCID}
				if ($exists -eq $null)
				{
					$langs += $lang.LCID
				}
			}
		}    
		if ($spWeb.IsMultilingual -eq $false) {
			$spWeb.IsMultilingual = $true;
		}
		Foreach($language in $langs)
		{	
			$spWeb.AddSupportedUICulture([int]$language);
		}
		$spWeb.Update()
	}
}

Function Configure-Audit()
{
<#
Ejemplo del elemento Audit:

<Site>
    <.......>

    <Audit TrimAuditLog="True" AuditLogTrimmingRetention="30" AuditFlags="View;Delete;Update">
    </Audit>

	Los posibles valores para AuditFlags están aquí https://msdn.microsoft.com/EN-US/library/microsoft.sharepoint.spauditmasktype.aspx
</Site>
#>

	Param
	(
		[Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPSite]$Site,

        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$Audit
	)
	Process
	{
		$Site.TrimAuditLog = Get-BoolValueOrNull $Audit.TrimAuditLog

		if ($Audit.AuditFlags -ne $null)
		{
			$flags = $Audit.AuditFlags.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)
			$flagsResult = $flags[0]

			for ($i=1; $i -lt $flags.length; $i++) {
				$flagsResult += [string]::Format(",{0}", $flags[$i])
			}

			$Site.Audit.AuditFlags = $flagsResult
		}

		$Site.Audit.Update()

		$logTrimmingRetention = Get-IntValueOrNull $Audit.AuditLogTrimmingRetention
		if ($logTrimmingRetention -ne $null)
		{
			$Site.AuditLogTrimmingRetention = $logTrimmingRetention
		}
		Write-Host -ForegroundColor Green "Auditoría configurada"
	}
}