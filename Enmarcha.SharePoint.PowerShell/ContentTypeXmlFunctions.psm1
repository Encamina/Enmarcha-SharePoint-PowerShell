$snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$currentPath\EnmarchaFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$currentPath\ContentTypeFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

Function Get-StringArrayFromChoices()
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$Choices = $null
    )
    Process
    {
        if ($Choices -eq $null -or $Choices -eq "") { return $null }
        return ($Choices.Split(";#", [System.StringSplitOptions]::RemoveEmptyEntries))
    }
}

Function Get-LocalizedDisplayNamesDictionary()
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [System.Xml.XmlElement]$Xml = $null
    )
    Process
    {
        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$displayNames = $null
        if ($Xml.DisplayName -ne $null -and $Xml.DisplayName -ne "")
        {
            $displayNames = New-Object "System.Collections.Generic.Dictionary``2[System.Globalization.CultureInfo,string]"
            $Xml.DisplayName | % {
                $cultureInfo = New-Object System.Globalization.CultureInfo($_.Label)
                $displayNames.Add($cultureInfo, $_.Value)
            }
        }

        return $displayNames
    }
}
Function Get-LocalizedDescriptionResourcesDictionary()
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [System.Xml.XmlElement]$Xml = $null
    )
    Process
    {
        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$descriptionResources = $null
        if ($Xml.DescriptionResource -ne $null -and $Xml.DescriptionResource -ne "")
        {
            $descriptionResources = New-Object "System.Collections.Generic.Dictionary``2[System.Globalization.CultureInfo,string]"
            $Xml.DescriptionResource | % {
                $cultureInfo = New-Object System.Globalization.CultureInfo($_.Label)
                $descriptionResources.Add($cultureInfo, $_.Value)
            }
        }

        return $descriptionResources
    }
}

Function Update-SiteColumnFromXml()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$Xml,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Iniciando función Update-SiteColumnFromXml en el sitio: $($Web.Url) Xml: $($Xml.OuterXml)"

        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$displayNames = Get-LocalizedDisplayNamesDictionary -Xml $Xml.DisplayNames

        if ($displayNames -eq $null)
        {
            $displayName = $Xml.Name
        }
        else
        {
            $displayName = $displayNames.Values | Select-Object -First 1
        }

        Update-SiteColumn -Web $Web -InternalName $Xml.Name `
            -LocalizedDisplayNames $displayNames `
            -StaticName $Xml.StaticName -Group $Xml.Group `
            -Hidden (Get-BoolValueOrNull $Xml.Hidden) -Required (Get-BoolValueOrNull $Xml.Required) -Sealed (Get-BoolValueOrNull $Xml.Sealed) `
			-MaxLength $Xml.MaxLength `
            -ShowInDisplayForm (Get-BoolValueOrNull $Xml.ShowInDisplayForm) -ShowInEditForm (Get-BoolValueOrNull $Xml.ShowInEditForm) `
            -ShowInListSettings (Get-BoolValueOrNull $Xml.ShowInListSettings) -ShowInNewForm (Get-BoolValueOrNull $Xml.ShowInDisplayForm) `
            -UpdateChildren $true -LogLevel $LogLevel `
            -DateTimeFormat $Xml.DateTime.Format `
            -UrlFormat $Xml.Url.URLFormat `
            -ImageRichText $Xml.Image.RichText -ImageRichTextMode $Xml.Image.RichTextMode `
            -LinkRichText $Xml.Link.RichText -LinkRichTextMode $Xml.Link.RichTextMode `
            -NoteRichText $Xml.Note.RichText -NoteRichTextMode $Xml.Note.RichTextMode `
            -UnlimitedLengthInDocumentLibrary (Get-BoolValueOrNull $Xml.Note.UnlimitedLengthInDocumentLibrary) `
            -HtmlRichText $Xml.Html.RichText -HtmlRichTextMode $Xml.Html.RichTextMode `
            -CalculatedFormulaValueType $Xml.Calculated.FormulaValueType -CalculatedFormula $Xml.Calculated.Formula `
            -UserSelectionMode $xml.User.UserSelectionMode -UserAllowMultipleValues (Get-BoolValueOrNull $Xml.User.AllowMultipleValues) `
            -Choices (Get-StringArrayFromChoices $Xml.Choice.Choices) `
            -IsPathRendered (Get-BoolValueOrNull $Xml.TaxonomyFieldType.FullPathRendered) `
			-IsOpen (Get-BoolValueOrNull $Xml.TaxonomyFieldType.IsOpen) `
            -AllowMultipleValues (Get-BoolValueOrNull $Xml.TaxonomyFieldType.AllowMultipleValues) `
            -TermStoreGroupName $Xml.TaxonomyFieldType.TermStoreGroupName -TermSetName $Xml.TaxonomyFieldType.TermSetName `
			-CurrencyFormat $Xml.CurrencyFormat -DecimalFormat $Xml.DecimalFormat
    }
}

Function New-SiteColumnFromXml()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$Xml,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Iniciando función New-SiteColumnFromXml en el sitio: $($Web.Url) Xml: $($Xml.OuterXml)"

        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$displayNames = Get-LocalizedDisplayNamesDictionary -Xml $Xml.DisplayNames

        if ($displayNames -eq $null)
        {
            $displayName = $Xml.Name
        }
        else
        {
            $displayName = $displayNames.Values | Select-Object -First 1
        }

        New-SiteColumn -Web $Web -FieldType $Xml.FieldType -InternalName $Xml.Name -Id ([System.Guid]::Parse($Xml.Id)) `
            -DisplayName $displayName -LocalizedDisplayNames $displayNames `
            -StaticName $Xml.StaticName -Group $Xml.Group `
            -Hidden (Get-BoolValueOrNull $Xml.Hidden) -Required (Get-BoolValueOrNull $Xml.Required) -Sealed (Get-BoolValueOrNull $Xml.Sealed) `
			-MaxLength $Xml.MaxLength `
            -ShowInDisplayForm (Get-BoolValueOrNull $Xml.ShowInDisplayForm) -ShowInEditForm (Get-BoolValueOrNull $Xml.ShowInEditForm) `
            -ShowInListSettings (Get-BoolValueOrNull $Xml.ShowInListSettings) -ShowInNewForm (Get-BoolValueOrNull $Xml.ShowInNewForm) `
            -LogLevel $LogLevel `
            -DateTimeFormat $Xml.DateTime.Format `
            -UrlFormat $Xml.Url.URLFormat `
            -ImageRichText $Xml.Image.RichText -ImageRichTextMode $Xml.Image.RichTextMode `
            -LinkRichText $Xml.Link.RichText -LinkRichTextMode $Xml.Link.RichTextMode `
            -NoteRichText $Xml.Note.RichText -NoteRichTextMode $Xml.Note.RichTextMode `
            -UnlimitedLengthInDocumentLibrary (Get-BoolValueOrNull $Xml.Note.UnlimitedLengthInDocumentLibrary) `
            -HtmlRichText $Xml.Html.RichText -HtmlRichTextMode $Xml.Html.RichTextMode `
            -CalculatedFormulaValueType $Xml.Calculated.FormulaValueType -CalculatedFormula $Xml.Calculated.Formula `
            -UserSelectionMode $xml.User.UserSelectionMode -UserAllowMultipleValues (Get-BoolValueOrNull $Xml.User.AllowMultipleValues) `
            -Choices (Get-StringArrayFromChoices $Xml.Choice.Choices) `
            -IsPathRendered (Get-BoolValueOrNull $Xml.TaxonomyFieldType.FullPathRendered) `
			-IsOpen (Get-BoolValueOrNull $Xml.TaxonomyFieldType.IsOpen) `
            -AllowMultipleValues (Get-BoolValueOrNull $Xml.TaxonomyFieldType.AllowMultipleValues) `
            -TermStoreGroupName $Xml.TaxonomyFieldType.TermStoreGroupName -TermSetName $Xml.TaxonomyFieldType.TermSetName `
			-CurrencyFormat $Xml.CurrencyFormat -DecimalFormat $Xml.DecimalFormat
    }
}

Function Remove-SiteColumnFromXml()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$Xml,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Iniciando función Remove-SiteColumnFromXml en el sitio: $($Web.Url) Xml: $($Xml.OuterXml)"

        Remove-SiteColumn -Web $Web -InternalName $Xml.Name -LogLevel $LogLevel
    }
}

Function Update-SiteContentTypeFromXml()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$Xml,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Iniciando función Update-SiteContentTypeFromXml en el sitio: $($Web.Url) Xml: $($Xml.OuterXml)"

        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$names = Get-LocalizedDisplayNamesDictionary -Xml $Xml.DisplayNames
        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$descriptions = Get-LocalizedDescriptionResourcesDictionary -Xml $Xml.DescriptionResources

        $hidden = $false
        if ($xml.Hidden -ne $null) { $hidden = [System.Convert]::ToBoolean($Xml.Required) }

        Update-SiteContentType -Web $Web -ContentTypeId (New-Object Microsoft.SharePoint.SPContentTypeId ($Xml.Id)) `
            -Description $Xml.Description -LocalizedNames $names `
			-LocalizedDescriptions $descriptions `
            -Group $Xml.Group `
            -DisplayFormUrl $Xml.DisplayFormUrl -EditFormUrl $Xml.EditFormUrl -NewFormUrl $Xml.NewFormUrl `
            -Hidden $hidden `
            -Fields $Xml.Fields `
            -UpdateChildren $true -LogLevel $LogLevel
    }
}

Function New-SiteContentTypeFromXml()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$Xml,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Iniciando función New-SiteContentTypeFromXml en el sitio: $($Web.Url) Xml: $($Xml.OuterXml)"

        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$names = Get-LocalizedDisplayNamesDictionary -Xml $Xml.DisplayNames
        [System.Collections.Generic.Dictionary[System.Globalization.CultureInfo,string]]$descriptions = Get-LocalizedDescriptionResourcesDictionary -Xml $Xml.DescriptionResources

        $hidden = $false
        if ($xml.Hidden -ne $null) { $hidden = [System.Convert]::ToBoolean($Xml.Required) }

        New-SiteContentType -Web $Web -ContentTypeId ((New-Object Microsoft.SharePoint.SPContentTypeId ($Xml.Id))) `
            -Name $Xml.Name -Description $Xml.Description -LocalizedNames $names `
			-LocalizedDescriptions $descriptions `
            -Group $Xml.Group `
            -DisplayFormUrl $Xml.DisplayFormUrl -EditFormUrl $Xml.EditFormUrl -NewFormUrl $Xml.NewFormUrl `
            -Hidden $hidden `
            -Fields $Xml.Fields `
            -LogLevel $LogLevel
    }
}

Function Remove-SiteContentTypeFromXml()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$Xml,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        Write-SPHost -LogLevel $LogLevel -MessageLevel Verbose "Iniciando función Remove-SiteContentTypeFromXml en el sitio: $($Web.Url) Xml: $($Xml.OuterXml)"

        Remove-SiteContentType -Web $Web -ContentTypeId (New-Object Microsoft.SharePoint.SPContentTypeId ($Xml.Id)) -LogLevel $LogLevel
    }
}

Function Import-ContentTypeXmlFile()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        [xml]$manifest = Get-Content $Path -Encoding UTF8

        if ($manifest.Site.SiteColumns.Add -ne $null)
        {
            $manifest.Site.SiteColumns.Add | % {
                New-SiteColumnFromXml -Xml $_ -Web $Web -LogLevel $LogLevel | Out-Null
            }
        }

        if ($manifest.Site.SiteColumns.Update -ne $null)
        {
            $manifest.Site.SiteColumns.Update | % {
                Update-SiteColumnFromXml -Xml $_ -Web $Web -LogLevel $LogLevel | Out-Null
            }
        }

        if ($manifest.Site.SiteColumns.Remove -ne $null)
        {
            $manifest.Site.SiteColumns.Remove | % {
                Remove-SiteColumnFromXml -Xml $_ -Web $Web -LogLevel $LogLevel | Out-Null
            }
        }

        if ($manifest.Site.ContentTypes.Add -ne $null)
        {
            $manifest.Site.ContentTypes.Add | % {
                New-SiteContentTypeFromXml -Xml $_ -Web $Web -LogLevel $LogLevel | Out-Null
            }
        }
		if ($manifest.Site.ContentTypes.Add.Required.Fields -ne $null)
        {
			$manifest.Site.ContentTypes.Add.Required.Fields.Add | %	{	
				Write-Host "Modificando $($_.DisplayName)" -ForegroundColor Blue
				Write-Host "Tipo de Contenido $($manifest.Site.ContentTypes.Add.Name)" -ForegroundColor Blue
				Write-Host "Url $($Web.Url)" -ForegroundColor Blue
				Modify-ContenType -SiteUrl $Web.Url -ContentName $manifest.Site.ContentTypes.Add.DisplayName -ColumnName $_.DisplayName -Required	
			}			
		}
        if ($manifest.Site.ContentTypes.Update -ne $null)
        {
            $manifest.Site.ContentTypes.Update | % {
                Update-SiteContentTypeFromXml -Xml $_ -Web $Web -LogLevel $LogLevel | Out-Null
            }
        }

        if ($manifest.Site.ContentTypes.Remove -ne $null)
        {
            $manifest.Site.ContentTypes.Remove | % {
                Remove-SiteContentTypeFromXml -Xml $_ -Web $Web -LogLevel $LogLevel | Out-Null
            }
        }

    }
}

Function Import-ContentTypesXmlFiles()
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [string]$ContentTypeMinVersion = $null,

        [Parameter(Mandatory=$false)]
        [string]$ContentTypeMaxVersion = $null,

        [Parameter(Mandatory=$true)]
        [Microsoft.SharePoint.SPWeb]$Web,

		[Parameter(Mandatory=$false)]
        [SPLogLevel]$LogLevel = [SPLogLevel]::Normal
    )
    Process
    {
        [string]$prefix = "ContentTypes-"
        Get-ChildItem -Path $Path -Filter "$prefix*" | Sort-Object -Property Name | % {
            [string]$version = $_.Name.Substring($prefix.Length).Split('-')[0]

            if ($ContentTypeMinVersion -eq $null -or $ContentTypeMinVersion -eq "" -or $version -ge $ContentTypeMinVersion)
            {
                if ($ContentTypeMaxVersion -eq $null -or $ContentTypeMaxVersion -eq "" -or $version -le $ContentTypeMaxVersion)
                {
                    Import-ContentTypeXmlFile -Path $_.FullName -Web $Web -LogLevel $LogLevel
                }
            }
        }
    }
}