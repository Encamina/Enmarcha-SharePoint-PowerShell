Param
(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Taxonomy.TermStore]$store, 
	[Parameter(Mandatory=$true)]
	[string] $groupName, 
	[Parameter(Mandatory=$true)]
	[string] $termSet, 
	[Parameter(Mandatory=$true)]
	[string] $l1term, 
	[Parameter(Mandatory=$false)]
	[string] $l2term, 
	[Parameter(Mandatory=$false)]
	[string] $l3term, 
	[Parameter(Mandatory=$true)]
	[string] $propertyName,
	[Parameter(Mandatory=$true)]
	[string] $propertyValue 
) 
Process
{
	$snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }    	 
	$group = $store.Groups[$groupName]
		
	$TermSetName = $group.TermSets[$termSet]
	Write-Host 
	$TermName = $TermSetName.Terms[$l1term]
    if($l2term -ne ""){ $TermName = $TermName.Terms[$l2term] }
    if($l3term -ne ""){ $TermName = $TermName.Terms[$l3term] }
	$TermName.SetCustomProperty($propertyName, $propertyValue)
	Write-Host "Término $l1term Propiedad agregada" -ForegroundColor Green
	return $true
}
