$snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$currentPath\EnmarchaFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

function ImportTermSet
(
    [Microsoft.SharePoint.Taxonomy.TermStore]$store,
    [string]$groupName,
    [PSCustomObject]$termSet)

{
    function ImportTerm(
        [Microsoft.SharePoint.Taxonomy.Group]$group,
        [Microsoft.SharePoint.Taxonomy.TermSet]$set,
        [Microsoft.SharePoint.Taxonomy.Term]$parent,

        [string[]]$path,
        [int]$lcid,
        [string]$availableForTagging,
        [string]$translation,
        [int]$translationLCID) {
        if ($path.Length -eq 0) {
            return
        } elseif ($group -eq $null) {
            $group = $store.Groups | where { $_.Name -eq $path[0] }
            if ($group -eq $null) {
                Write-Host -ForegroundColor Green "Creando grupo $path[0]"
                $group = $store.CreateGroup($path[0])
                Write-Host -ForegroundColor Green "Grupo creado $path[0]"
            }
        } elseif ($set -eq $null) {
            $set = $group.TermSets | where { $_.Name -eq $path[0] }
            if ($set -eq $null) {
                Write-Host -ForegroundColor Green "Creando conjunto de términos $path[0]"
                $set = $group.CreateTermSet($path[0])
                Write-Host -ForegroundColor Green "Conjunto de términos creado $path[0]"
            }
        } else {
            $node = if ($parent -eq $null) { $set } else { $parent }
			$pathNorm = [Microsoft.SharePoint.Taxonomy.TermSet]::NormalizeName($path[0])
            $parent = $node.Terms | where { $_.Name -eq $pathNorm }
            if ($parent -eq $null) {
                Write-Host -ForegroundColor Green "Creando término $path[0]"
                $parent = $node.CreateTerm($path[0], $lcid)
                if($availableForTagging -eq "false"){
                    $parent.IsAvailableForTagging = $false
                }
                Write-Host -ForegroundColor Green "Término creado $path[0]"  
            }
            if($translation -ne $null -and $translation -ne "" -and $translationLCID -ne $null -and $translationLCID -ne ""){
                    $label = $parent.Labels | where { $_.Language -eq $translationLCID }
                    if($label -eq $null){ $label = $parent.CreateLabel($translation, $translationLCID, $false); }
                    $label.Value = $translation
                }
        }

        ImportTerm $group $set $parent $path[1..($path.Length)] -lcid $lcid -availableForTagging $availableForTagging -translation $translation -translationLCID $translationLCID
    }

    $termSetName = $termSet[0]."Term Set Name"
    $termSet | where { $_."Level 1 Term" -ne "" } | foreach {
        $path = @($groupName, $termSetName) + @(for ($i = 1; $i -le 7; $i++) {
            $term = $_."Level $i Term"
            if ($term -eq "") {
                break
            } else {
                $term
            }
        }
        )
        ImportTerm -path $path -lcid $_.LCID -availableForTagging $_."Available for Tagging" -translation $_.Translation -translationLCID $_.TranslationLCID		

    }
	$group = $store.Groups | where { $_.Name -eq $groupName } 
	$set = $group.TermSets | where { $_.Name -eq $termSetName }

	if ($termSet[0].IsOpenForTermCreation -eq 'true' -or $termSet[0].IsOpenForTermCreation -eq 'True')
	{
		$set.IsOpenForTermCreation = $true
	}
	else
	{
		$set.IsOpenForTermCreation = $false
	}

	if ($termSet[0]."Custom sort" -eq "true")
	{
		OrderTaxonomyTerms $set $termSet
		Write-Host "Los términos del conjunto $termSetName han sido ordenados"
	}
	else
	{
		$set.CustomSortOrder = ''
	}
}



