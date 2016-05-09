$snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$currentPath\EnmarchaFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

    <#
    <Add
        Version="1"
        Id="79bb8843-8ba0-4b46-bd1c-ea6a1d12e2d1"
        FieldType="Boolean"
        Name="EsNuevo"
        StaticName="EsNuevo"
        Group="Enmarcha SiteColumns"
        Hidden="False"
        Required="False"
        
		="False"
        ShowInDisplayForm="True"
        ShowInEditForm="True"
        ShowInListSettings="True"
        ShowInNewForm="True">
        
        <DisplayNames>
          <DisplayName Label="es-ES" Value="Es nuevo" />
          <DisplayName Label="en-US" Value="Is new" />
        </DisplayNames>
        
        Dependiendo del atributo FieldType del elemento Add, el elemento contenido será distinto,
        con atributos específicos de ese tipo de campo

            <DateTime
                Format="DateOnly"
            />
        <Choice
            Choices="En ejecución;#Finalizado"
        />
        <Calculated
            Formula=""
            FormulaValueType=""
        />
        <Url
            URLFormat=""
        />
            <Link
                RichText=""
                RichTextMode=""
            />
            <Image
                RichText=""
                RichTextMode=""
            />
            <Html
                RichText=""
                RichTextMode=""
            />
        <Note
            RichText=""
            RichTextMode=""
                    UnlimitedLengthInDocumentLibrary="true"
        />
        <User
            UserSelectionMode=""
        />
        <TaxonomyFieldType
            TermStoreGroupName=""
            TermSetName=""
            AllowMultipleValues=""
            FullPathRendered=""
        />
     </Add>
    #>



Function Get-FieldType()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

        [Parameter(Mandatory=$true)]
        [string]$InternalName
    )
    Process
    {
        $field = $Web.Fields.GetFieldByInternalName($InternalName)
        if ($field -ne $null)
        {
            return $field.TypeAsString
        }
        else
        {
            return $null
        }
    }
}

Function Update-SiteColumn()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$true)]
        [string]$InternalName,

		[Parameter(Mandatory=$false)]
		[ValidateSet("Boolean","Number","Text","LookupMulti","DateTime","URL","Image","Link","Note","HTML","Calculated","User","UserMulti","Choice","MultiChoice","TaxonomyFieldType","TaxonomyFieldTypeMulti","SummaryLinks","MediaFieldType","Currency")]
        [string]$FieldType = (Get-FieldType -Web $Web -InternalName $InternalName),

        [Parameter(Mandatory=$false)]
        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$LocalizedDisplayNames = $null,

		[Parameter(Mandatory=$false)]
        [string]$StaticName = $null,

		[Parameter(Mandatory=$false)]
        [string]$Group = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$Hidden = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$Required = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$Sealed = $null,

		[Parameter(Mandatory=$false)]
        [string]$MaxLength = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$ShowInDisplayForm = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$ShowInEditForm = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$ShowInListSettings = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$ShowInNewForm = $null,

		[Parameter(Mandatory=$false)]
		[ValidateSet("", "DateOnly", "DateTime")]
        [string]$DateTimeFormat = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","Image","Hyperlink")]
        [string]$UrlFormat = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","TRUE","FALSE")]
        [string]$ImageRichText = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","FullHtml","ThemeHtml")]
        [string]$ImageRichTextMode = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","TRUE","FALSE")]
        [string]$LinkRichText = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","FullHtml","ThemeHtml")]
        [string]$LinkRichTextMode = "",
		
		[Parameter(Mandatory=$false)]
		[ValidateSet("","TRUE","FALSE")]
        [string]$NoteRichText = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","FullHtml","ThemeHtml")]
        [string]$NoteRichTextMode = "",

        [Parameter(Mandatory=$false)]
        [Nullable[bool]]$UnlimitedLengthInDocumentLibrary = $null,

		[Parameter(Mandatory=$false)]
		[ValidateSet("","TRUE","FALSE")]
        [string]$HtmlRichText = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","FullHtml","ThemeHtml")]
        [string]$HtmlRichTextMode = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","Boolean","Integer","Text","Note","DateTime")]   # http://msdn.microsoft.com/en-us/library/microsoft.sharepoint.spfieldtype(v=office.15).aspx
        [string]$CalculatedFormulaValueType = "",

		[Parameter(Mandatory=$false)]
        [string]$CalculatedFormula = "",

		[Parameter(Mandatory=$false)]
        [ValidateSet("","PeopleOnly","PeopleAndGroups")]
        [string]$UserSelectionMode = "",

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$UserAllowMultipleValues = $null,

		[Parameter(Mandatory=$false)]
        [string[]]$Choices = $null,

        [Parameter(Mandatory=$false)]
        [Nullable[bool]]$IsPathRendered = $null,

        [Parameter(Mandatory=$false)]
        [Nullable[bool]]$IsOpen = $null,

        [Parameter(Mandatory=$false)]
        [string]$TermStoreGroupName,

        [Parameter(Mandatory=$false)]
        [string]$TermSetName,

        [Parameter(Mandatory=$false)]
        [Nullable[bool]]$AllowMultipleValues = $null,

		[Parameter(Mandatory=$false)]
        [bool]$UpdateChildren = $true,

		[Parameter(Mandatory=$false)]
        [string]$CurrencyFormat,

        [Parameter(Mandatory=$false)]
        [string]$DecimalFormat,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        $existingField = $Web.Fields | ? { $_.InternalName -eq $InternalName }
        if ($existingField -eq $null)
        {
            Write-SPHost -LogLevel $LogLevel -MessageLevel Normal "Error actualizando el campo '$InternalName'. El campo no existe"
            return
        }
        
		
		$field = $Web.Fields.GetFieldByInternalName($InternalName)
        $FieldType = $field.TypeAsString

		if ($FieldType -eq "Calculated")	
		{
			[object] $field = $Web.Fields.GetFieldByInternalName($InternalName)
			$FieldType = $field.TypeAsString
		}

		
        if ($Group -ne $null -and $Group -ne "") { $field.Group =  $Group }
		if ($StaticName -ne $null -and $StaticName -ne "") { $field.StaticName = $StaticName }
		if ($Hidden -ne $null) { $field.Hidden = $Hidden }
        if ($Required -ne $null) { $field.Required = $Required }
        if ($Sealed -ne $null) { $field.Sealed = $Sealed }
        if ($ShowInDisplayForm -ne $null) { $field.ShowInDisplayForm = $ShowInDisplayForm }
        if ($ShowInEditForm -ne $null) { $field.ShowInEditForm = $ShowInEditForm }
        if ($ShowInListSettings -ne $null) { $field.ShowInListSettings = $ShowInListSettings }
        if ($ShowInNewForm -ne $null) { $field.ShowInNewForm = $ShowInNewForm }
		if ($MaxLength -ne $null -and $MaxLength -ne '') { $field.MaxLength = $MaxLength }

        if ($LocalizedDisplayNames -ne $null)
        {
			[int]$lcidThread = [System.Threading.Thread]::CurrentThread.CurrentUICulture.LCID
			[System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo([int]$Web.Language)

            $titleResource = $field.TitleResource
            $LocalizedDisplayNames.GetEnumerator() | % {
                if ($Web.Language -eq $_.Key.LCID)
                {
                    $field.Title = $_.Value
                }
                $titleResource.SetValueForUICulture($_.Key, $_.Value)
            }

			[System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($lcidThread)
        }

        switch ($FieldType)
        {
            "DateTime" {
                [Microsoft.SharePoint.SPFieldDateTime]$fieldDateTime = $field
                if ($DateTimeFormat -ne "") { $fieldDateTime.DisplayFormat = $DateTimeFormat }
			}
			"URL" {
                [Microsoft.SharePoint.SPFieldUrl]$fieldUrl = $field
                if ($UrlFormat -ne "") { $fieldUrl.DisplayFormat = $UrlFormat }
			}
			"Image" {
                [Microsoft.SharePoint.Publishing.Fields.ImageField]$fieldImage = $field
				if ($ImageRichText -ne "") { $fieldImage.RichText = $ImageRichText }
				if ($ImageRichTextMode -ne "") { $fieldImage.RichTextMode = $ImageRichTextMode }
			}
			"Link" {
                [Microsoft.SharePoint.Publishing.Fields.LinkField]$fieldLink = $field
				if ($LinkRichText -ne "") { $fieldLink.RichText = $LinkRichText }
				if ($LinkRichTextMode -ne "") { $fieldLink.RichTextMode = $LinkRichTextMode }
			}
			"Note" {
                [Microsoft.SharePoint.SPFieldMultiLineText]$fieldMultiLineText = $field
				if ($NoteRichText -ne "") { $fieldMultiLineText.RichText = $NoteRichText }
				if ($NoteRichTextMode -ne "") { $fieldMultiLineText.RichTextMode = $NoteRichTextMode }
                if ($UnlimitedLengthInDocumentLibrary -ne $null) { $fieldMultiLineText.UnlimitedLengthInDocumentLibrary = $UnlimitedLengthInDocumentLibrary }
			}
			"HTML" {
                [Microsoft.SharePoint.Publishing.Fields.HtmlField]$fieldHtml = $field
				if ($HtmlRichText -ne "") { $fieldHtml.RichText = $HtmlRichText }
				if ($HtmlRichTextMode -ne "") { $fieldHtml.RichTextMode = $HtmlRichTextMode }
			}
			"Calculated" {
                [Microsoft.SharePoint.SPFieldCalculated]$fieldCalculated = $field
				if ($CalculatedFormulaValueType -ne "") { $fieldCalculated.OutputType = $CalculatedFormulaValueType }
				if ($CalculatedFormula -ne "") { $fieldCalculated.Formula = $CalculatedFormula.Trim('"') }
			}
			{@("User","UserMulti") -contains $_} {
                [Microsoft.SharePoint.SPFieldUser]$fieldUser = $field
				if ($UserSelectionMode -ne "") { $fieldUser.SelectionMode = $UserSelectionMode }
				if ($UserAllowMultipleValues -ne $null) { $fieldUser.AllowMultipleValues = $UserAllowMultipleValues }
			}
			"Choice" {
                [Microsoft.SharePoint.SPFieldChoice]$fieldChoice = $field
				if ($Choices -ne $null -and $Choices.Count -gt 0)
				{
				    $fieldChoice.Choices.Clear();
                    $fieldChoice.Choices.AddRange($Choices)
				}
			}
			"MultiChoice" {
                [Microsoft.SharePoint.SPFieldMultiChoice]$fieldMultiChoice = $field
				if ($Choices -ne $null -and $Choices.Count -gt 0)
				{
                    $fieldMultiChoice.Choices.AddRange($Choices)
				}
			}
			{@("TaxonomyFieldType","TaxonomyFieldTypeMulti") -contains $_} {
                [Microsoft.SharePoint.Taxonomy.TaxonomyField]$fieldTaxonomy = $field

                $session = Get-SPTaxonomySession -Site $Web.Site
                $serviceApp = Get-DefaultManagedMetadataServiceApplication -Site $Web.Site
                #$termStore =$session.TermStores[$serviceApp.Name]
				$termStore =$session.TermStores[0]
                $termSet = $termStore.Groups[$TermStoreGroupName].TermSets[$TermSetName] 

				$fieldTaxonomy.SspId = $termSet.TermStore.Id
				$fieldTaxonomy.TermSetId = $termSet.Id
                
				if ($AllowMultipleValues -ne $null) { $fieldTaxonomy.AllowMultipleValues = $AllowMultipleValues }
                if ($IsPathRendered -ne $null) { $fieldTaxonomy.IsPathRendered = $IsPathRendered }
				if ($IsOpen -ne $null) { $fieldTaxonomy.Open = $IsOpen }
            }
            "Currency" {
                [Microsoft.SharePoint.SPFieldCurrency]$fieldCurrency = $field
                if ($CurrencyFormat -ne $null) { $fieldCurrency.Currency = $CurrencyFormat }
				if ($DecimalFormat -ne $null) { 
					if ($DecimalFormat -eq "NoDecimal") {
						$fieldCurrency.DisplayFormat = [Microsoft.SharePoint.SPNumberFormatTypes]::NoDecimal 
						$fieldCurrency.Update()
					}
				}
			}
		}

        $field.Update($UpdateChildren)

		$usages = $field.ListsFieldUsedIn()

		foreach ($usage in $usages)
		{
			$usageWeb = $Web.Site.OpenWeb($usage.WebID);

			if ($usageWeb)
			{
				$list = $usageWeb.Lists[$usage.ListID];

				if ($list)
				{
					$listField = $list.Fields.GetFieldByInternalName($field.InternalName);

					if ($LocalizedDisplayNames -ne $null)
					{
						[int]$lcidThread = [System.Threading.Thread]::CurrentThread.CurrentUICulture.LCID
						[System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo([int]$usageWeb.Language)

						$listTitleResource = $listField.TitleResource

						$LocalizedDisplayNames.GetEnumerator() | % {
							if ($usageWeb.Language -eq $_.Key.LCID)
							{
								$listField.Title = $_.Value

								Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Campo $InternalName actualizado con título $($_.Value) en $($usageWeb.Url)/$($list.RootFolder.Url)"
							}

							$listTitleResource.SetValueForUICulture($_.Key, $_.Value)

							Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Campo $InternalName título actualizado con $($_.Key), $($_.Value) en $($usageWeb.Url)/$($list.RootFolder.Url)"
						}

						[System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($lcidThread)
					}

					$listField.Update()
				}
			}
		}

        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Campo $InternalName actualizado"
	}
}

Function New-SiteColumn()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$true)]
		[ValidateSet("Boolean","Number","Text","LookupMulti","DateTime","URL","Image","Link","Note","HTML","Calculated","User","UserMulti","Choice","MultiChoice","TaxonomyFieldType","TaxonomyFieldTypeMulti","SummaryLinks","MediaFieldType","Currency")]
        [string]$FieldType,

		[Parameter(Mandatory=$true)]
        [string]$InternalName,

		[Parameter(Mandatory=$true)]
        [string]$DisplayName,

		[Parameter(Mandatory=$false)]
        [guid]$Id = [System.Guid]::NewGuid(),

        [Parameter(Mandatory=$false)]
        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$LocalizedDisplayNames,

		[Parameter(Mandatory=$true)]
        [string]$StaticName,

		[Parameter(Mandatory=$true)]
        [string]$Group,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$Hidden = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$Required = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$Sealed = $null,

		[Parameter(Mandatory=$false)]
        [string]$MaxLength = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$ShowInDisplayForm = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$ShowInEditForm = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$ShowInListSettings = $null,

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$ShowInNewForm = $null,

		[Parameter(Mandatory=$false)]
		[ValidateSet("", "DateOnly", "DateTime")]
        [string]$DateTimeFormat = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","Image","Hyperlink")]
        [string]$UrlFormat = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","TRUE","FALSE")]
        [string]$ImageRichText = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","FullHtml","ThemeHtml")]
        [string]$ImageRichTextMode = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","TRUE","FALSE")]
        [string]$LinkRichText = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","FullHtml","ThemeHtml")]
        [string]$LinkRichTextMode = "",
		
		[Parameter(Mandatory=$false)]
		[ValidateSet("","TRUE","FALSE")]
        [string]$NoteRichText = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","FullHtml","ThemeHtml")]
        [string]$NoteRichTextMode = "",

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$UnlimitedLengthInDocumentLibrary = $null,

		[Parameter(Mandatory=$false)]
		[ValidateSet("","TRUE","FALSE")]
        [string]$HtmlRichText = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","FullHtml","ThemeHtml")]
        [string]$HtmlRichTextMode = "",

		[Parameter(Mandatory=$false)]
		[ValidateSet("","Boolean","Integer","Text","Note","DateTime")]   # http://msdn.microsoft.com/en-us/library/microsoft.sharepoint.spfieldtype(v=office.15).aspx
        [string]$CalculatedFormulaValueType = "",

		[Parameter(Mandatory=$false)]
        [string]$CalculatedFormula = "",

		[Parameter(Mandatory=$false)]
        [ValidateSet("","PeopleOnly","PeopleAndGroups")]
        [string]$UserSelectionMode = "",

		[Parameter(Mandatory=$false)]
        [Nullable[bool]]$UserAllowMultipleValues = $null,

		[Parameter(Mandatory=$false)]
        [string[]]$Choices = $null,

        [Parameter(Mandatory=$false)]
        [Nullable[bool]]$IsPathRendered = $null,

        [Parameter(Mandatory=$false)]
        [Nullable[bool]]$IsOpen = $null,

        [Parameter(Mandatory=$false)]
        [string]$TermStoreGroupName,

        [Parameter(Mandatory=$false)]
        [string]$TermSetName,

        [Parameter(Mandatory=$false)]
        [Nullable[bool]]$AllowMultipleValues = $null,

		[Parameter(Mandatory=$false)]
        [string]$CurrencyFormat,

        [Parameter(Mandatory=$false)]
        [string]$DecimalFormat,

        [Parameter(Mandatory=$false)]
        [string]$Description,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        $existingField = $Web.Fields | ? { $_.InternalName -eq $InternalName }
        if ($existingField -ne $null)
        {
            Write-SPHost -LogLevel $LogLevel -MessageLevel Normal "El campo '$InternalName' ya existe"
            return
        }

        $fieldXml = "<Field Type='$FieldType' ID='$Id' Name='$InternalName' DisplayName='$DisplayName' Description='$Description'></Field>"
        $Web.Fields.AddFieldAsXml($fieldXml)

        $newField = Update-SiteColumn -Web $Web -FieldType Calculated -InternalName $InternalName `
            -LocalizedDisplayNames $LocalizedDisplayNames -StaticName $StaticName -Group $Group `
            -Hidden $Hidden -Required $Required -Sealed $Sealed -MaxLength $MaxLength `
            -ShowInDisplayForm $ShowInDisplayForm -ShowInEditForm $ShowInEditForm `
            -ShowInListSettings $ShowInListSettings -ShowInNewForm $ShowInNewForm `
            -DateTimeFormat $DateTimeFormat `
            -UrlFormat $UrlFormat `
            -ImageRichText $ImageRichText -ImageRichTextMode $ImageRichTextMode `
            -LinkRichText $LinkRichText -LinkRichTextMode $LinkRichTextMode `
            -NoteRichText $NoteRichText -NoteRichTextMode $NoteRichTextMode -UnlimitedLengthInDocumentLibrary $UnlimitedLengthInDocumentLibrary `
            -HtmlRichText $HtmlRichText -HtmlRichTextMode $HtmlRichTextMode `
            -CalculatedFormulaValueType $CalculatedFormulaValueType -CalculatedFormula $CalculatedFormula `
            -UserSelectionMode $UserSelectionMode -UserAllowMultipleValues $UserAllowMultipleValues `
            -Choices $Choices `
            -IsPathRendered $IsPathRendered -TermStoreGroupName $TermStoreGroupName -IsOpen $IsOpen `
            -TermSetName $TermSetName -AllowMultipleValues $AllowMultipleValues -CurrencyFormat $CurrencyFormat -DecimalFormat $DecimalFormat `
            -LogLevel $LogLevel

        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Campo '$InternalName' creado"
	}
}

Function Remove-SiteColumn()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$true)]
        [string]$InternalName,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        if (-not $Web.Fields.ContainsField($InternalName))
        {
            Write-SPHost -LogLevel $LogLevel -MessageLevel Normal "Error eliminando el campo '$InternalName'. El campo no existe"
            return
        }
        $Web.Fields.Delete($InternalName)
    }
}

Function Update-SiteContentType()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPContentTypeId]$ContentTypeId,

		[Parameter(Mandatory=$false)]
        [string]$Description = $null,

        [Parameter(Mandatory=$false)]
        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$LocalizedNames = $null,

		[Parameter(Mandatory=$false)]
        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$LocalizedDescriptions = $null,


		[Parameter(Mandatory=$false)]
        [string]$Group = $null,

        [Parameter(Mandatory=$false)]
		[string]$DisplayFormUrl = $null,

        [Parameter(Mandatory=$false)]
		[string]$EditFormUrl = $null,

        [Parameter(Mandatory=$false)]
		[string]$NewFormUrl = $null,

        [Parameter(Mandatory=$false)]
        [Nullable[bool]]$Hidden = $null,

		[Parameter(Mandatory=$false)]
        [System.Xml.XmlElement]$Fields = $null,

        [Parameter(Mandatory=$false)]
        [bool]$UpdateChildren = $true,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        $contentType = $Web.ContentTypes | ? { $_.Id -eq $ContentTypeId }
        if ($contentType -eq $null)
        {
            Write-SPHost -LogLevel $LogLevel -MessageLevel Normal "Error actualizando el tipo de contenido '$ContentTypeId'. El tipo de contenido no existe"
            return
        }

        if ($Description -ne $null -and $Description -ne "") { $contentType.Description = $Description }
        if ($Group -ne $null -and $Group -ne "") { $contentType.Group = $Group }
        if ($DisplayFormUrl -ne $null -and $DisplayFormUrl -ne "") { $contentType.DisplayFormUrl = $DisplayFormUrl }
        if ($EditFormUrl -ne $null -and $EditFormUrl -ne "") { $contentType.EditFormUrl = $EditFormUrl }
        if ($NewFormUrl -ne $null -and $NewFormUrl -ne "") { $contentType.NewFormUrl = $NewFormUrl }
        if ($Hidden -ne $null) { $contentType.Hidden = $Hidden }

        if ($LocalizedNames -ne $null)
        {
			[int]$lcidThread = [System.Threading.Thread]::CurrentThread.CurrentUICulture.LCID
			[System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo([int]$Web.Language)

            $nameResource = $contentType.NameResource
            $LocalizedNames.GetEnumerator() | % {
                if ($Web.Language -eq $_.Key.LCID)
                {
                    $contentType.Name = $_.Value
					$contentType.Update($UpdateChildren)
                }
                $nameResource.SetValueForUICulture($_.Key, $_.Value)
				$nameResource.Update()
            }

			[System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($lcidThread)
        }
		 if ($LocalizedDescriptions -ne $null)
        {
			[int]$lcidThread = [System.Threading.Thread]::CurrentThread.CurrentUICulture.LCID
			[System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo([int]$Web.Language)

            $DescriptionResource = $contentType.DescriptionResource
            $LocalizedDescriptions.GetEnumerator() | % {
                if ($Web.Language -eq $_.Key.LCID)
                {
                    $contentType.Description = $_.Value
					$contentType.Update($UpdateChildren)
                }
                $DescriptionResource.SetValueForUICulture($_.Key, $_.Value)
				$DescriptionResource.Update()
            }

			[System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($lcidThread)
        }

        if ($Fields -ne $null)
        {
            $Fields.Add | % {
                if ($Web.AvailableFields.ContainsField($_.InternalName))
                {
                    $field = $Web.AvailableFields.GetFieldByInternalName($_.InternalName)
                    $fieldLink = New-Object Microsoft.SharePoint.SPFieldLink($field)
					$fieldLink.Required = (Get-BoolValueOrNull $_.Required)
                    $contentType.FieldLinks.Add($fieldLink)
                }
            }

			$Fields.Remove | % {
                if ($contentType.Fields.ContainsField($_.InternalName))
                {
                    $contentType.FieldLinks.Delete($_.InternalName)
                }
            }
        }

        $contentType.Update($UpdateChildren)

		$usages = [Microsoft.Sharepoint.SPContentTypeUsage]::GetUsages($contentType)

		foreach ($usage in $usages)
		{
			if ($usage.IsUrlToList)
			{
				$usageWeb = $Web.Site.OpenWeb($usage.Url, $false);

				if ($usageWeb)
				{
					$list = $usageWeb.GetList($usage.Url)

					if ($list)
					{
						foreach ($listContentType in $list.ContentTypes)
						{
							if (($listContentType.Name -eq $contentType.Name) -or ($listContentType.Parent.Name -eq $contentType.Name))
							{
								if ($LocalizedNames -ne $null)
								{
									[int]$lcidThread = [System.Threading.Thread]::CurrentThread.CurrentUICulture.LCID
									[System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo([int]$usageWeb.Language)

									$listNameResource = $listContentType.NameResource

									$LocalizedNames.GetEnumerator() | % {
										if ($usageWeb.Language -eq $_.Key.LCID)
										{
											$listContentType.Name = $_.Value
											$listContentType.Update()

											Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Tipo de contenido de lista $($listContentType.Name) actualizado en $($usageWeb.Url)/$($list.RootFolder.Url)"
										}

										$listNameResource.SetValueForUICulture($_.Key, $_.Value)
										$listNameResource.Update()

										Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Tipo de contenido de lista $($listContentType.Name) nombre actualizado con $($_.Key), $($_.Value) en $($usageWeb.Url)/$($list.RootFolder.Url)"
									}

									[System.Threading.Thread]::CurrentThread.CurrentUICulture = New-Object System.Globalization.CultureInfo($lcidThread)
								}
							}
						}
					}
				}
			}
		}
    }
}

Function New-SiteContentType()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPContentTypeId]$ContentTypeId,

		[Parameter(Mandatory=$true)]
        [string]$Name,

		[Parameter(Mandatory=$false)]
        [string]$Description = $null,

        [Parameter(Mandatory=$false)]
        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$LocalizedNames = $null,

		[Parameter(Mandatory=$false)]
        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$LocalizedDescriptions = $null,

		[Parameter(Mandatory=$true)]
        [string]$Group,

        [Parameter(Mandatory=$false)]
		[string]$DisplayFormUrl = $null,

        [Parameter(Mandatory=$false)]
		[string]$EditFormUrl = $null,

        [Parameter(Mandatory=$false)]
		[string]$NewFormUrl = $null,

        [Parameter(Mandatory=$false)]
        [bool]$Hidden = $false,

        [Parameter(Mandatory=$false)]
        [System.Xml.XmlElement]$Fields = $null,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        $contentType = $Web.ContentTypes | ? { $_.Id -eq $ContentTypeId }
        if ($contentType -ne $null)
        {
            Write-SPHost -LogLevel $LogLevel -MessageLevel Normal "El tipo de contenido '$ContentTypeId' ya existe"
            return
        }

        $parent = $Web.AvailableContentTypes | ? { $_.Id -eq $ContentTypeId.Parent }
        if ($parent -eq $null)
        {
            Write-SPHost -LogLevel $LogLevel -MessageLevel Normal "El tipo de contenido del que hereda '$InternalName' no existe"
            return
        }

        [Microsoft.SharePoint.SPContentType]$contentType = New-Object Microsoft.SharePoint.SPContentType($ContentTypeId, $Web.ContentTypes, $Name)
        $Web.ContentTypes.Add($contentType) | Out-Null
		$Web.Update()

        Update-SiteContentType -Web $Web -ContentTypeId $ContentTypeId `
            -Description $Description -LocalizedNames $LocalizedNames `
			-LocalizedDescriptions $LocalizedDescriptions `
            -Group $Group -Hidden $Hidden `
            -DisplayFormUrl $DisplayFormUrl -EditFormUrl $EditFormUrl -NewFormUrl $NewFormUrl `
            -Fields $Fields `
            -LogLevel $LogLevel


        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Tipo de contenido '$ContentTypeId' creado"
	}
}

Function Remove-SiteContentType()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPContentTypeId]$ContentTypeId,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        $contentType = $Web.ContentTypes | ? { $_.Id -eq $ContentTypeId }
        if ($contentType -eq $null)
        {
            Write-SPHost -LogLevel $LogLevel -MessageLevel Normal "Error eliminando el tipo de contenido '$ContentTypeId'. El tipo de contenido no existe"
            return
        }

        $Web.ContentTypes.Delete($ContentTypeId)
        $Web.Update()
    }
}

Function Modify-ContenType
{
	[CmdletBinding()]
	# Parameters for the function
	Param
	(
		
	    [Parameter(Mandatory=$true,position=0)]
	    [String]$SiteUrl,
		[Parameter(Mandatory=$true,position=1)]
	    [String]$ContentName,
		[Parameter(Mandatory=$true,position=2)]
	    [String]$ColumnName,
		[Parameter(Mandatory=$true,position=3,ParameterSetName="Required")]
	    [Switch]$Required
	)
				
		$site=Get-SPSite -Identity $SiteUrl
		$web=$site.RootWeb		
		$MyContentType=$web.ContentTypes[$ContentName]				
		$MyField=$MyContentType.Fields[$ColumnName]		
		If($Required)
		{
			$MyContentType.FieldLinks[$MyField.Id].Required=$true
		}
		Else
		{
			$MyContentType.FieldLinks[$MyField.Id].Required=$False
		}
		$MyContentType.Update($true)
		Write-Host "El estado de $ColumnName se ha modificado" -ForegroundColor Green
	
	
}