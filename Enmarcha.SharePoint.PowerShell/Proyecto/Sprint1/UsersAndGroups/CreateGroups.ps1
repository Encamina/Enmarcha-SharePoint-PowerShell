Param
(
    [Parameter(Mandatory=$false)]
    [string]$GroupsFile = $(Read-Host -Prompt "Groups file"),
    [Parameter(Mandatory=$false)]  
    [string]$WebSiteUrl=  $(Read-Host -Prompt "Web site url")
)

#####################################################
# Script to create web site groups 
#####################################################


$snapin = Get-PSSnapin Microsoft.SharePoint.Powershoell -ErrorAction SilentlyContinue
if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }
#[Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint");


$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition


Write-Host -ForegroundColor Cyan "//comenzando";

Write-Host -ForegroundColor Gray "//abriendo sitio web " $WebSiteUrl
$web = Get-SPWeb($WebSiteUrl);

$file = Import-Csv -Path $groupsFile -Encoding UTF8 -Delimiter ";"

foreach($row in $file)
{
    $group = $web.SiteGroups[$row.SPSGroup]
    if($group -eq $null)
    {
        Write-Host -ForegroundColor Cyan "//creando grupo de sitio '"$row.SPSGroup"'..." -NoNewline

        $web.SiteGroups.Add($row.SPSGroup, $web.Site.Owner, $web.Site.Owner, $row.SPSGroup)
        $group = $web.SiteGroups[$row.SPSGroup]
        Write-Host -ForegroundColor Green "hecho"
    }

    Write-Host -ForegroundColor Cyan "//asignando permisos de '"$row.Permission"' al grupo '"$row.SPSGroup"'..." -NoNewline
    $roleAssignment = New-Object Microsoft.SharePoint.SPRoleAssignment($group)
    $roleDefinition = $web.Site.RootWeb.RoleDefinitions[$row.Permission]
    $roleAssignment.RoleDefinitionBindings.Add($roleDefinition)
    $web.RoleAssignments.Add($roleAssignment)
    $web.Update()
    Write-Host -ForegroundColor Green "hecho"
}

Write-Host -ForegroundColor Cyan "//terminado";