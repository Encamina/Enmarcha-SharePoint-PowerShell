 Param(  
  [string] $siteUrl = $(throw "Error: Parameter siteUrl is required"),  
  [string] $pathConfiguration = $(throw "Error: Parameter pathConfiguration is required"),  
  [boolean]$emptyfirst  
 )  
 ##Variables that should not be edited  
 $termsetName="Custom Navigation"  
 function CreateTerm( $parent, $name, $url )  
 {  
  Write-Host "Agregando el término $($parent.Name) -> $name"  
   $term = $parent.CreateTerm("$name", 1033)  
  $term.IsAvailableForTagging = $false  
  $term.SetLocalCustomProperty("_Sys_Nav_ExcludedProviders", '"CurrentNavigationTaxonomyProvider"')  
  $term.SetLocalCustomProperty("_Sys_Nav_SimpleLinkUrl", $url)    
  return $term  
 }  
 function GetTerm($termName, $parent, $customProperty, $propertyValue, $translation, $translationLCID)  
 {  
   $termName = [Microsoft.SharePoint.Taxonomy.TaxonomyItem]::NormalizeName($termName)  
   $term = $null  
  if( $termName -ne "" -and $parent -ne $null ){  
	  if( $parent.Terms -ne $null ) {  
	   $term = $parent.Terms | Where-Object {$_.Name -eq "$termName"}  
	  }  
	  if($term -eq $null ){  
	   $term = CreateTerm -parent $parent -name "$termName" -url $_.URL  
	  }  

	  if ($customProperty -ne $null -and $customProperty -ne ''){
		$term.SetCustomProperty($customProperty, $propertyValue)
	  }

	  if($translation -ne $null -and $translation -ne "" -and $translationLCID -ne $null -and $translationLCID -ne ""){
		$label = $term.Labels | where { $_.Language -eq $translationLCID }
		if($label -eq $null){ $label = $term.CreateLabel($translation, $translationLCID, $false); }
		$label.Value = $translation
      }
  }  
  return $term;  
 }  

 function ImportTermSet([Microsoft.SharePoint.Taxonomy.TermSet]$set, [PSCustomObject]$terms) {   
  $terms | foreach {  
	$level1TermName = $_."Level 1 Term"  
	$level2TermName = $_."Level 2 Term"  
	$level3TermName = $_."Level 3 Term"  
	$translation = $_."Translation"
	$translationLCID = $_."TranslationLCID" 
	$customProperty = $_.CustomProperty
	$propertyValue = $_.PropertyValue
	  
	if ($level2TermName -eq '') { 
		$level1Term = GetTerm -termName $level1TermName -parent $set -customProperty $customProperty -propertyValue $propertyValue -translation $translation -translationLCID $translationLCID
	} else {
		$level1Term = GetTerm -termName $level1TermName -parent $set -translation $translation -translationLCID $translationLCID
	}

	if ($level3TermName -eq '') {
		$level2Term = GetTerm -termName $level2TermName -parent $level1Term -customProperty $customProperty -propertyValue $propertyValue -translation $translation -translationLCID $translationLCID
	} else {
		$level2Term = GetTerm -termName $level2TermName -parent $level1Term -translation $translation -translationLCID $translationLCID
	}

	$level3Term = GetTerm -termName $level3TermName -parent $level2Term -customProperty $customProperty -propertyValue $propertyValue -translation $translation -translationLCID $translationLCID
  }  
  $ErrorActionPreference = "Continue";  
 }  
 
 Import-Module WebAdministration  
 Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue  
 $termsetName="My Navigation"  
 $site = Get-SPSite $siteUrl  
 $web = $site.RootWeb  
 $session = [Microsoft.SharePoint.Publishing.Navigation.TaxonomyNavigation]::CreateTaxonomySessionForEdit($web)  
 $store = $session.TermStores[0]    
 $group = $session.TermStores.Groups | Where-Object {$_.SiteCollectionAccessIds -eq $site.ID }  
 $navigationSet = $group.TermSets | where { $_.Name -eq $termsetName }  
 if( $navigationSet -ne $null -and $emptyfirst) {  
  Write-Host -ForegroundColor Yellow "Eliminando el conjunto de términos existente"  
  $navigationSet.Delete()  
  $navigationSet = $null  
 }  
 if( $navigationSet -eq $null) {  
  Write-Host -ForegroundColor Green "Creando conjunto de términos"  
  $navigationSet = $group.CreateTermSet($termsetName)  
 }  
 $navigationSet.SetCustomProperty("_Sys_Nav_IsNavigationTermSet", "True")  
 $navigationSet.SetCustomProperty("_Sys_Nav_AttachedWeb_SiteId", $site.ID.ToString())  
 $navigationSet.SetCustomProperty("_Sys_Nav_AttachedWeb_WebId", $site.RootWeb.ID.ToString())   
 $navigationSet.SetCustomProperty("_Sys_Nav_AttachedWeb_OriginalUrl", $site.RootWeb.Url )  
 #2013-02-05T12:52:07.5250653Z  
 $date = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"   
 $navigationSet.SetCustomProperty("_Sys_Nav_AttachedWeb_Timestamp", $date )  
 Write-Host "Importando el conjunto de términos desde el fichero CSV"  
 $currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
 $dir = "$pathConfiguration\Navigation"
   
 If (Test-Path $dir) {
 $fileEntries = [IO.Directory]::GetFiles($dir);   
 foreach($fileName in $fileEntries)   
 {   
  $ext=[System.IO.Path]::GetExtension($fileName)  
  if($ext -eq ".csv")  
  {  
  Write-Host -ForegroundColor Green "Procesando $fileName"  
  $CSVFILEPATH=$fileName;  
  $terms = Import-Csv -Delimiter ';' $fileName  
  ImportTermSet $navigationSet $terms  
  
  OrderTaxonomyTerms $navigationSet $terms
  Write-Host "Todos los conjuntos de términos han sido importados"
   }  
 }  
 $store.CommitAll()   
 Write-Host "Configurando la navegación del sitio para que use los metadatos administrados"  
 $settings = new-object Microsoft.SharePoint.Publishing.Navigation.WebNavigationSettings($web);  
 $settings.GlobalNavigation.Source = [Microsoft.SharePoint.Publishing.Navigation.StandardNavigationSource]::TaxonomyProvider  
 $settings.GlobalNavigation.TermStoreId = $store.Id  
 $settings.GlobalNavigation.TermSetId = $navigationSet.Id  
  $settings.Update($session) 
	 }
 $web.Update()  