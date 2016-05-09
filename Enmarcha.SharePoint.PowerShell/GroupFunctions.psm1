$snapin = Get-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }

$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$currentPath\EnmarchaFunctions.psm1" -PassThru -Force -DisableNameChecking | Out-Null

Function Created-Group()
{
Param
(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [Parameter(Mandatory=$false)]
    [string]$GroupsFile ,
    [Parameter(Mandatory=$false)]  
    [string]$WebSiteUrl
)

 Process
    {



$web = Get-SPWeb($WebSiteUrl);

$file = Import-Csv -Path "$Path\$groupsFile" -Encoding UTF8 -Delimiter ";"

foreach($row in $file)
{
    $group = $web.SiteGroups[$row.SPSGroup]
    if($group -eq $null)
    {
        Write-Host -ForegroundColor Cyan "//creando el grupo de sitio '"$row.SPSGroup"'..." -NoNewline
        $web.SiteGroups.Add($row.SPSGroup, $web.Site.Owner, $web.Site.Owner, $row.SPSGroup)
        $group = $web.SiteGroups[$row.SPSGroup]     
    }
    Write-Host -ForegroundColor Cyan "//asignando permisos al grupo '"$row.SPSGroup"' de '"$row.Permission"'..." -NoNewline
    $roleAssignment = New-Object Microsoft.SharePoint.SPRoleAssignment($group)
    $roleDefinition = $web.Site.RootWeb.RoleDefinitions[$row.Permission]
    $roleAssignment.RoleDefinitionBindings.Add($roleDefinition)
    $web.RoleAssignments.Add($roleAssignment)
    $web.Update()    
}
}
}