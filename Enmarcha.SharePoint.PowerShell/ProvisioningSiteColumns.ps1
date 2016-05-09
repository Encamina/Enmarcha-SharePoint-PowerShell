

Param(
        [Parameter(Mandatory=$True,Position=1)]
        [string]$sitecollectionURL,
        [Parameter(Mandatory=$True)]
        [string]$filepath
     )
Process
{
   $snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
   if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }
    # Reference the CSV holding the Site Column values and begin the loop
    $create = Import-Csv -Path $filepath -Encoding UTF8 -Delimiter ","
    # Get Site and Web object
    $site = Get-SPSite -Identity $sitecollectionUrl
    $web = $site.RootWeb

  foreach($row in $create)
      {


         #Assign fieldXML variable with XML string for site column
         $fieldXML = '<Field Type="'+$row.FieldType+'"
         ID="{'+$row.IdField+'}"
         Name="'+$row.Nombre+'"
         DisplayName="'+$row.DisplayName+'"
         StaticName="'+$row.StaticName+'"
         Group="'+$row.Group+'" '

         IF ($row.FieldType -eq "DateTime")
         {
            $fieldXML = $fieldXML + 'Format="DateOnly" '
         }

         IF (($row.FieldType -eq "URL") -and ($row.StaticName.StartsWith("Image")))
         {
                $fieldXML = $fieldXML + 'Format="Image" '
         }
         ELSEIF (($row.FieldType -eq "URL") -and ($row.("URL.URLFormat") -ne ""))
         {
            $fieldXML = $fieldXML + 'Format="'+$row.("URL.URLFormat")+'" '
         }

        IF (($row.FieldType -eq "Note") -and ($row.StaticName.StartsWith("Cuerpo")))
        {
            $fieldXML = $fieldXML + 'RichText="TRUE" '
        }
        ELSEIF (($row.FieldType -eq "Note") -and ($row.RichText -ne ""))
        {
            $fieldXML = $fieldXML + 'RichText="'+$row.("Note.RichText")+'" '

            IF ($row.RichTextMode -ne "")
            {
                $fieldXML = $fieldXML + 'RichTextMode="'+$row.("Note.RichTextMode")+'" '
            }
        }

        IF (($row.FieldType -eq "Calculated") -and ($row.("Calculated.FormulaValueType") -ne ""))
        {
            $fieldXML = $fieldXML + 'ResultType="'+$row.("Calculated.FormulaValueType")+'" '
        }

        IF (($row.FieldType -eq "User") -and ($row.UserSelectionMode -ne ""))
        {
            $fieldXML = $fieldXML + 'UserSelectionMode="'+$row.UserSelectionMode+'" '
        }


        $fieldXML = $fieldXML + 'Hidden="'+$row.Hidden+'"
        Required="'+$row.Required+'"
        Sealed="'+$row.Sealed+'"
        ShowInDisplayForm="'+$row.ShowInDisplayForm+'"
        ShowInEditForm="'+$row.ShowInEditForm+'"
        ShowInListSettings="'+$row.ShowInListSettings+'"
        ShowInNewForm="'+$row.ShowInNewForm+'">'

        IF (($row.FieldType -eq "Choice") -and ($row.Choices -ne "") -and ($row.Choices.Contains(";#")))
         {
            $arrChoices = $row.Choices.Split(";#");
            $fieldXML = $fieldXML + '<CHOICES>'

            FOR ($i = 0; $i -lt $arrChoices.length; $i++)
                {
	                IF ($arrChoices[$i] -ne "")
	                {
	                         $fieldXML = $fieldXML + '<CHOICE>' + $arrChoices[$i] + '</CHOICE>'
	                }
                }

            $fieldXML = $fieldXML + '</CHOICES>'
        } 
        IF (($row.FieldType -eq "Calculated") -and ($row."Calculated.Formula" -ne ""))
        {
            $fieldXML = $fieldXML + '<Formula>'    
            $strFormula = $row."Calculated.Formula"     
            IF ($strFormula.StartsWith('"'))
            {
                $strFormula = $strFormula.Substring(1, $strFormula.Length - 1)
            }
  
            IF ($strFormula.EndsWith('"'))
            {
                $strFormula = $strFormula.Substring(0, $strFormula.Length - 1)
            }
  
            $fieldXML = $fieldXML + $strFormula    
            $fieldXML = $fieldXML + '</Formula>'
        }
 
        $fieldXML = $fieldXML + '</Field>' 

        #Output XML to console
        write-host $fieldXML
        IF($row.FieldType -eq "TaxonomyFieldType")
        {

            $centralAdmin = Get-SPWebApplication -IncludeCentralAdministration | Where {$_.IsAdministrationWebApplication} | Get-SPSite  
            $session = new-object Microsoft.SharePoint.Taxonomy.TaxonomySession($centralAdmin)
            $serviceApp = Get-SPServiceApplication | Where {$_.TypeName -like "*Metadata*"}                 
			$termStore =$session.TermStores[0] 
            $groupName= $row."TaxonomyFieldType.TermStoreGroupName"
            $termName=  $row."TaxonomyFieldType.TermSetName"
            $termSet = $termStore.Groups[$groupName].TermSets[$termName] 
            $taxonomyField = $web.Fields.CreateNewField("TaxonomyFieldType", $row.DisplayName)
            $taxonomyField.SspId = $termSet.TermStore.Id
            $taxonomyField.TermSetId = $termSet.Id
            $taxonomyField.AllowMultipleValues = [System.Convert]::ToBoolean($row."TaxonomyFieldType.AllowMultipleValues")
            $taxonomyField.Group =  $row.Group        
            $taxonomyField.ShowInEditForm = [System.Convert]::ToBoolean($row.ShowInEditForm)
            $taxonomyField.ShowInNewForm = [System.Convert]::ToBoolean( $row.ShowInNewForm)
            $taxonomyField.ShowInDisplayForm = [System.Convert]::ToBoolean($row.ShowInDisplayForm)
            $taxonomyField.ShowInListSettings =   [System.Convert]::ToBoolean($row.ShowInListSettings)
            $taxonomyField.Hidden = [System.Convert]::ToBoolean($row.Hidden)
            $taxonomyField.Required = [System.Convert]::ToBoolean($row.Required)
            $taxonomyField.StaticName = $row.StaticName
            $web.Fields.Add($taxonomyField);
            $web.Update();
 
        }
        ELSE
        {
            # Create Site Column from XML string
            $web.Fields.AddFieldAsXml($fieldXML)
            $field = $web.fields.getfield($row.DisplayName)
            $field.Group = $row.Group 
            $field.Update()
      
        }
    }    
    $web.Dispose()
    $site.Dispose()
}
