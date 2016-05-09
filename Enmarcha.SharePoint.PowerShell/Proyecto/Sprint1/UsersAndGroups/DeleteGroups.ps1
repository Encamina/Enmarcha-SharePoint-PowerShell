Param
(
    [Parameter(Mandatory=$false)]
    [string]$GroupsFile = $(Read-Host -Prompt "Groups file"),
    [Parameter(Mandatory=$false)]  
    [string]$WebSiteUrl=  $(Read-Host -Prompt "Web site url"),
    [Switch] $Force
)

#####################################################
# Script to delete web site groups 
#####################################################


$snapin = Get-PSSnapin Microsoft.SharePoint.Powershoell -ErrorAction SilentlyContinue
if ($snapin -eq $null) { Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue }
#[Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint");


$currentPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition


Write-Host -ForegroundColor Cyan "//comenzando";


if($Force.IsPresent)
{
    Write-Host -ForegroundColor Gray "//abriendo el sitio web " $WebSiteUrl
    $web = Get-SPWeb($WebSiteUrl);

    $file = Import-Csv -Path $groupsFile -Encoding UTF8 -Delimiter ";"

    foreach($row in $file)
    {
        $group = $web.SiteGroups[$row.SPSGroup]
        if($group -ne $null)
        {
            Write-Host -ForegroundColor Yellow "//eliminando el grupo de sitio '"$row.SPSGroup"'..." -NoNewline
            $web.SiteGroups.Remove($row.SPSGroup)
            $web.Update()
            Write-Host -ForegroundColor Green "hecho"
        }
    }
}
else
{
    Write-Host -ForegroundColor Red "//los grupos de sitio no se eliminiarán porque no se especificó el parámetro Force"
}

Write-Host -ForegroundColor Cyan "//finalizado";